import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe

    @State private var isShowingTroubleshooting = false

    private let tileColumns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summary

                ingredientSection("Recipe.Detail.Ingredients.Supermarket", recipe.ingredients.supermarket)
                ingredientSection("Recipe.Detail.Ingredients.General", recipe.ingredients.general)
                ingredientSection("Recipe.Detail.Ingredients.Optional", recipe.ingredients.optional)

                toolSection(required: true)
                toolSection(required: false)

                section("Recipe.Detail.Steps") {
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        StepCard(number: index + 1, step: step)
                    }
                }
            }
            .padding(.horizontal, .listRowInset)
            .padding(.vertical, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !recipe.troubleshooting.isEmpty {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        isShowingTroubleshooting = true
                    } label: {
                        Label("Recipe.Detail.Troubleshooting", systemImage: "questionmark.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingTroubleshooting) {
            TroubleshootingView(entries: recipe.troubleshooting)
        }
    }

    /// Time, servings, and whether it has been cooked, side by side.
    private var summary: some View {
        Grid(horizontalSpacing: 12) {
            GridRow {
                SummaryCell(label: "Recipe.Detail.Time") {
                    Text(verbatim: recipe.time)
                }
                SummaryCell(label: "Recipe.Detail.Serves") {
                    Text(verbatim: recipe.serves)
                }
                SummaryCell(label: "Recipe.Detail.Tried") {
                    Image(systemName: recipe.tried == true ? "checkmark" : "minus")
                }
            }
        }
    }

    @ViewBuilder
    private func ingredientSection(
        _ title: LocalizedStringResource,
        _ entries: [Ingredient]?
    ) -> some View {
        if let entries, !entries.isEmpty {
            section(title) {
                LazyVGrid(columns: tileColumns, spacing: 12) {
                    ForEach(entries) { entry in
                        IconTile(
                            iconPath: entry.icon,
                            name: entry.item,
                            detail: entry.amount,
                            note: entry.note
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func toolSection(required: Bool) -> some View {
        let entries = recipe.tools.filter { $0.required == required }
        if !entries.isEmpty {
            section(required ? "Recipe.Detail.Tools.Required" : "Recipe.Detail.Tools.Optional") {
                LazyVGrid(columns: tileColumns, spacing: 12) {
                    ForEach(entries) { tool in
                        IconTile(iconPath: tool.icon, name: tool.name, note: tool.note)
                    }
                }
            }
        }
    }

    private func section(
        _ title: LocalizedStringResource,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}

private struct SummaryCell<Value: View>: View {
    let label: LocalizedStringResource
    @ViewBuilder let value: Value

    var body: some View {
        VStack(spacing: 4) {
            value
                .font(.title3.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .cardBackground()
    }
}

private struct StepCard: View {
    let number: Int
    let step: Step

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = step.image,
               let name = IconCatalog.assetName(for: image),
               UIImage(named: name) != nil {
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .background(
                        Color(uiColor: .tertiarySystemGroupedBackground),
                        in: .rect(cornerRadius: .listRowCornerRadius - 12, style: .continuous)
                    )
            }
            Text(String(format: String(localized: "Recipe.Detail.Step.Title"), number, step.title))
                .font(.headline)
            ForEach(step.points, id: \.self) { point in
                Text(verbatim: point)
                    .foregroundStyle(.secondary)
            }
            if let hint = step.hint, !hint.isEmpty {
                Label {
                    Text(verbatim: hint)
                } icon: {
                    Image(systemName: "lightbulb")
                }
                .font(.footnote)
                .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardBackground()
    }
}
