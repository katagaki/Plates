import FoundationModels
import Foundation

/// The shape Apple Intelligence fills in. It mirrors the recipe schema, flattened where the
/// nesting would only make the model's job harder.
@Generable(description: "A one-pan recipe that can be cooked in a single frying pan on a home stove")
struct GeneratedRecipe {
    @Guide(description: "Title in title case, two to four words. Do not use the words 'One-Pan'.")
    var title: String

    @Guide(description: "Total time written as a minute count, for example '15 min'")
    var time: String

    @Guide(description: "How many people it serves, as a plain count such as '1' or '1 to 2'")
    var serves: String

    @Guide(description: "Fresh and chilled items: vegetables, meat, seafood, dairy, bread, eggs", .count(1...6))
    var supermarket: [GeneratedIngredient]

    @Guide(description: "Shelf-stable pantry items: oil, soy sauce, salt, sugar, packed rice, pasta", .count(1...6))
    var general: [GeneratedIngredient]

    @Guide(description: "Anything that can be skipped. Leave empty when nothing is optional.", .maximumCount(3))
    var optional: [GeneratedIngredient]

    @Guide(description: "The pans, knives and bowls needed", .count(2...6))
    var tools: [GeneratedTool]

    @Guide(description: "The method, in order, from prep to plating", .count(4...8))
    var steps: [GeneratedStep]

    @Guide(description: "Things that commonly go wrong and how to fix them", .count(2...5))
    var troubleshooting: [GeneratedTroubleshooting]
}

@Generable
struct GeneratedIngredient {
    @Guide(description: "The ingredient name, for example 'Thick-cut bread' or 'Spring onion'")
    var item: String

    @Guide(description: "The icon that best matches this ingredient", .anyOf(IconCatalog.ingredients))
    var icon: String

    @Guide(description: "The quantity only, such as '150 g', '1/2', '2 tbsp', or 'to taste'")
    var amount: String

    @Guide(description: "One sentence, only when it changes what you buy. Otherwise leave empty.")
    var note: String
}

@Generable
struct GeneratedTool {
    @Guide(description: "The tool name. The main pan names its size, for example 'Frying pan (about 24 cm)'.")
    var name: String

    @Guide(description: "The icon that best matches this tool", .anyOf(IconCatalog.tools))
    var icon: String

    @Guide(description: "True when the recipe cannot be cooked without it")
    var required: Bool

    @Guide(description: "One sentence, only when the tool can be skipped or swapped. Otherwise leave empty.")
    var note: String
}

@Generable
struct GeneratedStep {
    @Guide(description: "A short imperative phrase such as 'Brown pork'")
    var title: String

    @Guide(description: "Two to three plain sentences describing what to do", .count(2...3))
    var points: [String]

    @Guide(description: "Optional background on why the step works. Leave empty when there is nothing to add.")
    var hint: String
}

@Generable
struct GeneratedTroubleshooting {
    @Guide(description: "A short symptom with no closing period, such as 'The rice turned mushy'")
    var problem: String

    @Guide(description: "One to three full sentences that fix it")
    var solution: String
}

/// Wraps the on-device model and converts its output into a schema-shaped `Recipe`.
@MainActor
@Observable
final class RecipeGenerator {
    enum State: Equatable {
        case idle
        case generating
        case failed(String)
    }

    private(set) var state: State = .idle

    private let model = SystemLanguageModel.default

    var availability: SystemLanguageModel.Availability { model.availability }

    var isAvailable: Bool { model.availability == .available }

    /// Why the button is disabled, in words a cook can act on.
    var unavailableReason: String? {
        switch model.availability {
        case .available:
            nil
        case .unavailable(.deviceNotEligible):
            "This device does not support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            "Turn on Apple Intelligence in Settings to generate recipes."
        case .unavailable(.modelNotReady):
            "Apple Intelligence is still downloading its model. Try again shortly."
        case .unavailable:
            "Apple Intelligence is not available right now."
        }
    }

    func generate(from idea: String) async -> Recipe? {
        state = .generating
        let session = LanguageModelSession {
            """
            You write recipes for a one-pan cooking site. Every recipe is cooked in a single \
            frying pan on a home stove, uses ingredients from an ordinary supermarket, and \
            finishes in under half an hour.

            Write plainly, like a good cookbook. Never use em-dashes. Do not use breathless \
            adjectives, and do not pad with rule-of-three lists. Write ranges with the word \
            "to", never a dash. Prep work such as "finely diced" belongs in a step, not in an \
            ingredient amount.
            """
        }
        do {
            let response = try await session.respond(
                to: idea.isEmpty ? "Invent a one-pan recipe for a weeknight dinner." : idea,
                generating: GeneratedRecipe.self
            )
            state = .idle
            return Self.makeRecipe(from: response.content)
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    /// Maps generated content onto the on-disk schema, pinning every icon to one that exists.
    static func makeRecipe(from generated: GeneratedRecipe) -> Recipe {
        let sections = IngredientSections(
            supermarket: section(generated.supermarket),
            general: section(generated.general),
            optional: section(generated.optional)
        )
        return Recipe(
            id: Recipe.makeID(from: generated.title),
            title: generated.title,
            time: generated.time,
            serves: generated.serves,
            tried: nil,
            ingredients: sections,
            tools: generated.tools.map { tool in
                Tool(
                    name: tool.name,
                    icon: IconCatalog.toolPath(for: IconCatalog.resolveTool(tool.icon, itemName: tool.name)),
                    required: tool.required,
                    note: trimmed(tool.note)
                )
            },
            steps: generated.steps.map { step in
                Step(title: step.title, points: step.points, hint: trimmed(step.hint), image: nil)
            },
            troubleshooting: generated.troubleshooting.map {
                Troubleshooting(problem: $0.problem, solution: $0.solution)
            }
        )
    }

    /// A section is written only when it holds entries.
    private static func section(_ entries: [GeneratedIngredient]) -> [Ingredient]? {
        guard !entries.isEmpty else { return nil }
        return entries.map { entry in
            Ingredient(
                item: entry.item,
                icon: IconCatalog.ingredientPath(
                    for: IconCatalog.resolveIngredient(entry.icon, itemName: entry.item)
                ),
                amount: entry.amount,
                note: trimmed(entry.note)
            )
        }
    }

    private static func trimmed(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
