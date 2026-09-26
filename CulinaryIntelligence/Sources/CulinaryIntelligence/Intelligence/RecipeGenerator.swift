import FoundationModels
import Foundation

/// What a new recipe is built from: a dish in the cook's words, what they have in the
/// kitchen, or both.
public struct GenerationRequest: Equatable, Sendable {
    /// The dish, written by the cook. May be empty when they only picked what they have.
    public var description = ""
    /// Ingredient asset names picked from the catalog.
    public var ingredients: [String] = []
    /// Tool asset names picked from the catalog.
    public var tools: [String] = []
    /// Set when the cook wants the picks left out, so the model writes from the dish alone.
    public var ignoresPicks = false

    public init(
        description: String = "",
        ingredients: [String] = [],
        tools: [String] = [],
        ignoresPicks: Bool = false
    ) {
        self.description = description
        self.ingredients = ingredients
        self.tools = tools
        self.ignoresPicks = ignoresPicks
    }

    /// Nothing to work from, so there is nothing to ask for. Ignoring the picks is itself an
    /// ask, so a recipe can be written from nothing else.
    public var isEmpty: Bool {
        !ignoresPicks && trimmedDescription.isEmpty && ingredients.isEmpty && tools.isEmpty
    }

    /// The request as the model is given it. The picks stay on the form so the next recipe
    /// starts from the same shelf, but nothing built from them reaches a prompt while they
    /// are ignored.
    var asAsked: GenerationRequest {
        guard ignoresPicks else { return self }
        var request = self
        request.ingredients = []
        request.tools = []
        return request
    }

    var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The picked ingredients as a cook would read them. A cook can tap the whole catalog,
    /// which is more than a prompt should carry, so only the first `listLimit` are named.
    /// Narrowing the choice is safe: what is left is still only things they have.
    var ingredientNames: [String] {
        ingredients.prefix(Self.listLimit).map(IconCatalog.displayName)
    }

    /// The picked tools as a cook would read them, capped the same way.
    var toolNames: [String] { tools.prefix(Self.listLimit).map(IconCatalog.displayName) }

    /// How many picked items a prompt names before it stops listing.
    static let listLimit = 40
}

/// The first Apple pass over the written recipe: what it is called, what it takes, and what it
/// is cooked in. The recipe is already written, so this sorts what is there rather than
/// deciding anything.
@Generable(description: "A recipe's title, timing, shopping list, and tools, taken from a written recipe")
struct StructuredShopping {
    @Guide(description: "The recipe's title in title case, two to four words. Name the dish and nothing else.")
    var title: String

    @Guide(description: "Total time written as a minute count, for example '15 min'")
    var time: String

    @Guide(description: "How many people it serves, as a plain count such as '1' or '1 to 2'")
    var serves: String

    @Guide(
        description: "The recipe's fresh and chilled items: vegetables, meat, seafood, dairy, bread, eggs",
        .maximumCount(8)
    )
    var supermarket: [StructuredIngredient]

    @Guide(
        description: "The recipe's shelf-stable items: oil, soy sauce, salt, sugar, packed rice, pasta",
        .maximumCount(8)
    )
    var general: [StructuredIngredient]

    @Guide(description: "Items the recipe says can be skipped. Leave empty when nothing is optional.", .maximumCount(3))
    var optional: [StructuredIngredient]

    @Guide(description: "The pans, pots, knives and bowls the recipe uses", .count(1...8))
    var tools: [GeneratedTool]
}

@Generable
struct StructuredIngredient {
    @Guide(description: "The ingredient's name as the recipe writes it, without the amount or the prep")
    var item: String

    @Guide(description: "The catalog icon for this ingredient in English, lowercase and hyphenated, such as 'spring-onion'")
    var icon: String

    @Guide(description: "The quantity only, such as '150 g', '1/2', '2 tbsp', or 'to taste'")
    var amount: String

    @Guide(description: "One sentence, only when it changes what you buy. Otherwise leave empty.")
    var note: String
}

/// The second Apple pass: the method and the troubleshooting, in the order the recipe gives
/// them.
@Generable(description: "A recipe's method and troubleshooting, taken from a written recipe")
struct StructuredMethod {
    @Guide(description: "The recipe's steps in the order it gives them", .count(1...10))
    var steps: [StructuredStep]

    @Guide(description: "The problems the recipe warns about and their fixes", .maximumCount(5))
    var troubleshooting: [GeneratedTroubleshooting]
}

@Generable
struct StructuredStep {
    @Guide(description: "A short imperative step title, such as 'Brown pork'")
    var title: String

    @Guide(description: "What the recipe says to do in this step, as one to three plain sentences", .count(1...3))
    var points: [String]
}

/// What goes wrong and how to fix it. The editor rewrites the notes in this shape.
@Generable(description: "Problems a cook runs into with this recipe, and their fixes")
struct GeneratedTroubleshootingList {
    @Guide(description: "Things that commonly go wrong and how to fix them", .count(2...5))
    var entries: [GeneratedTroubleshooting]
}

@Generable
struct GeneratedIngredient {
    @Guide(description: "The ingredient's name")
    var item: String

    @Guide(description: "The quantity only, such as '150 g', '1/2', '2 tbsp', or 'to taste'")
    var amount: String

    @Guide(description: "One sentence, only when it changes what you buy. Otherwise leave empty.")
    var note: String
}

@Generable
struct GeneratedTool {
    @Guide(description: "The tool name on its own, such as 'Pan'. A size or a qualifier goes in the note.")
    var name: String

    @Guide(description: "The catalog icon for this tool, lowercase and hyphenated, such as 'cutting-board'")
    var icon: String

    @Guide(description: "True when the recipe cannot be cooked without it")
    var required: Bool

    @Guide(description: "One sentence, only when the tool needs a size or can be skipped or swapped. Otherwise leave empty.")
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
public struct GenerationProgress: Equatable, Sendable {
    /// The passes the generator runs, in order.
    public enum Stage: Int, Equatable, Sendable {
        case write
        case shopping
        case method
        case review

        public var title: LocalizedStringResource {
            switch self {
            case .write: LocalizedStringResource(culinary: "Generate.Progress.Stage.Write")
            case .shopping: LocalizedStringResource(culinary: "Generate.Progress.Stage.Shopping")
            case .method: LocalizedStringResource(culinary: "Generate.Progress.Stage.Method")
            case .review: LocalizedStringResource(culinary: "Generate.Progress.Stage.Review")
            }
        }
    }

    public var stage: Stage = .write
    /// The recipe as Granite has written it so far, shown while it is the only thing there is.
    public var draft = ""
    /// How many tokens Granite has written, which is what the bar reads during the first pass.
    public var writtenTokens = 0
    public var title: String?
    public var time: String?
    public var serves: String?
    public var ingredientCount = 0
    public var toolCount = 0
    public var stepCount = 0
    public var troubleshootingCount = 0
    /// How many fixes the review asked for and got.
    public var fixCount = 0
    /// The step titles as they stand, so the preview reads the method as it is sorted.
    public var outline: [String] = []
    /// Set when the last pass ends, so the bar always lands on full.
    public var isFinished = false

    public init() {}

    /// What the lock screen is told, which is the pass in words and the dish once it has a
    /// name of its own.
    public var activity: ActivityProgress {
        ActivityProgress(
            stage: String(localized: stage.title),
            dish: title,
            fraction: fraction
        )
    }

    /// How far along the model is. Each pass carries the share of the work it does. How long
    /// Granite writes for is not known ahead, so the first pass is measured against the length
    /// a recipe usually runs to and held short of full until it stops.
    public var fraction: Double {
        guard !isFinished else { return 1 }
        let write = stage.rawValue > Stage.write.rawValue
            ? 1
            : min(Double(writtenTokens) / Self.typicalTokens, 0.95)
        let shopping = stage.rawValue > Stage.shopping.rawValue ? 1 : [
            title == nil ? 0 : 1,
            min(Double(ingredientCount) / 6, 1),
            min(Double(toolCount) / 3, 1),
        ].reduce(0, +) / 3
        let method = stage.rawValue > Stage.method.rawValue ? 1 : [
            min(Double(stepCount) / 5, 1),
            min(Double(troubleshootingCount) / 2, 1),
        ].reduce(0, +) / 2
        // How long the read through takes is not known while it runs, so it counts as half
        // done from the moment it starts and lands on full when the run ends.
        let review = stage == .review ? 0.5 : 0
        return write * 0.45 + shopping * 0.15 + method * 0.2 + review * 0.2
    }

    /// About how many tokens a Granite recipe runs to, read off the Plates Kitchen evals.
    private static let typicalTokens = 550.0
}

/// Writes a new recipe with two models, each doing what it is good at.
///
/// Granite, running through llama.cpp on device, writes the whole recipe as plain cookbook
/// text in one go. Apple Intelligence then sorts that text into the schema in two passes, each
/// in its own session: the title, the shopping list and the tools first, then the method and
/// the troubleshooting. Neither pass is asked to cook anything, only to put what is written
/// where it goes.
///
/// A last pass reads the sorted recipe back and says what does not hold up, and whatever it asks
/// for is made by the same passes a cook's own request goes through. The fixed recipe is read
/// back again, so a fix that breaks something else is caught, until nothing is left to fix or
/// the loop has been round `reviewLimit` times.
@MainActor
@Observable
public final class RecipeGenerator {
    public enum State: Equatable {
        case idle
        case generating
        case failed(String)
    }

    public private(set) var state: State = .idle

    /// Every change is passed on to the observer, so the lock screen keeps up with the sheet.
    public private(set) var progress = GenerationProgress() {
        didSet { observer?.runUpdated(progress.activity) }
    }

    /// The Apple model, the cloud it falls back to, and the background time a pass runs in.
    private let passes = ModelPasses()

    /// Where the run reports how far along it is.
    private let observer: (any RunObserver)?

    /// Carries out whatever the review asks for. It is the same editor a cook's own request
    /// runs through, driven here from a plan the review wrote rather than from words.
    private let reviser = RecipeAskEditor()

    /// How many times the recipe is read back before it is handed over as it stands.
    private static let reviewLimit = 2

    public init(observer: (any RunObserver)? = nil) {
        self.observer = observer
    }

    /// Both models have to be there: Granite to write and Apple Intelligence to sort.
    public var isAvailable: Bool { passes.isAvailable && WriterModel.isInstalled }

    /// Why the button is disabled, in words a cook can act on.
    public var unavailableReason: LocalizedStringResource? {
        passes.unavailableReason
            ?? (WriterModel.isInstalled ? nil : LocalizedStringResource(culinary: "Generate.Unavailable.WriterMissing"))
    }

    public func generate(_ asked: GenerationRequest) async -> Recipe? {
        let request = asked.asAsked
        state = .generating
        progress = GenerationProgress()
        observer?.runStarted(progress.activity)
        passes.beginBackgroundRun(named: "Recipe generation")
        defer { passes.endBackgroundRun() }
        do {
            let written = try await write(request)
            let shopping = try await structureShopping(written)
            let method = try await structureMethod(written, shopping: shopping)
            let sorted = Self.makeRecipe(shopping: shopping, method: method)
            let reviewed = await review(sorted)
            progress.isFinished = true
            state = .idle
            observer?.runEnded(progress.activity, succeeded: true)
            return reviewed
        } catch {
            state = .failed(error.localizedDescription)
            observer?.runEnded(progress.activity, succeeded: false)
            return nil
        }
    }

    // MARK: - Passes

    /// Granite writes the recipe as a cookbook would print it, streamed onto the screen as it
    /// comes.
    private func write(_ request: GenerationRequest) async throws -> String {
        progress.stage = .write
        var written = ""
        let stream = RecipeWriter.write(
            instructions: Self.writeInstructions(for: request),
            prompt: Self.prompt(for: request),
            model: WriterModel.fileURL
        )
        for try await piece in stream {
            written += piece
            progress.draft = written
            progress.writtenTokens += 1
        }
        let text = written.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw WriterError.empty }
        return text
    }

    private func structureShopping(_ written: String) async throws -> StructuredShopping {
        progress.stage = .shopping
        return try await passes.run(instructions: Self.structureInstructions) { session in
            let stream = session.streamResponse(
                to: Self.structurePrompt(written, ask: Self.text("Generate.Prompt.Structure.Shopping.Ask")),
                generating: StructuredShopping.self
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
            guard let latest else { throw IntelligenceError.empty }
            let shopping = try StructuredShopping(latest)
            guard !(shopping.supermarket + shopping.general + shopping.optional).isEmpty else {
                throw IntelligenceError.empty
            }
            return shopping
        }
    }

    /// The method is sorted with the shopping list beside it, so a step names an ingredient the
    /// way the list does.
    private func structureMethod(
        _ written: String,
        shopping: StructuredShopping
    ) async throws -> StructuredMethod {
        progress.stage = .method
        let method = try await passes.run(instructions: Self.structureInstructions) { session in
            let stream = session.streamResponse(
                to: Self.structurePrompt(
                    written,
                    ask: Self.text(
                        "Generate.Prompt.Structure.Method.Ask",
                        Self.joined((shopping.supermarket + shopping.general + shopping.optional).map(\.item))
                    )
                ),
                generating: StructuredMethod.self
            )
            var latest: GeneratedContent?
            for try await snapshot in stream {
                let partial = snapshot.content
                progress.outline = partial.steps?.compactMap(\.title) ?? []
                progress.stepCount = progress.outline.count
                progress.troubleshootingCount = partial.troubleshooting?.count ?? 0
                latest = snapshot.rawContent
            }
            guard let latest else { throw IntelligenceError.empty }
            return try StructuredMethod(latest)
        }
        guard !method.steps.isEmpty else { throw IntelligenceError.empty }
        return method
    }

    /// Reads the sorted recipe back and fixes whatever does not hold up, then reads it back
    /// again. The loop stops as soon as a read through finds nothing, and a recipe that is
    /// written is worth more than one more read through, so a review that fails leaves the
    /// recipe as it stands rather than losing it.
    private func review(_ written: Recipe) async -> Recipe {
        progress.stage = .review
        var recipe = written
        progress.title = recipe.title
        progress.outline = recipe.steps.map(\.title)
        for _ in 0..<Self.reviewLimit {
            do {
                let found = try await passes.run(instructions: Self.reviewInstructions) { session in
                    let response = try await session.respond(
                        to: Self.reviewPrompt(for: recipe),
                        generating: GeneratedRecipeReview.self
                    )
                    return response.content.isGood ? [] : response.content.fixes
                }
                let plan = RecipeAskEditor.ordered(found)
                guard !plan.isEmpty else { break }
                recipe = try await reviser.revise(recipe, with: plan)
                progress.fixCount += plan.count
                progress.title = recipe.title
                progress.time = recipe.time
                progress.serves = recipe.serves
                progress.outline = recipe.steps.map(\.title)
            } catch {
                break
            }
        }
        return recipe
    }

    // MARK: - Prompts

    /// The prompt shorthands, so a prompt below reads as prose rather than as calls.
    private static func text(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        let format = String(culinary: key)
        return arguments.isEmpty ? format : String(format: format, arguments: arguments)
    }

    private static func joined(_ items: [String]) -> String { ModelPasses.joined(items) }

    private static var houseStyle: String { ModelPasses.houseStyle }

    /// What Granite is told before the cook's request. The cook's kitchen and tools, when they
    /// listed them, are limits on the whole recipe, so they are set here rather than asked for.
    private static func writeInstructions(for request: GenerationRequest) -> String {
        var instructions = houseStyle + "\n\n" + text("Generate.Prompt.Write")
        if !request.ingredients.isEmpty {
            instructions += "\n\n" + text("Generate.Prompt.Write.Kitchen")
        }
        if !request.tools.isEmpty {
            instructions += "\n\n" + text("Generate.Prompt.Write.Tools")
        }
        return instructions
    }

    private static var structureInstructions: String {
        houseStyle + "\n\n" + text("Generate.Prompt.Structure")
    }

    private static var reviewInstructions: String {
        houseStyle + "\n\n" + text("Generate.Prompt.Review")
    }

    private static func prompt(for request: GenerationRequest) -> String {
        var lines: [String] = []
        if request.trimmedDescription.isEmpty {
            lines.append(text(request.ingredients.isEmpty ? "Generate.Prompt.Ask.Any" : "Generate.Prompt.Ask.FromKitchen"))
        } else {
            lines.append(text("Generate.Prompt.Ask.Dish", request.trimmedDescription))
        }
        if !request.ingredients.isEmpty {
            lines.append(text("Generate.Prompt.Have.Ingredients", joined(request.ingredientNames)))
        }
        if !request.tools.isEmpty {
            lines.append(text("Generate.Prompt.Have.Tools", joined(request.toolNames)))
        }
        return lines.joined(separator: "\n")
    }

    /// The written recipe handed to a sorting pass, fenced off so the model reads it as the
    /// thing to sort rather than as something it is being told.
    private static func structurePrompt(_ written: String, ask: String) -> String {
        [
            text("Generate.Prompt.Structure.Source", written),
            "",
            ask,
        ].joined(separator: "\n")
    }

    /// The whole recipe as the read through gets it, which is the same shape a cook's own
    /// request is planned against.
    private static func reviewPrompt(for recipe: Recipe) -> String {
        [
            RecipeAskEditor.summary(of: recipe),
            "",
            text("Generate.Prompt.Review.Ask"),
        ].joined(separator: "\n")
    }

    // MARK: - Assembly

    /// Maps the sorted recipe onto the on-disk schema, pinning every icon to one that exists.
    static func makeRecipe(shopping: StructuredShopping, method: StructuredMethod) -> Recipe {
        let sections = IngredientSections(
            supermarket: section(shopping.supermarket),
            general: section(shopping.general),
            optional: section(shopping.optional)
        )
        let tools = shopping.tools.map { tool in
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
            id: Recipe.makeID(from: shopping.title),
            title: shopping.title,
            time: shopping.time,
            serves: shopping.serves,
            tried: nil,
            ingredients: sections,
            tools: tools,
            steps: withoutRepeats(method.steps).map { step in
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
            troubleshooting: method.troubleshooting.map {
                Troubleshooting(problem: $0.problem, solution: $0.solution)
            }
        )
    }

    /// Drops a step that is the step above it written out again, which is how a sorting pass
    /// most often goes wrong. A step that only shares a title keeps its place, since what it
    /// says is still part of the method, and the read through is left to sort it out.
    private static func withoutRepeats(_ steps: [StructuredStep]) -> [StructuredStep] {
        var seen: Set<String> = []
        return steps.compactMap { step in
            let title = step.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let points = step.points
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !title.isEmpty, !points.isEmpty,
                  seen.insert(Step.comparable(([title] + points).joined(separator: " "))).inserted
            else { return nil }
            return StructuredStep(title: title, points: points)
        }
    }

    /// A section is written only when it holds entries. Each entry is pinned to the icon the
    /// sorting pass named, and falls back to a search on its name when that icon does not
    /// exist.
    private static func section(_ entries: [StructuredIngredient]) -> [Ingredient]? {
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
