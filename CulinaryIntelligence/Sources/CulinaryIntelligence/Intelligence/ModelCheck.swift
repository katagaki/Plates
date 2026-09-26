import FoundationModels
import Foundation

/// Says hello to the model the cook picked, so a wrong key or a model that cannot be reached is
/// found before the first recipe rather than part way through it.
@MainActor
public enum ModelCheck {
    /// One model's answer, with the name it goes by.
    public struct Reply: Identifiable, Equatable, Sendable {
        public var id: String { name }
        public let name: String
        public let text: String
    }

    /// The greeting sent, shown as the cook's side of the exchange.
    public static var greeting: String { String(culinary: "Check.Prompt.Hello") }

    /// Why Apple Intelligence cannot run on this iPhone, or nil when it can.
    public static var appleUnavailableReason: LocalizedStringResource? {
        ModelPasses.appleUnavailableReason
    }

    /// Greets every model the picked provider runs. A remote provider has one for each role,
    /// and both are checked, since either can be the one the key does not reach. Granite is
    /// checked by its download, not here.
    public static func sayHello() async throws -> [Reply] {
        let settings = ModelSettings.shared
        guard settings.provider.isRemote else {
            if let reason = appleUnavailableReason {
                throw CheckError.unavailable(String(localized: reason))
            }
            let session = LanguageModelSession(instructions: instructions)
            return [Reply(name: "Apple Intelligence", text: try await ask(session))]
        }
        var replies: [Reply] = []
        for role in [ModelRole.generation, .verification] {
            guard let remote = settings.remoteModel(for: role) else {
                throw CheckError.unavailable(String(culinary: "Generate.Unavailable.KeyMissing"))
            }
            // The same model picked for both roles only needs asking once.
            guard !replies.contains(where: { $0.name == remote.model.name }) else { continue }
            let session = LanguageModelSession(model: remote, instructions: instructions)
            replies.append(Reply(name: remote.model.name, text: try await ask(session)))
        }
        return replies
    }

    private static var instructions: String { String(culinary: "Check.Prompt.Instructions") }

    private static func ask(_ session: LanguageModelSession) async throws -> String {
        try await session.respond(
            to: greeting,
            options: GenerationOptions(maximumResponseTokens: 200)
        )
        .content
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CheckError: LocalizedError {
        case unavailable(String)

        var errorDescription: String? {
            switch self {
            case let .unavailable(reason): reason
            }
        }
    }
}
