import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe

    var body: some View {
        List {
            Section {
                LabeledContent("Time", value: recipe.time)
                LabeledContent("Serves", value: recipe.serves)
                if recipe.tried == true {
                    Label("Human tested", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            }

            ingredientSection("Fresh and chilled", recipe.ingredients.supermarket, color: .orange)
            ingredientSection("From the pantry", recipe.ingredients.general, color: .yellow)
            ingredientSection("Optional", recipe.ingredients.optional, color: .mint)

            toolSection("Required", required: true)
            toolSection("Optional", required: false)

            Section {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    StepRow(number: index + 1, step: step)
                }
            } header: {
                SectionHeading(title: "Steps", color: .red)
            }

            if !recipe.troubleshooting.isEmpty {
                Section {
                    ForEach(recipe.troubleshooting) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.problem)
                                .font(.headline)
                            Text(entry.solution)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    SectionHeading(title: "Troubleshooting", color: .purple)
                }
            }
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func ingredientSection(_ title: String, _ entries: [Ingredient]?, color: Color) -> some View {
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
    private func toolSection(_ title: String, required: Bool) -> some View {
        let entries = recipe.tools.filter { $0.required == required }
        if !entries.isEmpty {
            Section {
                ForEach(entries) { tool in
                    IconTile(iconPath: tool.icon, name: tool.name, note: tool.note)
                }
            } header: {
                SectionHeading(title: required ? "Tools, required" : "Tools, optional", color: .blue)
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
            Text("\(number). \(step.title)")
                .font(.headline)
            ForEach(step.points, id: \.self) { point in
                Text(point)
                    .foregroundStyle(.secondary)
            }
            if let hint = step.hint, !hint.isEmpty {
                Label(hint, systemImage: "lightbulb")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }
}
