import SwiftUI

/// Which of a recipe's four card lists something sits in, so an edit knows where to write back.
enum RecipeList: String, Identifiable, CaseIterable {
    case ingredients
    case optionalIngredients
    case tools
    case optionalTools

    var id: String { rawValue }

    /// Whether the list holds ingredients rather than tools.
    var isIngredients: Bool { self == .ingredients || self == .optionalIngredients }

    var title: LocalizedStringResource {
        switch self {
        case .ingredients: "Recipe.Detail.Ingredients"
        case .optionalIngredients: "Recipe.Detail.Ingredients.Optional"
        case .tools: "Recipe.Detail.Tools"
        case .optionalTools: "Recipe.Detail.Tools.Optional"
        }
    }
}

/// One card being edited: which list it is in and where in that list it sits.
struct CardEdit: Identifiable {
    let list: RecipeList
    let index: Int

    var id: String { "\(list.rawValue)-\(index)" }
}

/// Where in a list something being edited sits. An index past the end of the list is
/// something new, which is added when it is saved.
struct ListEdit: Identifiable {
    let index: Int

    var id: Int { index }
}

/// The sheet behind a card in the ingredient lists. The icon comes from the catalog, so it is
/// shown rather than typed; everything else is recipe text and is edited as written.
struct IngredientEditor: View {
    let save: (Ingredient) -> Void
    let remove: () -> Void

    @State private var draft: Ingredient

    init(ingredient: Ingredient, save: @escaping (Ingredient) -> Void, remove: @escaping () -> Void) {
        self.save = save
        self.remove = remove
        _draft = State(initialValue: ingredient)
    }

    var body: some View {
        EditorSheet(title: "Recipe.Edit.Ingredient.Title", remove: remove) {
            save(draft.tidied)
        } content: {
            Section {
                HStack(spacing: 12) {
                    RecipeIcon(path: draft.icon, size: 44)
                    TextField("Recipe.Edit.Name", text: $draft.item)
                }
                TextField("Recipe.Edit.Item.Amount", text: $draft.amount)
            }
            Section {
                TextField(
                    "Recipe.Edit.Item.Note",
                    text: Binding(get: { draft.note ?? "" }, set: { draft.note = $0 }),
                    axis: .vertical
                )
                .lineLimit(2...5)
            }
        }
    }
}

/// The same sheet for a tool, which carries a note but no amount.
struct ToolEditor: View {
    let save: (Tool) -> Void
    let remove: () -> Void

    @State private var draft: Tool

    init(tool: Tool, save: @escaping (Tool) -> Void, remove: @escaping () -> Void) {
        self.save = save
        self.remove = remove
        _draft = State(initialValue: tool)
    }

    var body: some View {
        EditorSheet(title: "Recipe.Edit.Tool.Title", remove: remove) {
            save(draft.tidied)
        } content: {
            Section {
                HStack(spacing: 12) {
                    RecipeIcon(path: draft.icon, size: 44)
                    TextField("Recipe.Edit.Name", text: $draft.name)
                }
            }
            Section {
                TextField(
                    "Recipe.Edit.Item.Note",
                    text: Binding(get: { draft.note ?? "" }, set: { draft.note = $0 }),
                    axis: .vertical
                )
                .lineLimit(2...5)
            }
        }
    }
}

/// The sheet behind a step: what it is called, what it reaches for, and what to do. The icons
/// are ticked off the recipe's own lists, so a step never shows something the recipe does not
/// carry.
struct StepEditor: View {
    /// One icon a step can be marked with, drawn from the recipe's ingredients and tools.
    struct Choice: Identifiable, Hashable {
        let path: String
        let name: String

        var id: String { path }
    }

    let choices: [Choice]
    let save: (Step) -> Void
    let remove: () -> Void

    @State private var draft: Step
    @State private var points: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    init(
        step: Step,
        choices: [Choice],
        save: @escaping (Step) -> Void,
        remove: @escaping () -> Void
    ) {
        self.choices = choices
        self.save = save
        self.remove = remove
        _draft = State(initialValue: step)
        _points = State(initialValue: step.points.joined(separator: "\n"))
    }

    var body: some View {
        EditorSheet(title: "Recipe.Edit.Step.Title", remove: remove) {
            var step = draft
            step.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            step.points = points
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            step.icons = (step.icons?.isEmpty ?? true) ? nil : step.icons
            save(step)
        } content: {
            Section {
                TextField("Recipe.Edit.Step.Name", text: $draft.title, axis: .vertical)
                    .lineLimit(1...3)
            }

            Section {
                TextField("Recipe.Edit.Step.Points", text: $points, axis: .vertical)
                    .lineLimit(4...12)
            } footer: {
                Text("Recipe.Edit.Step.Points.Footer")
            }

            if !choices.isEmpty {
                Section("Recipe.Edit.Step.Icons") {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(choices) { choice in
                            cell(choice)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
                }
            }
        }
    }

    private func cell(_ choice: StepEditor.Choice) -> some View {
        let isPicked = draft.icons?.contains(choice.path) ?? false
        return Button {
            var icons = draft.icons ?? []
            if let index = icons.firstIndex(of: choice.path) {
                icons.remove(at: index)
            } else {
                icons.append(choice.path)
            }
            draft.icons = icons
        } label: {
            VStack(spacing: 4) {
                RecipeIcon(path: choice.path, size: 44, outline: isPicked ? .accentColor : nil)
                Text(verbatim: choice.name)
                    .font(.caption)
                    .fontWeight(isPicked ? .semibold : .regular)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isPicked ? Color.accentColor : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

/// The sheet behind one of the notes kept with a recipe: what goes wrong, and what to do
/// about it.
struct NoteEditor: View {
    let save: (Troubleshooting) -> Void
    let remove: () -> Void

    @State private var draft: Troubleshooting

    init(
        note: Troubleshooting,
        save: @escaping (Troubleshooting) -> Void,
        remove: @escaping () -> Void
    ) {
        self.save = save
        self.remove = remove
        _draft = State(initialValue: note)
    }

    var body: some View {
        EditorSheet(title: "Recipe.Edit.Note.Title", remove: remove) {
            var note = draft
            note.problem = draft.problem.trimmingCharacters(in: .whitespacesAndNewlines)
            note.solution = draft.solution.trimmingCharacters(in: .whitespacesAndNewlines)
            save(note)
        } content: {
            Section {
                TextField("Recipe.Edit.Note.Problem", text: $draft.problem, axis: .vertical)
                    .lineLimit(1...3)
            }
            Section {
                TextField("Recipe.Edit.Note.Solution", text: $draft.solution, axis: .vertical)
                    .lineLimit(2...8)
            }
        }
    }
}

/// What every editing sheet is built out of: a form, a way back out without saving, and a way
/// to drop the thing being edited.
private struct EditorSheet<Content: View>: View {
    let title: LocalizedStringResource
    let remove: () -> Void
    let save: () -> Void
    @ViewBuilder let content: Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                content
                Section {
                    Button(role: .destructive) {
                        remove()
                        dismiss()
                    } label: {
                        // The role reddens the text on its own; the symbol is told to match.
                        Label("Shared.Delete", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Shared.Save") {
                        save()
                        dismiss()
                    }
                }
            }
        }
    }
}

extension Ingredient {
    /// The entry with its whitespace taken off and an empty note dropped, so nothing blank is
    /// written back to the file.
    var tidied: Ingredient {
        var entry = self
        entry.item = item.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.amount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.note = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        if entry.note?.isEmpty ?? true { entry.note = nil }
        return entry
    }
}

extension Tool {
    var tidied: Tool {
        var entry = self
        entry.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.note = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        if entry.note?.isEmpty ?? true { entry.note = nil }
        return entry
    }
}

extension Recipe {
    /// The cards one of the four lists shows. The shopping list is written in two sections but
    /// read as one, so both come back together.
    func items(in list: RecipeList) -> [TileInfo] {
        list.isIngredients
            ? ingredientList(in: list).map(TileInfo.init)
            : toolList(in: list).map(TileInfo.init)
    }

    func ingredientList(in list: RecipeList) -> [Ingredient] {
        switch list {
        case .ingredients: (ingredients.supermarket ?? []) + (ingredients.general ?? [])
        case .optionalIngredients: ingredients.optional ?? []
        default: []
        }
    }

    func toolList(in list: RecipeList) -> [Tool] {
        tools.filter { $0.required == (list == .tools) }
    }

    /// Writes a list of ingredients back. The required list is split into the two sections the
    /// schema keeps, and an entry that was already in one of them stays where it was, so
    /// editing an amount never shuffles the file around.
    mutating func setIngredients(_ list: [Ingredient], in target: RecipeList) {
        switch target {
        case .optionalIngredients:
            ingredients.optional = list.isEmpty ? nil : list
        case .ingredients:
            let wasSupermarket = Set((ingredients.supermarket ?? []).map(\.icon))
            let wasGeneral = Set((ingredients.general ?? []).map(\.icon))
            var supermarket: [Ingredient] = []
            var general: [Ingredient] = []
            for entry in list {
                if wasSupermarket.contains(entry.icon) {
                    supermarket.append(entry)
                } else if wasGeneral.contains(entry.icon) {
                    general.append(entry)
                } else if IconCatalog.iconName(for: entry.icon).map(IconCatalog.shelf(of:)) == .pantry {
                    general.append(entry)
                } else {
                    supermarket.append(entry)
                }
            }
            ingredients.supermarket = supermarket.isEmpty ? nil : supermarket
            ingredients.general = general.isEmpty ? nil : general
        default:
            break
        }
    }

    /// Writes a list of tools back, keeping the ones from the other list as they were.
    mutating func setTools(_ list: [Tool], in target: RecipeList) {
        let required = target == .tools
        let others = tools.filter { $0.required != required }
        tools = required ? list + others : others + list
    }
}
