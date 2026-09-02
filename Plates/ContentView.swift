import SwiftUI

struct ContentView: View {
    enum SortOrder: String, CaseIterable, Identifiable {
        case alphabetical
        case quickest

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .alphabetical: "Sort.Alphabetical"
            case .quickest: "Sort.Quickest"
            }
        }
    }

    @State private var store = RecipeStore()
    @State private var sortOrder: SortOrder = .alphabetical
    @State private var showTriedOnly = false
    @State private var search = ""
    @State private var isGenerating = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleRecipes) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeRow(recipe: recipe)
                    }
                }
                .onDelete { store.delete(atOffsets: $0, in: visibleRecipes) }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Recipe.List.Title")
            .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
            .searchable(text: $search, prompt: Text("Recipe.List.Search.Prompt"))
            .overlay {
                if store.recipes.isEmpty {
                    emptyState
                } else if visibleRecipes.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    menu
                }
            }
            .sheet(isPresented: $isGenerating) {
                GenerateRecipeView(store: store)
            }
        }
    }

    private var menu: some View {
        Menu {
            Button {
                isGenerating = true
            } label: {
                Label("Menu.Generate", systemImage: "apple.intelligence")
            }

            Section("Menu.Sort.Title") {
                Picker("Menu.Sort.Title", selection: $sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                .pickerStyle(.inline)
                Toggle("Menu.Sort.TriedOnly", isOn: $showTriedOnly)
            }

            Section("Menu.Storage.Title") {
                Picker(
                    "Menu.Storage.Title",
                    selection: Binding(get: { store.location }, set: { store.location = $0 })
                ) {
                    ForEach(StorageLocation.allCases) { location in
                        Label {
                            Text(location.title)
                        } icon: {
                            Image(systemName: location.symbol)
                        }
                        .tag(location)
                    }
                }
                .pickerStyle(.inline)
            }

            Section {
                Button {
                    store.addSampleRecipes()
                } label: {
                    Label("Menu.AddSamples", systemImage: "tray.and.arrow.down")
                }
                Button {
                    store.load()
                } label: {
                    Label("Menu.Refresh", systemImage: "arrow.clockwise")
                }
            }
        } label: {
            Label("Menu.Label", systemImage: "ellipsis")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Recipe.List.Empty.Title", systemImage: "frying.pan")
        } description: {
            if let loadError = store.loadError {
                Text(verbatim: loadError)
            } else {
                Text("Recipe.List.Empty.Description")
            }
        } actions: {
            Button("Menu.Generate") { isGenerating = true }
                .buttonStyle(.borderedProminent)
            Button("Menu.AddSamples") { store.addSampleRecipes() }
        }
    }

    /// Sorted and filtered on every render, so the order files come back in never matters.
    private var visibleRecipes: [Recipe] {
        var list = store.recipes
        if showTriedOnly {
            list = list.filter { $0.tried == true }
        }
        if !search.isEmpty {
            list = list.filter { $0.title.localizedCaseInsensitiveContains(search) }
        }
        switch sortOrder {
        case .alphabetical:
            list.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .quickest:
            list.sort {
                $0.minutes == $1.minutes
                    ? $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    : $0.minutes < $1.minutes
            }
        }
        return list
    }
}

private struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            RecipeIcon(path: recipe.ingredients.supermarket?.first?.icon
                ?? recipe.ingredients.general?.first?.icon
                ?? "", size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: recipe.title)
                Text(String(format: String(localized: "Recipe.Row.Subtitle"), recipe.time, recipe.serves))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if recipe.tried == true {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

#Preview {
    ContentView()
}
