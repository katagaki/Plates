import SwiftUI

struct RecipeDetailView: View {
    /// Where edits are written. A recipe being looked over before it is saved has no store, so
    /// it is shown without the way into the editor.
    private let store: RecipeStore?

    @State private var recipe: Recipe
    @State private var isEditing = false
    @State private var isShowingTroubleshooting = false
    @State private var tapped: TileInfo?
    @State private var field: Field?
    @State private var fieldText = ""
    @State private var editingCard: CardEdit?
    @State private var editingStep: ListEdit?
    @State private var editingNote: ListEdit?
    @State private var shared: SharedFile?
    @State private var shareFailed = false

    /// The three things about a recipe that are edited in an alert rather than a sheet.
    private enum Field {
        case name
        case time
        case serves
    }

    init(recipe: Recipe, store: RecipeStore? = nil) {
        _recipe = State(initialValue: recipe)
        self.store = store
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if isEditing {
                    nameCard
                        .padding(.horizontal, .listRowInset)
                }

                summary
                    .padding(.horizontal, .listRowInset)

                ForEach(RecipeList.allCases) { carousel($0) }

                steps
                    .padding(.horizontal, .listRowInset)

                if isEditing {
                    notes
                        .padding(.horizontal, .listRowInset)
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.large)
        .animation(.default, value: isEditing)
        .toolbar {
            if store != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isEditing.toggle()
                    } label: {
                        Label(
                            isEditing ? "Shared.Done" : "Recipe.Edit.Start",
                            systemImage: isEditing ? "checkmark" : "pencil"
                        )
                    }
                }
            }

            ToolbarItem(placement: .bottomBar) {
                shareMenu
            }

            if !recipe.troubleshooting.isEmpty, !isEditing {
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        isShowingTroubleshooting = true
                    } label: {
                        Label("Recipe.Detail.Troubleshooting", systemImage: "questionmark.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingTroubleshooting) {
            TroubleshootingView(entries: recipe.troubleshooting)
        }
        .sheet(item: $shared) { file in
            ShareSheet(url: file.url)
        }
        .sheet(item: $editingCard) { card in
            cardEditor(card)
        }
        .sheet(item: $editingStep) { edit in
            stepEditor(edit)
        }
        .sheet(item: $editingNote) { edit in
            noteEditor(edit)
        }
        .alert(
            Text(verbatim: tapped?.name ?? ""),
            isPresented: Binding(get: { tapped != nil }, set: { if !$0 { tapped = nil } }),
            presenting: tapped
        ) { _ in
            Button("Shared.Done", role: .cancel) {}
        } message: { info in
            // A tool with no note has nothing beyond its name, which the alert already titles.
            if !info.message.isEmpty {
                Text(verbatim: info.message)
            }
        }
        .alert("Recipe.Edit.Name", isPresented: editing(.name)) {
            TextField("Recipe.Edit.Name", text: $fieldText)
            Button("Shared.Cancel", role: .cancel) {}
            Button("Shared.Save") { setTitle() }
        }
        .alert("Recipe.Detail.Time", isPresented: editing(.time)) {
            TextField("Recipe.Edit.Time.Prompt", text: $fieldText)
            Button("Shared.Cancel", role: .cancel) {}
            Button("Shared.Save") { setTime() }
        } message: {
            Text("Recipe.Edit.Time.Message")
        }
        .alert("Recipe.Detail.Serves", isPresented: editing(.serves)) {
            TextField("Recipe.Edit.Serves.Prompt", text: $fieldText)
            Button("Shared.Cancel", role: .cancel) {}
            Button("Shared.Save") { setServes(scaling: false) }
            Button("Recipe.Edit.Serves.Scale") { setServes(scaling: true) }
        } message: {
            Text("Recipe.Edit.Serves.Message")
        }
        .alert("Recipe.Share.Error", isPresented: $shareFailed) {
            Button("Shared.Done", role: .cancel) {}
        }
    }

    // MARK: - The page

    /// What the recipe is called, editable while the rest of it is.
    private var nameCard: some View {
        Button {
            open(.name, with: recipe.title)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Recipe.Edit.Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: recipe.title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .cardBackground()
        }
        .buttonStyle(.plain)
    }

    /// Time, servings, and whether it has been cooked, side by side. The cooked mark turns over
    /// on a tap; the other two open an alert while the recipe is being edited.
    private var summary: some View {
        Grid(horizontalSpacing: 12) {
            GridRow {
                Button {
                    guard isEditing else { return }
                    open(.time, with: recipe.time)
                } label: {
                    SummaryCell(label: "Recipe.Detail.Time") {
                        Text(verbatim: recipe.formattedTime)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isEditing)

                Button {
                    guard isEditing else { return }
                    open(.serves, with: recipe.serves)
                } label: {
                    SummaryCell(label: "Recipe.Detail.Serves") {
                        Text(verbatim: recipe.serves)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isEditing)

                Button {
                    recipe.tried = recipe.tried == true ? nil : true
                    save()
                } label: {
                    SummaryCell(label: "Recipe.Detail.Tried") {
                        // Drawn as text so the mark sits on the same line as the other two cells.
                        Text(Image(systemName: recipe.tried == true ? "checkmark" : "xmark"))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// A row that scrolls sideways, cut so the third card is half on screen and the cook can
    /// see there is more to come. While the recipe is being edited the row always shows, with
    /// the way into the catalog at the end of it.
    @ViewBuilder
    private func carousel(_ list: RecipeList) -> some View {
        let items = recipe.items(in: list)
        if !items.isEmpty || isEditing {
            VStack(alignment: .leading, spacing: 12) {
                Text(list.title)
                    .font(.headline)
                    .padding(.horizontal, .listRowInset)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            Button {
                                if isEditing {
                                    editingCard = CardEdit(list: list, index: index)
                                } else {
                                    tapped = item
                                }
                            } label: {
                                IconTile(item: item)
                            }
                            .buttonStyle(.plain)
                            .containerRelativeFrame(.horizontal, count: 5, span: 2, spacing: 12)
                        }

                        if isEditing {
                            NavigationLink {
                                picker(for: list)
                            } label: {
                                AddCard(label: "Recipe.Edit.Add")
                            }
                            .buttonStyle(.plain)
                            .containerRelativeFrame(.horizontal, count: 5, span: 2, spacing: 12)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, .listRowInset, for: .scrollContent)
            }
        }
    }

    /// The method. While the recipe is being edited a step opens on a tap and moves on a drag,
    /// and a new one is added at the end.
    private var steps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recipe.Detail.Steps")
                .font(.headline)

            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                if isEditing {
                    Button {
                        editingStep = ListEdit(index: index)
                    } label: {
                        StepCard(number: index + 1, step: step)
                    }
                    .buttonStyle(.plain)
                    .draggable(String(index)) {
                        StepCard(number: index + 1, step: step)
                            .frame(width: 280)
                    }
                    .dropDestination(for: String.self) { payload, _ in
                        guard let from = payload.first.flatMap({ Int($0) }) else { return false }
                        move(from: from, to: index)
                        return true
                    }
                } else {
                    StepCard(number: index + 1, step: step)
                }
            }

            if isEditing {
                Button {
                    editingStep = ListEdit(index: recipe.steps.count)
                } label: {
                    AddCard(label: "Recipe.Edit.Step.Add")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The notes kept with the recipe, which are read from the bottom bar and written here.
    private var notes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recipe.Detail.Troubleshooting")
                .font(.headline)

            ForEach(Array(recipe.troubleshooting.enumerated()), id: \.offset) { index, note in
                Button {
                    editingNote = ListEdit(index: index)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: note.problem)
                            .font(.headline)
                        Text(verbatim: note.solution)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .cardBackground()
                }
                .buttonStyle(.plain)
            }

            Button {
                editingNote = ListEdit(index: recipe.troubleshooting.count)
            } label: {
                AddCard(label: "Recipe.Edit.Note.Add")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }

    private var shareMenu: some View {
        Menu {
            ForEach(ShareFormat.allCases) { format in
                Button {
                    share(format)
                } label: {
                    Label(format.title, systemImage: format.symbol)
                }
            }
        } label: {
            Label("Recipe.Share.Title", systemImage: "square.and.arrow.up")
        }
    }

    // MARK: - The editors

    /// The catalog, picking into one of the recipe's own lists.
    @ViewBuilder
    private func picker(for list: RecipeList) -> some View {
        if list.isIngredients {
            CatalogPickerView.recipeIngredients(title: list.title, selection: assets(in: list))
        } else {
            CatalogPickerView.recipeTools(title: list.title, selection: assets(in: list))
        }
    }

    @ViewBuilder
    private func cardEditor(_ card: CardEdit) -> some View {
        if card.list.isIngredients {
            let list = recipe.ingredientList(in: card.list)
            if list.indices.contains(card.index) {
                IngredientEditor(ingredient: list[card.index]) { edited in
                    var list = list
                    list[card.index] = edited
                    recipe.setIngredients(list, in: card.list)
                    save()
                } remove: {
                    var list = list
                    list.remove(at: card.index)
                    recipe.setIngredients(list, in: card.list)
                    save()
                }
            }
        } else {
            let list = recipe.toolList(in: card.list)
            if list.indices.contains(card.index) {
                ToolEditor(tool: list[card.index]) { edited in
                    var list = list
                    list[card.index] = edited
                    recipe.setTools(list, in: card.list)
                    save()
                } remove: {
                    var list = list
                    list.remove(at: card.index)
                    recipe.setTools(list, in: card.list)
                    save()
                }
            }
        }
    }

    private func stepEditor(_ edit: ListEdit) -> some View {
        let isNew = !recipe.steps.indices.contains(edit.index)
        return StepEditor(
            step: isNew ? Step(title: "", icons: nil, points: []) : recipe.steps[edit.index],
            choices: stepChoices
        ) { edited in
            if isNew {
                recipe.steps.append(edited)
            } else {
                recipe.steps[edit.index] = edited
            }
            save()
        } remove: {
            guard !isNew else { return }
            recipe.steps.remove(at: edit.index)
            save()
        }
    }

    private func noteEditor(_ edit: ListEdit) -> some View {
        let isNew = !recipe.troubleshooting.indices.contains(edit.index)
        return NoteEditor(
            note: isNew
                ? Troubleshooting(problem: "", solution: "")
                : recipe.troubleshooting[edit.index]
        ) { edited in
            if isNew {
                recipe.troubleshooting.append(edited)
            } else {
                recipe.troubleshooting[edit.index] = edited
            }
            save()
        } remove: {
            guard !isNew else { return }
            recipe.troubleshooting.remove(at: edit.index)
            save()
        }
    }

    /// The icons a step can be marked with: whatever the recipe itself carries.
    private var stepChoices: [StepEditor.Choice] {
        RecipeList.allCases
            .flatMap { recipe.items(in: $0) }
            .map { StepEditor.Choice(path: $0.icon, name: $0.name) }
            .reduce(into: [StepEditor.Choice]()) { picked, choice in
                if !picked.contains(choice) { picked.append(choice) }
            }
    }

    /// One of the recipe's lists as the catalog picker reads and writes it: asset names in,
    /// entries out. An entry already in the list keeps its amount and its note.
    private func assets(in list: RecipeList) -> Binding<[String]> {
        Binding(
            get: { recipe.items(in: list).compactMap { IconCatalog.iconName(for: $0.icon) } },
            set: { picks in
                if list.isIngredients {
                    let existing = recipe.ingredientList(in: list)
                    recipe.setIngredients(
                        picks.map { asset in
                            existing.first { IconCatalog.iconName(for: $0.icon) == asset }
                                ?? Ingredient(
                                    item: IconCatalog.displayName(for: asset),
                                    icon: IconCatalog.ingredientPath(for: asset),
                                    amount: "",
                                    note: nil
                                )
                        },
                        in: list
                    )
                } else {
                    let existing = recipe.toolList(in: list)
                    recipe.setTools(
                        picks.map { asset in
                            existing.first { IconCatalog.iconName(for: $0.icon) == asset }
                                ?? Tool(
                                    name: IconCatalog.displayName(for: asset),
                                    icon: IconCatalog.toolPath(for: asset),
                                    required: list == .tools,
                                    note: nil
                                )
                        },
                        in: list
                    )
                }
                save()
            }
        )
    }

    // MARK: - Editing

    private func editing(_ value: Field) -> Binding<Bool> {
        Binding(get: { field == value }, set: { if !$0 { field = nil } })
    }

    private func open(_ value: Field, with text: String) {
        fieldText = text
        field = value
    }

    private func setTitle() {
        let text = fieldText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        recipe.title = text
        save()
    }

    private func setTime() {
        let text = fieldText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        recipe.time = text
        save()
    }

    /// A new serving count, on its own or with every amount written up or down to match.
    private func setServes(scaling: Bool) {
        let text = fieldText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if scaling,
           let before = Recipe.servings(in: recipe.serves),
           let after = Recipe.servings(in: text) {
            recipe.scaleAmounts(by: after / before)
        }
        recipe.serves = text
        save()
    }

    private func move(from: Int, to: Int) {
        guard recipe.steps.indices.contains(from), from != to else { return }
        let step = recipe.steps.remove(at: from)
        recipe.steps.insert(step, at: min(to, recipe.steps.count))
        save()
    }

    private func share(_ format: ShareFormat) {
        do {
            shared = SharedFile(url: try RecipeExport.file(format, for: recipe))
        } catch {
            shareFailed = true
        }
    }

    /// Every edit goes straight to the file, so leaving the editor is never the thing that
    /// keeps the work.
    private func save() {
        store?.save(recipe)
    }
}

/// Time, servings, or whether the recipe has been cooked.
private struct SummaryCell<Content: View>: View {
    let label: LocalizedStringResource
    @ViewBuilder let value: Content

    var body: some View {
        VStack(spacing: 4) {
            value
                .font(.title3.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
    }
}

/// The card at the end of a row that adds to it.
private struct AddCard: View {
    let label: LocalizedStringResource

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
            Text(label)
                .font(.subheadline)
                .lineLimit(1)
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(minHeight: 68, maxHeight: 68)
        .frame(maxWidth: .infinity)
        .background(
            .quaternary.opacity(0.4),
            in: .rect(cornerRadius: .listRowCornerRadius, style: .continuous)
        )
    }
}

private struct StepCard: View {
    let number: Int
    let step: Step

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: String(localized: "Recipe.Detail.Step.Title"), number, step.title))
                .font(.headline)

            if let icons = step.icons, !icons.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(icons, id: \.self) { icon in
                            RecipeIcon(path: icon, size: 32)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            ForEach(step.points, id: \.self) { point in
                Text(verbatim: point)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardBackground()
    }
}
