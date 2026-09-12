import SwiftUI

/// The sheet that asks Apple Intelligence for a new recipe and shows it before it is saved.
struct GenerateRecipeView: View {
    @Environment(\.dismiss) private var dismiss

    let store: RecipeStore

    @State private var generator = RecipeGenerator()
    @State private var request = GenerationRequest(
        ingredients: Pantry.ingredients,
        tools: Pantry.tools
    )
    @State private var draft: Recipe?

    var body: some View {
        NavigationStack {
            Group {
                if let draft {
                    RecipeDetailView(recipe: draft)
                } else if isGenerating {
                    progress
                } else {
                    form
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                        .disabled(isGenerating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let draft {
                        Button("Shared.Save") {
                            store.save(draft, isNew: true)
                            dismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isGenerating)
        // A pass can take a while, and the sheet is not touched while it runs, so the screen
        // is held awake rather than locking part way through a recipe.
        .onChange(of: isGenerating) { UIApplication.shared.isIdleTimerDisabled = isGenerating }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: request.ingredients) { Pantry.ingredients = request.ingredients }
        .onChange(of: request.tools) { Pantry.tools = request.tools }
    }

    /// A generated recipe titles itself, so its title is shown as written.
    private var title: Text {
        if let draft {
            Text(verbatim: draft.title)
        } else {
            Text("Generate.Title")
        }
    }

    private var form: some View {
        Form {
            Section {
                TextField(
                    "Generate.Description.Label",
                    text: $request.description,
                    prompt: Text("Generate.Description.Prompt"),
                    axis: .vertical
                )
                .lineLimit(2...5)
                .disabled(!generator.isAvailable)
            } footer: {
                Text("Generate.Description.Footer")
            }

            Section {
                Toggle("Generate.IgnorePicks.Label", isOn: $request.ignoresPicks)
                    .disabled(!generator.isAvailable)
            } footer: {
                Text("Generate.IgnorePicks.Footer")
            }

            picks(
                "Generate.Choose.Ingredients",
                assets: shelf(.fresh),
                path: IconCatalog.ingredientPath
            ) {
                CatalogPickerView.ingredients(selection: shelf(.fresh))
            }
            .disabled(request.ignoresPicks)

            picks(
                "Generate.Choose.Pantry",
                assets: shelf(.pantry),
                path: IconCatalog.ingredientPath
            ) {
                CatalogPickerView.pantry(selection: shelf(.pantry))
            }
            .disabled(request.ignoresPicks)

            picks(
                "Generate.Choose.Tools",
                assets: $request.tools,
                path: IconCatalog.toolPath
            ) {
                CatalogPickerView.tools(selection: $request.tools)
            }
            .disabled(request.ignoresPicks)
        }
        .safeAreaInset(edge: .bottom) { generateBar }
    }

    /// The one thing left to do on this screen, so it floats over the form rather than sitting
    /// at the end of it. Whatever is keeping the model from answering is said above the button.
    private var generateBar: some View {
        VStack(spacing: 8) {
            if let reason = generator.unavailableReason {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if case let .failed(message) = generator.state {
                Text(verbatim: message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task { draft = await generator.generate(request) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.intelligence")
                    Text("Menu.Generate")
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.accentColor)
            .disabled(!canGenerate)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// One shelf of the picks, so each picker shows and edits its own half while the model is
    /// still handed a single list. Writing back keeps the other shelf as it was.
    private func shelf(_ shelf: IngredientShelf) -> Binding<[String]> {
        Binding(
            get: { request.ingredients.filter { IconCatalog.shelf(of: $0) == shelf } },
            set: { picks in
                request.ingredients =
                    request.ingredients.filter { IconCatalog.shelf(of: $0) != shelf } + picks
            }
        )
    }

    /// What the cook has already picked, with the way back into the catalog under it.
    private func picks(
        _ label: LocalizedStringResource,
        assets: Binding<[String]>,
        path: @escaping (String) -> String,
        @ViewBuilder picker: @escaping () -> some View
    ) -> some View {
        Section {
            if !assets.wrappedValue.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(assets.wrappedValue, id: \.self) { asset in
                            Button {
                                assets.wrappedValue.removeAll { $0 == asset }
                            } label: {
                                VStack(spacing: 2) {
                                    RecipeIcon(path: path(asset), size: 30)
                                    Text(verbatim: IconCatalog.displayName(for: asset))
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                }
                                .frame(width: 66)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .listRowInsets(EdgeInsets())
            }

            NavigationLink {
                picker()
            } label: {
                Text(label)
            }
        }
    }

    /// While the model works, the form goes away and the passes have the screen to themselves.
    private var progress: some View {
        GenerationProgressView(progress: generator.progress)
            .padding(.listRowInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(uiColor: .systemGroupedBackground))
    }

    private var isGenerating: Bool { generator.state == .generating }

    private var canGenerate: Bool {
        generator.isAvailable && !isGenerating && !request.isEmpty
    }
}

/// The recipe filling in, stage by stage, while the model writes it.
private struct GenerationProgressView: View {
    let progress: GenerationProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(progress.stage.title)
                .font(.subheadline)

            if let heading = progress.title ?? progress.dish, !heading.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: heading)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let time = progress.time, let serves = progress.serves {
                        Text(String(
                            format: String(localized: "Recipe.Row.Subtitle"),
                            Recipe.formatTime(time),
                            serves
                        ))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            row("Generate.Progress.Row.Picked", count: progress.pickedCount, stage: .pick)
            row("Generate.Progress.Row.Ingredients", count: progress.ingredientCount, stage: .idea)
            row("Generate.Progress.Row.Tools", count: progress.toolCount, stage: .idea)
            row("Generate.Progress.Row.Steps", count: progress.stepCount, stage: .outline)
            row("Generate.Progress.Row.StepDetails", count: progress.writtenStepCount, stage: .details)
            row(
                "Generate.Progress.Row.Troubleshooting",
                count: progress.troubleshootingCount,
                stage: .troubleshooting
            )

            if progress.stage == .details, let latestStep = progress.latestStep, !latestStep.isEmpty {
                Text(verbatim: latestStep)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .animation(.default, value: progress)
    }

    /// Where a line has got to: spinning while its pass is the one running, ticked once it has
    /// something to show.
    private func marker(
        for stage: GenerationProgress.Stage,
        count: Int
    ) -> ProgressMarkerState {
        if progress.stage == stage && !progress.isFinished { return .working }
        return count > 0 ? .done : .waiting
    }

    /// One line of the checklist, spinning while its pass is the one running.
    private func row(
        _ label: LocalizedStringResource,
        count: Int,
        stage: GenerationProgress.Stage
    ) -> some View {
        HStack(spacing: 8) {
            ProgressMarker(state: marker(for: stage, count: count))
            Text(label)
            Spacer(minLength: 0)
            if count > 0 {
                Text(count, format: .number)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
    }
}

