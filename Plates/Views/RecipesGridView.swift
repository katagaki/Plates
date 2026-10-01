import CulinaryIntelligence
import SwiftUI

/// The recipes as a two column grid of cards. What is in it, and in which order, is worked
/// out by whoever presents it.
struct RecipesGridView: View {
    let recipes: [Recipe]
    let delete: (Recipe) -> Void

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(recipes) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeCard(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(DragGesture(minimumDistance: 10))
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
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

/// One recipe at a glance: the dish from above, then the title and how long it takes, on the
/// plain card colour so the dish is what carries the colour. Recipe data is shown as written
/// rather than looked up in the string catalog.
private struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DishIcon(recipe: recipe, size: 112)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)
            Text(verbatim: recipe.title)
                .font(.headline)
                .lineLimit(2, reservesSpace: true)
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
        .foregroundStyle(.primary)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardBackground()
    }
}
