import Foundation
import Observation

/// Who writes the recipes. The cook picks one when the app is first opened, and again from the
/// menu whenever they like.
public nonisolated enum ModelProvider: String, CaseIterable, Identifiable, Sendable {
    /// Granite writes on device and Apple Intelligence sorts what it wrote.
    case granite
    /// Apple Intelligence does both.
    case apple
    case claude
    case openAI

    public var id: String { rawValue }

    /// Reached over the network with the cook's own API key.
    public var isRemote: Bool { self == .claude || self == .openAI }

    /// The models the cook can pick from, in the order the pickers list them.
    public var models: [RemoteModel] { RemoteModel.allCases.filter { $0.provider == self } }

    /// The company a remote model's requests are sent to.
    public var company: String? {
        switch self {
        case .claude: "Anthropic"
        case .openAI: "OpenAI"
        case .granite, .apple: nil
        }
    }
}

/// A model a remote provider serves, by the identifier its API takes.
public nonisolated enum RemoteModel: String, CaseIterable, Identifiable, Sendable {
    case claudeHaiku = "claude-haiku-4-5"
    case claudeSonnet = "claude-sonnet-5"
    case claudeOpus = "claude-opus-5-5"
    case gptAstra = "gpt-6-astra"
    case gptSol = "gpt-6-sol"
    case gptLuna = "gpt-6-luna"

    public var id: String { rawValue }

    public var provider: ModelProvider {
        switch self {
        case .claudeHaiku, .claudeSonnet, .claudeOpus: .claude
        case .gptAstra, .gptSol, .gptLuna: .openAI
        }
    }

    /// The product name, which reads the same in every language.
    public var name: String {
        switch self {
        case .claudeHaiku: "Claude Haiku 4.5"
        case .claudeSonnet: "Claude Sonnet 5"
        case .claudeOpus: "Claude Opus 5.5"
        case .gptAstra: "GPT-6 Astra"
        case .gptSol: "GPT-6 Sol"
        case .gptLuna: "GPT-6 Luna"
        }
    }

    /// Whether the request can ask for less thinking. Haiku 4.5 takes no effort setting.
    var takesEffort: Bool { self == .claudeSonnet || self == .claudeOpus }
}

/// The two jobs a remote provider's models are picked for.
public nonisolated enum ModelRole: Sendable {
    /// Writing a recipe and making the changes a cook asks for.
    case generation
    /// Sorting what was written into the recipe, and reading an edited one back.
    case verification
}

/// The model the cook picked, the models picked for each role, and the API keys. The choice is
/// kept in the app's defaults and the keys in the Keychain, so a key never lands in a backup of
/// the recipe folder.
@Observable
public final class ModelSettings {
    public static let shared = ModelSettings()

    public var provider: ModelProvider {
        didSet { defaults.set(provider.rawValue, forKey: Self.providerKey) }
    }

    private var picks: [String: RemoteModel]
    private var keys: [ModelProvider: String]

    @ObservationIgnored private let defaults = UserDefaults.standard

    private init() {
        provider = defaults.string(forKey: Self.providerKey).flatMap(ModelProvider.init) ?? .granite
        var picks: [String: RemoteModel] = [:]
        for provider in ModelProvider.allCases where provider.isRemote {
            for role in [ModelRole.generation, .verification] {
                let key = Self.pickKey(provider, role)
                picks[key] = defaults.string(forKey: key).flatMap(RemoteModel.init)
                    ?? Self.defaultModel(provider, role)
            }
        }
        self.picks = picks
        keys = Dictionary(uniqueKeysWithValues: ModelProvider.allCases.filter(\.isRemote).map {
            ($0, Keychain.read(account: $0.rawValue) ?? "")
        })
    }

    public func model(for role: ModelRole, of provider: ModelProvider) -> RemoteModel? {
        picks[Self.pickKey(provider, role)]
    }

    public func setModel(_ model: RemoteModel, for role: ModelRole) {
        let key = Self.pickKey(model.provider, role)
        picks[key] = model
        defaults.set(model.rawValue, forKey: key)
    }

    public func apiKey(for provider: ModelProvider) -> String {
        keys[provider] ?? ""
    }

    public func setAPIKey(_ key: String, for provider: ModelProvider) {
        keys[provider] = key
        Keychain.write(key.trimmingCharacters(in: .whitespacesAndNewlines), account: provider.rawValue)
    }

    /// True when the picked provider is remote and has a key to call it with.
    var hasKey: Bool {
        !apiKey(for: provider).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The model a pass in this role runs on, or nil when the picked provider is not remote or
    /// has no key yet. The model is asked for less thinking when it only checks, since a
    /// recipe is sorted in dozens of small passes.
    func remoteModel(for role: ModelRole) -> RemoteLanguageModel? {
        guard provider.isRemote, hasKey, let model = model(for: role, of: provider) else { return nil }
        return RemoteLanguageModel(
            model: model,
            apiKey: apiKey(for: provider).trimmingCharacters(in: .whitespacesAndNewlines),
            effort: role == .verification && model.takesEffort ? "low" : nil
        )
    }

    // MARK: - Defaults

    private static let providerKey = "Model.Provider"

    private static func pickKey(_ provider: ModelProvider, _ role: ModelRole) -> String {
        "Model.\(provider.rawValue).\(role == .generation ? "Generation" : "Verification")"
    }

    /// A capable model to write with and a quicker one to sort with.
    private static func defaultModel(_ provider: ModelProvider, _ role: ModelRole) -> RemoteModel {
        switch (provider, role) {
        case (.openAI, .generation): .gptSol
        case (.openAI, _): .gptLuna
        case (_, .generation): .claudeSonnet
        default: .claudeHaiku
        }
    }
}

/// The API keys, one Keychain item per provider. They are readable after the first unlock, so a
/// run carried on in the background can still send its requests.
private nonisolated enum Keychain {
    static let service = "com.tsubuzaki.Plates.APIKey"

    static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var item = query
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }
}
