import SwiftUI

/// The sheet that asks Apple Intelligence for a new recipe and shows it before it is saved.
struct GenerateRecipeView: View {
    @Environment(\.dismiss) private var dismiss

    let store: RecipeStore

    @State private var generator = RecipeGenerator()
    @State private var request = GenerationRequest()
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
            ForEach(assets.wrappedValue, id: \.self) { asset in
                HStack(spacing: 12) {
                    RecipeIcon(path: path(asset), size: 32)
                    Text(verbatim: IconCatalog.displayName(for: asset))
                }
            }
            .onDelete { assets.wrappedValue.remove(atOffsets: $0) }

            NavigationLink {
                picker()
            } label: {
                Label(label, systemImage: systemImage)
            }
        }
    }

    /// While the model works, the form goes away and the passes are all that is on screen.
    private var progress: some View {
        VStack {
            GenerationProgressView(progress: generator.progress)
                .padding(.listRowInset)
                .cardBackground()
            Spacer(minLength: 0)
        }
        .padding(.listRowInset)
        .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(alignment: .leading, spacing: 12) {
            ProgressView(value: progress.fraction) {
                Text(progress.stage.title)
                    .font(.subheadline)
            }

            if let title = progress.title, !title.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let time = progress.time, let serves = progress.serves {
                        Text(String(format: String(localized: "Recipe.Row.Subtitle"), time, serves))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            stage("Generate.Progress.Row.Ingredients", count: progress.ingredientCount)
            stage("Generate.Progress.Row.Tools", count: progress.toolCount)
            stage("Generate.Progress.Row.Steps", count: progress.stepCount)
            stage("Generate.Progress.Row.StepDetails", count: progress.writtenStepCount)
            stage("Generate.Progress.Row.Troubleshooting", count: progress.troubleshootingCount)

            if progress.stage == .details, let latestStep = progress.latestStep, !latestStep.isEmpty {
                Text(verbatim: latestStep)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .animation(.default, value: progress)
    }

    private func stage(_ label: LocalizedStringResource, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: count > 0 ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(.secondary)
            Text(label)
                .font(.subheadline)
            Spacer(minLength: 0)
            if count > 0 {
                Text(count, format: .number)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
    }
}
