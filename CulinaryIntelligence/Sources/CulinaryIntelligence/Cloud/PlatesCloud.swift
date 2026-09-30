import CryptoKit
import DeviceCheck
import Foundation

/// What can go wrong reaching PlatesCloud, in words a cook can act on.
public enum CloudError: LocalizedError, Equatable {
    /// The app was built without the address of the Worker.
    case notConfigured
    /// This device cannot prove it is running Plates, which every request has to.
    case unsupported
    /// Today's allowance is used up.
    case limitReached
    case server(Int, String?)
    case noResponse

    public var errorDescription: String? {
        switch self {
        case .notConfigured: String(culinary: "Cloud.Error.NotConfigured")
        case .unsupported: String(culinary: "Cloud.Error.Unsupported")
        case .limitReached: String(culinary: "Cloud.Error.LimitReached")
        case let .server(code, message):
            String(format: String(culinary: "Cloud.Error.Server"),
                   message ?? HTTPURLResponse.localizedString(forStatusCode: code))
        case .noResponse: String(culinary: "Cloud.Error.NoResponse")
        }
    }
}

/// The idea Jev picked, and how many more picks are left today.
public struct CloudPick: Equatable, Sendable {
    public let index: Int
    public let remaining: Int
}

/// The Worker the app talks to: Gemma on Workers AI writes, and Jev picks an idea when the cook
/// asks it to. Every request is signed with an App Attest key, made and registered the first
/// time the app needs one, so the Worker only answers Plates on a real device.
@MainActor
public final class PlatesCloud {
    public static let shared = PlatesCloud()

    private let service = DCAppAttestService.shared
    private var attesting: Task<String, Error>?

    private static let keyAccount = "AppAttestKeyID"

    /// A debug build in Simulator, where App Attest does not run, talks to `npm run dev` in
    /// ../PlatesCloud unsigned. The Worker only allows that on localhost with `SKIP_APP_ATTEST`.
    #if DEBUG && targetEnvironment(simulator)
    private static let skipsAppAttest = true
    private static let fallbackURL = "http://localhost:8787"
    #else
    private static let skipsAppAttest = false
    private static let fallbackURL = ""
    #endif

    /// The Worker's address, written in when Xcode Cloud builds the app. Empty otherwise.
    private var baseURL: URL? {
        let trimmed = PlatesCloudAddress.url.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = trimmed.isEmpty ? Self.fallbackURL : trimmed
        return address.isEmpty ? nil : URL(string: address)
    }

    public var isConfigured: Bool { baseURL != nil }

    // MARK: - Writing

    /// Gemma's answer streamed back a piece at a time.
    func write(instructions: String, prompt: String, maximumTokens: Int = 1400) -> AsyncThrowingStream<String, Error> {
        let body = Self.chat(instructions: instructions, prompt: prompt, maximumTokens: maximumTokens, stream: true)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, _) = try await self.send("/v1/chat/completions", body: body)
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        guard payload != "[DONE]",
                              let data = payload.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(Chunk.self, from: data),
                              let text = chunk.choices.first?.delta.content, !text.isEmpty
                        else { continue }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Gemma's whole answer at once, for text that is read only once it is finished.
    func complete(instructions: String, prompt: String, maximumTokens: Int) async throws -> String {
        let body = Self.chat(instructions: instructions, prompt: prompt, maximumTokens: maximumTokens, stream: false)
        let data = try await Self.collect(try await send("/v1/chat/completions", body: body).0)
        guard let answer = try? JSONDecoder().decode(Completion.self, from: data),
              let text = answer.choices.first?.message.content else { throw CloudError.noResponse }
        return text
    }

    // MARK: - Deciding

    /// Asks Jev which of the ideas fits the cook's request best. A retry with the same request
    /// ID is answered from the first pick and not counted again.
    public func decide(
        requestID: String,
        request: String,
        ingredients: [String],
        tools: [String],
        ideas: [(title: String, summary: String)]
    ) async throws -> CloudPick {
        let body = try JSONSerialization.data(withJSONObject: [
            "requestId": requestID,
            "request": request,
            "ingredients": ingredients,
            "tools": tools,
            "ideas": ideas.map { ["title": $0.title, "summary": $0.summary] },
        ])
        let data = try await Self.collect(try await send("/v1/decide", body: body).0)
        guard let answer = try? JSONDecoder().decode(DecideAnswer.self, from: data) else { throw CloudError.noResponse }
        return CloudPick(index: answer.index, remaining: answer.remaining)
    }

    /// How many picks are left today.
    public func decisionsRemaining() async throws -> Int {
        let data = try await Self.collect(try await send("/v1/decide/remaining", body: Data("{}".utf8)).0)
        guard let answer = try? JSONDecoder().decode(Remaining.self, from: data) else { throw CloudError.noResponse }
        return answer.remaining
    }

    // MARK: - Requests

    /// Sends a signed request. A key the Worker no longer knows, as after the app is deleted and
    /// installed again, is dropped and a new one made, once.
    private func send(_ path: String, body: Data) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        do {
            return try await sendOnce(path, body: body)
        } catch let error as CloudError where error == .server(401, nil) {
            Keychain.write(nil, account: Self.keyAccount)
            return try await sendOnce(path, body: body)
        } catch let error as DCError where error.code == .invalidKey {
            Keychain.write(nil, account: Self.keyAccount)
            return try await sendOnce(path, body: body)
        }
    }

    private func sendOnce(_ path: String, body: Data) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        var request = try post(path, body: body)
        if !Self.skipsAppAttest {
            let keyID = try await keyID()
            let assertion = try await service.generateAssertion(keyID, clientDataHash: Data(SHA256.hash(data: body)))
            request.setValue(keyID, forHTTPHeaderField: "X-Plates-Key-Id")
            request.setValue(assertion.base64EncodedString(), forHTTPHeaderField: "X-Plates-Assertion")
        }
        request.setValue(String(TimeZone.current.secondsFromGMT() / 60), forHTTPHeaderField: "X-Plates-UTC-Offset")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw CloudError.noResponse }
        guard http.statusCode == 200 else {
            let message = try? JSONDecoder().decode(Failure.self, from: await Self.collect(bytes)).error
            switch http.statusCode {
            case 401: throw CloudError.server(401, nil)
            case 429: throw CloudError.limitReached
            default: throw CloudError.server(http.statusCode, message)
            }
        }
        return (bytes, http)
    }

    private func post(_ path: String, body: Data) throws -> URLRequest {
        guard let baseURL else { throw CloudError.notConfigured }
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    // MARK: - App Attest

    /// The key every request is signed with, made and registered with the Worker the first time
    /// one is needed. Requests that arrive while it is being made wait for the same key.
    private func keyID() async throws -> String {
        if let stored = Keychain.read(account: Self.keyAccount) { return stored }
        if let attesting { return try await attesting.value }
        let task = Task { try await self.attest() }
        attesting = task
        defer { attesting = nil }
        return try await task.value
    }

    private func attest() async throws -> String {
        guard service.isSupported else { throw CloudError.unsupported }
        let keyID = try await service.generateKey()
        let (challengeData, challengeResponse) = try await URLSession.shared.data(for: try post("/v1/challenge", body: Data()))
        let challengeStatus = (challengeResponse as? HTTPURLResponse)?.statusCode ?? 0
        guard challengeStatus == 200 else {
            throw CloudError.server(challengeStatus, try? JSONDecoder().decode(Failure.self, from: challengeData).error)
        }
        guard let challenge = try? JSONDecoder().decode(Challenge.self, from: challengeData).challenge
        else { throw CloudError.noResponse }
        let attestation = try await service.attestKey(keyID, clientDataHash: Data(SHA256.hash(data: Data(challenge.utf8))))
        let body = try JSONSerialization.data(withJSONObject: [
            "keyId": keyID,
            "attestation": attestation.base64EncodedString(),
            "challenge": challenge,
        ])
        let (data, response) = try await URLSession.shared.data(for: try post("/v1/attest", body: body))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 || status == 409 else {
            throw CloudError.server(status, try? JSONDecoder().decode(Failure.self, from: data).error)
        }
        Keychain.write(keyID, account: Self.keyAccount)
        return keyID
    }

    // MARK: - Bodies

    private static func chat(instructions: String, prompt: String, maximumTokens: Int, stream: Bool) -> Data {
        let object: [String: Any] = [
            "messages": [
                ["role": "system", "content": instructions],
                ["role": "user", "content": prompt],
            ],
            "max_tokens": maximumTokens,
            "temperature": 0.7,
            "stream": stream,
        ]
        return (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }

    private static func collect(_ bytes: URLSession.AsyncBytes) async throws -> Data {
        var data = Data()
        for try await byte in bytes { data.append(byte) }
        return data
    }

    private struct Chunk: Decodable {
        struct Choice: Decodable { let delta: Delta }
        struct Delta: Decodable { let content: String? }
        let choices: [Choice]
    }

    private struct Completion: Decodable {
        struct Choice: Decodable { let message: Message }
        struct Message: Decodable { let content: String? }
        let choices: [Choice]
    }

    private struct DecideAnswer: Decodable {
        let index: Int
        let remaining: Int
    }

    private struct Remaining: Decodable { let remaining: Int }
    private struct Challenge: Decodable { let challenge: String }
    private struct Failure: Decodable { let error: String }
}
