import ActivityKit
import SwiftUI
import WidgetKit

/// The lock screen and Dynamic Island face of a recipe being written. Every string it draws
/// was localized by the app before it was handed over, so it is all shown verbatim.
struct GenerationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GenerationActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                header(context.state)
                ProgressView(value: context.state.fraction)
            }
            .padding()
            .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "apple.intelligence")
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.center) {
                    header(context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.fraction)
                }
            } compactLeading: {
                Image(systemName: "apple.intelligence")
            } compactTrailing: {
                ProgressView(value: context.state.fraction)
                    .progressViewStyle(.circular)
                    .frame(width: 16, height: 16)
            } minimal: {
                ProgressView(value: context.state.fraction)
                    .progressViewStyle(.circular)
            }
        }
    }

    /// The dish over the line saying what is being written, or how it ended.
    @ViewBuilder
    private func header(_ state: GenerationActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let dish = state.dish, !dish.isEmpty {
                Text(verbatim: dish)
                    .font(.headline)
                    .lineLimit(1)
            }
            Text(verbatim: state.outcome ?? state.stage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
