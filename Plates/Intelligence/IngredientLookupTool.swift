import FoundationModels
import Foundation

/// Lets the model check an ingredient against the icon catalog while it writes the shopping
/// list, so it asks for something the app can draw and suggests a swap when it cannot. The
/// answers are written in the language the recipe is being written in, and the icon names in
/// them are catalog data, so they stay as the catalog spells them.
struct IngredientLookupTool: FoundationModels.Tool {
    /// What the cook said they have. Empty when they did not narrow it down, and the whole
    /// catalog is fair game.
    let available: [String]

    let name = "checkIngredient"
    var description: String { String(localized: "Generate.Lookup.Description") }

    @Generable
    struct Arguments {
        @Guide(description: "The ingredient to check, such as 'spring onion'")
        var ingredient: String
    }

    func call(arguments: Arguments) async throws -> String {
        let ingredient = arguments.ingredient
        let asset = IconCatalog.ingredient(named: ingredient)
        if let asset, available.isEmpty || available.contains(asset) {
            return text("Generate.Lookup.InCatalog", ingredient, asset)
        }
        let suggestions = available.isEmpty
            ? IconCatalog.ingredientSuggestions(for: ingredient)
            : Array(available.prefix(8))
        guard !suggestions.isEmpty else {
            return text("Generate.Lookup.Nothing", ingredient)
        }
        let closest = suggestions.map { "\"\($0)\"" }.joined(separator: ", ")
        if available.isEmpty {
            return text("Generate.Lookup.Closest", ingredient, closest)
        }
        return text("Generate.Lookup.NotAvailable", ingredient, closest)
    }

    private func text(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        String(format: String(localized: key), arguments: arguments)
    }
}
