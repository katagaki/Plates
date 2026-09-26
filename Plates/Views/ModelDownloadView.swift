import CulinaryIntelligence
import SwiftUI

/// Granite coming down, when it was picked and is not on disk yet. Onboarding downloads it
/// first, so this is for a download that was cut short or a file that went missing. Every recipe
/// starts with that model while it is picked, so the sheet cannot be swiped away, and it goes by
/// itself once the download lands.
struct ModelDownloadView: View {
    let download: WriterModelDownload

    var body: some View {
        VStack(spacing: 20) {
            DownloadDonut(fraction: download.fraction)

            Text("Onboarding.Download.Label")
                .font(.headline)

            if case let .failed(message) = download.state {
                Text(verbatim: message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Shared.TryAgain") { download.start() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .multilineTextAlignment(.center)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}

/// A ring that fills as the file arrives, with how much has arrived written in the middle.
struct DownloadDonut: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: .donutLineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(.tint, style: StrokeStyle(lineWidth: .donutLineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: fraction)
            Text(fraction, format: .percent.precision(.fractionLength(0)))
                .font(.title2.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
                .animation(.default, value: Int(fraction * 100))
        }
        .padding(.donutLineWidth / 2)
        .frame(width: 140, height: 140)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Onboarding.Download.Label"))
        .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
    }
}

extension CGFloat {
    /// How thick the download ring is drawn.
    fileprivate static let donutLineWidth: CGFloat = 12
}
