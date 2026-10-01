import Foundation

extension Dish {
    /// The dish a recipe makes, worked out from what the recipe already says: the catalog icons
    /// of its ingredients and tools, which hold in any language, and the words of its title and
    /// steps, read in English and Japanese. The grain or the sauce becomes the food the dish is
    /// built on, the vessel follows from that and from the tools, and the ingredients that can
    /// still be seen once the dish is served are laid on top, each cut the way the recipe cuts it.
    public static func planned(for recipe: Recipe) -> Dish {
        DishPlanner(recipe).dish
    }
}

private nonisolated struct DishPlanner {
    private struct Entry {
        let asset: String
        let section: Section
        /// The entry's own words and every step point that names it, lowercased, for reading
        /// how it is cut.
        let text: String
    }

    private enum Section {
        case main, optional
    }

    private let recipe: Recipe
    private let entries: [Entry]
    private let assets: Set<String>
    private let tools: Set<String>
    private let title: String
    private let method: String
    private let finish: String

    init(_ recipe: Recipe) {
        self.recipe = recipe
        title = recipe.title.lowercased()
        method = recipe.steps.flatMap { [$0.title] + $0.points }.joined(separator: "\n").lowercased()
        finish = recipe.steps.last.map { ([$0.title] + $0.points).joined(separator: "\n") }?.lowercased() ?? ""
        tools = Set(recipe.tools.compactMap { IconCatalog.iconName(for: $0.icon) })
        let points = recipe.steps.flatMap(\.points).map { $0.lowercased() }
        var seen = Set<String>()
        var entries: [Entry] = []
        let sections: [([Ingredient]?, Section)] = [
            (recipe.ingredients.supermarket, .main),
            (recipe.ingredients.general, .main),
            (recipe.ingredients.optional, .optional),
        ]
        for (list, section) in sections {
            for ingredient in list ?? [] {
                guard let asset = IconCatalog.iconName(for: ingredient.icon), seen.insert(asset).inserted else { continue }
                let item = ingredient.item.lowercased()
                let mentions = points.filter { !item.isEmpty && $0.contains(item) }
                let text = ([ingredient.item, ingredient.amount, ingredient.note ?? ""].map { $0.lowercased() } + mentions)
                    .joined(separator: "\n")
                entries.append(Entry(asset: asset, section: section, text: text))
            }
        }
        self.entries = entries
        assets = seen
    }

    // MARK: Words

    private static let soupWords = [
        "soup", "ramen", "udon", "soba", "pho", "broth", "stew", "chowder", "laksa", "noodle soup",
        "スープ", "ラーメン", "うどん", "そば", "蕎麦", "汁", "鍋", "シチュー", "ポタージュ", "フォー",
    ]
    private static let friedRiceWords = [
        "fried rice", "garlic rice", "butter rice", "nasi goreng", "pilaf", "pilau", "paella",
        "チャーハン", "炒飯", "焼き飯", "焼飯", "ピラフ", "パエリア", "ガーリックライス", "バターライス",
    ]
    private static let bowlWords = ["bowl", "donburi", "bibimbap", "poke", "丼", "どんぶり", "ビビンバ"]
    private static let saladWords = ["salad", "サラダ"]
    private static let mashWords = ["mash", "マッシュ"]
    private static let meltWords = [
        "gratin", "melt", "cheese toast", "mac and cheese", "macaroni cheese", "lasagn", "pizza", "quesadilla",
        "グラタン", "ドリア", "チーズ焼き", "とろける", "ピザ",
    ]
    private static let omeletteWords = ["omelet", "frittata", "tamagoyaki", "okonomiyaki", "オムレツ", "卵焼き", "玉子焼き", "お好み焼き", "オムライス"]
    private static let curryWords = ["curry", "カレー"]

    /// Words that say how an ingredient is cut, each with the variant names they point to, in
    /// the order they are tried.
    private static let cuts: [(words: [String], variants: [String])] = [
        (["fried egg", "sunny", "目玉焼き"], ["fried"]),
        (["boiled egg", "soft-boiled", "hard-boiled", "jammy", "ゆで卵", "ゆでたまご", "半熟", "煮卵", "味玉"], ["boiled"]),
        (["yolk", "卵黄", "黄身"], ["yolk"]),
        (["scrambl", "beaten", "炒り卵", "いり卵", "溶き", "ふわふわ"], ["scrambled"]),
        (["chip", "crisp", "チップ", "カリカリ"], ["chips", "crispy", "bits", "crushed"]),
        (["julienne", "matchstick", "shred", "千切り", "せん切り", "細切り"], ["julienne", "shredded", "strips", "slivers", "sliced"]),
        (["ring", "輪切り", "小口切り", "小口"], ["rings", "coins", "slices"]),
        (["dice", "cube", "cubed", "角切り", "さいの目", "サイコロ"], ["diced", "cubes", "chunks", "lardons"]),
        (["wedge", "quarter", "くし切り", "くし形"], ["wedges", "segments", "quartered", "quarters", "halves"]),
        (["half", "halve", "半分"], ["halves", "half"]),
        (["grate", "おろし", "すりおろ"], ["grated", "crumbs"]),
        (["mince", "chop", "みじん"], ["chopped", "minced", "diced", "crumbled", "bits", "flecks", "snipped"]),
        (["tear", "torn", "ちぎ"], ["torn", "leaves", "chopped"]),
        (["slice", "sliced", "薄切り", "スライス", "そぎ切り"], ["sliced", "slices", "coins", "half-moons", "rashers", "sashimi", "ribbons", "strips"]),
        (["chunk", "bite-size", "一口大", "ぶつ切り", "乱切り"], ["chunks", "pieces", "cubes", "chopped"]),
        (["crumbl", "ほぐ"], ["crumbled", "flaked"]),
        (["melt", "とろけ"], ["melted"]),
    ]

    private func says(_ words: [String], in text: String) -> Bool {
        words.contains { text.contains($0) }
    }

    /// Whether the title or the last step names an ingredient, in the reader's language or in
    /// English. What the last step names is what goes on top as the dish is served.
    private func named(_ asset: String, in text: String) -> Bool {
        let names = [IconCatalog.displayName(for: asset), IconCatalog.englishName(for: asset)]
            .map { $0.lowercased() }
            .filter { $0.count > 1 }
        return names.contains { text.contains($0) }
    }

    private func isGrain(_ asset: String) -> Bool {
        IngredientCategory.grains.icons.contains(asset)
    }

    // MARK: Planning

    var dish: Dish {
        var random = SeededRandom(recipe.id)
        var consumed = Set<String>()
        var fills: [DishLayer] = []
        let soupy = says(Self.soupWords, in: title)
        let visible = entries.filter { !DishParts.isHidden($0.asset) && !DishParts.variants(of: $0.asset).isEmpty }

        // The food the dish is built on.
        let grain = visible.first { $0.section == .main && isGrain($0.asset) && hasFill($0.asset) }
        let sauce = Self.sauces.first { asset in
            visible.contains { $0.asset == asset && $0.section == .main } && !(grain.map { Self.pastaTakesSauce($0.asset) } ?? false)
        }
        var kind = vesselKind(grain: grain?.asset, sauce: sauce, soupy: soupy)

        if let grain {
            let variant = grainVariant(grain.asset, kind: kind, soupy: soupy, consumed: &consumed)
            if let variant {
                fills.append(DishLayer(grain.asset, variant))
                consumed.insert(grain.asset)
            }
        }
        if let sauce, let variant = fillVariant(sauce, kind: kind, roles: [.sauce, .soup]) {
            fills.append(DishLayer(sauce, variant))
            consumed.insert(sauce)
        }
        if fills.isEmpty, soupy {
            let soup = Self.soups.first { assets.contains($0) } ?? "dashi"
            if let variant = fillVariant(soup, kind: "bowl", roles: [.soup]) {
                kind = "bowl"
                fills.append(DishLayer(soup, variant))
                consumed.insert(soup)
            }
        }
        if fills.isEmpty, says(Self.omeletteWords, in: title), assets.contains("egg") {
            kind = "plate"
            fills.append(DishLayer("egg", "omelette"))
            consumed.insert("egg")
        }
        if fills.isEmpty, says(Self.mashWords, in: title),
           let mash = visible.first(where: { DishParts.part($0.asset, "mash") != nil }) {
            fills.append(DishLayer(mash.asset, "mash"))
            consumed.insert(mash.asset)
        }
        if fills.isEmpty, let bed = visible.first(where: { $0.section == .main && DishParts.part($0.asset, "bed") != nil }),
           says(Self.saladWords, in: title) || !visible.contains(where: { isGrain($0.asset) }) {
            if kind == "pan" || kind == "pot" { kind = "plate" }
            fills.append(DishLayer(bed.asset, "bed"))
            consumed.insert(bed.asset)
        }
        if says(Self.meltWords, in: title) || says(Self.meltWords, in: finish),
           let cheese = visible.first(where: { DishParts.part($0.asset, "melted") != nil }), !fills.isEmpty {
            fills.append(DishLayer(cheese.asset, "melted"))
            consumed.insert(cheese.asset)
        }

        // An egg beaten into a batter or a coating is not seen on the plate.
        if assets.contains("panko") || assets.contains("breadcrumbs") || assets.contains("flour") && !says(Self.omeletteWords, in: title) {
            if !(entries.first { $0.asset == "egg" }.map { says(["fried egg", "目玉焼き", "boiled", "ゆで卵"], in: $0.text) } ?? false) {
                consumed.insert("egg")
            }
        }

        let base = fills.first.map { $0.ingredient }
        let pieces = toppings(on: base, kind: kind, visible: visible, consumed: consumed)
        let vessel = pickVessel(kind: kind, under: fills.first, random: &random)
        return Dish(vessel: vessel, layers: fills + pieces)
    }

    /// Sauces that fill a region of their own, most telling first.
    private static let sauces = [
        "curry-roux", "coconut-milk", "lentils", "passata", "canned-tomatoes", "pesto", "tianmianjiang", "beans",
    ]
    private static let soups = ["miso", "doenjang", "pumpkin", "butternut-squash", "dashi"]

    /// Pasta that takes its sauce into its own fill, so the sauce is not drawn beside it.
    private static func pastaTakesSauce(_ asset: String) -> Bool {
        ["spaghetti", "fettuccine", "penne", "rigatoni", "fusilli", "macaroni", "orzo", "gnocchi", "ravioli", "lasagna"]
            .contains(asset)
    }

    private func hasFill(_ asset: String) -> Bool {
        DishParts.variants(of: asset).contains { $0.part.kind == .fill }
    }

    private func vesselKind(grain: String?, sauce: String?, soupy: Bool) -> String {
        if soupy { return "bowl" }
        if says(Self.bowlWords, in: title) { return "bowl" }
        if says(Self.curryWords, in: title), sauce != nil { return "plate" }
        if let grain, !DishParts.variants(of: grain).contains(where: { $0.part.kind == .fill && ($0.part.vessels ?? []).contains("plate") }) {
            return "bowl"
        }
        if ["bread", "tortilla", "pita", "rice-paper"].contains(grain) { return "plate" }
        let hasPlate = tools.contains("plate")
        let hasBowl = tools.contains("bowl")
        if !hasPlate, !hasBowl, tools.contains("pan") || tools.contains("wok") { return "pan" }
        if hasBowl, !hasPlate, grain != nil { return "bowl" }
        return "plate"
    }

    /// The variant a grain is drawn as: fried rice for fried rice, broth for noodle soup, the
    /// pasta in the sauce the recipe gives it.
    private func grainVariant(_ grain: String, kind: String, soupy: Bool, consumed: inout Set<String>) -> String? {
        switch grain {
        case "rice":
            if says(Self.friedRiceWords, in: title) || tools.contains("wok") && !says(Self.curryWords, in: title) {
                let red = ["kimchi", "gochujang", "ketchup", "gochugaru", "canned-tomatoes", "tomato-paste"].contains { assets.contains($0) }
                return red ? "red-fried" : "fried"
            }
            return kind == "bowl" || kind == "pot" ? "bowl" : "mound"
        case "spaghetti", "fettuccine":
            let tomato = ["tomato", "passata", "canned-tomatoes", "tomato-paste", "ketchup"].first { assets.contains($0) }
            if grain == "spaghetti", let tomato {
                consumed.insert(tomato)
                return "tomato"
            }
            let creamy = ["cream", "egg", "milk", "cream-cheese", "mascarpone"].filter { assets.contains($0) }
            if grain == "spaghetti", !creamy.isEmpty {
                consumed.formUnion(creamy)
                return "creamy"
            }
            return fillVariant(grain, kind: kind, roles: [.base])
        case "bread":
            if ["egg", "milk"].allSatisfy({ assets.contains($0) }) && tools.contains("pan") || title.contains("french toast") || title.contains("フレンチトースト") {
                consumed.formUnion(["egg", "milk", "cream"])
                return "french-toast"
            }
            return tools.contains("toaster") || tools.contains("oven") || title.contains("toast") || title.contains("トースト") ? "toast" : "slice"
        default:
            if soupy, DishParts.part(grain, "broth") != nil { return "broth" }
            return fillVariant(grain, kind: kind, roles: [.base])
        }
    }

    /// The lowest ranked fill of an ingredient that goes in this kind of vessel.
    private func fillVariant(_ asset: String, kind: String, roles: Set<DishParts.Role>) -> String? {
        let fills = DishParts.variants(of: asset).filter { $0.part.kind == .fill && roles.contains($0.part.role ?? .base) }
        return (fills.first { ($0.part.vessels ?? []).contains(kind) } ?? fills.first)?.name
    }

    // MARK: Toppings

    /// Ingredients that are cooked into nearly every dish and only seen when the dish is named
    /// for them or served with them on top.
    private static let aromatics: Set<String> = ["onion", "garlic", "ginger", "shallot", "butter", "milk", "cream", "red-onion"]

    private func toppings(on base: String?, kind: String, visible: [Entry], consumed: Set<String>) -> [DishLayer] {
        var scattered: [DishLayer] = []
        var centered: [DishLayer] = []
        var garnish: [DishLayer] = []
        let onBread = ["bread", "egg", "tofu", "yogurt", "tortilla", "pita"].contains(base ?? "")

        for entry in visible where !consumed.contains(entry.asset) {
            let shown = named(entry.asset, in: title) || named(entry.asset, in: finish)
            let pantry = IconCatalog.shelf(of: entry.asset) == .pantry
            if entry.section == .optional || pantry || Self.aromatics.contains(entry.asset) {
                let butterOnBread = entry.asset == "butter" && onBread
                guard shown || butterOnBread else { continue }
            }
            guard let (variant, part) = pieceVariant(entry) else { continue }
            let layer = DishLayer(entry.asset, variant)
            switch part.tier ?? .scattered {
            case .scattered: scattered.append(layer)
            case .centered: centered.append(layer)
            case .garnish: garnish.append(layer)
            }
        }

        scattered = Array(scattered.prefix(3))
        let share = [1.0, 1.0, 0.8, 0.6][min(scattered.count, 3)] * (kind == "plate" || kind == "pan" ? 1 : 1.1)
        scattered = scattered.map { layer in
            let count = DishParts.part(layer.ingredient, layer.variant)?.count ?? 4
            return DishLayer(layer.ingredient, layer.variant, count: max(2, Int((Double(count) * share).rounded())))
        }
        return scattered + Array(centered.prefix(2)) + Array(garnish.prefix(3))
    }

    /// The piece an ingredient is drawn as, read off how the recipe cuts it, or its most usual
    /// piece when the recipe does not say.
    private func pieceVariant(_ entry: Entry) -> (String, DishParts.Part)? {
        let pieces = DishParts.variants(of: entry.asset).filter { $0.part.kind == .piece }
        guard !pieces.isEmpty else { return nil }
        let text = entry.text + (entry.asset == "egg" ? "\n" + title : "")
        for cut in Self.cuts where says(cut.words, in: text) {
            for name in cut.variants {
                if let match = pieces.first(where: { $0.name == name }) { return (match.name, match.part) }
            }
        }
        if entry.asset == "egg" {
            let fried = says(Self.friedRiceWords, in: title) || method.contains("scrambl") || method.contains("炒り")
            let name = fried ? "scrambled" : "fried"
            if let match = pieces.first(where: { $0.name == name }) { return (match.name, match.part) }
        }
        return (pieces[0].name, pieces[0].part)
    }

    /// One of the vessels of a kind, chosen so the food stands apart from the dish it is on.
    /// Every colour far enough from the food is a fair pick, and the recipe's own seed picks
    /// between them, so a grid of recipes is not all on the one plate.
    private func pickVessel(kind: String, under base: DishLayer?, random: inout SeededRandom) -> String {
        let vessels = DishParts.vessels(ofKind: kind)
        guard !vessels.isEmpty else { return "plate" }
        guard let base, let tone = DishParts.part(base.ingredient, base.variant)?.tones.first,
              let food = DishLayout.Color(hex: tone)
        else { return random.pick(vessels) ?? vessels[0] }
        let scored = vessels.compactMap { name -> (String, Double)? in
            guard let well = DishParts.vessels[name].flatMap({ DishLayout.Color(hex: $0.tone) }) else { return nil }
            return (name, well.distance(to: food))
        }
        let clear = scored.filter { $0.1 >= 25 }.map(\.0)
        return random.pick(clear) ?? scored.max { $0.1 < $1.1 }?.0 ?? vessels[0]
    }
}
