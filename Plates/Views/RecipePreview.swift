import CulinaryIntelligence
import SwiftUI

/// The recipe as it stands, read under the checklist while the model works on it. Writing one
/// and rewriting one both show it, so a cook watching either screen reads the same thing.
struct RecipePreview: View {
    /// Everything here is written by the model, so it is shown as written rather than looked up.
    let title: String
    let time: String
    let serves: String
    /// The step titles, in order.
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                    .font(.title2)
                    .fontWeight(.semibold)
                if !time.isEmpty, !serves.isEmpty {
                    Text(String(
                        format: String(localized: "Recipe.Row.Subtitle"),
                        Recipe.formatTime(time),
                        serves
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(index + 1, format: .number)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(verbatim: step)
                        .font(.subheadline)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
