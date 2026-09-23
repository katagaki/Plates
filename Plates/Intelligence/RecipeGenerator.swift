import FoundationModels
import Foundation
import UIKit

/// What a new recipe is built from: a dish in the cook's words, what they have in the
/// kitchen, or both.
struct GenerationRequest: Equatable, Sendable {
    /// The dish, written by the cook. May be empty when they only picked what they have.
    var description = ""
    /// Ingredient asset names picked from the catalog.
    var ingredients: [String] = []
    /// Tool asset names picked from the catalog.
    var tools: [String] = []
    /// Set when the cook wants the picks left out, so the model writes from the dish alone.
    var ignoresPicks = false

    /// Nothing to work from, so there is nothing to ask for. Ignoring the picks is itself an
    /// ask, so a recipe can be written from nothing else.
    var isEmpty: Bool {
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

/// One ingredient the dish is built from, already pinned to an icon the app can draw.
struct PickedIngredient: Equatable, Sendable {
    /// The name the model wrote, kept as the cook reads it.
    var name: String
    /// The catalog asset it was resolved onto.
    var asset: String
}

/// What the first pass settled on: the dish, and the ingredients it is cooked from.
struct IngredientPick: Equatable, Sendable {
    var dish: String
    var items: [PickedIngredient]

    var names: [String] { items.map(\.name) }
}

/// The first pass: the ingredients the dish is built from, chosen before anything is written
/// about how to cook it. Settling the list on its own means the next pass measures ingredients
/// that already work together, instead of inventing them and checking them against the catalog
/// while it writes everything else.
@Generable(description: "The ingredients a dish is built from")
struct GeneratedIngredientPick {
    @Guide(description: "The dish these ingredients make, in two to four words")
    var dish: String

    @Guide(
        description: "Ingredient names the dish is cooked from, such as 'Spring onion'",
        .count(4...10)
    )
    var items: [String]
}

/// The second pass: what the dish is called and what each picked ingredient is measured at.
/// The method comes later, so this stays small enough to generate reliably.
@Generable(description: "A recipe's title, timing, measured shopping list, and tools")
struct GeneratedRecipeBase {
    @Guide(description: "Title in title case, two to four words. Name the dish and nothing else.")
    var title: String

    @Guide(description: "Total time written as a minute count, for example '15 min'")
    var time: String

    @Guide(description: "How many people it serves, as a plain count such as '1' or '1 to 2'")
    var serves: String

    @Guide(
        description: "The picked fresh and chilled items: vegetables, meat, seafood, dairy, bread, eggs",
        .maximumCount(6)
    )
    var supermarket: [GeneratedIngredient]

    @Guide(
        description: "The picked shelf-stable items: oil, soy sauce, salt, sugar, packed rice, pasta",
        .maximumCount(6)
    )
    var general: [GeneratedIngredient]

    @Guide(description: "Any picked item that can be skipped. Leave empty when nothing is optional.", .maximumCount(3))
    var optional: [GeneratedIngredient]

    @Guide(description: "The pans, pots, knives and bowls needed", .count(2...6))
    var tools: [GeneratedTool]
}

/// The third pass: the shape of the method, titles only. The prep and the cooking are asked
/// for as two lists rather than one, so the order they are written in is the order they are
/// done in, and a model that would have reached back for the chopping half way through the
/// cooking has nowhere to put it.
@Generable(description: "The method for a recipe, as step titles: the prep, then the cooking")
struct GeneratedStepOutline {
    @Guide(
        description: "Titles for the work done before any heat: cutting, measuring, mixing, marinating",
        .count(1...3)
    )
    var prep: [String]

    @Guide(
        description: "Titles for the cooking and the plating, in the order they are done",
        .count(3...6)
    )
    var cooking: [String]

    /// The method as the recipe carries it: the prep first, then the cooking.
    var steps: [String] { prep + cooking }
}

/// The fourth pass: one step written out on its own.
@Generable(description: "What to do during one step of a recipe")
struct GeneratedStepDetail {
    @Guide(description: "Two to three plain sentences describing what to do", .count(2...3))
    var points: [String]
}

/// The fifth pass: what goes wrong and how to fix it.
@Generable(description: "Problems a cook runs into with this recipe, and their fixes")
struct GeneratedTroubleshootingList {
    @Guide(description: "Things that commonly go wrong and how to fix them", .count(2...5))
    var entries: [GeneratedTroubleshooting]
}

@Generable
struct GeneratedIngredient {
    @Guide(description: "The picked ingredient's name, written exactly as it was given to you")
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
struct GenerationProgress: Equatable, Sendable {
    /// The passes the generator runs, in order.
    enum Stage: Int, Equatable, Sendable {
        case pick
        case idea
        case outline
        case details
        case troubleshooting
        case review

        var title: LocalizedStringResource {
            switch self {
            case .pick: "Generate.Progress.Stage.Pick"
            case .idea: "Generate.Progress.Stage.Idea"
            case .outline: "Generate.Progress.Stage.Outline"
            case .details: "Generate.Progress.Stage.Details"
            case .troubleshooting: "Generate.Progress.Stage.Troubleshooting"
            case .review: "Generate.Progress.Stage.Review"
            }
        }
    }

    var stage: Stage = .pick
    /// The dish the pick pass named, shown until the recipe has a title of its own.
    var dish: String?
    var title: String?
    var time: String?
    var serves: String?
    var pickedCount = 0
    var ingredientCount = 0
    var toolCount = 0
    var stepCount = 0
    var writtenStepCount = 0
    var troubleshootingCount = 0
    /// How many fixes the review asked for and got.
    var fixCount = 0
    /// The step titles as they stand, so the preview reads the method as it is written.
    var outline: [String] = []
    /// The step the model is writing right now.
    var latestStep: String?
    /// Set when the last pass ends, so the bar always lands on full.
    var isFinished = false

    /// What the lock screen is told, which is the pass in words and the dish once it has a
    /// name of its own.
    var activity: ActivityProgress {
        ActivityProgress(
            stage: String(localized: stage.title),
            dish: title ?? dish,
            fraction: fraction
        )
    }

    /// How far along the model is. Each pass carries the share of the work it does.
    var fraction: Double {
        guard !isFinished else { return 1 }
        let pick = min(Double(pickedCount) / 6, 1)
        let idea = [
            title == nil ? 0 : 1,
            min(Double(ingredientCount) / 6, 1),
            min(Double(toolCount) / 3, 1),
        ].reduce(0, +) / 3
        let outline = min(Double(stepCount) / 5, 1)
        let details = stepCount == 0 ? 0 : Double(writtenStepCount) / Double(stepCount)
        let troubleshooting = min(Double(troubleshootingCount) / 2, 1)
        // How long the read through takes is not known while it runs, so it counts as half
        // done from the moment it starts and lands on full when the run ends.
        let review = stage == .review ? 0.5 : 0
        return pick * 0.15 + idea * 0.2 + outline * 0.1 + details * 0.3
            + troubleshooting * 0.1 + review * 0.15
    }

    /// Whether a step has been written out, so the preview can tell a step that is on the page
    /// from one that is still only a title.
    func isWritten(step index: Int) -> Bool {
        stage.rawValue > Stage.details.rawValue || index < writtenStepCount
    }
}

/// Wraps the on-device model and converts its output into a schema-shaped `Recipe`.
///
/// The recipe is written in five passes, each in its own session: the ingredients that work
/// together, then the title and their amounts, then the step titles, then every step on its
/// own, then troubleshooting. Nothing carries the whole recipe in its context, so a long
/// recipe cannot run the window out.
///
/// A sixth pass reads the finished recipe back and says what does not hold up, and whatever it
/// asks for is made by the same passes a cook's own request goes through. The fixed recipe is
/// read back again, so a fix that breaks something else is caught, until nothing is left to fix
/// or the loop has been round `reviewLimit` times.
@MainActor
@Observable
final class RecipeGenerator {
    enum State: Equatable {
        case idle
        case generating
        case failed(String)
    }

    private(set) var state: State = .idle

    /// Every change is pushed to the Live Activity, so the lock screen keeps up with the sheet.
    private(set) var progress = GenerationProgress() {
        didSet { activity.update(progress.activity) }
    }

    /// The on-device model and the background time a pass runs in.
    private let passes = ModelPasses()

    /// The lock screen face of the run.
    private let activity = GenerationActivity()

    /// Carries out whatever the review asks for. It is the same editor a cook's own request
    /// runs through, driven here from a plan the review wrote rather than from words.
    private let reviser = RecipeAskEditor()

    /// How many times the recipe is read back before it is handed over as it stands.
    private static let reviewLimit = 2

    var availability: SystemLanguageModel.Availability { passes.availability }

    var isAvailable: Bool { passes.isAvailable }

    /// Why the button is disabled, in words a cook can act on.
    var unavailableReason: LocalizedStringResource? { passes.unavailableReason }

    func generate(_ asked: GenerationRequest) async -> Recipe? {
        let request = asked.asAsked
        state = .generating
        progress = GenerationProgress()
        activity.start(progress.activity)
        passes.beginBackgroundRun(named: "Recipe generation")
        defer { passes.endBackgroundRun() }
        do {
            let pick = try await pickIngredients(request)
            let base = try await generateBase(request, pick: pick)
            let outline = try await generateOutline(for: base)
            let steps = try await generateSteps(outline: outline, base: base)
            let troubleshooting = try await generateTroubleshooting(base: base, outline: outline)
            let written = Self.makeRecipe(
                base: base,
                pick: pick,
                steps: steps,
                troubleshooting: troubleshooting
            )
            let reviewed = await review(written)
            progress.isFinished = true
            state = .idle
            activity.end(progress.activity, outcome: "Generate.Activity.Done")
            return reviewed
        } catch {
            state = .failed(error.localizedDescription)
            activity.end(progress.activity, outcome: "Generate.Activity.Failed")
            return nil
        }
    }

    // MARK: - Passes

    /// Picks the shopping list first, from the cook's kitchen when they listed one and from
    /// the catalog otherwise, and pins every name onto an icon before a word of the recipe is
    /// written.
    private func pickIngredients(_ request: GenerationRequest) async throws -> IngredientPick {
        progress.stage = .pick
        let picked = try await passes.run(
            tools: [IngredientLookupTool(available: request.ingredients)],
            instructions: Self.pickInstructions(for: request)
        ) { session in
            let stream = session.streamResponse(
                to: Self.prompt(for: request),
                generating: GeneratedIngredientPick.self
            )
            var latest: GeneratedContent?
            for try await snapshot in stream {
                progress.dish = snapshot.content.dish
                progress.pickedCount = snapshot.content.items?.count ?? 0
                latest = snapshot.rawContent
            }
            guard let latest else { throw IntelligenceError.empty }
            return try GeneratedIngredientPick(latest)
        }
        let items = Self.resolve(picked.items, kitchen: request.ingredients)
        guard !items.isEmpty else { throw IntelligenceError.empty }
        progress.pickedCount = items.count
        return IngredientPick(dish: picked.dish, items: items)
    }

    /// Pins each name the model wrote onto an icon that exists, dropping duplicates, anything
    /// the catalog has nothing close to, and anything the cook did not say they have. When
    /// that leaves nothing, the cook's own picks stand in.
    private static func resolve(_ items: [String], kitchen: [String]) -> [PickedIngredient] {
        let available = Set(kitchen)
        var picked: [PickedIngredient] = []
        for item in items {
            let name = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty,
                  let asset = IconCatalog.ingredient(named: name)
                      ?? IconCatalog.ingredientSuggestions(for: name, limit: 1).first,
                  available.isEmpty || available.contains(asset),
                  !picked.contains(where: { $0.asset == asset })
            else { continue }
            picked.append(PickedIngredient(name: name, asset: asset))
        }
        guard picked.isEmpty else { return picked }
        return kitchen.prefix(GenerationRequest.listLimit).map {
            PickedIngredient(name: IconCatalog.displayName(for: $0), asset: $0)
        }
    }

    private func generateBase(
        _ request: GenerationRequest,
        pick: IngredientPick
    ) async throws -> GeneratedRecipeBase {
        progress.stage = .idea
        return try await passes.run(instructions: Self.instructions(for: request)) { session in
            let stream = session.streamResponse(
                to: Self.basePrompt(for: pick, request: request),
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
            guard let latest else { throw IntelligenceError.empty }
            return try GeneratedRecipeBase(latest)
        }
    }

    private func generateOutline(for base: GeneratedRecipeBase) async throws -> [String] {
        progress.stage = .outline
        let steps = try await passes.run(instructions: Self.outlineInstructions) { session in
            let stream = session.streamResponse(
                to: Self.outlinePrompt(for: base),
                generating: GeneratedStepOutline.self
            )
            var latest: GeneratedContent?
            for try await snapshot in stream {
                let partial = snapshot.content
                progress.stepCount = (partial.prep?.count ?? 0) + (partial.cooking?.count ?? 0)
                latest = snapshot.rawContent
            }
            guard let latest else { throw IntelligenceError.empty }
            return try GeneratedStepOutline(latest).steps
        }
        let method = Self.withoutRepeats(steps)
        guard !method.isEmpty else { throw IntelligenceError.empty }
        progress.stepCount = method.count
        progress.outline = method
        return method
    }

    /// Drops a step that says again what a step above it already said. The prompts ask for a
    /// method with no repeats in it, and this is what holds when the model writes one anyway.
    private static func withoutRepeats(_ steps: [String]) -> [String] {
        var seen: Set<String> = []
        return steps.compactMap { step in
            let title = step.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, seen.insert(Step.comparable(title)).inserted else { return nil }
            return title
        }
    }

    /// Each step is written in its own session, given only the shopping list and the outline.
    private func generateSteps(outline: [String], base: GeneratedRecipeBase) async throws -> [Step] {
        progress.stage = .details
        var steps: [Step] = []
        for (index, title) in outline.enumerated() {
            progress.latestStep = title
            let points = try await passes.run(instructions: Self.stepInstructions) { session in
                let response = try await session.respond(
                    to: Self.stepPrompt(number: index + 1, title: title, base: base, outline: outline),
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
        return try await passes.run(instructions: Self.troubleshootingInstructions) { session in
            let stream = session.streamResponse(
                to: Self.troubleshootingPrompt(base: base, outline: outline),
                generating: GeneratedTroubleshootingList.self
            )
            var latest: GeneratedContent?
            for try await snapshot in stream {
                progress.troubleshootingCount = snapshot.content.entries?.count ?? 0
                latest = snapshot.rawContent
            }
            guard let latest else { throw IntelligenceError.empty }
            return try GeneratedTroubleshootingList(latest).entries.map {
                Troubleshooting(problem: $0.problem, solution: $0.solution)
            }
        }
    }

    /// Reads the finished recipe back and fixes whatever does not hold up, then reads it back
    /// again. The loop stops as soon as a read through finds nothing, and a recipe that is
    /// written is worth more than one more read through, so a review that fails leaves the
    /// recipe as it stands rather than losing it.
    private func review(_ written: Recipe) async -> Recipe {
        progress.stage = .review
        var recipe = written
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
        let format = String(localized: key)
        return arguments.isEmpty ? format : String(format: format, arguments: arguments)
    }

    private static func joined(_ items: [String]) -> String { ModelPasses.joined(items) }

    private static var houseStyle: String { ModelPasses.houseStyle }

    private static func pickInstructions(for request: GenerationRequest) -> String {
        var instructions = houseStyle + "\n\n" + text("Generate.Prompt.Pick")
        if !request.ingredients.isEmpty {
            instructions += "\n\n" + text("Generate.Prompt.Pick.Kitchen")
        }
        if request.trimmedDescription.isEmpty {
            instructions += "\n\n" + text("Generate.Prompt.Pick.NoDish")
        }
        return instructions
    }

    private static func instructions(for request: GenerationRequest) -> String {
        var instructions = houseStyle + "\n\n" + text("Generate.Prompt.Base")
        if !request.tools.isEmpty {
            instructions += "\n\n" + text("Generate.Prompt.Base.Tools")
        }
        return instructions
    }

    private static var outlineInstructions: String {
        houseStyle + "\n\n" + text("Generate.Prompt.Outline")
    }

    private static var stepInstructions: String {
        houseStyle + "\n\n" + text("Generate.Prompt.Step")
    }

    private static var troubleshootingInstructions: String {
        houseStyle + "\n\n" + text("Generate.Prompt.Troubleshooting")
    }

    private static var reviewInstructions: String {
        houseStyle + "\n\n" + text("Generate.Prompt.Review")
    }

    private static func prompt(for request: GenerationRequest) -> String {
        var lines: [String] = []
        if request.trimmedDescription.isEmpty {
            lines.append(text("Generate.Prompt.Ask.Any"))
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

    /// The picked list handed to the pass that measures it.
    private static func basePrompt(for pick: IngredientPick, request: GenerationRequest) -> String {
        var lines = [
            text("Generate.Prompt.Line.Dish", pick.dish),
            text("Generate.Prompt.Line.Ingredients", joined(pick.names)),
        ]
        if !request.tools.isEmpty {
            lines.append(text("Generate.Prompt.Have.Tools", joined(request.toolNames)))
        }
        lines.append("")
        lines.append(text("Generate.Prompt.Base.Ask"))
        return lines.joined(separator: "\n")
    }

    private static func outlinePrompt(for base: GeneratedRecipeBase) -> String {
        [
            summary(of: base),
            text("Generate.Prompt.Line.Ingredients", list(base.supermarket + base.general + base.optional)),
            text("Generate.Prompt.Line.Tools", joined(base.tools.map(\.name))),
            "",
            text("Generate.Prompt.Outline.Ask"),
        ].joined(separator: "\n")
    }

    private static func stepPrompt(
        number: Int,
        title: String,
        base: GeneratedRecipeBase,
        outline: [String]
    ) -> String {
        [
            summary(of: base),
            text("Generate.Prompt.Line.Ingredients", list(base.supermarket + base.general + base.optional)),
            text("Generate.Prompt.Line.Method", method(outline)),
            "",
            text("Generate.Prompt.Step.Ask", String(number), title),
        ].joined(separator: "\n")
    }

    private static func troubleshootingPrompt(base: GeneratedRecipeBase, outline: [String]) -> String {
        [
            summary(of: base),
            text("Generate.Prompt.Line.Method", method(outline)),
            "",
            text("Generate.Prompt.Troubleshooting.Ask"),
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

    /// The one line every later pass opens with: what is being cooked, how long it takes, and
    /// how many it feeds.
    private static func summary(of base: GeneratedRecipeBase) -> String {
        text("Generate.Prompt.Line.Summary", base.title, base.time, base.serves)
    }

    /// The outline as one numbered line.
    private static func method(_ outline: [String]) -> String {
        outline.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: " ")
    }

    /// A compact "item (amount)" list, small enough to hand to every later pass.
    private static func list(_ ingredients: [GeneratedIngredient]) -> String {
        joined(ingredients.map { "\($0.item) (\($0.amount))" })
    }

    // MARK: - Assembly

    /// Maps generated content onto the on-disk schema, pinning every icon to one that exists.
    static func makeRecipe(
        base: GeneratedRecipeBase,
        pick: IngredientPick,
        steps: [Step],
        troubleshooting: [Troubleshooting]
    ) -> Recipe {
        let icons = Dictionary(
            pick.items.map { ($0.name.lowercased(), $0.asset) },
            uniquingKeysWith: { first, _ in first }
        )
        let sections = IngredientSections(
            supermarket: section(base.supermarket, icons: icons),
            general: section(base.general, icons: icons),
            optional: section(base.optional, icons: icons)
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

    /// A section is written only when it holds entries. Each entry keeps the icon the pick
    /// pass settled on, and falls back to a search when the name came back changed.
    private static func section(
        _ entries: [GeneratedIngredient],
        icons: [String: String]
    ) -> [Ingredient]? {
        guard !entries.isEmpty else { return nil }
        return entries.map { entry in
            Ingredient(
                item: entry.item,
                icon: IconCatalog.ingredientPath(
                    for: IconCatalog.resolveIngredient(
                        icons[entry.item.lowercased()] ?? entry.item,
                        itemName: entry.item
                    )
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
