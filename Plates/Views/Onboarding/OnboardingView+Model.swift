import CulinaryIntelligence
import SwiftUI

extension OnboardingView {
    var modelStep: some View {
        page {
            stepHeader(
                icon: "cpu",
                title: "Onboarding.Model.Title",
                description: "Onboarding.Model.Description"
            )

            VStack(spacing: 12) {
                ForEach(ModelProvider.allCases) { provider in
                    providerRow(provider)
                }
            }

            if settings.provider == .apple, let reason = ModelCheck.appleUnavailableReason {
                Label {
                    Text(reason)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if settings.provider.isRemote {
                remoteSettings(for: settings.provider)
            }
        } buttons: {
            primaryButton("Onboarding.Continue") { advance() }
                .disabled(!canLeaveModelStep)
        }
        .animation(.smooth.speed(2), value: settings.provider)
    }

    /// The picked provider has what it needs to be asked: a key for a remote one, and Apple
    /// Intelligence turned on for Apple's.
    private var canLeaveModelStep: Bool {
        switch settings.provider {
        case .granite:
            true
        case .apple:
            ModelCheck.appleUnavailableReason == nil
        case .claude, .openAI:
            !settings.apiKey(for: settings.provider).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func providerRow(_ provider: ModelProvider) -> some View {
        let isSelected = settings.provider == provider
        return Button {
            settings.provider = provider
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: provider.symbol)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 36, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.title)
                        .font(.body.weight(.semibold))
                    Text(provider.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .multilineTextAlignment(.leading)
            .padding()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The key and the two models for a remote provider, and where what the cook writes is sent.
    private func remoteSettings(for provider: ModelProvider) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                SecureField(
                    "Onboarding.Model.APIKey.Prompt",
                    text: Binding(
                        get: { settings.apiKey(for: provider) },
                        set: { settings.setAPIKey($0, for: provider) }
                    )
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal)
                .padding(.vertical, 12)

                Divider()
                    .padding(.leading)

                modelPicker("Onboarding.Model.Generation", role: .generation, of: provider)

                Divider()
                    .padding(.leading)

                modelPicker("Onboarding.Model.Verification", role: .verification, of: provider)
            }
            .background(.regularMaterial, in: .rect(cornerRadius: 20))

            Text("Onboarding.Model.Roles")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let company = provider.company {
                Text(verbatim: String(format: String(localized: "Onboarding.Model.Privacy"), company))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func modelPicker(_ title: LocalizedStringKey, role: ModelRole, of provider: ModelProvider) -> some View {
        HStack {
            Text(title)
            Spacer()
            Picker(
                title,
                selection: Binding(
                    get: { settings.model(for: role, of: provider) ?? provider.models[0] },
                    set: { settings.setModel($0, for: role) }
                )
            ) {
                ForEach(provider.models) { model in
                    Text(verbatim: model.name).tag(model)
                }
            }
            .labelsHidden()
        }
        .padding(.leading)
        .padding(.vertical, 6)
    }
}

extension ModelProvider {
    var title: LocalizedStringResource {
        switch self {
        case .granite: "Onboarding.Model.Granite"
        case .apple: "Onboarding.Model.Apple"
        case .claude: "Onboarding.Model.Claude"
        case .openAI: "Onboarding.Model.OpenAI"
        }
    }

    var summary: LocalizedStringResource {
        switch self {
        case .granite: "Onboarding.Model.Granite.Description"
        case .apple: "Onboarding.Model.Apple.Description"
        case .claude: "Onboarding.Model.Claude.Description"
        case .openAI: "Onboarding.Model.OpenAI.Description"
        }
    }

    var symbol: String {
        switch self {
        case .granite: "iphone.gen3"
        case .apple: "apple.intelligence"
        case .claude: "asterisk"
        case .openAI: "circle.hexagongrid"
        }
    }
}
