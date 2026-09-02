import FoundationModels
import Foundation

/// What a new recipe is built from.
enum GenerationMode: String, CaseIterable, Identifiable, Sendable {
    /// A dish the user names, written as a one-pan version.
    case dish
    /// Whatever the user has to hand.
    case fridge

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .dish: "Generate.Mode.Dish"
        case .fridge: "Generate.Mode.Fridge"
        }
    }

    var fieldLabel: LocalizedStringResource {
        switch self {
        case .dish: "Generate.Dish.Label"
        case .fridge: "Generate.Fridge.Label"
        }
    }

    var fieldPrompt: LocalizedStringResource {
        switch self {
        case .dish: "Generate.Dish.Prompt"
        case .fridge: "Generate.Fridge.Prompt"
        }
    }

    var footer: LocalizedStringResource {
        switch self {
        case .dish: "Generate.Dish.Footer"
        case .fridge: "Generate.Fridge.Footer"
        }
    }

    /// The fridge needs a list to work from. A dish can be left to the model.
    var requiresInput: Bool { self == .fridge }
}

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

/// How much of the recipe has arrived so far, read off each streamed snapshot.
struct GenerationProgress: Equatable, Sendable {
    var title: String?
    var time: String?
    var serves: String?
    var ingredientCount = 0
    var toolCount = 0
    var stepCount = 0
    var troubleshootingCount = 0
    /// The step the model is writing right now.
    var latestStep: String?
    /// Set when the stream ends, so the bar always lands on full.
    var isFinished = false

    /// Roughly how far along the model is, weighted evenly across the five stages. The counts
    /// it divides by are what a recipe usually comes back with, not the guided maximums.
    var fraction: Double {
        guard !isFinished else { return 1 }
        let stages = [
            title == nil ? 0 : 1,
            min(Double(ingredientCount) / 6, 1),
            min(Double(toolCount) / 3, 1),
            min(Double(stepCount) / 5, 1),
            min(Double(troubleshootingCount) / 2, 1),
        ]
        return stages.reduce(0, +) / Double(stages.count)
    }

    init() {}

    init(_ partial: GeneratedRecipe.PartiallyGenerated) {
        title = partial.title
        time = partial.time
        serves = partial.serves
        ingredientCount = (partial.supermarket?.count ?? 0)
            + (partial.general?.count ?? 0)
            + (partial.optional?.count ?? 0)
        toolCount = partial.tools?.count ?? 0
        stepCount = partial.steps?.count ?? 0
        troubleshootingCount = partial.troubleshooting?.count ?? 0
        latestStep = partial.steps?.last?.title
    }
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
    private(set) var progress = GenerationProgress()

    private let model = SystemLanguageModel.default

    var availability: SystemLanguageModel.Availability { model.availability }

    var isAvailable: Bool { model.availability == .available }

    /// Why the button is disabled, in words a cook can act on.
    var unavailableReason: LocalizedStringResource? {
        switch model.availability {
        case .available:
            nil
        case .unavailable(.deviceNotEligible):
            "Generate.Unavailable.DeviceNotEligible"
        case .unavailable(.appleIntelligenceNotEnabled):
            "Generate.Unavailable.AppleIntelligenceNotEnabled"
        case .unavailable(.modelNotReady):
            "Generate.Unavailable.ModelNotReady"
        case .unavailable:
            "Generate.Unavailable.Unknown"
        }
    }

    /// Streams a recipe so the sheet can show it filling in rather than a bare spinner.
    func generate(mode: GenerationMode, input: String) async -> Recipe? {
        state = .generating
        progress = GenerationProgress()
        let session = LanguageModelSession(instructions: Self.instructions(for: mode))
        do {
            let stream = session.streamResponse(
                to: Self.prompt(for: mode, input: input),
                generating: GeneratedRecipe.self
            )
            var latest: GeneratedContent?
            for try await snapshot in stream {
                progress = GenerationProgress(snapshot.content)
                latest = snapshot.rawContent
            }
            guard let latest else {
                state = .failed(String(localized: "Generate.Error.Empty"))
                return nil
            }
            let generated = try GeneratedRecipe(latest)
            progress.isFinished = true
            state = .idle
            return Self.makeRecipe(from: generated)
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    private static func instructions(for mode: GenerationMode) -> String {
        let shared = """
        You write recipes for a one-pan cooking site. Every recipe is cooked in a single \
        frying pan on a home stove, uses ingredients from an ordinary supermarket, and \
        finishes in under half an hour.

        Write plainly, like a good cookbook. Never use em-dashes. Do not use breathless \
        adjectives, and do not pad with rule-of-three lists. Write ranges with the word \
        "to", never a dash. Prep work such as "finely diced" belongs in a step, not in an \
        ingredient amount.
        """
        switch mode {
        case .dish:
            return shared + "\n\n" + """
            The cook names a dish. Write that dish as a one-pan recipe, keeping what makes \
            it recognisable and dropping any step that needs a second pan or an oven.
            """
        case .fridge:
            return shared + "\n\n" + """
            The cook lists what they have. Build the recipe around that list. You may add \
            pantry staples such as oil, salt, pepper, soy sauce, sugar, and water, but do \
            not ask for anything else fresh that they did not mention.
            """
        }
    }

    private static func prompt(for mode: GenerationMode, input: String) -> String {
        let input = input.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .dish:
            return input.isEmpty
                ? "Invent a one-pan recipe for a weeknight dinner."
                : "Write a one-pan version of \(input)."
        case .fridge:
            return "Write a one-pan recipe using what I have: \(input)."
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
