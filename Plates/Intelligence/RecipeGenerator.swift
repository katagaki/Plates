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
@Generable(description: "The ingredients a one-pan dish is built from")
struct GeneratedIngredientPick {
    @Guide(description: "The dish these ingredients make, in two to four words")
    var dish: String

    @Guide(
        description: "Ingredient names that cook together in one pan, such as 'Spring onion'",
        .count(4...10)
    )
    var items: [String]
}

/// The second pass: what the dish is called and what each picked ingredient is measured at.
/// The method comes later, so this stays small enough to generate reliably.
@Generable(description: "A one-pan recipe's title, timing, measured shopping list, and tools")
struct GeneratedRecipeBase {
    @Guide(description: "Title in title case, two to four words. Do not use the words 'One-Pan'.")
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

    @Guide(description: "The pans, knives and bowls needed", .count(2...6))
    var tools: [GeneratedTool]
}

/// The third pass: the shape of the method, titles only.
@Generable(description: "The method for a one-pan recipe, as an ordered list of step titles")
struct GeneratedStepOutline {
    @Guide(description: "Short imperative step titles in order, such as 'Brown pork'", .count(4...8))
    var steps: [String]
}

/// The fourth pass: one step written out on its own.
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
    @Guide(description: "The picked ingredient's name, written exactly as it was given to you")
    var item: String

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
        case pick
        case idea
        case outline
        case details
        case troubleshooting

        var title: LocalizedStringResource {
            switch self {
            case .pick: "Generate.Progress.Stage.Pick"
            case .idea: "Generate.Progress.Stage.Idea"
            case .outline: "Generate.Progress.Stage.Outline"
            case .details: "Generate.Progress.Stage.Details"
            case .troubleshooting: "Generate.Progress.Stage.Troubleshooting"
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
    /// The step the model is writing right now.
    var latestStep: String?
    /// Set when the last pass ends, so the bar always lands on full.
    var isFinished = false

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
        return pick * 0.15 + idea * 0.25 + outline * 0.15 + details * 0.3 + troubleshooting * 0.15
    }
}

/// Wraps the on-device model and converts its output into a schema-shaped `Recipe`.
///
/// The recipe is written in five passes, each in its own session: the ingredients that work
/// together, then the title and their amounts, then the step titles, then every step on its
/// own, then troubleshooting. Nothing carries the whole recipe in its context, so a long
/// recipe cannot run the window out.
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
            let pick = try await pickIngredients(request)
            let base = try await generateBase(request, pick: pick)
            let outline = try await generateOutline(for: base)
            let steps = try await generateSteps(outline: outline, base: base)
            let troubleshooting = try await generateTroubleshooting(base: base, outline: outline)
            progress.isFinished = true
            state = .idle
            return Self.makeRecipe(
                base: base,
                pick: pick,
                steps: steps,
                troubleshooting: troubleshooting
            )
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

    /// Picks the shopping list first, from the cook's kitchen when they listed one and from
    /// the catalog otherwise, and pins every name onto an icon before a word of the recipe is
    /// written.
    private func pickIngredients(_ request: GenerationRequest) async throws -> IngredientPick {
        progress.stage = .pick
        let picked = try await run(
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
            guard let latest else { throw GenerationError.empty }
            return try GeneratedIngredientPick(latest)
        }
        let items = Self.resolve(picked.items, kitchen: request.ingredients)
        guard !items.isEmpty else { throw GenerationError.empty }
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
        return try await run(instructions: Self.instructions(for: request)) { session in
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
            guard let latest else { throw GenerationError.empty }
            return try GeneratedRecipeBase(latest)
        }
    }

    private func generateOutline(for base: GeneratedRecipeBase) async throws -> [String] {
        progress.stage = .outline
        let steps = try await run(instructions: Self.outlineInstructions) { session in
            let stream = session.streamResponse(
                to: Self.outlinePrompt(for: base),
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
        return try await run(instructions: Self.troubleshootingInstructions) { session in
            let stream = session.streamResponse(
                to: Self.troubleshootingPrompt(base: base, outline: outline),
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

    /// Every word the model is given is written in the reader's language, so the recipe
    /// comes back in the language the app is being read in.
    private static func text(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        let format = String(localized: key)
        return arguments.isEmpty ? format : String(format: format, arguments: arguments)
    }

    /// A list as the reader's language punctuates one.
    private static func joined(_ items: [String]) -> String {
        items.joined(separator: text("Generate.Prompt.Separator"))
    }

    private static var houseStyle: String { text("Generate.Prompt.HouseStyle") }

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
