import CulinaryIntelligence
import SwiftUI
import UIKit

/// A recipe drawn for paper: the same content the detail view shows, in one column and in ink
/// rather than in the reader's appearance. Recipe text is shown as written.
struct RecipePage: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RecipeHeader(recipe: recipe)
            ForEach(RecipeList.allCases) { list in
                let items = recipe.items(in: list)
                if !items.isEmpty {
                    PaperSection(title: list.title) {
                        ForEach(items) { PaperItemRow(item: $0) }
                    }
                }
            }
            if !recipe.steps.isEmpty {
                PaperSection(title: "Recipe.Detail.Steps") {
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        PaperStepRow(number: index + 1, step: step)
                    }
                }
            }
            if !recipe.troubleshooting.isEmpty {
                PaperSection(title: "Recipe.Detail.Troubleshooting") {
                    ForEach(recipe.troubleshooting) { PaperNoteRow(note: $0) }
                }
            }
        }
        .padding(48)
        .frame(width: RecipeExport.pageWidth, alignment: .leading)
        .background(.white)
        .environment(\.colorScheme, .light)
    }
}
