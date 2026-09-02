import SwiftUI

/// The sheet that asks Apple Intelligence for a new recipe and shows it before it is saved.
struct GenerateRecipeView: View {
    @Environment(\.dismiss) private var dismiss

    let store: RecipeStore

    @State private var generator = RecipeGenerator()
    @State private var mode: GenerationMode = .dish
    @State private var dishInput = ""
    @State private var fridgeInput = ""
    @State private var draft: Recipe?

    var body: some View {
        NavigationStack {
            Group {
                if let draft {
                    RecipeDetailView(recipe: draft)
                } else {
                    form
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Shared.Cancel") { dismiss() }
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
        .interactiveDismissDisabled(generator.state == .generating)
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
                Picker("Generate.Mode.Title", selection: $mode) {
                    ForEach(GenerationMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                TextField(
                    mode.fieldLabel,
                    text: input,
                    prompt: Text(mode.fieldPrompt),
                    axis: .vertical
                )
                .lineLimit(2...5)
                .disabled(!generator.isAvailable || isGenerating)
            } footer: {
                Text(mode.footer)
            }

            Section {
                Button {
                    Task { draft = await generator.generate(mode: mode, input: input.wrappedValue) }
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

            if isGenerating {
                Section {
                    GenerationProgressView(progress: generator.progress)
                }
            }
        }
    }

    private var isGenerating: Bool { generator.state == .generating }

    private var input: Binding<String> {
        switch mode {
        case .dish: $dishInput
        case .fridge: $fridgeInput
        }
    }

    private var canGenerate: Bool {
        guard generator.isAvailable, !isGenerating else { return false }
        guard mode.requiresInput else { return true }
        return !input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// The recipe filling in, stage by stage, while the model writes it.
private struct GenerationProgressView: View {
    let progress: GenerationProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView(value: progress.fraction) {
                Text("Generate.Progress.Title")
                    .font(.subheadline)
            }

            if let title = progress.title, !title.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title)
                        .font(.headline)
                    if let time = progress.time, let serves = progress.serves {
                        Text(String(format: String(localized: "Recipe.Row.Subtitle"), time, serves))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            stage("Recipe.Detail.Ingredients.Supermarket", count: progress.ingredientCount)
            stage("Recipe.Detail.Tools.Required", count: progress.toolCount)
            stage("Recipe.Detail.Steps", count: progress.stepCount)
            stage("Recipe.Detail.Troubleshooting", count: progress.troubleshootingCount)

            if let latestStep = progress.latestStep, !latestStep.isEmpty {
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
