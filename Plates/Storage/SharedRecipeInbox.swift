import CulinaryIntelligence
import Foundation

/// A future share extension puts reviewed, complete recipe JSON files here for Plates to import.
/// Each file has a unique name and is written atomically before the extension completes.
enum SharedRecipeInbox {
    static let groupIdentifier = "group.com.tsubuzaki.Plates"

    private static var directory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)?
            .appending(path: "PendingRecipes", directoryHint: .isDirectory)
    }

    static func pendingRecipes() throws -> [(url: URL, recipe: Recipe)] {
        guard let directory else { return [] }
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }

        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let recipe = try? JSONDecoder().decode(Recipe.self, from: data)
            else { return nil }
            return (url, recipe)
        }
    }

    static func remove(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}
