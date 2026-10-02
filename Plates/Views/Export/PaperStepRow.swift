import CulinaryIntelligence
import SwiftUI
import UIKit

struct PaperStepRow: View {
    let number: Int
    let step: Step

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(format: String(localized: "Recipe.Detail.Step.Title"), number, step.title))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.paperInk)
            if let icons = step.icons, !icons.isEmpty {
                HStack(spacing: 6) {
                    ForEach(icons, id: \.self) { RecipeIcon(path: $0, size: 20) }
                }
            }
            ForEach(step.points, id: \.self) { point in
                Text(verbatim: point)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.paperSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
