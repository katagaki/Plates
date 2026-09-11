import SwiftUI
import UIKit

/// The three ways a recipe leaves the app: as the file the app itself reads, as a picture, or
/// as pages to print.
enum ShareFormat: String, CaseIterable, Identifiable {
    case plate
    case image
    case pdf

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .plate: "Recipe.Share.Plate"
        case .image: "Recipe.Share.Image"
        case .pdf: "Recipe.Share.PDF"
        }
    }

    var symbol: String {
        switch self {
        case .plate: "doc.text"
        case .image: "photo"
        case .pdf: "doc.richtext"
        }
    }
}

/// A file written to the temporary folder, waiting to be handed to the share sheet.
struct SharedFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// Writes a recipe out in whichever format is being shared. Every file lands in the temporary
/// folder under the recipe's own id, so sharing the same recipe twice does not pile up copies.
enum RecipeExport {
    /// The page a printed or pictured recipe is laid out on, in points.
    static let pageWidth: CGFloat = 612
    static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 48
    private static let spacing: CGFloat = 12

    @MainActor
    static func file(_ format: ShareFormat, for recipe: Recipe) throws -> URL {
        switch format {
        case .plate: try plate(recipe)
        case .image: try image(recipe)
        case .pdf: try pdf(recipe)
        }
    }

    /// The recipe as the app stores it. A `.plate` file is the recipe's JSON under a name the
    /// app recognises.
    static func plate(_ recipe: Recipe) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let url = destination(for: recipe, extension: "plate")
        try encoder.encode(recipe).write(to: url, options: .atomic)
        return url
    }

    /// The whole recipe in one tall picture.
    @MainActor
    static func image(_ recipe: Recipe) throws -> URL {
        let renderer = ImageRenderer(content: RecipePage(recipe: recipe))
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw ExportError.renderFailed
        }
        let url = destination(for: recipe, extension: "png")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// The recipe as pages. The content is drawn rather than photographed, so the text stays
    /// text and can be selected, searched, and edited in a reader.
    @MainActor
    static func pdf(_ recipe: Recipe) throws -> URL {
        let pages = paginate(blocks(for: recipe))
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil) else {
            throw ExportError.renderFailed
        }
        for page in pages {
            ImageRenderer(content: page).render { size, draw in
                var mediaBox = CGRect(origin: .zero, size: size)
                let info = [
                    kCGPDFContextMediaBox as String: Data(
                        bytes: &mediaBox,
                        count: MemoryLayout<CGRect>.size
                    ),
                ]
                context.beginPDFPage(info as CFDictionary)
                draw(context)
                context.endPDFPage()
            }
        }
        context.closePDF()
        let url = destination(for: recipe, extension: "pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// The blocks a recipe is broken into, each one small enough to keep together on a page.
    /// A heading travels with what it introduces, so no page ends on a title with nothing
    /// under it.
    @MainActor
    private static func blocks(for recipe: Recipe) -> [AnyView] {
        var blocks: [AnyView] = [AnyView(RecipeHeader(recipe: recipe))]
        for list in RecipeList.allCases {
            for (index, item) in recipe.items(in: list).enumerated() {
                blocks.append(heading(list.title, over: PaperItemRow(item: item), first: index == 0))
            }
        }
        for (index, step) in recipe.steps.enumerated() {
            blocks.append(heading(
                "Recipe.Detail.Steps",
                over: PaperStepRow(number: index + 1, step: step),
                first: index == 0
            ))
        }
        for (index, note) in recipe.troubleshooting.enumerated() {
            blocks.append(heading(
                "Recipe.Detail.Troubleshooting",
                over: PaperNoteRow(note: note),
                first: index == 0
            ))
        }
        return blocks
    }

    /// A row on its own, or under the heading of the section it opens.
    private static func heading(
        _ title: LocalizedStringResource,
        over row: some View,
        first: Bool
    ) -> AnyView {
        first ? AnyView(PaperSection(title: title) { row }) : AnyView(row)
    }

    /// The blocks packed into pages, measured one at a time so nothing is cut in half. A block
    /// taller than a page keeps a page of its own.
    @MainActor
    private static func paginate(_ blocks: [AnyView]) -> [AnyView] {
        // A little is kept back, so a block measured a hair short of how it draws is never
        // squeezed into what is left of a page and cut short.
        let available = pageHeight - margin * 2 - 12
        let width = pageWidth - margin * 2
        var pages: [AnyView] = []
        var current: [AnyView] = []
        var used: CGFloat = 0

        func close() {
            guard !current.isEmpty else { return }
            pages.append(AnyView(PaperPage(blocks: current, height: max(pageHeight, used + margin * 2))))
            current = []
            used = 0
        }

        for block in blocks {
            let height = measure(block, width: width)
            if !current.isEmpty, used + spacing + height > available {
                close()
            }
            used += current.isEmpty ? height : spacing + height
            current.append(block)
        }
        close()
        return pages
    }

    /// How tall a block draws at the page's text width.
    @MainActor
    private static func measure(_ block: AnyView, width: CGFloat) -> CGFloat {
        let controller = UIHostingController(rootView: block.frame(width: width))
        controller.view.backgroundColor = .clear
        return controller.sizeThatFits(
            in: CGSize(width: width, height: .greatestFiniteMagnitude)
        ).height.rounded(.up)
    }

    private static func destination(for recipe: Recipe, extension suffix: String) -> URL {
        let name = recipe.id.isEmpty ? Recipe.makeID(from: recipe.title) : recipe.id
        return FileManager.default.temporaryDirectory
            .appending(path: "\(name).\(suffix)", directoryHint: .notDirectory)
    }

    enum ExportError: Error {
        case renderFailed
    }
}

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

/// One sheet of a printed recipe, filled from the top.
private struct PaperPage: View {
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

private struct RecipeHeader: View {
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

private struct PaperSection<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.paperInk)
            content
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PaperItemRow: View {
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

private struct PaperStepRow: View {
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

private struct PaperNoteRow: View {
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

private extension Color {
    /// Paper is white whatever the reader's appearance is, so the ink is written down rather
    /// than taken from the environment.
    static let paperInk = Color(white: 0.08)
    static let paperSoft = Color(white: 0.42)
}

/// The system share sheet, for handing over the file a format was written to.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
