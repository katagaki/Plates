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

/// A tile: icon, name, and the amount or nothing. The heading says what the group is,
/// so the tile never repeats it. The name, amount, and note come from recipe data, so
/// they are shown as written rather than looked up in the string catalog.
struct IconTile: View {
    let iconPath: String
    let name: String
    var detail: String?
    var note: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RecipeIcon(path: iconPath)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name)
                if let detail, !detail.isEmpty {
                    Text(verbatim: detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let note, !note.isEmpty {
                    Text(verbatim: note)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }
}
