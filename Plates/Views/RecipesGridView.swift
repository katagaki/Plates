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

/// One recipe at a glance: an icon, the title, and how long it takes. Recipe data is shown as
/// written rather than looked up in the string catalog.
private struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                RecipeIcon(path: iconPath, size: 40)
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(verbatim: recipe.title)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if recipe.tried == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                Text(String(format: String(localized: "Recipe.Row.Subtitle"), recipe.formattedTime, recipe.serves))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardBackground()
    }

    /// The first ingredient's icon stands in for the recipe.
    private var iconPath: String {
        recipe.ingredients.supermarket?.first?.icon
            ?? recipe.ingredients.general?.first?.icon
            ?? ""
    }
}
