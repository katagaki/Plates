import CulinaryIntelligence
import SwiftUI
import UIKit

struct PaperItemRow: View {
    let item: TileInfo

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RecipeIcon(path: item.icon, size: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.name)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.paperInk)
                if let note = item.note, !note.isEmpty {
                    Text(verbatim: note)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.paperSoft)
                }
            }
            Spacer(minLength: 8)
            if let detail = item.detail, !detail.isEmpty {
                Text(verbatim: detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.paperSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
