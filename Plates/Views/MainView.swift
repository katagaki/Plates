import CulinaryIntelligence
import SwiftUI

/// The app's one screen: the recipes, what is sorted and searched out of them, and the menus
/// that act on the store.
struct MainView: View {
    @Environment(\.scenePhase) private var scenePhase

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
    @State private var generation: Generation?
    @State private var isShowingLimits = false
    @AppStorage("Onboarding.Completed") private var onboardingCompleted = false
    @State private var isOnboarding = false
    /// The dish named at the end of onboarding, written in once the recipe sheet opens.
    @State private var firstDish = ""

    var body: some View {
        NavigationStack {
            RecipesGridView(recipes: visibleRecipes, delete: store.delete)
                .navigationTitle("Recipe.List.Title")
                .toolbarTitleDisplayMode(.inlineLarge)
                .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0, store: store) }
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
                            generation = Generation()
                        } label: {
                            Label("Menu.Generate", systemImage: "plus")
                        }
                    }
                }
                .sheet(item: $generation) { generation in
                    GenerateRecipeView(
                        store: store,
                        dish: generation.dish,
                        startsAtOnce: generation.startsAtOnce,
                        decidesAtOnce: generation.decidesAtOnce
                    )
                }
        }
        .sheet(isPresented: $isShowingLimits) {
            LimitsView()
        }
        .sheet(isPresented: $isOnboarding, onDismiss: openFirstRecipe) {
            OnboardingView { dish in
                onboardingCompleted = true
                firstDish = dish ?? ""
                isOnboarding = false
            }
        }
        .onAppear {
            store.importSharedRecipes()
            if !onboardingCompleted { isOnboarding = true }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active { store.importSharedRecipes() }
        }
        #if DEBUG
        .onOpenURL(perform: openDebugLink)
        #endif
    }

    /// What the recipe sheet opens with. It is handed over whole, since a sheet shown from a
    /// flag can be built before the values set beside the flag reach it.
    struct Generation: Identifiable {
        let id = UUID()
        var dish = ""
        var startsAtOnce = false
        var decidesAtOnce = false
    }

    /// The recipe sheet waits for onboarding to be gone, since one sheet cannot open over
    /// another that is closing.
    private func openFirstRecipe() {
        if !firstDish.isEmpty { generation = Generation(dish: firstDish) }
        firstDish = ""
    }

    #if DEBUG
    /// `plates-debug://generate?request=...&decide=true` writes a recipe on launch, and with
    /// `decide` lets Jev pick from the ideas. Debug builds only register the scheme.
    private func openDebugLink(_ url: URL) {
        guard url.host() == "generate", generation == nil,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let request = items.first(where: { $0.name == "request" })?.value, !request.isEmpty
        else { return }
        onboardingCompleted = true
        isOnboarding = false
        generation = Generation(
            dish: request,
            startsAtOnce: true,
            decidesAtOnce: items.contains { $0.name == "decide" && $0.value == "true" }
        )
    }
    #endif

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

            if PlatesCloud.shared.isConfigured {
                Button {
                    isShowingLimits = true
                } label: {
                    Label("Menu.Limits", systemImage: "gauge.with.dots.needle.33percent")
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
            Button("Menu.Generate") { generation = Generation() }
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
