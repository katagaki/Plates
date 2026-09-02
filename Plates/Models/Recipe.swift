import Foundation

/// One recipe, shaped exactly like the JSON files in the One-Pan Food site's `recipes` folder.
/// Property order matters: it is the key order written back out to disk.
nonisolated struct Recipe: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var time: String
    var serves: String
    /// Written only when the recipe has been cooked, always as `true`.
    var tried: Bool?
    var ingredients: IngredientSections
    var tools: [Tool]
    var steps: [Step]
    var troubleshooting: [Troubleshooting]

    /// The minute count behind `time`, used for sorting. Unreadable values sort last.
    var minutes: Int {
        Int(time.prefix { $0.isNumber }) ?? Int.max
    }
}

/// The three ingredient sections. A section is written only when it holds entries.
nonisolated struct IngredientSections: Codable, Hashable {
    var supermarket: [Ingredient]?
    var general: [Ingredient]?
    var optional: [Ingredient]?

    var isEmpty: Bool {
        (supermarket?.isEmpty ?? true) && (general?.isEmpty ?? true) && (optional?.isEmpty ?? true)
    }
}

nonisolated struct Ingredient: Codable, Hashable, Identifiable {
    var item: String
    var icon: String
    var amount: String
    var note: String?

    var id: String { item + amount }
}

nonisolated struct Tool: Codable, Hashable, Identifiable {
    var name: String
    var icon: String
    var required: Bool
    var note: String?

    var id: String { name }
}

nonisolated struct Step: Codable, Hashable, Identifiable {
    var title: String
    /// The ingredient and tool icon paths this step works with, shown as a strip above its points.
    var icons: [String]?
    var points: [String]

    var id: String { title }
}

nonisolated struct Troubleshooting: Codable, Hashable, Identifiable {
    var problem: String
    var solution: String

    var id: String { problem }
}

extension Recipe {
    /// Turns a title into the kebab-case id the schema uses for file names and image paths.
    static func makeID(from title: String) -> String {
        let slug = title.lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : " " }
            .joined()
            .split(separator: " ")
            .joined(separator: "-")
        return slug.isEmpty ? "recipe-\(Int(Date.now.timeIntervalSince1970))" : slug
    }
}

extension Step {
    /// Words that say nothing about which ingredient or tool a step reaches for.
    private static let ignored: Set<String> = [
        "about", "chopped", "cooking", "cut", "diced", "dried", "fine", "finely", "fresh",
        "ground", "large", "leave", "medium", "plain", "sliced", "small", "steamed", "thick",
        "thin", "whole",
    ]

    /// The icons a step's words point at, taken from the recipe's own lists so a step never
    /// shows something the recipe does not carry. Ingredients come first, then tools.
    static func icons(
        forText text: String,
        ingredients: [Ingredient],
        tools: [Tool],
        limit: Int = 6
    ) -> [String] {
        let words = Set(terms(in: text))
        let ingredientIcons = ingredients.filter { entry in
            matches(words, name: entry.item, icon: entry.icon)
        }
        let toolIcons = tools.filter { tool in
            matches(words, name: tool.name, icon: tool.icon)
        }
        let icons = ingredientIcons.map(\.icon) + toolIcons.map(\.icon)
        return Array(NSOrderedSet(array: icons).compactMap { $0 as? String }.prefix(limit))
    }

    /// An entry is in the step when the step names it, or names the icon it carries.
    private static func matches(_ words: Set<String>, name: String, icon: String) -> Bool {
        var candidates = terms(in: name)
        if let name = IconCatalog.iconName(for: icon) {
            candidates += terms(in: IconCatalog.displayName(for: name))
        }
        return candidates.contains { words.contains($0) }
    }

    /// The words worth matching on: lowercased, singular, and long enough to mean something.
    private static func terms(in text: String) -> [String] {
        text.lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : " " }
            .joined()
            .split(separator: " ")
            .map { $0.count > 3 && $0.hasSuffix("s") ? String($0.dropLast()) : String($0) }
            .filter { $0.count > 2 && !ignored.contains($0) }
    }
}
