import CulinaryIntelligence
import SwiftUI

/// The changes filling in as the model makes them, with the recipe reading under them. The
/// first line is the model deciding what to change, the lines under it are what it decided, and
/// the last is the read through, which adds a line of its own for anything it asks for. The
/// checklist is only as long as the work turned out to be.
struct EditProgressView: View {
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
