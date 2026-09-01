import Foundation

/// One recipe, shaped exactly like the JSON files in the One-Pan Food site's `recipes` folder.
/// Property order matters: it is the key order written back out to disk.
struct Recipe: Codable, Identifiable, Hashable {
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
struct IngredientSections: Codable, Hashable {
    var supermarket: [Ingredient]?
    var general: [Ingredient]?
    var optional: [Ingredient]?

    var isEmpty: Bool {
        (supermarket?.isEmpty ?? true) && (general?.isEmpty ?? true) && (optional?.isEmpty ?? true)
    }
}

struct Ingredient: Codable, Hashable, Identifiable {
    var item: String
    var icon: String
    var amount: String
    var note: String?

    var id: String { item + amount }
}

struct Tool: Codable, Hashable, Identifiable {
    var name: String
    var icon: String
    var required: Bool
    var note: String?

    var id: String { name }
}

struct Step: Codable, Hashable, Identifiable {
    var title: String
    var points: [String]
    var hint: String?
    var image: String?

    var id: String { title }
}

struct Troubleshooting: Codable, Hashable, Identifiable {
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
