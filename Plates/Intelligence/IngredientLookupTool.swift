import FoundationModels

/// Lets the model check an ingredient against the icon catalog while it writes the shopping
/// list, so it asks for something the app can draw and suggests a swap when it cannot.
struct IngredientLookupTool: FoundationModels.Tool {
    let name = "checkIngredient"
    let description = """
    Check whether an ingredient is in the app's catalog. Answers with the icon to use, or with \
    the closest ingredients to use instead when the catalog does not carry it.
    """

    @Generable
    struct Arguments {
        @Guide(description: "The ingredient to check, such as 'spring onion'")
        var ingredient: String
    }

    func call(arguments: Arguments) async throws -> String {
        let ingredient = arguments.ingredient
        if let asset = IconCatalog.ingredient(named: ingredient) {
            return "\(ingredient) is in the catalog. Use the icon \"\(asset)\"."
        }
        let suggestions = IconCatalog.ingredientSuggestions(for: ingredient)
        guard !suggestions.isEmpty else {
            return """
            \(ingredient) is not in the catalog and nothing comes close. Leave it out and \
            build the recipe from ingredients that are in the catalog.
            """
        }
        return """
        \(ingredient) is not in the catalog. The closest entries are \
        \(suggestions.map { "\"\($0)\"" }.joined(separator: ", ")). Use one of those as the \
        icon, or swap the ingredient for one of them.
        """
    }
}
