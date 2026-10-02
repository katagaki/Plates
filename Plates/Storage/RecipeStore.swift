import CulinaryIntelligence
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

    /// Moves complete recipes from the App Group inbox into the selected storage location.
    /// A file stays in the inbox if saving fails, so the next app launch can retry it.
    func importSharedRecipes() {
        do {
            for pending in try SharedRecipeInbox.pendingRecipes() {
                var recipe = pending.recipe
                recipe.ingredients.supermarket = importedIcons(in: recipe.ingredients.supermarket)
                recipe.ingredients.general = importedIcons(in: recipe.ingredients.general)
                recipe.ingredients.optional = importedIcons(in: recipe.ingredients.optional)
                guard save(recipe, isNew: true) else { return }
                try SharedRecipeInbox.remove(pending.url)
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func importedIcons(in ingredients: [Ingredient]?) -> [Ingredient]? {
        ingredients?.map { ingredient in
            var ingredient = ingredient
            if ingredient.icon.isEmpty,
               let name = IconCatalog.ingredient(named: ingredient.item) {
                ingredient.icon = IconCatalog.ingredientPath(for: name)
            }
            return ingredient
        }
    }

    /// Writes a recipe out. New recipes get a unique id so a second "Tomato Egg" does not
    /// overwrite the first; existing ones keep the file they came from. A new recipe that came
    /// without a dish, from the share extension or the samples, has one worked out before it is
    /// written, and Jev's answer replaces it once it comes back, the way a generated recipe's
    /// dish is asked.
    @discardableResult
    func save(_ recipe: Recipe, isNew: Bool = false) -> Bool {
        guard let directory else { return false }
        var recipe = recipe
        if isNew {
            recipe.id = uniqueID(for: recipe)
            if recipe.dish == nil {
                recipe.dish = Dish.planned(for: recipe)
                askDish(for: recipe)
            }
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try recipe.fileContents().write(to: url(for: recipe.id, in: directory), options: .atomic)
            load()
            return true
        } catch {
            loadError = error.localizedDescription
            return false
        }
    }

    /// Asks for a new recipe's dish and writes it in, unless its dish was redrawn while Jev
    /// was being asked.
    private func askDish(for recipe: Recipe) {
        Task {
            let dish = await Dish.asked(for: recipe)
            guard dish != recipe.dish, var current = recipes.first(where: { $0.id == recipe.id }),
                  current.dish == recipe.dish else { return }
            current.dish = dish
            save(current)
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

    /// Copies the recipes bundled with the app into the current folder, but only into an empty
    /// one. The samples ship in every language the app is written in, so the reader's language is
    /// the one that gets copied over.
    func addSampleRecipes() {
        guard recipes.isEmpty else { return }
        let language = Bundle.main.preferredLocalizations.first ?? "en-US"
        let urls = Bundle.main.urls(
            forResourcesWithExtension: "json",
            subdirectory: nil,
            localization: language
        ) ?? []
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let recipe = try? decoder.decode(Recipe.self, from: data) else { continue }
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
