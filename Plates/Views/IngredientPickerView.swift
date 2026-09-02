import SwiftUI

/// The catalog of ingredients the app can draw, in a grid grouped the way a shop is, so a cook
/// can tick off what they have instead of typing it. Ingredient names are catalog data, so they
/// are shown as written.
struct IngredientPickerView: View {
    @Binding var selection: [String]

    @State private var query = ""
    @State private var collapsed: Set<IngredientCategory> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12, pinnedViews: .sectionHeaders) {
                if !picked.isEmpty {
                    section("Generate.Ingredients.Picked", icons: picked)
                }
                ForEach(matches, id: \.category) { group in
                    section(
                        group.category.title,
                        icons: group.icons,
                        isExpanded: isExpanded(group.category)
                    ) {
                        collapsed.formSymmetricDifference([group.category])
                    }
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

    /// A group closes on a tap of its header. A search leaves every group it matched open,
    /// so nothing found is hidden behind a closed header.
    private func isExpanded(_ category: IngredientCategory) -> Bool {
        !query.isEmpty || !collapsed.contains(category)
    }

    private func section(
        _ title: LocalizedStringResource,
        icons: [String],
        isExpanded: Bool = true,
        toggle: (() -> Void)? = nil
    ) -> some View {
        Section {
            if isExpanded {
                ForEach(icons, id: \.self) { cell($0) }
            }
        } header: {
            HStack {
                Text(title)
                Spacer(minLength: 0)
                if toggle != nil {
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 8)
            .contentShape(.rect)
            .background(Color(uiColor: .systemGroupedBackground))
            .onTapGesture {
                withAnimation { toggle?() }
            }
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
