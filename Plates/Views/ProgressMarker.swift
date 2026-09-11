import SwiftUI

/// Where one line of a checklist has got to: still to come, being worked on, or finished.
enum ProgressMarkerState: Equatable {
    case waiting
    case working
    case done
}

/// The mark at the head of a checklist line. Every state is drawn in the same circle, so
/// nothing shifts when a line finishes.
struct ProgressMarker: View {
    let state: ProgressMarkerState

    var body: some View {
        switch state {
        case .working:
            DonutSpinner()
        case .waiting, .done:
            Image(systemName: state == .done ? "checkmark.circle.fill" : "circle.dotted")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .frame(width: .markerSize, height: .markerSize)
        }
    }
}

extension CGFloat {
    /// The circle every checklist marker is drawn in, so the ring, the dotted circle, and the
    /// checkmark are all the same size.
    static let markerSize: CGFloat = 20
    /// How thick the ring is drawn. The ring is inset by half of it so its outer edge lands on
    /// the circle the symbols fill.
    static let markerLineWidth: CGFloat = 2
}

/// A ring with a gap in it, turning while the model works on that line. It sits where the
/// line's checkmark goes, so nothing shifts when the work finishes.
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
