import Foundation
import Observation

/// Reads and writes recipe JSON in whichever folder the user picked, one file per recipe.
@MainActor
@Observable
final class RecipeStore {
    private(set) var recipes: [Recipe] = []
    private(set) var loadError: String?

    var location: StorageLocation {
        didSet {
            guard location != oldValue else { return }
            UserDefaults.standard.set(location.rawValue, forKey: Self.locationKey)
            load()
        }
    }

    private static let locationKey = "storageLocation"

    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return encoder
    }()

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.locationKey)
        let saved = stored.flatMap(StorageLocation.init(rawValue:)) ?? .onMyIPhone
        location = saved.isAvailable ? saved : .onMyIPhone
        load()
    }

    /// The folder currently in use, falling back to the local Documents folder when iCloud is unavailable.
    var directory: URL? {
        location.directory ?? StorageLocation.onMyIPhone.directory
    }

    func load() {
        loadError = nil
        guard let directory else {
            recipes = []
            loadError = String(localized: "Storage.Error.NoDirectory")
            return
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "json" }
            recipes = files.compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(Recipe.self, from: data)
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        } catch {
            recipes = []
            loadError = error.localizedDescription
        }
    }

    /// Writes a recipe out. New recipes get a unique id so a second "Tomato Egg" does not
    /// overwrite the first; existing ones keep the file they came from.
    @discardableResult
    func save(_ recipe: Recipe, isNew: Bool = false) -> Bool {
        guard let directory else { return false }
        var recipe = recipe
        if isNew {
            recipe.id = uniqueID(for: recipe)
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(recipe)
            try data.write(to: url(for: recipe.id, in: directory), options: .atomic)
            load()
            return true
        } catch {
            loadError = error.localizedDescription
            return false
        }
    }

    func delete(_ recipe: Recipe) {
        guard let directory else { return }
        try? FileManager.default.removeItem(at: url(for: recipe.id, in: directory))
        load()
    }

    func delete(atOffsets offsets: IndexSet, in list: [Recipe]) {
        for index in offsets {
            delete(list[index])
        }
    }

    /// Copies the recipes bundled with the app into the current folder, skipping ones already there.
    func addSampleRecipes() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let recipe = try? decoder.decode(Recipe.self, from: data),
                  !recipes.contains(where: { $0.id == recipe.id }) else { continue }
            save(recipe, isNew: true)
        }
    }

    private func url(for id: String, in directory: URL) -> URL {
        directory.appending(path: "\(id).json", directoryHint: .notDirectory)
    }

    private func uniqueID(for recipe: Recipe) -> String {
        let base = recipe.id.isEmpty ? Recipe.makeID(from: recipe.title) : recipe.id
        guard recipes.contains(where: { $0.id == base }) else { return base }
        var suffix = 2
        while recipes.contains(where: { $0.id == "\(base)-\(suffix)" }) {
            suffix += 1
        }
        return "\(base)-\(suffix)"
    }
}
