import SwiftUI

/// The catalog of ingredients the app can draw, in a grid grouped the way a shop is, so a cook
/// can tick off what they have instead of typing it. Ingredient names are catalog data, so they
/// are shown as written.
struct IngredientPickerView: View {
    @Binding var selection: [String]

    @State private var query = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12, pinnedViews: .sectionHeaders) {
                if !picked.isEmpty {
                    section("Generate.Ingredients.Picked", icons: picked)
                }
                ForEach(matches, id: \.category) { group in
                    section(group.category.title, icons: group.icons)
                }
            }
            .padding(.horizontal, .listRowInset)
            .padding(.bottom, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
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

    private func section(_ title: LocalizedStringResource, icons: [String]) -> some View {
        Section {
            ForEach(icons, id: \.self) { cell($0) }
        } header: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .background(Color(uiColor: .systemGroupedBackground))
        }
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
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .top)
            .background(
                isPicked ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)),
                in: .rect(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}
