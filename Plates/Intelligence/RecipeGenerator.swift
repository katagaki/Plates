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

/// The first pass: what the dish is and what it needs. The method comes later, so this
/// stays small enough to generate reliably.
@Generable(description: "The idea for a one-pan recipe: what it is and what it needs")
struct GeneratedRecipeBase {
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
}

/// The second pass: the shape of the method, titles only.
@Generable(description: "The method for a one-pan recipe, as an ordered list of step titles")
struct GeneratedStepOutline {
    @Guide(description: "Short imperative step titles in order, such as 'Brown pork'", .count(4...8))
    var steps: [String]
}

/// The third pass: one step written out on its own.
@Generable(description: "What to do during one step of a recipe")
struct GeneratedStepDetail {
    @Guide(description: "Two to three plain sentences describing what to do", .count(2...3))
    var points: [String]

    @Guide(description: "Optional background on why the step works. Leave empty when there is nothing to add.")
    var hint: String
}

/// The last pass: what goes wrong and how to fix it.
@Generable(description: "Problems a cook runs into with this recipe, and their fixes")
struct GeneratedTroubleshootingList {
    @Guide(description: "Things that commonly go wrong and how to fix them", .count(2...5))
    var entries: [GeneratedTroubleshooting]
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
struct GeneratedTroubleshooting {
    @Guide(description: "A short symptom with no closing period, such as 'The rice turned mushy'")
    var problem: String

    @Guide(description: "One to three full sentences that fix it")
    var solution: String
}

/// How much of the recipe has arrived so far, read off each streamed snapshot.
struct GenerationProgress: Equatable, Sendable {
    /// The passes the generator runs, in order.
    enum Stage: Int, Equatable, Sendable {
        case idea
        case outline
        case details
        case troubleshooting

        var title: LocalizedStringResource {
            switch self {
            case .idea: "Generate.Progress.Stage.Idea"
            case .outline: "Generate.Progress.Stage.Outline"
            case .details: "Generate.Progress.Stage.Details"
            case .troubleshooting: "Generate.Progress.Stage.Troubleshooting"
            }
        }
    }

    var stage: Stage = .idea
    var title: String?
    var time: String?
    var serves: String?
    var ingredientCount = 0
    var toolCount = 0
    var stepCount = 0
    var writtenStepCount = 0
    var troubleshootingCount = 0
    /// The step the model is writing right now.
    var latestStep: String?
    /// Set when the last pass ends, so the bar always lands on full.
    var isFinished = false

    /// How far along the model is. Each pass carries the share of the work it does.
    var fraction: Double {
        guard !isFinished else { return 1 }
        let idea = [
            title == nil ? 0 : 1,
            min(Double(ingredientCount) / 6, 1),
            min(Double(toolCount) / 3, 1),
        ].reduce(0, +) / 3
        let outline = min(Double(stepCount) / 5, 1)
        let details = stepCount == 0 ? 0 : Double(writtenStepCount) / Double(stepCount)
        let troubleshooting = min(Double(troubleshootingCount) / 2, 1)
        return idea * 0.35 + outline * 0.15 + details * 0.35 + troubleshooting * 0.15
    }
}

/// Wraps the on-device model and converts its output into a schema-shaped `Recipe`.
///
/// The recipe is written in four passes, each in its own session: the idea and shopping list,
/// then the step titles, then every step on its own, then troubleshooting. Nothing carries the
/// whole recipe in its context, so a long recipe cannot run the window out.
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

    func generate(mode: GenerationMode, input: String) async -> Recipe? {
        state = .generating
        progress = GenerationProgress()
        do {
            let base = try await generateBase(mode: mode, input: input)
            let outline = try await generateOutline(for: base)
            let steps = try await generateSteps(outline: outline, base: base)
            let troubleshooting = try await generateTroubleshooting(base: base, outline: outline)
            progress.isFinished = true
            state = .idle
            return Self.makeRecipe(base: base, steps: steps, troubleshooting: troubleshooting)
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    // MARK: - Passes

    private func generateBase(mode: GenerationMode, input: String) async throws -> GeneratedRecipeBase {
        progress.stage = .idea
        let session = LanguageModelSession(
            tools: [IngredientLookupTool()],
            instructions: Self.instructions(for: mode)
        )
        let stream = session.streamResponse(
            to: Self.prompt(for: mode, input: input),
            generating: GeneratedRecipeBase.self
        )
        var latest: GeneratedContent?
        for try await snapshot in stream {
            let partial = snapshot.content
            progress.title = partial.title
            progress.time = partial.time
            progress.serves = partial.serves
            progress.ingredientCount = (partial.supermarket?.count ?? 0)
                + (partial.general?.count ?? 0)
                + (partial.optional?.count ?? 0)
            progress.toolCount = partial.tools?.count ?? 0
            latest = snapshot.rawContent
        }
        guard let latest else { throw GenerationError.empty }
        return try GeneratedRecipeBase(latest)
    }

    private func generateOutline(for base: GeneratedRecipeBase) async throws -> [String] {
        progress.stage = .outline
        let session = LanguageModelSession(instructions: Self.outlineInstructions)
        let stream = session.streamResponse(
            to: """
            Recipe: \(base.title), \(base.time), serves \(base.serves).
            Ingredients: \(Self.list(base.supermarket + base.general + base.optional)).
            Tools: \(base.tools.map(\.name).joined(separator: ", ")).

            Outline the method as step titles, from prep to plating.
            """,
            generating: GeneratedStepOutline.self
        )
        var latest: GeneratedContent?
        for try await snapshot in stream {
            progress.stepCount = snapshot.content.steps?.count ?? 0
            latest = snapshot.rawContent
        }
        guard let latest else { throw GenerationError.empty }
        let steps = try GeneratedStepOutline(latest).steps
        progress.stepCount = steps.count
        return steps
    }

    /// Each step is written in its own session, given only the shopping list and the outline.
    private func generateSteps(outline: [String], base: GeneratedRecipeBase) async throws -> [Step] {
        progress.stage = .details
        var steps: [Step] = []
        for (index, title) in outline.enumerated() {
            progress.latestStep = title
            let session = LanguageModelSession(instructions: Self.stepInstructions)
            let response = try await session.respond(
                to: """
                Recipe: \(base.title), \(base.time), serves \(base.serves).
                Ingredients: \(Self.list(base.supermarket + base.general + base.optional)).
                Method: \(outline.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: " ")).

                Write step \(index + 1), "\(title)".
                """,
                generating: GeneratedStepDetail.self
            )
            steps.append(
                Step(
                    title: title,
                    points: response.content.points,
                    hint: Self.trimmed(response.content.hint),
                    image: nil
                )
            )
            progress.writtenStepCount = steps.count
        }
        return steps
    }

    private func generateTroubleshooting(
        base: GeneratedRecipeBase,
        outline: [String]
    ) async throws -> [Troubleshooting] {
        progress.stage = .troubleshooting
        let session = LanguageModelSession(instructions: Self.troubleshootingInstructions)
        let stream = session.streamResponse(
            to: """
            Recipe: \(base.title), \(base.time), serves \(base.serves).
            Method: \(outline.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: " ")).

            What goes wrong when someone cooks this, and how do they fix it?
            """,
            generating: GeneratedTroubleshootingList.self
        )
        var latest: GeneratedContent?
        for try await snapshot in stream {
            progress.troubleshootingCount = snapshot.content.entries?.count ?? 0
            latest = snapshot.rawContent
        }
        guard let latest else { throw GenerationError.empty }
        return try GeneratedTroubleshootingList(latest).entries.map {
            Troubleshooting(problem: $0.problem, solution: $0.solution)
        }
    }

    // MARK: - Prompts

    private enum GenerationError: LocalizedError {
        case empty

        var errorDescription: String? { String(localized: "Generate.Error.Empty") }
    }

    private static let houseStyle = """
    You write recipes for a one-pan cooking site. Every recipe is cooked in a single frying \
    pan on a home stove, uses ingredients from an ordinary supermarket, and finishes in under \
    half an hour.

    Write plainly, like a good cookbook. Never use em-dashes. Do not use breathless adjectives, \
    and do not pad with rule-of-three lists. Write ranges with the word "to", never a dash.
    """

    private static func instructions(for mode: GenerationMode) -> String {
        let shared = houseStyle + "\n\n" + """
        You are working out what a dish is and what it needs. Prep work such as "finely diced" \
        belongs in the method, not in an ingredient amount, so leave it out here.

        The app draws each ingredient from a fixed catalog of icons. Call checkIngredient for \
        any ingredient you are unsure of before you write it down, and take the swap it \
        suggests when the catalog has nothing for it.
        """
        switch mode {
        case .dish:
            return shared + "\n\n" + """
            The cook names a dish. Work out the one-pan version of it, keeping what makes it \
            recognisable and dropping anything that needs a second pan or an oven.
            """
        case .fridge:
            return shared + "\n\n" + """
            The cook lists what they have. Build the recipe around that list. You may add pantry \
            staples such as oil, salt, pepper, soy sauce, sugar, and water, but do not ask for \
            anything else fresh that they did not mention.
            """
        }
    }

    private static let outlineInstructions = houseStyle + "\n\n" + """
    You are outlining the method only. Give each step a short imperative title such as \
    "Brown pork" or "Toast first side". Do not explain the steps, the titles alone are enough, \
    and do not number them.
    """

    private static let stepInstructions = houseStyle + "\n\n" + """
    You are writing one step of a method that is already planned. Cover that step only, and \
    do not repeat what earlier or later steps do. The hint is for background on why the step \
    works, so leave it empty when there is nothing worth adding.
    """

    private static let troubleshootingInstructions = houseStyle + "\n\n" + """
    You are writing the troubleshooting notes. Each problem is a short symptom with no closing \
    period, written in the third person such as "The rice turned mushy", or as a want without \
    the pronoun such as "Want it more filling". Each solution is one to three full sentences.
    """

    private static func prompt(for mode: GenerationMode, input: String) -> String {
        let input = input.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .dish:
            return input.isEmpty
                ? "Invent a one-pan recipe for a weeknight dinner."
                : "Work out a one-pan version of \(input)."
        case .fridge:
            return "Work out a one-pan recipe using what I have: \(input)."
        }
    }

    /// A compact "item (amount)" list, small enough to hand to every later pass.
    private static func list(_ ingredients: [GeneratedIngredient]) -> String {
        ingredients.map { "\($0.item) (\($0.amount))" }.joined(separator: ", ")
    }

    // MARK: - Assembly

    /// Maps generated content onto the on-disk schema, pinning every icon to one that exists.
    static func makeRecipe(
        base: GeneratedRecipeBase,
        steps: [Step],
        troubleshooting: [Troubleshooting]
    ) -> Recipe {
        let sections = IngredientSections(
            supermarket: section(base.supermarket),
            general: section(base.general),
            optional: section(base.optional)
        )
        return Recipe(
            id: Recipe.makeID(from: base.title),
            title: base.title,
            time: base.time,
            serves: base.serves,
            tried: nil,
            ingredients: sections,
            tools: base.tools.map { tool in
                Tool(
                    name: tool.name,
                    icon: IconCatalog.toolPath(for: IconCatalog.resolveTool(tool.icon, itemName: tool.name)),
                    required: tool.required,
                    note: trimmed(tool.note)
                )
            },
            steps: steps,
            troubleshooting: troubleshooting
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
