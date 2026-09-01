import Foundation

/// The SVG icon sets shipped in the asset catalog, mirroring the folders in the recipe site's `img` directory.
enum IconCatalog {
    /// Asset names for every icon in `img/ingredients`.
    static let ingredients: [String] = [
        "aonori",
        "bacon",
        "bean-sprouts",
        "bell-pepper",
        "bouillon",
        "bread",
        "butter",
        "cabbage",
        "carrot",
        "cheese",
        "chicken",
        "curry-roux",
        "egg",
        "garlic",
        "ginger",
        "honey",
        "ketchup",
        "kimchi",
        "maple-syrup",
        "milk",
        "mushroom",
        "mustard",
        "noodles",
        "oil",
        "onion",
        "pepper",
        "pork",
        "rice",
        "sake",
        "salt",
        "sausage",
        "seafood",
        "sesame-oil",
        "soy-sauce",
        "spaghetti",
        "spring-onion",
        "sugar",
        "tomato",
        "water",
        "yakisoba-sauce",
    ]

    /// Asset names for every icon in `img/tools`.
    static let tools: [String] = [
        "bowl",
        "butter-knife",
        "chopsticks",
        "cutting-board",
        "grater",
        "knife",
        "lid",
        "measuring-cup",
        "measuring-spoons",
        "microwave",
        "pan",
        "peeler",
        "plate",
        "scissors",
        "slotted-spoon",
        "spatula",
    ]

    /// Turns a schema icon path such as `img/ingredients/garlic.svg` into an asset name.
    static func assetName(for path: String) -> String? {
        let name = (path as NSString).lastPathComponent.replacingOccurrences(of: ".svg", with: "")
        return name.isEmpty ? nil : name
    }

    /// The icon path a recipe file should carry for an ingredient asset.
    static func ingredientPath(for name: String) -> String {
        "img/ingredients/\(name).svg"
    }

    /// The icon path a recipe file should carry for a tool asset.
    static func toolPath(for name: String) -> String {
        "img/tools/\(name).svg"
    }

    /// Maps a model guess back onto an icon that actually exists, falling back to a sensible default.
    static func resolveIngredient(_ guess: String, itemName: String) -> String {
        resolve(guess, itemName: itemName, in: ingredients) ?? "salt"
    }

    /// Maps a model guess back onto a tool icon that actually exists.
    static func resolveTool(_ guess: String, itemName: String) -> String {
        resolve(guess, itemName: itemName, in: tools) ?? "pan"
    }

    private static func resolve(_ guess: String, itemName: String, in set: [String]) -> String? {
        let cleaned = (assetName(for: guess) ?? guess).lowercased()
        if set.contains(cleaned) { return cleaned }
        let haystack = itemName.lowercased()
        return set.first { haystack.contains($0.replacingOccurrences(of: "-", with: " ")) }
            ?? set.first { cleaned.contains($0) }
    }
}
