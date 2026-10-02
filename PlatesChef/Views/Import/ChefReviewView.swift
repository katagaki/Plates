import SwiftUI

struct ChefReviewView: View {
    @Binding var recipe: ChefRecipe

    var body: some View {
        Form {
            Section("Chef.Review") {
                Text("Chef.Review.Help")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if (recipe.ingredients.supermarket ?? []).contains(where: { $0.amount.isEmpty }) {
                    Text("Chef.Review.AmountHelp")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                TextField("Chef.Name", text: $recipe.title)
                TextField("Chef.Time", text: $recipe.time)
                TextField("Chef.Serves", text: $recipe.serves)
            }

            ingredients("Chef.Ingredients", entries: $recipe.ingredients.supermarket)
            ingredients("Chef.Pantry", entries: $recipe.ingredients.general)
            ingredients("Chef.Optional", entries: $recipe.ingredients.optional)

            Section("Chef.Steps") {
                ForEach($recipe.steps) { $step in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Chef.Step.Title", text: $step.title)
                            .font(.headline)
                        TextEditor(text: Binding(
                            get: { step.points.joined(separator: "\n") },
                            set: { step.points = $0.components(separatedBy: "\n") }
                        ))
                        .frame(minHeight: 75)
                    }
                }
                .onDelete { recipe.steps.remove(atOffsets: $0) }
                Button("Chef.Step.Add", systemImage: "plus") {
                    recipe.steps.append(.init(title: "", points: [""]))
                }
            }

            if !recipe.tools.isEmpty {
                Section("Chef.Tools") {
                    ForEach($recipe.tools) { $tool in
                        TextField("Chef.Tool.Name", text: $tool.name)
                    }
                }
            }
            if !recipe.troubleshooting.isEmpty {
                Section("Chef.Troubleshooting") {
                    ForEach($recipe.troubleshooting) { $entry in
                        TextField("Chef.Problem", text: $entry.problem)
                        TextField("Chef.Solution", text: $entry.solution, axis: .vertical)
                    }
                }
            }
        }
    }

    private func ingredients(
        _ title: LocalizedStringResource,
        entries: Binding<[ChefRecipe.Ingredient]?>
    ) -> some View {
        let list = Binding<[ChefRecipe.Ingredient]>(
            get: { entries.wrappedValue ?? [] },
            set: { entries.wrappedValue = $0 }
        )
        return Section(title) {
            ForEach(list) { $entry in
                VStack(alignment: .leading) {
                    TextField("Chef.Ingredient.Name", text: $entry.item)
                    TextField("Chef.Ingredient.Amount", text: $entry.amount)
                        .font(.subheadline)
                }
            }
            .onDelete { list.wrappedValue.remove(atOffsets: $0) }
            Button("Chef.Ingredient.Add", systemImage: "plus") {
                list.wrappedValue.append(.init(item: "", icon: "", amount: ""))
            }
        }
    }
}
