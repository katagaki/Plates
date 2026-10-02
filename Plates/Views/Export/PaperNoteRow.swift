import CulinaryIntelligence
import SwiftUI
import UIKit

struct PaperNoteRow: View {
    let note: Troubleshooting

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: note.problem)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.paperInk)
            Text(verbatim: note.solution)
                .font(.system(size: 13))
                .foregroundStyle(Color.paperSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
