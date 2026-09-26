import CulinaryIntelligence
import SwiftUI

/// What a new install shows first: what Plates does, the model that writes its recipes, a check
/// that the model is there, and a way into the first recipe. Choosing the model again from the
/// menu opens it at the model step and closes it once the model has answered.
struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome
        case model
        case connect
        case firstRecipe
    }

    /// Where the sheet opened, which is as far back as it goes.
    let start: Step

    /// Called when the cook is done, with the dish they asked for when they asked for one.
    let onComplete: (String?) -> Void

    @State var step: Step
    /// The model picked when the sheet opened, put back when the cook closes it without
    /// finishing.
    @State private var openingProvider = ModelSettings.shared.provider
    @State var settings = ModelSettings.shared
    @State var download = WriterModelDownload.shared
    @State var check = CheckState.idle
    @State var dish = ""
    @FocusState var isDishFocused: Bool

    /// How far the hello to the picked model has got.
    enum CheckState: Equatable {
        case idle
        case checking
        case passed([ModelCheck.Reply])
        case failed(String)
    }

    init(start: Step = .welcome, onComplete: @escaping (String?) -> Void) {
        self.start = start
        self.onComplete = onComplete
        _step = State(initialValue: start)
    }

    /// Opened from the menu to change the model, so there is no first recipe to write.
    var isChangingModel: Bool { start != .welcome }

    var body: some View {
        content
            .overlay(alignment: .topLeading) {
                if step != start {
                    Button {
                        goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2.weight(.semibold))
                            .padding(4)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel(Text("Onboarding.Back"))
                    .padding()
                }
            }
            .overlay(alignment: .topTrailing) {
                if isChangingModel {
                    Button {
                        settings.provider = openingProvider
                        onComplete(nil)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2.weight(.semibold))
                            .padding(4)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel(Text("Shared.Cancel"))
                    .padding()
                }
            }
            .interactiveDismissDisabled()
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcomeStep
        case .model: modelStep
        case .connect: connectStep
        case .firstRecipe: firstRecipeStep
        }
    }

    // MARK: - Navigation

    func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1), step != start else { return }
        withAnimation(.smooth.speed(2)) { step = previous }
    }

    func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        // A model picked again only has to answer, so the sheet closes once it has.
        if next == .firstRecipe, isChangingModel {
            onComplete(nil)
            return
        }
        // Whatever the last check found was for the model picked then.
        if next == .connect {
            check = .idle
        }
        withAnimation(.smooth.speed(2)) { step = next }
    }
}

extension OnboardingView.Step: Identifiable {
    var id: Int { rawValue }
}

#Preview {
    OnboardingView { _ in }
}
