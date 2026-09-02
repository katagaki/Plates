import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe

    var body: some View {
        List {
            Section {
                LabeledContent {
                    Text(verbatim: recipe.time)
                } label: {
                    Text("Recipe.Detail.Time")
                }
                LabeledContent {
                    Text(verbatim: recipe.serves)
                } label: {
                    Text("Recipe.Detail.Serves")
                }
                if recipe.tried == true {
                    Label("Recipe.Detail.Tried", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            }

            ingredientSection(
                "Recipe.Detail.Ingredients.Supermarket",
                recipe.ingredients.supermarket,
                color: .orange
            )
            ingredientSection(
                "Recipe.Detail.Ingredients.General",
                recipe.ingredients.general,
                color: .yellow
            )
            ingredientSection(
                "Recipe.Detail.Ingredients.Optional",
                recipe.ingredients.optional,
                color: .mint
            )

            toolSection(required: true)
            toolSection(required: false)

            Section {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    StepRow(number: index + 1, step: step)
                }
            } header: {
                SectionHeading(title: "Recipe.Detail.Steps", color: .red)
            }

            if !recipe.troubleshooting.isEmpty {
                Section {
                    ForEach(recipe.troubleshooting) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: entry.problem)
                                .font(.headline)
                            Text(verbatim: entry.solution)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    SectionHeading(title: "Recipe.Detail.Troubleshooting", color: .purple)
                }
            }
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func ingredientSection(
        _ title: LocalizedStringResource,
        _ entries: [Ingredient]?,
        color: Color
    ) -> some View {
        if let entries, !entries.isEmpty {
            Section {
                ForEach(entries) { entry in
                    IconTile(iconPath: entry.icon, name: entry.item, detail: entry.amount, note: entry.note)
                }
            } header: {
                SectionHeading(title: title, color: color)
            }
        }
    }

    @ViewBuilder
    private func toolSection(required: Bool) -> some View {
        let entries = recipe.tools.filter { $0.required == required }
        if !entries.isEmpty {
            Section {
                ForEach(entries) { tool in
                    IconTile(iconPath: tool.icon, name: tool.name, note: tool.note)
                }
            } header: {
                SectionHeading(
                    title: required ? "Recipe.Detail.Tools.Required" : "Recipe.Detail.Tools.Optional",
                    color: .blue
                )
            }
        }
    }
}

private struct StepRow: View {
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
                    .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 12))
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
        .padding(.vertical, 6)
    }
}
