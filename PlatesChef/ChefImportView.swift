import SwiftUI

struct ChefImportView: View {
    let items: [NSExtensionItem]
    let complete: () -> Void
    let cancel: () -> Void

    @State private var recipe: ChefRecipe?
    @State private var isLoading = true
    @State private var failure: Failure?
    @State private var saveFailed = false

    private enum Failure {
        case noURL, unsupportedURL, downloadFailed, noRecipe
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Chef.Loading")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if recipe != nil {
                    ChefReviewView(recipe: Binding(
                        get: { recipe! },
                        set: { recipe = $0 }
                    ))
                } else {
                    errorView
                }
            }
            .navigationTitle("Chef.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chef.Cancel", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if recipe != nil {
                        Button("Chef.Add", action: save)
                            .disabled(recipe?.canSave != true)
                    }
                }
            }
        }
        .task { await load() }
        .alert("Chef.Error.Save", isPresented: $saveFailed) {
            Button("Chef.OK", role: .cancel) {}
        }
    }

    private var errorView: some View {
        ContentUnavailableView {
            Label("Chef.Error.Title", systemImage: "doc.text.magnifyingglass")
        } description: {
            switch failure {
            case .noURL: Text("Chef.Error.NoURL")
            case .unsupportedURL: Text("Chef.Error.UnsupportedURL")
            case .downloadFailed: Text("Chef.Error.Download")
            case .noRecipe, .none: Text("Chef.Error.NoRecipe")
            }
        } actions: {
            Button("Chef.Retry") { Task { await load() } }
        }
    }

    private func load() async {
        isLoading = true
        do {
            recipe = try await RecipePageLoader.load(from: items)
            failure = nil
        } catch let error as RecipePageLoader.LoadError {
            switch error {
            case .noURL: failure = .noURL
            case .unsupportedURL: failure = .unsupportedURL
            case .downloadFailed: failure = .downloadFailed
            case .noRecipe: failure = .noRecipe
            }
        } catch {
            failure = .downloadFailed
        }
        isLoading = false
    }

    private func save() {
        guard var recipe else { return }
        recipe.tidy()
        guard recipe.canSave,
              let group = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.Plates"
              ) else {
            saveFailed = true
            return
        }
        do {
            let directory = group.appending(path: "PendingRecipes", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appending(path: "\(UUID().uuidString).json")
            try JSONEncoder().encode(recipe).write(to: destination, options: .atomic)
            complete()
        } catch {
            saveFailed = true
        }
    }
}

private struct ChefReviewView: View {
    @Binding var recipe: ChefRecipe

    var body: some View {
        Form {
            Section("Chef.Review") {
                Text("Chef.Review.Help")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if (recipe.ingredients.supermarket ?? []).contains(where: { $0.amount.isEmpty }) {
                    Text("Chef.Review.AmountHelp")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                TextField("Chef.Name", text: $recipe.title)
                TextField("Chef.Time", text: $recipe.time)
                TextField("Chef.Serves", text: $recipe.serves)
            }

            ingredients("Chef.Ingredients", entries: $recipe.ingredients.supermarket)
            ingredients("Chef.Pantry", entries: $recipe.ingredients.general)
            ingredients("Chef.Optional", entries: $recipe.ingredients.optional)

            Section("Chef.Steps") {
                ForEach($recipe.steps) { $step in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Chef.Step.Title", text: $step.title)
                            .font(.headline)
                        TextEditor(text: Binding(
                            get: { step.points.joined(separator: "\n") },
                            set: { step.points = $0.components(separatedBy: "\n") }
                        ))
                        .frame(minHeight: 75)
                    }
                }
                .onDelete { recipe.steps.remove(atOffsets: $0) }
                Button("Chef.Step.Add", systemImage: "plus") {
                    recipe.steps.append(.init(title: "", points: [""]))
                }
            }

            if !recipe.tools.isEmpty {
                Section("Chef.Tools") {
                    ForEach($recipe.tools) { $tool in
                        TextField("Chef.Tool.Name", text: $tool.name)
                    }
                }
            }
            if !recipe.troubleshooting.isEmpty {
                Section("Chef.Troubleshooting") {
                    ForEach($recipe.troubleshooting) { $entry in
                        TextField("Chef.Problem", text: $entry.problem)
                        TextField("Chef.Solution", text: $entry.solution, axis: .vertical)
                    }
                }
            }
        }
    }

    private func ingredients(
        _ title: LocalizedStringResource,
        entries: Binding<[ChefRecipe.Ingredient]?>
    ) -> some View {
        let list = Binding<[ChefRecipe.Ingredient]>(
            get: { entries.wrappedValue ?? [] },
            set: { entries.wrappedValue = $0 }
        )
        return Section(title) {
            ForEach(list) { $entry in
                VStack(alignment: .leading) {
                    TextField("Chef.Ingredient.Name", text: $entry.item)
                    TextField("Chef.Ingredient.Amount", text: $entry.amount)
                        .font(.subheadline)
                }
            }
            .onDelete { list.wrappedValue.remove(atOffsets: $0) }
            Button("Chef.Ingredient.Add", systemImage: "plus") {
                list.wrappedValue.append(.init(item: "", icon: "", amount: ""))
            }
        }
    }
}
