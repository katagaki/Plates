import SwiftUI

/// The catalog of ingredients the app can draw, searchable, so a cook can tick off what they
/// have instead of typing it. Ingredient names are catalog data, so they are shown as written.
struct IngredientPickerView: View {
    @Binding var selection: [String]

    @State private var query = ""

    var body: some View {
        List {
            if !picked.isEmpty {
                Section("Generate.Ingredients.Picked") {
                    ForEach(picked, id: \.self) { row($0) }
                }
            }
            Section("Generate.Ingredients.All") {
                ForEach(rest, id: \.self) { row($0) }
            }
        }
        .searchable(text: $query, prompt: Text("Generate.Ingredients.Search"))
        .overlay {
            if picked.isEmpty, rest.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle("Generate.Ingredients.Title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var matches: [String] { IconCatalog.ingredients(matching: query) }

    private var picked: [String] { selection.filter(matches.contains) }

    private var rest: [String] { matches.filter { !selection.contains($0) } }

    private func row(_ asset: String) -> some View {
        Button {
            if let index = selection.firstIndex(of: asset) {
                selection.remove(at: index)
            } else {
                selection.append(asset)
            }
        } label: {
            HStack(spacing: 12) {
                RecipeIcon(path: IconCatalog.ingredientPath(for: asset), size: 32)
                Text(verbatim: IconCatalog.displayName(for: asset))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                if selection.contains(asset) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }
}
