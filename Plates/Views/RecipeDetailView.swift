import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe

    @State private var isShowingTroubleshooting = false
    @State private var tapped: TileInfo?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summary
                    .padding(.horizontal, .listRowInset)

                carousel("Recipe.Detail.Ingredients", ingredients)
                carousel("Recipe.Detail.Ingredients.Optional", optionalIngredients)
                carousel("Recipe.Detail.Tools", tools(required: true))
                carousel("Recipe.Detail.Tools.Optional", tools(required: false))

                section("Recipe.Detail.Steps") {
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        StepCard(number: index + 1, step: step)
                    }
                }
                .padding(.horizontal, .listRowInset)
            }
            .padding(.vertical, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !recipe.troubleshooting.isEmpty {
                ToolbarSpacer(.flexible, placement: .bottomBar)
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
        .alert(
            Text(verbatim: tapped?.name ?? ""),
            isPresented: Binding(get: { tapped != nil }, set: { if !$0 { tapped = nil } }),
            presenting: tapped
        ) { _ in
            Button("Shared.Done", role: .cancel) {}
        } message: { info in
            Text(verbatim: info.message)
        }
    }

    /// Time, servings, and whether it has been cooked, side by side.
    private var summary: some View {
        Grid(horizontalSpacing: 12) {
            GridRow {
                SummaryCell(label: "Recipe.Detail.Time") {
                    Text(verbatim: recipe.formattedTime)
                }
                SummaryCell(label: "Recipe.Detail.Serves") {
                    Text(verbatim: recipe.serves)
                }
                SummaryCell(label: "Recipe.Detail.Tried") {
                    // Drawn as text so the mark sits on the same line as the other two cells.
                    Text(Image(systemName: recipe.tried == true ? "checkmark" : "xmark"))
                }
            }
        }
    }

    /// The shopping list is written in sections, but a cook reads it as one list.
    private var ingredients: [TileInfo] {
        ((recipe.ingredients.supermarket ?? []) + (recipe.ingredients.general ?? [])).map(TileInfo.init)
    }

    private var optionalIngredients: [TileInfo] {
        (recipe.ingredients.optional ?? []).map(TileInfo.init)
    }

    private func tools(required: Bool) -> [TileInfo] {
        recipe.tools.filter { $0.required == required }.map(TileInfo.init)
    }

    /// A row that scrolls sideways, cut so the third card is half on screen and the cook can
    /// see there is more to come.
    @ViewBuilder
    private func carousel(_ title: LocalizedStringResource, _ items: [TileInfo]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal, .listRowInset)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(items) { item in
                            Button {
                                if item.message.isEmpty == false { tapped = item }
                            } label: {
                                IconTile(item: item)
                            }
                            .buttonStyle(.plain)
                            .containerRelativeFrame(.horizontal, count: 5, span: 2, spacing: 12)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, .listRowInset, for: .scrollContent)
            }
        }
    }

    @ViewBuilder
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

/// Time, servings, or whether the recipe has been cooked.
private struct SummaryCell<Content: View>: View {
    let label: LocalizedStringResource
    @ViewBuilder let value: Content

    var body: some View {
        VStack(spacing: 4) {
            value
                .font(.title3.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
    }
}

private struct StepCard: View {
    let number: Int
    let step: Step

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: String(localized: "Recipe.Detail.Step.Title"), number, step.title))
                .font(.headline)

            if let icons = step.icons, !icons.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(icons, id: \.self) { icon in
                            RecipeIcon(path: icon, size: 32)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            ForEach(step.points, id: \.self) { point in
                Text(verbatim: point)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardBackground()
    }
}
