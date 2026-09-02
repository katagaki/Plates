import SwiftUI

/// One of the shared 48 pt SVG icons, drawn at 44 pt the way the site does.
struct RecipeIcon: View {
    let path: String
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let name = IconCatalog.assetName(for: path), UIImage(named: name) != nil {
                Image(name)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "fork.knife")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

/// An ingredient or a tool as the detail view shows it. The name, amount, and note come from
/// recipe data, so they are shown as written rather than looked up in the string catalog.
nonisolated struct TileInfo: Identifiable, Hashable {
    let id: String
    let icon: String
    let name: String
    let detail: String?
    let note: String?

    init(_ ingredient: Ingredient) {
        id = "ingredient-" + ingredient.id
        icon = ingredient.icon
        name = ingredient.item
        detail = ingredient.amount
        note = ingredient.note
    }

    init(_ tool: Tool) {
        id = "tool-" + tool.id
        icon = tool.icon
        name = tool.name
        detail = nil
        note = tool.note
    }

    /// What the card has no room for, shown in an alert when the card is tapped.
    var message: String {
        [detail, note].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}

/// A card in one of the carousels: the icon, the name, and the amount when there is one.
struct IconTile: View {
    let item: TileInfo

    var body: some View {
        HStack(spacing: 10) {
            RecipeIcon(path: item.icon, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: item.name)
                    .font(.subheadline)
                    .lineLimit(2)
                if let detail = item.detail, !detail.isEmpty {
                    Text(verbatim: detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80, alignment: .leading)
        .cardBackground()
    }
}
