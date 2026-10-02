import CulinaryIntelligence
import SwiftUI

/// The bottom bar field where the cook asks for changes to a recipe in their own words.
struct RecipeRevisionBar: View {
    @Binding var text: String
    let canSend: Bool
    let send: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Edit.Ask.Label", text: $text, prompt: Text("Edit.Ask.Prompt"))
                .submitLabel(.send)
                .onSubmit { if canSend { send() } }
                .padding(.leading, 12)
            Button(action: send) {
                Label("Edit.Ask.Title", systemImage: "arrow.up")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .disabled(!canSend)
        }
        .frame(maxWidth: .infinity)
    }
}

/// While the model works, the recipe goes away and the changes have the screen to themselves.
/// The recipe reads under them and grows as they land, so it scrolls rather than running off
/// the bottom.
struct RevisionProgressView: View {
    let progress: EditProgress

    var body: some View {
        ScrollView {
            EditProgressView(progress: progress)
                .padding(.listRowInset)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(uiColor: .systemGroupedBackground))
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
        HStack(alignment: .center, spacing: 8) {
            ProgressMarker(state: state)
            label()
            Spacer(minLength: 0)
        }
    }
}
