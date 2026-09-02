import SwiftUI

/// A grid of catalog icons to tick off, grouped into native list sections, so a cook can pick
/// what they have instead of typing it. Icon names are catalog data, so they are shown as
/// written.
struct CatalogPickerView: View {
    /// One collapsible group of icons.
    struct Group: Identifiable {
        let id: String
        let title: LocalizedStringResource
        let icons: [String]
    }

    let title: LocalizedStringResource
    let searchPrompt: LocalizedStringResource
    /// The groups a search turns up. An empty search returns everything.
    let groups: (String) -> [Group]
    /// Where an asset name sits in the schema, so the tile can draw it.
    let path: (String) -> String

    @Binding var selection: [String]

    @State private var query = ""
    @State private var collapsed: Set<String> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        List {
            if !picked.isEmpty {
                Section("Generate.Picker.Picked") {
                    grid(picked)
                }
            }
            ForEach(matches) { group in
                Section(isExpanded: expansion(for: group.id)) {
                    grid(group.icons)
                } header: {
                    Text(group.title)
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $query, prompt: Text(searchPrompt))
        .overlay {
            if matches.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var matches: [Group] { groups(query) }

    /// What is already picked, kept at the top so a long list never hides it.
    private var picked: [String] {
        let shown = Set(matches.flatMap(\.icons))
        return selection.filter(shown.contains)
    }

    /// A group closes on a tap of its header. A search leaves every group it matched open,
    /// so nothing found is hidden behind a closed header.
    private func expansion(for id: String) -> Binding<Bool> {
        Binding(
            get: { !query.isEmpty || !collapsed.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    collapsed.remove(id)
                } else {
                    collapsed.insert(id)
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
                RecipeIcon(path: path(asset), size: 40)
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

extension CatalogPickerView {
    /// The ingredient catalog, in the groups a shop is laid out in.
    static func ingredients(selection: Binding<[String]>) -> CatalogPickerView {
        CatalogPickerView(
            title: "Generate.Ingredients.Title",
            searchPrompt: "Generate.Ingredients.Search",
            groups: { query in
                IconCatalog.categories(matching: query).map {
                    Group(id: $0.category.rawValue, title: $0.category.title, icons: $0.icons)
                }
            },
            path: IconCatalog.ingredientPath,
            selection: selection
        )
    }

    /// The tool catalog, which is short enough to read as one group.
    static func tools(selection: Binding<[String]>) -> CatalogPickerView {
        CatalogPickerView(
            title: "Generate.Tools.Title",
            searchPrompt: "Generate.Tools.Search",
            groups: { query in
                let icons = IconCatalog.tools(matching: query)
                return icons.isEmpty ? [] : [Group(id: "tools", title: "Generate.Tools.Title", icons: icons)]
            },
            path: IconCatalog.toolPath,
            selection: selection
        )
    }
}
