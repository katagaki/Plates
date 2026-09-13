import FoundationModels
import Foundation

/// What the model decided to change, and where. The target is written as a plain token rather
/// than prose, so a plan can be carried out rather than read.
enum EditTarget: String, CaseIterable, Sendable {
    case details
    case ingredients
    case tools
    case step
    case addStep = "add-step"
    case removeStep = "remove-step"
    case troubleshooting

    /// Whether the change lands on one step rather than on the recipe as a whole.
    var isAboutOneStep: Bool {
        self == .step || self == .addStep || self == .removeStep
    }
}

/// One change from the plan, ready to carry out.
struct PlannedEdit: Equatable, Sendable {
    var target: EditTarget
    /// What to call this change on screen. The model writes it, in the cook's language.
    var title: String
    /// What to change, in the model's own words, handed to the pass that carries it out.
    var instruction: String
    /// The step it is about, counting from 1, or 0 when it is not about one step.
    var step: Int
}

/// The plan: what the model decided to change about the recipe, in the order to change it.
@Generable(description: "The changes to make to a recipe")
struct GeneratedEditPlan {
    @Guide(description: "The changes to make. Only what the cook asked for, nothing else.", .count(1...5))
    var edits: [GeneratedEdit]
}

@Generable
struct GeneratedEdit {
    @Guide(
        description: """
            What this change touches. Use 'details' for the title, the time, or the serving \
            count, 'ingredients' for the shopping list, 'tools' for the equipment, 'step' to \
            rewrite a step that is already there, 'add-step' for a new step, 'remove-step' to \
            drop one, and 'troubleshooting' for the notes about what goes wrong.
            """,
        .anyOf(EditTarget.allCases.map(\.rawValue))
    )
    var target: String

    @Guide(description: "What this change does, as a short imperative title of two to five words")
    var title: String

    @Guide(description: "One sentence telling whoever makes this change exactly what to do")
    var instruction: String

    @Guide(description: "The step number this change is about, counting from 1. Use 0 when it is about no single step.")
    var step: Int
}

/// A recipe read back the way a cook reads one, with anything that does not hold up written as
/// the change that fixes it. The read through at the end of a generation and the one at the end
/// of a rewrite both come back in this shape, so both are carried out as a plan.
@Generable(description: "Problems with a written recipe, as the changes that fix them")
struct GeneratedRecipeReview {
    @Guide(description: "True when the recipe holds up as it is and nothing needs changing")
    var isGood: Bool

    @Guide(
        description: "The changes the recipe needs. Leave this empty when it is already good.",
        .maximumCount(3)
    )
    var fixes: [GeneratedEdit]
}

/// A recipe's title, timing, and serving count, rewritten.
@Generable(description: "A recipe's title, timing, and serving count")
struct GeneratedRecipeDetails {
    @Guide(description: "Title in title case, two to four words. Name the dish and nothing else.")
    var title: String

    @Guide(description: "Total time written as a minute count, for example '15 min'")
    var time: String

    @Guide(description: "How many people it serves, as a plain count such as '1' or '1 to 2'")
    var serves: String
}

/// A recipe's shopping list, rewritten.
@Generable(description: "A recipe's measured shopping list")
struct GeneratedIngredientList {
    @Guide(
        description: "The fresh and chilled items: vegetables, meat, seafood, dairy, bread, eggs",
        .maximumCount(8)
    )
    var supermarket: [GeneratedIngredient]

    @Guide(
        description: "The shelf-stable items: oil, soy sauce, salt, sugar, packed rice, pasta",
        .maximumCount(8)
    )
    var general: [GeneratedIngredient]

    @Guide(description: "Anything that can be skipped. Leave empty when nothing is optional.", .maximumCount(3))
    var optional: [GeneratedIngredient]
}

/// A recipe's equipment, rewritten.
@Generable(description: "The tools a recipe needs")
struct GeneratedToolList {
    @Guide(description: "The pans, pots, knives and bowls needed", .count(2...8))
    var tools: [GeneratedTool]
}

/// One step, written out whole.
@Generable(description: "One step of a recipe")
struct GeneratedStep {
    @Guide(description: "A short imperative step title, such as 'Brown pork'")
    var title: String

    @Guide(description: "Two to three plain sentences describing what to do", .count(2...3))
    var points: [String]
}

/// How far along a rewrite is. The rows are not known until the model has decided what to
/// change, so unlike a generation they are built as the run goes, and the read through at the
/// end adds rows of its own for whatever it asks for.
struct EditProgress: Equatable, Sendable {
    /// One planned change, as the screen shows it.
    struct Change: Equatable, Sendable, Identifiable {
        enum State: Equatable, Sendable {
            case waiting
            case working
            case done
        }

        let id: Int
        /// Written by the model, so shown as written rather than looked up.
        var title: String
        var state: State = .waiting
    }

    /// True until the model has settled on what to change.
    var isPlanning = true
    var changes: [Change] = []
    /// How many changes the plan itself called for. Anything past them came out of the read
    /// through, so the bar counts it as part of the read through rather than the plan.
    var plannedCount = 0
    /// True while the recipe is being read back, which is once the plan has been carried out.
    var isReviewing = false
    var isFinished = false

    /// The recipe as it stands, so the preview under the checklist reads what the changes have
    /// done to it. Written by the model, so shown as written.
    var title = ""
    var time = ""
    var serves = ""
    var steps: [String] = []

    /// Takes the recipe as it now stands, after a change lands on it.
    mutating func show(_ recipe: Recipe) {
        title = recipe.title
        time = recipe.time
        serves = recipe.serves
        steps = recipe.steps.map(\.title)
    }

    /// The change being made right now, for the lock screen.
    var currentTitle: String? {
        changes.first { $0.state == .working }?.title
    }

    /// Working out the plan is worth the first sixth, the planned changes most of the rest, and
    /// the read through the last fifth. Only the planned changes are counted, so the rows the
    /// read through adds never send the bar backwards. How long the read through itself takes
    /// is not known while it runs, so it counts as half done from the moment it starts.
    var fraction: Double {
        guard !isFinished else { return 1 }
        guard !isPlanning else { return 0.05 }
        let planned = changes.prefix(plannedCount).filter { $0.state == .done }.count
        let applied = plannedCount == 0 ? 1 : Double(planned) / Double(plannedCount)
        let review = isReviewing ? 0.5 : 0.0
        return 0.15 + applied * 0.65 + review * 0.2
    }

    var activity: ActivityProgress {
        let stage: LocalizedStringResource = if isPlanning {
            "Edit.Progress.Planning"
        } else if isReviewing {
            "Edit.Progress.Reviewing"
        } else {
            "Edit.Progress.Applying"
        }
        return ActivityProgress(
            stage: String(localized: stage),
            dish: currentTitle,
            fraction: fraction
        )
    }
}

/// Rewrites a recipe from a request in the cook's own words.
///
/// The model is asked twice over: once to decide what to change, and then once for each change
/// it decided on, each in its own session and each given only the part of the recipe it
/// touches. Nothing carries the whole recipe and the whole request at once, and the plan is
/// what the screen shows as a checklist, so the cook watches the changes it settled on being
/// made one at a time.
///
/// Once the plan is carried out the recipe is read back against what the cook asked for, and
/// whatever that finds is made the same way, as rows added to the checklist. The fixed recipe is
/// read back again, until nothing is left to fix or the loop has been round `reviewLimit` times.
@MainActor
@Observable
final class RecipeAskEditor {
    enum State: Equatable {
        case idle
        case working
        case awaitingApproval
        case failed(String)
    }

    private(set) var state: State = .idle

    private(set) var progress = EditProgress() {
        didSet { activity.update(progress.activity) }
    }

    private(set) var proposedEdits: [PlannedEdit] = []
    private var plannedRecipe: Recipe?
    private var plannedRequest = ""

    private let passes = ModelPasses()
    private let activity = GenerationActivity()

    /// How many times the recipe is read back before it is handed over as it stands.
    private static let reviewLimit = 2

    var isAvailable: Bool { passes.isAvailable }

    var unavailableReason: LocalizedStringResource? { passes.unavailableReason }

    /// Plans changes without generating or saving any rewritten recipe content.
    func prepare(_ recipe: Recipe, request: String) async {
        guard state != .working else { return }
        state = .working
        proposedEdits = []
        plannedRecipe = nil
        progress = EditProgress()
        progress.show(recipe)
        passes.beginBackgroundRun(named: "Recipe edit planning")
        defer { passes.endBackgroundRun() }
        do {
            let plan = try await planEdits(for: recipe, request: request)
            guard !plan.isEmpty else { throw EditError.nothingToChange }
            proposedEdits = plan
            plannedRecipe = recipe
            plannedRequest = request
            progress.isPlanning = false
            state = .awaitingApproval
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func discardPlan() {
        guard state != .working else { return }
        proposedEdits = []
        plannedRecipe = nil
        plannedRequest = ""
        state = .idle
    }

    /// Applies exactly the reviewed plan to the recipe it was prepared for.
    func applyApprovedPlan() async -> Recipe? {
        guard state == .awaitingApproval, let recipe = plannedRecipe,
              !proposedEdits.isEmpty else { return nil }
        let plan = proposedEdits
        let request = plannedRequest
        state = .working
        progress = EditProgress()
        progress.show(recipe)
        progress.isPlanning = false
        progress.plannedCount = plan.count
        progress.changes = plan.enumerated().map {
            EditProgress.Change(id: $0.offset, title: $0.element.title)
        }
        activity.start(progress.activity)
        passes.beginBackgroundRun(named: "Recipe editing")
        defer { passes.endBackgroundRun() }
        do {
            var edited = recipe
            for (index, edit) in plan.enumerated() {
                progress.changes[index].state = .working
                edited = try await apply(edit, to: edited)
                progress.changes[index].state = .done
                progress.show(edited)
            }
            edited = await review(edited, request: request)
            progress.isFinished = true
            state = .idle
            activity.end(progress.activity, outcome: "Edit.Activity.Done")
            return Self.tidied(edited, against: recipe)
        } catch {
            state = .failed(error.localizedDescription)
            activity.end(progress.activity, outcome: "Edit.Activity.Failed")
            return nil
        }
    }

    // MARK: - Reading it back

    /// Reads the rewritten recipe back against what the cook asked for, and makes whatever that
    /// asks for the same way the plan was made, as rows added under the ones already there. A
    /// recipe the cook can cook is worth more than one more read through, so a read that fails
    /// leaves the recipe as it stands rather than losing the changes already made.
    private func review(_ edited: Recipe, request: String) async -> Recipe {
        progress.isReviewing = true
        defer { progress.isReviewing = false }
        var recipe = edited
        for _ in 0..<Self.reviewLimit {
            do {
                let found = try await passes.run(instructions: Self.reviewInstructions) { session in
                    let response = try await session.respond(
                        to: Self.reviewPrompt(for: recipe, request: request),
                        generating: GeneratedRecipeReview.self
                    )
                    return response.content.isGood ? [] : response.content.fixes
                }
                let plan = Self.ordered(found)
                guard !plan.isEmpty else { break }
                let first = progress.changes.count
                progress.changes += plan.enumerated().map {
                    EditProgress.Change(id: first + $0.offset, title: $0.element.title)
                }
                for (index, edit) in plan.enumerated() {
                    progress.changes[first + index].state = .working
                    recipe = try await apply(edit, to: recipe)
                    progress.changes[first + index].state = .done
                    progress.show(recipe)
                }
            } catch {
                break
            }
        }
        return recipe
    }

    /// Carries out a plan somebody else worked out, with no progress or activity of its own.
    /// The read through at the end of a generation comes back with a plan in this shape, so a
    /// fix it asks for is made by the same passes a cook's own request goes through.
    func revise(_ recipe: Recipe, with plan: [PlannedEdit]) async throws -> Recipe {
        var edited = recipe
        for edit in plan {
            edited = try await apply(edit, to: edited)
        }
        return Self.tidied(edited, against: recipe)
    }

    // MARK: - Working out what to change

    /// Asks what to change, and puts the answer in an order that can be carried out.
    private func planEdits(for recipe: Recipe, request: String) async throws -> [PlannedEdit] {
        let planned = try await passes.run(instructions: Self.planInstructions) { session in
            let stream = session.streamResponse(
                to: Self.planPrompt(for: recipe, request: request),
                generating: GeneratedEditPlan.self
            )
            var latest: GeneratedContent?
            for try await snapshot in stream {
                latest = snapshot.rawContent
            }
            guard let latest else { throw IntelligenceError.empty }
            return try GeneratedEditPlan(latest).edits
        }
        return Self.ordered(planned)
    }

    /// Reads a plan the model wrote, dropping anything it cannot carry out, and puts what is
    /// left in an order that can be. Changes to the recipe as a whole come first, and step
    /// changes run from the last step back, so adding or dropping one never moves a step a
    /// later change was counting on.
    static func ordered(_ planned: [GeneratedEdit]) -> [PlannedEdit] {
        let edits = planned.compactMap { edit -> PlannedEdit? in
            let token = edit.target.trimmingCharacters(in: .whitespaces).lowercased()
            let title = edit.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let target = EditTarget(rawValue: token), !title.isEmpty else { return nil }
            return PlannedEdit(
                target: target,
                title: title,
                instruction: edit.instruction.trimmingCharacters(in: .whitespacesAndNewlines),
                step: max(0, edit.step)
            )
        }
        let wholeRecipe = edits.filter { !$0.target.isAboutOneStep }
        let steps = edits.filter(\.target.isAboutOneStep).sorted { $0.step > $1.step }
        return wholeRecipe + steps
    }

    // MARK: - Making the change

    private func apply(_ edit: PlannedEdit, to recipe: Recipe) async throws -> Recipe {
        var recipe = recipe
        switch edit.target {
        case .details:
            let details = try await write(GeneratedRecipeDetails.self, for: edit, in: recipe)
            recipe.title = details.title
            recipe.time = details.time
            recipe.serves = details.serves
        case .ingredients:
            let list = try await writeIngredients(for: edit, in: recipe)
            recipe.ingredients = Self.sections(list, keeping: recipe)
        case .tools:
            let list = try await write(GeneratedToolList.self, for: edit, in: recipe)
            recipe.tools = list.tools.map(Self.tool)
        case .step:
            let index = edit.step - 1
            guard recipe.steps.indices.contains(index) else { return recipe }
            let written = try await write(GeneratedStep.self, for: edit, in: recipe)
            recipe.steps[index] = Step(title: written.title, icons: nil, points: written.points)
        case .addStep:
            let written = try await write(GeneratedStep.self, for: edit, in: recipe)
            // A step the method already has is not added again. The model is told to put a new
            // step where a cook would do it, and this is what holds when it writes one that is
            // already there.
            let title = Step.comparable(written.title)
            guard !recipe.steps.contains(where: { Step.comparable($0.title) == title }) else {
                return recipe
            }
            let index = edit.step == 0 ? recipe.steps.count : min(edit.step - 1, recipe.steps.count)
            let step = Step(title: written.title, icons: nil, points: written.points)
            recipe.steps.insert(step, at: max(0, index))
        case .removeStep:
            let index = edit.step - 1
            // A recipe with no method at all is worse than one step too many.
            guard recipe.steps.indices.contains(index), recipe.steps.count > 1 else {
                return recipe
            }
            recipe.steps.remove(at: index)
        case .troubleshooting:
            let list = try await write(GeneratedTroubleshootingList.self, for: edit, in: recipe)
            recipe.troubleshooting = list.entries.map {
                Troubleshooting(problem: $0.problem, solution: $0.solution)
            }
        }
        return recipe
    }

    /// One change, made in a session of its own that is given the recipe and nothing else.
    private func write<Content: Generable>(
        _ type: Content.Type,
        for edit: PlannedEdit,
        in recipe: Recipe
    ) async throws -> Content {
        try await passes.run(instructions: Self.applyInstructions(for: edit.target)) { session in
            try await session.respond(
                to: Self.applyPrompt(for: edit, in: recipe),
                generating: Content.self
            ).content
        }
    }

    /// The shopping list is the one change the catalog has a say in, so the pass that writes it
    /// can look an ingredient up while it works.
    private func writeIngredients(
        for edit: PlannedEdit,
        in recipe: Recipe
    ) async throws -> GeneratedIngredientList {
        try await passes.run(
            tools: [IngredientLookupTool(available: [])],
            instructions: Self.applyInstructions(for: .ingredients)
        ) { session in
            try await session.respond(
                to: Self.applyPrompt(for: edit, in: recipe),
                generating: GeneratedIngredientList.self
            ).content
        }
    }

    // MARK: - Assembly

    /// A rewritten shopping list, pinned to icons. An ingredient the recipe already carried
    /// keeps the icon it had, so a change to the amounts does not redraw the list.
    private static func sections(
        _ list: GeneratedIngredientList,
        keeping recipe: Recipe
    ) -> IngredientSections {
        let known = Dictionary(
            (RecipeList.allCases.filter(\.isIngredients).flatMap(recipe.ingredientList(in:)))
                .map { ($0.item.lowercased(), $0.icon) },
            uniquingKeysWith: { first, _ in first }
        )
        func section(_ entries: [GeneratedIngredient]) -> [Ingredient]? {
            guard !entries.isEmpty else { return nil }
            return entries.map { entry in
                Ingredient(
                    item: entry.item,
                    icon: known[entry.item.lowercased()]
                        ?? IconCatalog.ingredientPath(
                            for: IconCatalog.resolveIngredient(entry.item, itemName: entry.item)
                        ),
                    amount: entry.amount,
                    note: trimmed(entry.note)
                )
            }
        }
        return IngredientSections(
            supermarket: section(list.supermarket),
            general: section(list.general),
            optional: section(list.optional)
        )
    }

    private static func tool(_ tool: GeneratedTool) -> Tool {
        Tool(
            name: tool.name,
            icon: IconCatalog.toolPath(
                for: IconCatalog.resolveTool(tool.icon, itemName: tool.name)
            ),
            required: tool.required,
            note: trimmed(tool.note)
        )
    }

    /// The edited recipe put straight: a step the model rewrote is marked with the icons its
    /// words point at, a step it left alone keeps the icons it had minus anything the recipe no
    /// longer carries, and the file it came from is the file it goes back to.
    private static func tidied(_ edited: Recipe, against original: Recipe) -> Recipe {
        var recipe = edited
        recipe.id = original.id
        let ingredients = RecipeList.allCases
            .filter(\.isIngredients)
            .flatMap(recipe.ingredientList(in:))
        let carried = Set(ingredients.map(\.icon) + recipe.tools.map(\.icon))
        let untouched = Set(original.steps.map(\.title))
        recipe.steps = recipe.steps.map { step in
            var step = step
            if untouched.contains(step.title), let icons = step.icons {
                step.icons = icons.filter(carried.contains)
            } else {
                step.icons = Step.icons(
                    forText: ([step.title] + step.points).joined(separator: " "),
                    ingredients: ingredients,
                    tools: recipe.tools
                )
            }
            if step.icons?.isEmpty ?? false { step.icons = nil }
            return step
        }
        return recipe
    }

    private static func trimmed(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private enum EditError: LocalizedError {
        case nothingToChange

        var errorDescription: String? {
            String(localized: "Edit.Error.NoChanges")
        }
    }

    // MARK: - Prompts

    private static func text(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        let format = String(localized: key)
        return arguments.isEmpty ? format : String(format: format, arguments: arguments)
    }

    private static var planInstructions: String {
        ModelPasses.houseStyle + "\n\n" + text("Edit.Prompt.Plan")
    }

    private static var reviewInstructions: String {
        ModelPasses.houseStyle + "\n\n" + text("Edit.Prompt.Review")
    }

    private static func applyInstructions(for target: EditTarget) -> String {
        let key: String.LocalizationValue = switch target {
        case .details: "Edit.Prompt.Apply.Details"
        case .ingredients: "Edit.Prompt.Apply.Ingredients"
        case .tools: "Edit.Prompt.Apply.Tools"
        case .step, .addStep, .removeStep: "Edit.Prompt.Apply.Step"
        case .troubleshooting: "Edit.Prompt.Apply.Troubleshooting"
        }
        return ModelPasses.houseStyle + "\n\n" + text(key)
    }

    private static func planPrompt(for recipe: Recipe, request: String) -> String {
        [
            summary(of: recipe),
            "",
            text("Edit.Prompt.Plan.Ask", request),
        ].joined(separator: "\n")
    }

    /// The rewritten recipe and the request it was rewritten for, so the read through can say
    /// whether the recipe answers what was asked and still holds up as a recipe.
    private static func reviewPrompt(for recipe: Recipe, request: String) -> String {
        [
            reviewSummary(of: recipe),
            "",
            text("Edit.Prompt.Review.Ask", request),
        ].joined(separator: "\n")
    }

    /// The recipe as the read through gets it. Every other pass reads the method as step titles,
    /// which is enough to work against but not enough to check: whether a recipe makes sense is
    /// in what the steps actually say, so this is the one pass handed the steps written out, and
    /// the problems the troubleshooting notes claim to fix. It is the largest prompt the app
    /// sends, and still a fraction of the on-device window.
    private static func reviewSummary(of recipe: Recipe) -> String {
        let ingredients = RecipeList.allCases
            .filter(\.isIngredients)
            .flatMap(recipe.ingredientList(in:))
        var lines = [
            text("Generate.Prompt.Line.Summary", recipe.title, recipe.time, recipe.serves),
            text(
                "Generate.Prompt.Line.Ingredients",
                ModelPasses.joined(ingredients.map { "\($0.item) (\($0.amount))" })
            ),
            text("Generate.Prompt.Line.Tools", ModelPasses.joined(recipe.tools.map(\.name))),
            text("Edit.Prompt.Review.Method"),
        ]
        lines += recipe.steps.enumerated().map { index, step in
            text(
                "Edit.Prompt.Review.Step",
                String(index + 1),
                step.title,
                step.points.joined(separator: " ")
            )
        }
        if !recipe.troubleshooting.isEmpty {
            lines.append(text(
                "Edit.Prompt.Review.Notes",
                ModelPasses.joined(recipe.troubleshooting.map(\.problem))
            ))
        }
        return lines.joined(separator: "\n")
    }

    private static func applyPrompt(for edit: PlannedEdit, in recipe: Recipe) -> String {
        var lines = [summary(of: recipe)]
        if edit.target.isAboutOneStep, recipe.steps.indices.contains(edit.step - 1) {
            let step = recipe.steps[edit.step - 1]
            lines.append(text(
                "Edit.Prompt.Line.Step",
                String(edit.step),
                ([step.title] + step.points).joined(separator: " ")
            ))
        }
        lines.append("")
        lines.append(text("Edit.Prompt.Ask", edit.instruction))
        return lines.joined(separator: "\n")
    }

    /// The recipe as a pass reads it: what it is, what goes in it, what it is cooked with, and
    /// the method as numbered titles. Short enough that a pass carries the whole recipe, and
    /// the same shape the read through at the end of a generation is given.
    static func summary(of recipe: Recipe) -> String {
        let ingredients = RecipeList.allCases
            .filter(\.isIngredients)
            .flatMap(recipe.ingredientList(in:))
        return [
            text("Generate.Prompt.Line.Summary", recipe.title, recipe.time, recipe.serves),
            text(
                "Generate.Prompt.Line.Ingredients",
                ModelPasses.joined(ingredients.map { "\($0.item) (\($0.amount))" })
            ),
            text("Generate.Prompt.Line.Tools", ModelPasses.joined(recipe.tools.map(\.name))),
            text("Generate.Prompt.Line.Method", method(of: recipe)),
        ].joined(separator: "\n")
    }

    private static func method(of recipe: Recipe) -> String {
        recipe.steps.enumerated()
            .map { "\($0.offset + 1). \($0.element.title)" }
            .joined(separator: " ")
    }
}
