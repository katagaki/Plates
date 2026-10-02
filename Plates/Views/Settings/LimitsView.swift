import CulinaryIntelligence
import SwiftUI

/// What is left of today's limits on PlatesCloud, as the Worker counts them for this device.
struct LimitsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var limits: CloudLimits?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let limits {
                    Section {
                        row("Limits.Write", limits.write)
                        row("Limits.Ideate", limits.ideate)
                        row("Limits.Decide", limits.decide)
                    } footer: {
                        Text("Limits.Footer")
                    }
                } else if let error {
                    Text(verbatim: error)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Limits.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    /// What is left of one limit, as a count and a bar that empties as the day's calls are used.
    private func row(_ label: LocalizedStringResource, _ allowance: CloudLimits.Allowance) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent {
                Text(verbatim: String(
                    format: String(localized: "Limits.Remaining"),
                    allowance.remaining,
                    allowance.limit
                ))
                .monospacedDigit()
            } label: {
                Text(label)
            }
            ProgressView(value: Double(allowance.remaining), total: Double(max(allowance.limit, 1)))
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        do {
            limits = try await PlatesCloud.shared.limits()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
