import CulinaryIntelligence
import SwiftUI

extension OnboardingView {
    /// Where a request goes, asked before the first recipe. A cook who does not allow it can
    /// still go on, and is asked again when they first generate a recipe.
    var consentStep: some View {
        page {
            stepHeader(
                icon: "hand.raised",
                title: "Onboarding.Consent.Title",
                description: "Onboarding.Consent.Description"
            )

            VStack(alignment: .leading, spacing: 24) {
                featureRow(
                    icon: "text.page",
                    title: "Onboarding.Consent.Gemma",
                    description: "Onboarding.Consent.Gemma.Description"
                )
                featureRow(
                    icon: "dice",
                    title: "Onboarding.Consent.Jev",
                    description: "Onboarding.Consent.Jev.Description"
                )
                featureRow(
                    icon: "lock.shield",
                    title: "Onboarding.Consent.Private",
                    description: "Onboarding.Consent.Private.Description"
                )
            }

            Text("Onboarding.Consent.Footer")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } buttons: {
            primaryButton("Onboarding.Consent.Allow") {
                PlatesCloud.shared.isAllowed = true
                advance()
            }
            secondaryButton("Onboarding.Consent.Deny") { advance() }
        }
    }
}
