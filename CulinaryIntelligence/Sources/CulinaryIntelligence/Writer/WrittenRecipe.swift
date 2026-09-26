import Foundation

/// A recipe as Granite wrote it, cut into its sections by reading the text, before any model
/// sorts it. Granite writes in a regular cookbook shape, headed sections of bulleted or numbered
/// lines, so the lines can be counted here. The sorting passes are then asked for exactly that
/// many ingredients, steps, and fixes, which keeps them from dropping a line or making one up.
nonisolated struct WrittenRecipe: Equatable {
    var title = ""
    var time = ""
    var serves = ""
    var ingredients: [String] = []
    var tools: [String] = []
    var steps: [String] = []
    /// Each problem with its fix, as one entry.
    var problems: [String] = []

    private enum Section {
        case none, ingredients, tools, method, problems
    }

    init(parsing text: String) {
        var section = Section.none
        for raw in text.components(separatedBy: .newlines) {
            let line = Self.plain(raw)
            guard !line.isEmpty else { continue }

            if let (heading, rest) = Self.heading(in: line) {
                switch heading {
                case .title:
                    if title.isEmpty { title = rest }
                    continue
                case let .time(isTotal):
                    // A prep time and a cooking time can both be given. The total is the one
                    // the recipe carries.
                    if time.isEmpty || isTotal { time = rest }
                    continue
                case .serves:
                    if serves.isEmpty { serves = rest }
                    continue
                case let .section(next):
                    section = next
                    if !rest.isEmpty { append(rest, to: section, startsItem: true) }
                    continue
                }
            }

            // "Makes 4 servings" and "Serves 4" say how many it feeds without a colon. They come
            // before the lists, so a line inside one is never read this way.
            if section == .none, serves.isEmpty, Self.isServingLine(line) {
                serves = line
                continue
            }

            let indented = raw.first?.isWhitespace ?? false
            let (item, startsItem) = Self.item(in: line, section: section, indented: indented)
            if section == .none {
                if title.isEmpty { title = item }
                continue
            }
            // A heading of its own inside a section, such as "For the sauce:", groups lines
            // rather than being one.
            if !startsItem, item.hasSuffix(":") { continue }
            append(item, to: section, startsItem: startsItem)
        }
    }

    private mutating func append(_ text: String, to section: Section, startsItem: Bool) {
        func add(_ list: inout [String]) {
            if startsItem || list.isEmpty {
                list.append(text)
            } else {
                list[list.count - 1] += " " + text
            }
        }
        switch section {
        case .ingredients: add(&ingredients)
        case .tools: add(&tools)
        case .method: add(&steps)
        case .problems: add(&problems)
        case .none: break
        }
    }

    // MARK: - Reading a line

    private enum Heading {
        case title, serves
        case time(isTotal: Bool)
        case section(Section)
    }

    /// The line with Markdown emphasis and heading marks taken off.
    private static func plain(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespaces)
        while text.hasPrefix("#") { text.removeFirst() }
        text = text.replacingOccurrences(of: "**", with: "")
        text = text.replacingOccurrences(of: "__", with: "")
        return text.trimmingCharacters(in: .whitespaces)
    }

    /// A line such as "Ingredients:" or "Total Time: 20 minutes", with whatever follows the
    /// colon. Only a short label counts, so a sentence with a colon in it is left alone.
    private static func heading(in line: String) -> (Heading, String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let label = line[..<colon].lowercased().trimmingCharacters(in: .whitespaces)
        let rest = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty, label.split(separator: " ").count <= 5,
              !label.first!.isNumber, !"-*•".contains(label.first!)
        else { return nil }
        let heading: Heading
        if label == "title" || label == "recipe" {
            heading = .title
        } else if label.contains("time") {
            heading = .time(isTotal: label.contains("total"))
        } else if label.hasPrefix("serv") || label.hasPrefix("yield") {
            heading = .serves
        } else if label.contains("ingredient") {
            heading = .section(.ingredients)
        } else if label.contains("tool") || label.contains("equipment") || label.contains("utensil") {
            heading = .section(.tools)
        } else if ["method", "instruction", "direction", "step", "preparation"].contains(where: label.contains) {
            heading = .section(.method)
        } else if ["problem", "troubleshoot", "fixes", "mistake"].contains(where: label.contains) {
            heading = .section(.problems)
        } else {
            return nil
        }
        return (heading, rest)
    }

    /// A short line that says how many the recipe feeds.
    private static func isServingLine(_ line: String) -> Bool {
        let lowered = line.lowercased()
        return lowered.split(separator: " ").count <= 6
            && lowered.contains(where: \.isNumber)
            && (lowered.hasPrefix("serves") || lowered.hasPrefix("makes") || lowered.contains("serving"))
    }

    /// A line with its bullet or number taken off, and whether it opens an entry of its own
    /// rather than carrying on the one above. A marked line opens one, and so does a plain line
    /// that is not indented under the one before. In the problems, a problem opens an entry and
    /// its fix carries on under it, however the two are marked.
    private static func item(in line: String, section: Section, indented: Bool) -> (String, Bool) {
        var text = line
        var marked = false
        if let first = text.first, "-*•".contains(first) {
            text.removeFirst()
            marked = true
        } else if let match = text.firstMatch(of: #/^\d+[.)]\s+/#) {
            text.removeSubrange(match.range)
            marked = true
        }
        text = text.trimmingCharacters(in: .whitespaces)
        if section == .problems {
            let lowered = text.lowercased()
            if lowered.hasPrefix("fix") || lowered.hasPrefix("solution") {
                return (text, false)
            }
            if lowered.hasPrefix("problem") || lowered.hasPrefix("issue") {
                return (text, true)
            }
        }
        return (text, marked || !indented)
    }
}
