import FoundationModels
import Foundation

/// What a new recipe is built from: a dish in the cook's words, what they have in the
/// kitchen, or both.
struct GenerationRequest: Equatable, Sendable {
    /// The dish, written by the cook. May be empty when they only picked what they have.
    var description = ""
    /// Ingredient asset names picked from the catalog.
    var ingredients: [String] = []
    /// Tool asset names picked from the catalog.
    var tools: [String] = []

    /// Nothing to work from, so there is nothing to ask for.
    var isEmpty: Bool {
        trimmedDescription.isEmpty && ingredients.isEmpty && tools.isEmpty
    }

    var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The picked ingredients as a cook would read them. A cook can tap the whole catalog,
    /// which is more than the on-device window holds, so only the first `listLimit` are named.
    /// Narrowing the choice is safe: what is left is still only things they have.
    var ingredientNames: [String] {
        ingredients.prefix(Self.listLimit).map(IconCatalog.displayName)
    }

    /// The picked tools as a cook would read them, capped the same way.
    var toolNames: [String] { tools.prefix(Self.listLimit).map(IconCatalog.displayName) }

    /// How many picked items a prompt names before it stops listing.
    static let listLimit = 40
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

    @Guide(description: "The catalog icon for this ingredient, lowercase and hyphenated, such as 'spring-onion'")
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

    @Guide(description: "The catalog icon for this tool, lowercase and hyphenated, such as 'cutting-board'")
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

    /// Where a pass goes when it does not fit on device. Held rather than made per pass so
    /// availability and quota are read from one place.
    private let cloud = PrivateCloudComputeLanguageModel()

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

    func generate(_ request: GenerationRequest) async -> Recipe? {
        state = .generating
        progress = GenerationProgress()
        do {
            let base = try await generateBase(request)
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

    /// Runs one pass on device, and runs it again on Private Cloud Compute when the request
    /// does not fit the on-device window. Nothing leaves the device until the on-device model
    /// has turned the pass down, and a pass small enough to run at home never reaches the
    /// cloud at all.
    private func run<Value>(
        tools: [any FoundationModels.Tool] = [],
        instructions: String,
        _ body: (LanguageModelSession) async throws -> Value
    ) async throws -> Value {
        do {
            return try await body(LanguageModelSession(tools: tools, instructions: instructions))
        } catch let error as LanguageModelError {
            guard case .contextSizeExceeded = error else { throw error }
            guard cloud.isAvailable else { throw GenerationError.tooLarge }
            return try await body(
                LanguageModelSession(
                    model: cloud,
                    tools: cloud.capabilities.contains(.toolCalling) ? tools : [],
                    instructions: instructions
                )
            )
        }
    }

    private func generateBase(_ request: GenerationRequest) async throws -> GeneratedRecipeBase {
        progress.stage = .idea
        return try await run(
            tools: [IngredientLookupTool(available: request.ingredients)],
            instructions: Self.instructions(for: request)
        ) { session in
            let stream = session.streamResponse(
                to: Self.prompt(for: request),
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
    }

    private func generateOutline(for base: GeneratedRecipeBase) async throws -> [String] {
        progress.stage = .outline
        let steps = try await run(instructions: Self.outlineInstructions) { session in
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
            return try GeneratedStepOutline(latest).steps
        }
        progress.stepCount = steps.count
        return steps
    }

    /// Each step is written in its own session, given only the shopping list and the outline.
    private func generateSteps(outline: [String], base: GeneratedRecipeBase) async throws -> [Step] {
        progress.stage = .details
        var steps: [Step] = []
        for (index, title) in outline.enumerated() {
            progress.latestStep = title
            let points = try await run(instructions: Self.stepInstructions) { session in
                let response = try await session.respond(
                    to: """
                    Recipe: \(base.title), \(base.time), serves \(base.serves).
                    Ingredients: \(Self.list(base.supermarket + base.general + base.optional)).
                    Method: \(outline.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: " ")).

                    Write step \(index + 1), "\(title)".
                    """,
                    generating: GeneratedStepDetail.self
                )
                return response.content.points
            }
            steps.append(Step(title: title, icons: nil, points: points))
            progress.writtenStepCount = steps.count
        }
        return steps
    }

    private func generateTroubleshooting(
        base: GeneratedRecipeBase,
        outline: [String]
    ) async throws -> [Troubleshooting] {
        progress.stage = .troubleshooting
        return try await run(instructions: Self.troubleshootingInstructions) { session in
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
    }

    // MARK: - Prompts

    private enum GenerationError: LocalizedError {
        case empty
        /// Too big for this iPhone, with no cloud to send it to.
        case tooLarge

        var errorDescription: String? {
            switch self {
            case .empty: String(localized: "Generate.Error.Empty")
            case .tooLarge: String(localized: "Generate.Error.TooLarge")
            }
        }
    }

    private static let houseStyle = """
    You write recipes for a one-pan cooking site. Every recipe is cooked in a single frying \
    pan on a home stove, uses ingredients from an ordinary supermarket, and finishes in under \
    half an hour.

    Write plainly, like a good cookbook. Never use em-dashes. Do not use breathless adjectives, \
    and do not pad with rule-of-three lists. Write ranges with the word "to", never a dash.
    """

    private static func instructions(for request: GenerationRequest) -> String {
        var instructions = houseStyle + "\n\n" + """
        You are working out what a dish is and what it needs. Prep work such as "finely diced" \
        belongs in the method, not in an ingredient amount, so leave it out here.

        The app draws each ingredient from a fixed catalog of icons. Call checkIngredient for \
        any ingredient you are unsure of before you write it down, and take the swap it \
        suggests when the catalog has nothing for it.
        """

        if !request.ingredients.isEmpty {
            instructions += "\n\n" + """
            The cook has told you everything they have in the kitchen. Ask for nothing else. \
            Every ingredient in the recipe has to come from their list, and it is fine to leave \
            some of the list unused. If the list cannot make the dish they named, write the \
            closest dish it can make.
            """
        }
        if !request.tools.isEmpty {
            instructions += "\n\n" + """
            They have listed the tools they own too, so the method can only use those. Do not \
            ask for a tool they did not list.
            """
        }
        if request.trimmedDescription.isEmpty {
            instructions += "\n\n" + """
            They have not named a dish, so pick one their ingredients make well.
            """
        }
        return instructions
    }

    private static let outlineInstructions = houseStyle + "\n\n" + """
    You are outlining the method only. Give each step a short imperative title such as \
    "Brown pork" or "Toast first side". Do not explain the steps, the titles alone are enough, \
    and do not number them.
    """

    private static let stepInstructions = houseStyle + "\n\n" + """
    You are writing one step of a method that is already planned. Cover that step only, and \
    do not repeat what earlier or later steps do.
    """

    private static let troubleshootingInstructions = houseStyle + "\n\n" + """
    You are writing the troubleshooting notes. Each problem is a short symptom with no closing \
    period, written in the third person such as "The rice turned mushy", or as a want without \
    the pronoun such as "Want it more filling". Each solution is one to three full sentences.
    """

    private static func prompt(for request: GenerationRequest) -> String {
        var lines: [String] = []
        if request.trimmedDescription.isEmpty {
            lines.append("Work out a one-pan recipe I can cook tonight.")
        } else {
            lines.append("Work out a one-pan version of \(request.trimmedDescription).")
        }
        if !request.ingredients.isEmpty {
            lines.append("All I have to cook with: \(request.ingredientNames.joined(separator: ", ")).")
        }
        if !request.tools.isEmpty {
            lines.append("All I have to cook in: \(request.toolNames.joined(separator: ", ")).")
        }
        return lines.joined(separator: "\n")
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
        let tools = base.tools.map { tool in
            Tool(
                name: tool.name,
                icon: IconCatalog.toolPath(for: IconCatalog.resolveTool(tool.icon, itemName: tool.name)),
                required: tool.required,
                note: trimmed(tool.note)
            )
        }
        let ingredients = [sections.supermarket, sections.general, sections.optional]
            .compactMap { $0 }
            .flatMap { $0 }
        return Recipe(
            id: Recipe.makeID(from: base.title),
            title: base.title,
            time: base.time,
            serves: base.serves,
            tried: nil,
            ingredients: sections,
            tools: tools,
            steps: steps.map { step in
                Step(
                    title: step.title,
                    icons: Step.icons(
                        forText: ([step.title] + step.points).joined(separator: " "),
                        ingredients: ingredients,
                        tools: tools
                    ),
                    points: step.points
                )
            },
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
