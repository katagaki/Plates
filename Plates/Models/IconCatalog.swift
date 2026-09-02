import Foundation

/// The SVG icon sets shipped in the asset catalog, mirroring the folders in the recipe site's `img` directory.
nonisolated enum IconCatalog {
    /// Asset names for every icon in `img/ingredients`.
    static let ingredients: [String] = [
        "aonori",
        "apple",
        "asparagus",
        "avocado",
        "bacon",
        "baking-powder",
        "banana",
        "basil",
        "bay-leaf",
        "bean-sprouts",
        "beans",
        "beef",
        "bell-pepper",
        "bouillon",
        "bread",
        "breadcrumbs",
        "broccoli",
        "brown-sugar",
        "butter",
        "cabbage",
        "canned-tomatoes",
        "carrot",
        "cauliflower",
        "celery",
        "cheese",
        "chicken",
        "chickpeas",
        "chili",
        "chili-flakes",
        "chocolate",
        "cinnamon",
        "clams",
        "coconut-milk",
        "coriander",
        "corn",
        "cornstarch",
        "couscous",
        "cream",
        "cucumber",
        "cumin",
        "curry-powder",
        "curry-roux",
        "daikon",
        "dried-shiitake",
        "egg",
        "eggplant",
        "fish",
        "fish-sauce",
        "flour",
        "garlic",
        "ginger",
        "gochujang",
        "green-beans",
        "ham",
        "honey",
        "jam",
        "katsuobushi",
        "ketchup",
        "kimchi",
        "leek",
        "lemon",
        "lentils",
        "lettuce",
        "lime",
        "macaroni",
        "maple-syrup",
        "mayonnaise",
        "milk",
        "minced-meat",
        "mint",
        "mirin",
        "miso",
        "mozzarella",
        "mushroom",
        "mustard",
        "noodles",
        "nori",
        "nuts",
        "oats",
        "oil",
        "olive-oil",
        "onion",
        "orange",
        "oregano",
        "oyster-sauce",
        "paprika",
        "parmesan",
        "parsley",
        "peanut-butter",
        "peas",
        "pepper",
        "pork",
        "potato",
        "pumpkin",
        "ramen",
        "rice",
        "rice-noodles",
        "rice-vinegar",
        "rosemary",
        "sake",
        "salmon",
        "salt",
        "sausage",
        "seafood",
        "sesame-oil",
        "sesame-seeds",
        "shrimp",
        "soy-sauce",
        "spaghetti",
        "spinach",
        "spring-onion",
        "squid",
        "sriracha",
        "strawberry",
        "sugar",
        "sweet-potato",
        "thyme",
        "tofu",
        "tomato",
        "tomato-paste",
        "tortilla",
        "tuna",
        "turmeric",
        "udon",
        "vanilla",
        "vinegar",
        "wakame",
        "water",
        "worcestershire",
        "yakisoba-sauce",
        "yeast",
        "yogurt",
        "zucchini",
    ]

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
        "cilantro": "coriander",
        "corn flour": "cornstarch",
        "courgette": "zucchini",
        "double cream": "cream",
        "green onion": "spring-onion",
        "ground beef": "minced-meat",
        "ground pork": "minced-meat",
        "heavy cream": "cream",
        "mange tout": "peas",
        "peanut": "nuts",
        "prawn": "shrimp",
        "rocket": "lettuce",
        "scallion": "spring-onion",
        "seaweed": "nori",
        "shiitake": "dried-shiitake",
        "stock cube": "bouillon",
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
