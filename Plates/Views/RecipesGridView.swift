import SwiftUI

/// The recipes as a two column grid of cards. What is in it, and in which order, is worked
/// out by whoever presents it.
struct RecipesGridView: View {
    let recipes: [Recipe]
    let delete: (Recipe) -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(recipes) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeCard(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            delete(recipe)
                        } label: {
                            Label("Menu.Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, .listRowInset)
            .padding(.vertical, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

/// One recipe at a glance: the title and how long it takes, over a blend of the colours its
/// ingredients are drawn in. Recipe data is shown as written rather than looked up in the
/// string catalog.
private struct RecipeCard: View {
    let recipe: Recipe

    @Environment(\.colorScheme) private var scheme

    private static let points: [SIMD2<Float>] = [
        SIMD2(0, 0), SIMD2(1, 0),
        SIMD2(0, 1), SIMD2(1, 1),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: recipe.title)
                .font(.headline)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                Text(String(format: String(localized: "Recipe.Row.Subtitle"), recipe.formattedTime, recipe.serves))
                if recipe.tried == true {
                    Image(systemName: "checkmark.seal.fill")
                }
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background { blend }
        .cardBackground()
    }

    /// The ingredient colours poured into the four corners of the card. It sits over the card
    /// background rather than replacing it, so the title keeps its contrast in either
    /// appearance.
    private var blend: some View {
        MeshGradient(
            width: 2,
            height: 2,
            points: Self.points,
            colors: IngredientPalette.colors(for: recipe, in: scheme)
        )
        .opacity(scheme == .dark ? 0.9 : 0.5)
            .clipShape(.rect(cornerRadius: .listRowCornerRadius, style: .continuous))
    }
}
