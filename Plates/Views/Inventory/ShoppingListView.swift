import CulinaryIntelligence
import SwiftUI

/// What a recipe needs that is not in the inventory. A tap on a line puts it in the inventory
/// once it is bought, and a second tap takes it out again. The list is worked out when the
/// sheet opens, so a line that is ticked off stays on screen.
struct ShoppingListView: View {
    @Environment(\.dismiss) private var dismiss

    private let list: ShoppingList

    @State private var ingredients = Pantry.ingredients
    @State private var tools = Pantry.tools

    init(recipe: Recipe) {
        list = ShoppingList(
            recipe: recipe,
            inventoryIngredients: Pantry.ingredients,
            inventoryTools: Pantry.tools
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if list.isEmpty {
                    ContentUnavailableView {
                        Label("ShoppingList.Empty.Title", systemImage: "checkmark.circle")
                    } description: {
                        Text("ShoppingList.Empty.Description")
                    }
                } else {
                    List {
                        if !list.ingredients.isEmpty {
                            Section {
                                ForEach(list.ingredients) { ingredient in
                                    row(
                                        TileInfo(ingredient),
                                        catalog: IconCatalog.ingredients,
                                        inventory: $ingredients
                                    )
                                }
                            } header: {
                                Text("Generate.Ingredients.Title")
                            } footer: {
                                if list.tools.isEmpty {
                                    Text("ShoppingList.Footer")
                                }
                            }
                        }
                        if !list.tools.isEmpty {
                            Section {
                                ForEach(list.tools) { tool in
                                    row(TileInfo(tool), catalog: IconCatalog.tools, inventory: $tools)
                                }
                            } header: {
                                Text("Generate.Tools.Title")
                            } footer: {
                                Text("ShoppingList.Footer")
                            }
                        }
                    }
                }
            }
            .navigationTitle("ShoppingList.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .onChange(of: ingredients) { Pantry.ingredients = ingredients }
        .onChange(of: tools) { Pantry.tools = tools }
    }

    /// One line to buy. A line drawn with an icon the catalog does not carry cannot go in the
    /// inventory, so it has no mark to tick.
    @ViewBuilder
    private func row(_ item: TileInfo, catalog: [String], inventory: Binding<[String]>) -> some View {
        let name = IconCatalog.iconName(for: item.icon).flatMap { catalog.contains($0) ? $0 : nil }
        let isBought = name.map(inventory.wrappedValue.contains) ?? false
        Button {
            guard let name else { return }
            if isBought {
                inventory.wrappedValue.removeAll { $0 == name }
            } else {
                inventory.wrappedValue.append(name)
            }
        } label: {
            HStack(spacing: 12) {
                RecipeIcon(path: item.icon, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: item.name)
                        .strikethrough(isBought)
                    if let detail = item.detail, !detail.isEmpty {
                        Text(verbatim: detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if name != nil {
                    Image(systemName: isBought ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isBought ? Color.accentColor : .secondary)
                        .font(.title3)
                }
            }
        }
        .tint(.primary)
        .disabled(name == nil)
        .accessibilityAddTraits(isBought ? .isSelected : [])
    }
}
