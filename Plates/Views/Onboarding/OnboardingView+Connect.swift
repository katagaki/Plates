import CulinaryIntelligence
import SwiftUI

extension OnboardingView {
    /// Granite is downloaded here. Any other model is said hello to, so a wrong key shows up
    /// now rather than part way through the first recipe.
    @ViewBuilder
    var connectStep: some View {
        if settings.provider == .granite {
            downloadStep
        } else {
            helloStep
        }
    }

    // MARK: - Granite

    private var downloadStep: some View {
        page {
            stepHeader(
                icon: "arrow.down.circle",
                title: "Onboarding.Download.Title",
                description: "Onboarding.Download.Description"
            )

            VStack(spacing: 16) {
                DownloadDonut(fraction: download.fraction)
                Text("Onboarding.Download.Label")
                    .font(.headline)
                if case let .failed(message) = download.state {
                    Text(verbatim: message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        } buttons: {
            if case .failed = download.state {
                secondaryButton("Shared.TryAgain") { download.start() }
            }
            primaryButton(isChangingModel ? "Shared.Done" : "Onboarding.Continue") { advance() }
                .disabled(!download.isReady)
        }
        .onAppear { download.start() }
        .keepsScreenAwake(while: download.state == .downloading)
    }

    // MARK: - Hello

    private var helloStep: some View {
        page {
            stepHeader(
                icon: "bubble.left.and.text.bubble.right",
                title: "Onboarding.Connect.Title",
                description: "Onboarding.Connect.Description"
            )

            VStack(alignment: .leading, spacing: 16) {
                bubble(ModelCheck.greeting, isCook: true)

                switch check {
                case .idle, .checking:
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Onboarding.Connect.Waiting")
                            .foregroundStyle(.secondary)
                    }
                case let .passed(replies):
                    ForEach(replies) { reply in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: reply.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            bubble(reply.text, isCook: false)
                        }
                    }
                case let .failed(message):
                    Label {
                        Text(verbatim: message)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    .font(.subheadline)
                }
            }
        } buttons: {
            if case .failed = check {
                secondaryButton("Shared.TryAgain") { runCheck() }
            }
            primaryButton(isChangingModel ? "Shared.Done" : "Onboarding.Continue") { advance() }
                .disabled(!isCheckPassed)
        }
        .task {
            if check == .idle { runCheck() }
        }
    }

    private var isCheckPassed: Bool {
        if case .passed = check { true } else { false }
    }

    private func runCheck() {
        check = .checking
        Task {
            do {
                let replies = try await ModelCheck.sayHello()
                withAnimation(.smooth.speed(2)) { check = .passed(replies) }
            } catch {
                withAnimation(.smooth.speed(2)) { check = .failed(error.localizedDescription) }
            }
        }
    }

    /// One side of the exchange: the cook's greeting on the right, the model's answer on the
    /// left.
    private func bubble(_ text: String, isCook: Bool) -> some View {
        Text(verbatim: text)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(isCook ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .background(
                isCook ? AnyShapeStyle(.tint) : AnyShapeStyle(.regularMaterial),
                in: .rect(cornerRadius: 18)
            )
            .frame(maxWidth: .infinity, alignment: isCook ? .trailing : .leading)
    }
}
