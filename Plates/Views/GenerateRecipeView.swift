import SwiftUI

/// The sheet that asks Apple Intelligence for a new recipe and shows it before it is saved.
struct GenerateRecipeView: View {
    @Environment(\.dismiss) private var dismiss

    let store: RecipeStore

    @State private var generator = RecipeGenerator()
    @State private var mode: GenerationMode = .dish
    @State private var dishInput = ""
    @State private var fridgeInput = ""
    @State private var fridgePicks: [String] = []
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

            if mode == .fridge {
                Section {
                    ForEach(fridgePicks, id: \.self) { asset in
                        HStack(spacing: 12) {
                            RecipeIcon(path: IconCatalog.ingredientPath(for: asset), size: 32)
                            Text(verbatim: IconCatalog.displayName(for: asset))
                        }
                    }
                    .onDelete { fridgePicks.remove(atOffsets: $0) }

                    NavigationLink {
                        IngredientPickerView(selection: $fridgePicks)
                    } label: {
                        Label("Generate.Fridge.Choose", systemImage: "magnifyingglass")
                    }
                    .disabled(isGenerating)
                } footer: {
                    Text("Generate.Fridge.Choose.Footer")
                }
            }

            Section {
                Button {
                    Task { draft = await generator.generate(mode: mode, input: generationInput) }
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

    private var input: Binding<String> {
        switch mode {
        case .dish: $dishInput
        case .fridge: $fridgeInput
        }
    }

    private var canGenerate: Bool {
        guard generator.isAvailable, !isGenerating else { return false }
        guard mode.requiresInput else { return true }
        return !generationInput.isEmpty
    }

    /// What the model is given: for the fridge, the ingredients picked from the catalog and
    /// anything else typed in, as one list.
    private var generationInput: String {
        let typed = input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard mode == .fridge, !fridgePicks.isEmpty else { return typed }
        let picked = fridgePicks.map(IconCatalog.displayName).joined(separator: ", ")
        return typed.isEmpty ? picked : "\(picked), \(typed)"
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
