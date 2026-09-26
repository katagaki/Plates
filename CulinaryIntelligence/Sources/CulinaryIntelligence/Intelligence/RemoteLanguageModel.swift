import FoundationModels
import Foundation

/// Claude or OpenAI, reached with the cook's own key, as a model a `LanguageModelSession` runs
/// on. Every pass the app already has works through it unchanged: the session hands over the
/// transcript and, for a `@Generable` answer, its schema, and the reply is streamed back as the
/// JSON the session reads.
nonisolated struct RemoteLanguageModel: LanguageModel {
    typealias Executor = RemoteModelExecutor

    let model: RemoteModel
    let apiKey: String
    /// How hard a Claude model thinks, when it is told. Left to the model otherwise.
    let effort: String?

    /// Tools are not passed on, so a pass that offers one runs without it, as it does on the
    /// cloud fallback.
    var capabilities: LanguageModelCapabilities { LanguageModelCapabilities([.guidedGeneration]) }

    var executorConfiguration: RemoteModelExecutor.Configuration {
        RemoteModelExecutor.Configuration(model: model, apiKey: apiKey, effort: effort)
    }
}

nonisolated struct RemoteModelExecutor: LanguageModelExecutor {
    struct Configuration: Hashable, Sendable {
        var model: RemoteModel
        var apiKey: String
        var effort: String?
    }

    typealias Model = RemoteLanguageModel

    private let configuration: Configuration

    init(configuration: Configuration) throws {
        self.configuration = configuration
    }

    func respond(
        to request: LanguageModelExecutorGenerationRequest,
        model: RemoteLanguageModel,
        streamingInto channel: LanguageModelExecutorGenerationChannel
    ) async throws {
        let provider = configuration.model.provider
        let urlRequest = try provider == .claude
            ? anthropicRequest(for: request)
            : openAIRequest(for: request)
        let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw RemoteModelError.noResponse }
        guard http.statusCode == 200 else {
            var body = Data()
            for try await byte in bytes { body.append(byte) }
            throw RemoteModelError.server(http.statusCode, Self.errorMessage(in: body))
        }
        var answered = false
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard payload != "[DONE]",
                  let data = payload.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            guard let text = try Self.text(in: event, from: provider), !text.isEmpty else { continue }
            answered = true
            // The APIs count tokens per response, not per piece, so a piece is counted as
            // roughly what its length comes to.
            await channel.send(.response(action: .appendText(text, tokenCount: max(1, text.count / 4))))
        }
        guard answered else { throw RemoteModelError.noResponse }
    }

    // MARK: - Requests

    /// The most a reply may run to. Passes on device are held far shorter, but a remote model
    /// may think before it answers, and the thinking counts against this too.
    private static let maximumTokens = 16_000

    private func anthropicRequest(for request: LanguageModelExecutorGenerationRequest) throws -> URLRequest {
        let conversation = Self.conversation(in: request.transcript)
        var body: [String: Any] = [
            "model": configuration.model.rawValue,
            "max_tokens": Self.maximumTokens,
            "stream": true,
            "messages": conversation.messages.map { ["role": $0.role, "content": $0.text] },
        ]
        if !conversation.system.isEmpty {
            body["system"] = conversation.system
        }
        var output: [String: Any] = [:]
        if let schema = request.schema {
            output["format"] = ["type": "json_schema", "schema": try Self.strictSchema(schema)]
        }
        if let effort = configuration.effort {
            output["effort"] = effort
        }
        if !output.isEmpty {
            body["output_config"] = output
        }
        var urlRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        urlRequest.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        return try Self.post(urlRequest, body: body)
    }

    private func openAIRequest(for request: LanguageModelExecutorGenerationRequest) throws -> URLRequest {
        let conversation = Self.conversation(in: request.transcript)
        var body: [String: Any] = [
            "model": configuration.model.rawValue,
            "max_output_tokens": Self.maximumTokens,
            "stream": true,
            "input": conversation.messages.map { ["role": $0.role, "content": $0.text] },
        ]
        if !conversation.system.isEmpty {
            body["instructions"] = conversation.system
        }
        if let schema = request.schema {
            body["text"] = [
                "format": [
                    "type": "json_schema",
                    "name": "answer",
                    "schema": try Self.strictSchema(schema),
                    "strict": true,
                ],
            ]
        }
        var urlRequest = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        return try Self.post(urlRequest, body: body)
    }

    private static func post(_ request: URLRequest, body: [String: Any]) throws -> URLRequest {
        var request = request
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// The transcript as a system prompt and the turns after it. A session in this app asks
    /// once, so this is usually the instructions and one prompt.
    private static func conversation(in transcript: Transcript) -> (system: String, messages: [(role: String, text: String)]) {
        var system: [String] = []
        var messages: [(role: String, text: String)] = []
        for entry in transcript {
            switch entry {
            case let .instructions(instructions):
                system.append(text(of: instructions.segments))
            case let .prompt(prompt):
                messages.append(("user", text(of: prompt.segments)))
            case let .response(response):
                messages.append(("assistant", text(of: response.segments)))
            default:
                break
            }
        }
        return (system.joined(separator: "\n\n"), messages)
    }

    private static func text(of segments: [Transcript.Segment]) -> String {
        segments.compactMap { segment -> String? in
            switch segment {
            case let .text(text): text.content
            case let .structure(structure): structure.content.jsonString
            default: nil
            }
        }
        .joined(separator: "\n")
    }

    /// The session's schema in the form both APIs take. It is JSON Schema already, with every
    /// object closed and every property required, but it carries keys of its own and limits the
    /// APIs turn down, so those are taken out. The counts and ranges a pass asks for are in its
    /// descriptions too, which is where a model this size reads them.
    private static func strictSchema(_ schema: GenerationSchema) throws -> Any {
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(schema))
        return stripped(object)
    }

    private static let unsupportedKeywords: Set<String> = [
        "x-order", "title", "minItems", "maxItems", "minimum", "maximum",
        "exclusiveMinimum", "exclusiveMaximum", "multipleOf", "minLength", "maxLength", "pattern",
    ]

    /// Takes the unsupported keywords out, leaving property names alone: a recipe's `title`
    /// is a property, not the schema keyword.
    private static func stripped(_ value: Any, namesProperties: Bool = false) -> Any {
        if let dictionary = value as? [String: Any] {
            var kept: [String: Any] = [:]
            for (key, child) in dictionary {
                if namesProperties {
                    kept[key] = stripped(child)
                } else if !unsupportedKeywords.contains(key) {
                    kept[key] = stripped(child, namesProperties: key == "properties" || key == "$defs")
                }
            }
            return kept
        }
        if let array = value as? [Any] {
            return array.map { stripped($0) }
        }
        return value
    }

    // MARK: - Replies

    /// The text a streamed event carries, if any. An event that says the request failed is
    /// thrown with the reason the server gave.
    private static func text(in event: [String: Any], from provider: ModelProvider) throws -> String? {
        let type = event["type"] as? String
        if provider == .claude {
            switch type {
            case "content_block_delta":
                let delta = event["delta"] as? [String: Any]
                return delta?["type"] as? String == "text_delta" ? delta?["text"] as? String : nil
            case "error":
                throw RemoteModelError.server(nil, (event["error"] as? [String: Any])?["message"] as? String)
            default:
                return nil
            }
        }
        switch type {
        case "response.output_text.delta":
            return event["delta"] as? String
        case "response.failed":
            let response = event["response"] as? [String: Any]
            throw RemoteModelError.server(nil, (response?["error"] as? [String: Any])?["message"] as? String)
        case "error":
            throw RemoteModelError.server(nil, event["message"] as? String)
        default:
            return nil
        }
    }

    /// Both APIs put the reason for a failed request in `error.message`.
    private static func errorMessage(in body: Data) -> String? {
        let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        return (object?["error"] as? [String: Any])?["message"] as? String
    }
}

/// What can go wrong reaching a remote model, in words a cook can act on.
nonisolated enum RemoteModelError: LocalizedError {
    /// The server turned the request down, with its status code and reason when it gave them.
    case server(Int?, String?)
    case noResponse

    var errorDescription: String? {
        switch self {
        case let .server(code, message):
            let reason = message ?? code.map { HTTPURLResponse.localizedString(forStatusCode: $0) } ?? ""
            return String(format: String(culinary: "Remote.Error.Server"), reason)
        case .noResponse:
            return String(culinary: "Remote.Error.NoResponse")
        }
    }
}
