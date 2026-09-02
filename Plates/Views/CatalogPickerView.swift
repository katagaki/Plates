import SwiftUI

/// A grid of catalog icons to tick off, grouped into native list sections, so a cook can pick
/// what they have instead of typing it. Icon names are catalog data, so they are shown as
/// written.
struct CatalogPickerView: View {
    /// One collapsible group of icons.
    struct IconGroup: Identifiable {
        let id: String
        let title: LocalizedStringResource
        let icons: [String]
    }

    let title: LocalizedStringResource
    let searchPrompt: LocalizedStringResource
    /// What the picked bar says while nothing is picked.
    let emptyLabel: LocalizedStringResource
    /// The groups a search turns up. An empty search returns everything.
    let groups: (String) -> [IconGroup]
    /// Where an asset name sits in the schema, so the tile can draw it.
    let path: (String) -> String

    @Binding var selection: [String]

    @State private var query = ""
    @State private var collapsed: Set<String> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)

    var body: some View {
        List {
            ForEach(matches) { group in
                Section(isExpanded: expansion(for: group.id)) {
                    grid(group.icons)
                } header: {
                    Text(group.title)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) { pickedBar }
        .animation(.default, value: selection)
        .searchable(text: $query, prompt: Text(searchPrompt))
        .overlay {
            if matches.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var matches: [IconGroup] { groups(query) }

    /// What is picked so far, floating over the catalog rather than taking a section from it.
    /// A tap in here drops the pick, so nothing in the bar is highlighted. The bar stays put
    /// when nothing is picked, so the catalog never shifts under a finger.
    private var pickedBar: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return GlassEffectContainer {
            Group {
                if selection.isEmpty {
                    Text(emptyLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 4) {
                            ForEach(selection, id: \.self) { asset in
                                Button {
                                    toggle(asset)
                                } label: {
                                    VStack(spacing: 2) {
                                        RecipeIcon(path: path(asset), size: 30)
                                        Text(verbatim: IconCatalog.displayName(for: asset))
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .foregroundStyle(.primary)
                                    }
                                    .frame(width: 66)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .frame(height: 62)
            .glassEffect(.regular, in: shape)
            .clipShape(shape)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// A group closes on a tap of its header. A search leaves every group it matched open,
    /// so nothing found is hidden behind a closed header. The disclosure is the list's own,
    /// which only the sidebar style draws.
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
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(icons, id: \.self) { cell($0) }
        }
        .padding(.vertical, 2)
        .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
    }

    private func toggle(_ asset: String) {
        if let index = selection.firstIndex(of: asset) {
            selection.remove(at: index)
        } else {
            selection.append(asset)
        }
    }

    private func cell(_ asset: String) -> some View {
        let isPicked = selection.contains(asset)
        return Button {
            toggle(asset)
        } label: {
            VStack(spacing: 2) {
                RecipeIcon(path: path(asset), size: 34)
                Text(verbatim: IconCatalog.displayName(for: asset))
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isPicked ? Color.white : Color.primary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .top)
            .background {
                if isPicked {
                    RoundedRectangle(cornerRadius: .listRowCornerRadius, style: .continuous)
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
            emptyLabel: "Generate.Ingredients.Empty",
            groups: { query in
                IconCatalog.categories(matching: query).map {
                    IconGroup(id: $0.category.rawValue, title: $0.category.title, icons: $0.icons)
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
            emptyLabel: "Generate.Tools.Empty",
            groups: { query in
                let icons = IconCatalog.tools(matching: query)
                return icons.isEmpty ? [] : [IconGroup(id: "tools", title: "Generate.Tools.Title", icons: icons)]
            },
            path: IconCatalog.toolPath,
            selection: selection
        )
    }
}
