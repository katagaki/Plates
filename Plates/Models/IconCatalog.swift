import Foundation

/// The groups the ingredient catalog is browsed in. Every ingredient icon sits in exactly one,
/// and the flat list `IconCatalog.ingredients` is built from them.
nonisolated enum IngredientCategory: String, CaseIterable, Identifiable, Sendable {
    case vegetables, fruits, meat, seafood, dairy, grains, seasonings, sauces, baking, pantry

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .vegetables: "Ingredient.Category.Vegetables"
        case .fruits: "Ingredient.Category.Fruits"
        case .meat: "Ingredient.Category.Meat"
        case .seafood: "Ingredient.Category.Seafood"
        case .dairy: "Ingredient.Category.Dairy"
        case .grains: "Ingredient.Category.Grains"
        case .seasonings: "Ingredient.Category.Seasonings"
        case .sauces: "Ingredient.Category.Sauces"
        case .baking: "Ingredient.Category.Baking"
        case .pantry: "Ingredient.Category.Pantry"
        }
    }

    /// The ingredient assets in this group, in the order the picker shows them.
    var icons: [String] {
        switch self {
        case .vegetables:
            [
                "artichoke",
                "arugula",
                "asparagus",
                "bean-sprouts",
                "bell-pepper",
                "broccoli",
                "burdock",
                "cabbage",
                "carrot",
                "cauliflower",
                "celery",
                "chili",
                "corn",
                "cucumber",
                "daikon",
                "edamame",
                "eggplant",
                "enoki",
                "fennel",
                "garlic",
                "ginger",
                "green-beans",
                "kimchi",
                "leek",
                "lettuce",
                "lotus-root",
                "mushroom",
                "napa-cabbage",
                "onion",
                "peas",
                "potato",
                "pumpkin",
                "shimeji",
                "shiso",
                "spinach",
                "spring-onion",
                "sweet-potato",
                "tomato",
                "zucchini",
            ]
        case .fruits:
            [
                "apple",
                "avocado",
                "banana",
                "lemon",
                "lime",
                "orange",
                "strawberry",
                "yuzu",
            ]
        case .meat:
            [
                "bacon",
                "beef",
                "chicken",
                "guanciale",
                "ham",
                "minced-meat",
                "pancetta",
                "pork",
                "prosciutto",
                "sausage",
            ]
        case .seafood:
            [
                "anchovies",
                "clams",
                "fish",
                "salmon",
                "seafood",
                "shrimp",
                "squid",
                "tuna",
            ]
        case .dairy:
            [
                "butter",
                "cheese",
                "cream",
                "egg",
                "mascarpone",
                "milk",
                "mozzarella",
                "parmesan",
                "pecorino",
                "ricotta",
                "yogurt",
            ]
        case .grains:
            [
                "arborio-rice",
                "bread",
                "breadcrumbs",
                "couscous",
                "fusilli",
                "gnocchi",
                "lasagna",
                "macaroni",
                "mochi",
                "noodles",
                "oats",
                "panko",
                "penne",
                "polenta",
                "ramen",
                "rice",
                "rice-noodles",
                "spaghetti",
                "tortilla",
                "udon",
            ]
        case .seasonings:
            [
                "basil",
                "bay-leaf",
                "chili-flakes",
                "cinnamon",
                "coriander",
                "cumin",
                "curry-powder",
                "mint",
                "oregano",
                "paprika",
                "parsley",
                "pepper",
                "rosemary",
                "sage",
                "salt",
                "sesame-seeds",
                "shichimi",
                "thyme",
                "turmeric",
                "wasabi",
            ]
        case .sauces:
            [
                "balsamic-vinegar",
                "dashi",
                "fish-sauce",
                "gochujang",
                "honey",
                "ketchup",
                "maple-syrup",
                "mayonnaise",
                "mentsuyu",
                "mirin",
                "miso",
                "mustard",
                "oil",
                "olive-oil",
                "oyster-sauce",
                "pesto",
                "ponzu",
                "red-wine",
                "rice-vinegar",
                "sake",
                "sesame-oil",
                "soy-sauce",
                "sriracha",
                "tonkatsu-sauce",
                "vinegar",
                "water",
                "white-wine",
                "worcestershire",
                "yakisoba-sauce",
            ]
        case .baking:
            [
                "baking-powder",
                "brown-sugar",
                "chocolate",
                "cornstarch",
                "flour",
                "jam",
                "peanut-butter",
                "sugar",
                "vanilla",
                "yeast",
            ]
        case .pantry:
            [
                "aonori",
                "beans",
                "bouillon",
                "canned-tomatoes",
                "capers",
                "chickpeas",
                "coconut-milk",
                "curry-roux",
                "dried-shiitake",
                "katsuobushi",
                "kombu",
                "lentils",
                "natto",
                "nori",
                "nuts",
                "olives",
                "passata",
                "pine-nuts",
                "sun-dried-tomatoes",
                "tofu",
                "tomato-paste",
                "umeboshi",
                "wakame",
            ]
        }
    }
}

/// The SVG icon sets shipped in the asset catalog, mirroring the folders in the recipe site's `img` directory.
nonisolated enum IconCatalog {
    /// Asset names for every icon in `img/ingredients`, gathered from the browsing groups.
    static let ingredients: [String] = IngredientCategory.allCases.flatMap(\.icons).sorted()

    /// Asset names for every icon in `img/tools`.
    static let tools: [String] = [
        "baking-sheet",
        "blender",
        "bowl",
        "brush",
        "butter-knife",
        "can-opener",
        "chopsticks",
        "colander",
        "cutting-board",
        "foil",
        "fork",
        "garlic-press",
        "grater",
        "kettle",
        "knife",
        "ladle",
        "lid",
        "masher",
        "measuring-cup",
        "measuring-spoons",
        "microwave",
        "mortar-pestle",
        "oven",
        "oven-mitt",
        "pan",
        "paper-towel",
        "parchment-paper",
        "peeler",
        "plate",
        "pot",
        "rice-cooker",
        "rolling-pin",
        "saucepan",
        "scissors",
        "sieve",
        "skewer",
        "slotted-spoon",
        "spatula",
        "spoon",
        "steamer",
        "storage-container",
        "thermometer",
        "timer",
        "toaster",
        "tongs",
        "whisk",
        "wok",
        "wooden-spoon",
    ]

    /// Other words cooks use for an ingredient, mapped onto the asset that covers it.
    /// Looked up through `normalized`, so plurals and spacing do not need their own entries.
    private static let aliases: [String: String] = [
        "aubergine": "eggplant",
        "bonito flakes": "katsuobushi",
        "capsicum": "bell-pepper",
        "chilli": "chili",
        "chinese cabbage": "napa-cabbage",
        "cilantro": "coriander",
        "corn flour": "cornstarch",
        "courgette": "zucchini",
        "double cream": "cream",
        "gobo": "burdock",
        "green onion": "spring-onion",
        "ground beef": "minced-meat",
        "ground pork": "minced-meat",
        "hakusai": "napa-cabbage",
        "heavy cream": "cream",
        "katakuriko": "cornstarch",
        "mange tout": "peas",
        "negi": "spring-onion",
        "parmigiano": "parmesan",
        "peanut": "nuts",
        "prawn": "shrimp",
        "renkon": "lotus-root",
        "rocket": "arugula",
        "scallion": "spring-onion",
        "sea bream": "fish",
        "seaweed": "nori",
        "shiitake": "dried-shiitake",
        "stock cube": "bouillon",
        "togarashi": "shichimi",
        "white radish": "daikon",
        "yoghurt": "yogurt",
    ].reduce(into: [:]) { table, entry in table[normalized(entry.key)] = entry.value }

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

    /// How an asset name reads in a list: `spring-onion` becomes "Spring onion".
    static func displayName(for asset: String) -> String {
        let words = asset.replacingOccurrences(of: "-", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    /// Maps a model guess back onto an icon that actually exists, falling back to a sensible default.
    static func resolveIngredient(_ guess: String, itemName: String) -> String {
        resolve(guess, itemName: itemName, in: ingredients) ?? "salt"
    }

    /// Maps a model guess back onto a tool icon that actually exists.
    static func resolveTool(_ guess: String, itemName: String) -> String {
        resolve(guess, itemName: itemName, in: tools) ?? "pan"
    }

    // MARK: - Searching

    /// The ingredients a cook's search text turns up, closest match first. An empty search
    /// returns the whole catalog.
    static func ingredients(matching query: String) -> [String] {
        search(query, in: ingredients)
    }

    /// The tools a cook's search text turns up, closest match first.
    static func tools(matching query: String) -> [String] {
        search(query, in: tools)
    }

    /// The same search, kept in browsing groups. Groups with nothing left in them are dropped.
    static func categories(matching query: String) -> [(category: IngredientCategory, icons: [String])] {
        let matches = Set(ingredients(matching: query))
        return IngredientCategory.allCases.compactMap { category in
            let icons = category.icons.filter(matches.contains)
            return icons.isEmpty ? nil : (category, icons)
        }
    }

    /// The asset covering an ingredient name, when the catalog has one.
    static func ingredient(named name: String) -> String? {
        let cleaned = normalized(name)
        guard !cleaned.isEmpty else { return nil }
        if let alias = aliases[cleaned] { return alias }
        return ingredients.first { normalized($0) == cleaned }
    }

    /// The nearest ingredients to a name the catalog does not carry, for suggesting a swap.
    static func ingredientSuggestions(for name: String, limit: Int = 4) -> [String] {
        Array(search(name, in: ingredients).prefix(limit))
    }

    /// Ranks a set by how well each name matches the search text: whole word, then prefix,
    /// then anywhere in the name.
    private static func search(_ query: String, in set: [String]) -> [String] {
        let cleaned = normalized(query)
        guard !cleaned.isEmpty else { return set }
        let words = cleaned.split(separator: " ").map(String.init)
        var ranked: [(name: String, score: Int)] = []
        for name in set {
            let candidate = normalized(name)
            var score = 0
            if candidate == cleaned {
                score = 100
            } else if candidate.hasPrefix(cleaned) || cleaned.hasPrefix(candidate) {
                score = 60
            } else if candidate.contains(cleaned) || cleaned.contains(candidate) {
                score = 40
            } else {
                let candidateWords = Set(candidate.split(separator: " ").map(String.init))
                let shared = candidateWords.intersection(words)
                if !shared.isEmpty { score = 20 + shared.count }
            }
            if score > 0 { ranked.append((name, score)) }
        }
        if let alias = aliases[cleaned], !ranked.contains(where: { $0.name == alias }) {
            ranked.append((alias, 90))
        }
        return ranked
            .sorted { $0.score == $1.score ? $0.name < $1.name : $0.score > $1.score }
            .map(\.name)
    }

    /// Lowercased, punctuation free, and space separated, so `Spring Onions!` and
    /// `spring-onion` compare equal.
    private static func normalized(_ text: String) -> String {
        let stripped = text.lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : " " }
            .joined()
            .split(separator: " ")
            .map { $0.count > 3 && $0.hasSuffix("s") ? String($0.dropLast()) : String($0) }
        return stripped.joined(separator: " ")
    }

    private static func resolve(_ guess: String, itemName: String, in set: [String]) -> String? {
        let cleaned = (assetName(for: guess) ?? guess).lowercased()
        if set.contains(cleaned) { return cleaned }
        return search(itemName, in: set).first ?? search(cleaned, in: set).first
    }
}
