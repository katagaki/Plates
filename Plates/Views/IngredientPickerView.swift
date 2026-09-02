import SwiftUI

/// The catalog of ingredients the app can draw, in a grid grouped the way a shop is, so a cook
/// can tick off what they have instead of typing it. Ingredient names are catalog data, so they
/// are shown as written.
struct IngredientPickerView: View {
    @Binding var selection: [String]

    @State private var query = ""
    @State private var collapsed: Set<IngredientCategory> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        List {
            if !picked.isEmpty {
                Section("Generate.Ingredients.Picked") {
                    grid(picked)
                }
            }
            ForEach(matches, id: \.category) { group in
                Section(isExpanded: expansion(for: group.category)) {
                    grid(group.icons)
                } header: {
                    Text(group.category.title)
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $query, prompt: Text("Generate.Ingredients.Search"))
        .overlay {
            if matches.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle("Generate.Ingredients.Title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var matches: [(category: IngredientCategory, icons: [String])] {
        IconCatalog.categories(matching: query)
    }

    /// What is already picked, kept at the top so a long list never hides it.
    private var picked: [String] {
        let shown = Set(matches.flatMap(\.icons))
        return selection.filter(shown.contains)
    }

    /// A group closes on a tap of its header. A search leaves every group it matched open,
    /// so nothing found is hidden behind a closed header.
    private func expansion(for category: IngredientCategory) -> Binding<Bool> {
        Binding(
            get: { !query.isEmpty || !collapsed.contains(category) },
            set: { isExpanded in
                if isExpanded {
                    collapsed.remove(category)
                } else {
                    collapsed.insert(category)
                }
            }
        )
    }

    private func grid(_ icons: [String]) -> some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(icons, id: \.self) { cell($0) }
        }
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
    }

    private func cell(_ asset: String) -> some View {
        let isPicked = selection.contains(asset)
        return Button {
            if let index = selection.firstIndex(of: asset) {
                selection.remove(at: index)
            } else {
                selection.append(asset)
            }
        } label: {
            VStack(spacing: 4) {
                RecipeIcon(path: IconCatalog.ingredientPath(for: asset), size: 40)
                Text(verbatim: IconCatalog.displayName(for: asset))
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isPicked ? Color.white : Color.primary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .top)
            .background {
                if isPicked {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.tint)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
