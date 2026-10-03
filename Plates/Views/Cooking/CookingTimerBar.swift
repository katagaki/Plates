import CulinaryIntelligence
import SwiftUI

/// The timer while it is set, kept along the bottom of every step so it can be read and
/// paused from wherever the cook has scrolled to.
struct CookingTimerBar: View {
    let timer: CookingTimer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let isFinished = timer.isFinished(at: context.date)
            HStack(spacing: 12) {
                Image(systemName: isFinished ? "bell.fill" : "timer")
                    .font(.title2)
                    .symbolEffect(.wiggle, options: .repeat(.continuous), isActive: isFinished)

                Group {
                    if isFinished {
                        Text("Recipe.Cook.Timer.Finished")
                    } else {
                        Text(verbatim: Self.clock(timer.remaining(at: context.date)))
                            .monospacedDigit()
                    }
                }
                .font(.title.weight(.bold))
                .contentTransition(.numericText(countsDown: true))
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Recipe.Cook.Timer.AddMinute", systemImage: "goforward.60") {
                    timer.addMinute()
                }

                if !isFinished {
                    if timer.isRunning {
                        Button("Recipe.Cook.Timer.Pause", systemImage: "pause.fill") {
                            timer.pause()
                        }
                    } else {
                        Button("Recipe.Cook.Timer.Resume", systemImage: "play.fill") {
                            timer.resume()
                        }
                    }
                }

                Button("Recipe.Cook.Timer.Stop", systemImage: "xmark") {
                    timer.stop()
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .padding(.leading, 20)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
            .glassEffect(isFinished ? .regular.tint(.red) : .regular, in: .capsule)
        }
    }

    /// The time left as a kitchen timer shows it: "4:05", or "1:20:00" past the hour.
    private static func clock(_ remaining: Duration) -> String {
        remaining.formatted(
            remaining >= .seconds(3600)
                ? .time(pattern: .hourMinuteSecond)
                : .time(pattern: .minuteSecond)
        )
    }
}
