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

            picks(
                "Generate.Choose.Ingredients",
                systemImage: "carrot",
                assets: $request.ingredients,
                path: IconCatalog.ingredientPath
            ) {
                CatalogPickerView.ingredients(selection: $request.ingredients)
            }

            picks(
                "Generate.Choose.Tools",
                systemImage: "frying.pan",
                assets: $request.tools,
                path: IconCatalog.toolPath
            ) {
                CatalogPickerView.tools(selection: $request.tools)
            }

            Section {
                Button {
                    Task { draft = await generator.generate(request) }
                } label: {
                    Label("Menu.Generate", systemImage: "apple.intelligence")
                }
                .disabled(!canGenerate)
            } footer: {
                if let reason = generator.unavailableReason {
                    Text(reason)
                } else if case let .failed(message) = generator.state {
                    Text(verbatim: message)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    /// What the cook has already picked, with the way back into the catalog under it.
    private func picks(
        _ label: LocalizedStringResource,
        systemImage: String,
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
                Label(label, systemImage: systemImage)
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
            ProgressView(value: progress.fraction) {
                Text(progress.stage.title)
                    .font(.subheadline)
            }

            if let heading = progress.title ?? progress.dish, !heading.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: heading)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let time = progress.time, let serves = progress.serves {
                        Text(String(format: String(localized: "Recipe.Row.Subtitle"), time, serves))
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

    /// One line of the checklist, spinning while its pass is the one running.
    private func row(
        _ label: LocalizedStringResource,
        count: Int,
        stage: GenerationProgress.Stage
    ) -> some View {
        HStack(spacing: 8) {
            if progress.stage == stage && !progress.isFinished {
                DonutSpinner()
            } else {
                Image(systemName: count > 0 ? "checkmark.circle.fill" : "circle.dotted")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .frame(width: .markerSize, height: .markerSize)
            }
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

private extension CGFloat {
    /// The circle every checklist marker is drawn in, so the ring, the dotted circle, and the
    /// checkmark are all the same size.
    static let markerSize: CGFloat = 20
    /// How thick the ring is drawn. The ring is inset by half of it so its outer edge lands on
    /// the circle the symbols fill.
    static let markerLineWidth: CGFloat = 2
}

/// A ring with a gap in it, turning while the model works on that line. It sits where the
/// line's checkmark goes, so nothing shifts when the pass finishes.
private struct DonutSpinner: View {
    @State private var isTurning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(.secondary, style: StrokeStyle(lineWidth: .markerLineWidth, lineCap: .round))
            .padding(.markerLineWidth / 2)
            .rotationEffect(.degrees(isTurning ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isTurning)
            .frame(width: .markerSize, height: .markerSize)
            .onAppear { isTurning = true }
    }
}
