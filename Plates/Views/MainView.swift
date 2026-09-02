import SwiftUI

/// The app's one screen: the recipes, what is sorted and searched out of them, and the menus
/// that act on the store.
struct MainView: View {
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
            RecipesGridView(recipes: visibleRecipes, delete: store.delete)
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
                    ToolbarItem(placement: .bottomBar) {
                        sortFilterMenu
                    }
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            isGenerating = true
                        } label: {
                            Label("Menu.Generate", systemImage: "apple.intelligence")
                        }
                    }
                }
                .sheet(isPresented: $isGenerating) {
                    GenerateRecipeView(store: store)
                }
        }
    }

    private var menu: some View {
        Menu {
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

    private var sortFilterMenu: some View {
        Menu {
            Picker("Menu.Sort.Title", selection: $sortOrder) {
                ForEach(SortOrder.allCases) { order in
                    Text(order.title).tag(order)
                }
            }
            .pickerStyle(.inline)
            Toggle("Menu.Sort.TriedOnly", isOn: $showTriedOnly)
        } label: {
            Label("Menu.Sort.Title", systemImage: "line.3.horizontal.decrease")
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

#Preview {
    MainView()
}
