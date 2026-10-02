import CulinaryIntelligence
import SwiftUI
import UIKit

/// One sheet of a printed recipe, filled from the top.
struct PaperPage: View {
    let blocks: [AnyView]
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                block
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(48)
        // The page grows rather than squeezing what is on it, so a block measured a hair short
        // of how it draws is never cut off at the foot of the page.
        .frame(width: RecipeExport.pageWidth, alignment: .topLeading)
        .frame(minHeight: height, alignment: .topLeading)
        .background(.white)
        .environment(\.colorScheme, .light)
    }
}
