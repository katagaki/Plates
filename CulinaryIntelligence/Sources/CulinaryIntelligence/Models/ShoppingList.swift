import Foundation

/// What a recipe needs that the kitchen does not have: the required ingredients and tools whose
/// icons are missing from the inventory. Optional lines are left off, since the dish is made
/// without them.
public nonisolated struct ShoppingList: Hashable {
    public let ingredients: [Ingredient]
    public let tools: [Tool]

    /// `inventoryIngredients` and `inventoryTools` are catalog names, such as `spring-onion`.
    public init(recipe: Recipe, inventoryIngredients: [String], inventoryTools: [String]) {
        let haveIngredients = Set(inventoryIngredients)
        let haveTools = Set(inventoryTools)
        ingredients = Self.unique(recipe.ingredientList(in: .ingredients).filter {
            !Self.has($0.icon, in: haveIngredients)
        })
        tools = Self.unique(recipe.toolList(in: .tools).filter {
            !Self.has($0.icon, in: haveTools)
        })
    }

    public var isEmpty: Bool { ingredients.isEmpty && tools.isEmpty }

    private static func has(_ path: String, in inventory: Set<String>) -> Bool {
        IconCatalog.iconName(for: path).map(inventory.contains) ?? false
    }

    /// A line the recipe writes twice is only listed once.
    private static func unique<Item: Identifiable>(_ items: [Item]) -> [Item] {
        var seen = Set<Item.ID>()
        return items.filter { seen.insert($0.id).inserted }
    }
}
