import SwiftUI

/// The sheet that rewrites a recipe from a request in the cook's own words. Apple Intelligence
/// works out what to change, and the screen fills in with the changes it settled on as it makes
/// them, so the cook sees what is being done rather than a spinner.
struct AskEditRecipeView: View {
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe
    /// Handed the rewritten recipe when the cook keeps it.
    let apply: (Recipe) -> Void

    @State private var editor = RecipeAskEditor()
    @State private var request = ""
    @State private var edited: Recipe?

    var body: some View {
        NavigationStack {
            Group {
                if let edited {
                    RecipeDetailView(recipe: edited)
                } else if isWorking {
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
                        .disabled(isWorking)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let edited {
                        Button("Shared.Save") {
                            apply(edited)
                            dismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isWorking)
        // A pass can take a while, and the sheet is not touched while it runs, so the screen is
        // held awake rather than locking part way through.
        .onChange(of: isWorking) { UIApplication.shared.isIdleTimerDisabled = isWorking }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    /// A rewritten recipe titles itself, so its title is shown as written.
    private var title: Text {
        if let edited {
            Text(verbatim: edited.title)
        } else {
            Text("Edit.Ask.Title")
        }
    }

    private var form: some View {
        Form {
            Section {
                TextField(
                    "Edit.Ask.Label",
                    text: $request,
                    prompt: Text("Edit.Ask.Prompt"),
                    axis: .vertical
                )
                .lineLimit(2...5)
                .disabled(!editor.isAvailable)
            } footer: {
                Text("Edit.Ask.Footer")
            }

            Section("Edit.Ask.Recipe") {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: recipe.title)
                        .font(.headline)
                    Text(String(
                        format: String(localized: "Recipe.Row.Subtitle"),
                        recipe.formattedTime,
                        recipe.serves
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
        .safeAreaInset(edge: .bottom) { askBar }
    }

    /// The one thing left to do on this screen, so it floats over the form rather than sitting
    /// at the end of it. Whatever is keeping the model from answering is said above the button.
    private var askBar: some View {
        VStack(spacing: 8) {
            if let reason = editor.unavailableReason {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if case let .failed(message) = editor.state {
                Text(verbatim: message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task { edited = await editor.edit(recipe, request: trimmedRequest) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.intelligence")
                    Text("Edit.Ask.Action")
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.accentColor)
            .disabled(!canAsk)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// While the model works, the form goes away and the changes have the screen to themselves.
    /// The recipe reads under them and grows as they land, so it scrolls rather than running
    /// off the bottom.
    private var progress: some View {
        ScrollView {
            EditProgressView(progress: editor.progress)
                .padding(.listRowInset)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var isWorking: Bool { editor.state == .working }

    private var trimmedRequest: String {
        request.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAsk: Bool {
        editor.isAvailable && !isWorking && !trimmedRequest.isEmpty
    }
}

/// The changes filling in as the model makes them, with the recipe reading under them. The
/// first line is the model deciding what to change, the lines under it are what it decided, and
/// the last is the read through, which adds a line of its own for anything it asks for. The
/// checklist is only as long as the work turned out to be.
private struct EditProgressView: View {
    let progress: EditProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                row(state: progress.isPlanning ? .working : .done) {
                    Text("Edit.Progress.Planning")
                }

                // Change titles are written by the model, so they are shown as written.
                ForEach(progress.changes) { change in
                    row(state: state(of: change)) {
                        Text(verbatim: change.title)
                    }
                }

                row(state: reviewState) {
                    Text("Edit.Progress.Reviewing")
                }
            }

            if !progress.title.isEmpty {
                RecipePreview(
                    title: progress.title,
                    time: progress.time,
                    serves: progress.serves,
                    steps: progress.steps
                )
            }
        }
        .animation(.default, value: progress)
    }

    /// The read through waits its turn like any other line, and is ticked with the rest when
    /// the run ends.
    private var reviewState: ProgressMarkerState {
        if progress.isFinished { return .done }
        return progress.isReviewing ? .working : .waiting
    }

    private func state(of change: EditProgress.Change) -> ProgressMarkerState {
        switch change.state {
        case .waiting: .waiting
        case .working: progress.isFinished ? .done : .working
        case .done: .done
        }
    }

    private func row(
        state: ProgressMarkerState,
        @ViewBuilder label: () -> some View
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            ProgressMarker(state: state)
            label()
            Spacer(minLength: 0)
        }
    }
}
