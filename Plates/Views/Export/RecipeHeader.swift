import CulinaryIntelligence
import SwiftUI
import UIKit

struct RecipeHeader: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: recipe.title)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.paperInk)
            HStack(spacing: 6) {
                Text(String(
                    format: String(localized: "Recipe.Row.Subtitle"),
                    recipe.formattedTime,
                    recipe.serves
                ))
                if recipe.tried == true {
                    Image(systemName: "checkmark.seal.fill")
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(Color.paperSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
