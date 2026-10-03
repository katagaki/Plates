import AudioToolbox
import CulinaryIntelligence
import SwiftUI

/// The recipe as it is cooked: one step to a screen, scrolled through upwards, with a timer that
/// runs on from step to step. The screen is kept awake the whole time, since hands are busy.
struct CookingView: View {
    let recipe: Recipe
    /// Marks the recipe as tried from the last page. Nil when the recipe has nowhere to be saved.
    let markTried: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var timer = CookingTimer()
    @State private var rings = 0
    @State private var isShowingTroubleshooting = false

    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        CookingStepPage(
                            number: index + 1,
                            count: recipe.steps.count,
                            step: step,
                            items: items,
                            startTimer: { timer.start($0) }
                        )
                        .page(insets: insets, background: .step(index))
                    }

                    finished
                        .page(insets: insets, background: .step(recipe.steps.count))
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottom) {
            if timer.isSet {
                CookingTimerBar(timer: timer)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: timer.isSet)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isShowingTroubleshooting) {
            TroubleshootingView(entries: recipe.troubleshooting)
        }
        // Goes off once when a running timer reaches zero, wherever the cook has scrolled to.
        .task(id: timer.endDate) {
            guard let end = timer.endDate else { return }
            try? await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            rings += 1
            AudioServicesPlayAlertSound(SystemSoundID(1005))
        }
        .sensoryFeedback(.warning, trigger: rings)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var topBar: some View {
        HStack {
            Button("Recipe.Cook.Close", systemImage: "xmark") {
                dismiss()
            }

            Spacer()

            if !recipe.troubleshooting.isEmpty {
                Button("Recipe.Detail.Troubleshooting", systemImage: "questionmark") {
                    isShowingTroubleshooting = true
                }
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .padding(.horizontal, 16)
    }

    /// The page after the last step: the dish, and the way back out.
    private var finished: some View {
        VStack(spacing: 28) {
            Spacer()
            DishIcon(recipe: recipe, size: 200)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            Text("Recipe.Cook.Finished")
                .font(.largeTitle.weight(.heavy))
            Text(verbatim: recipe.title)
                .font(.title3.weight(.medium))
                .opacity(0.8)
            Spacer()
            if let markTried, recipe.tried != true {
                Button {
                    markTried()
                    dismiss()
                } label: {
                    Text("Recipe.Cook.MarkTried")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
            Button {
                dismiss()
            } label: {
                Text("Shared.Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    /// Every ingredient and tool the recipe lists, so a step's icon can be named and measured.
    private var items: [TileInfo] {
        RecipeList.allCases.flatMap { recipe.items(in: $0) }
    }
}

private extension View {
    /// Fills one screen of the pager in a colour that runs to the edges, with the content kept
    /// clear of the top buttons, the timer, and the device's own edges.
    func page(insets: EdgeInsets, background: Color) -> some View {
        padding(.horizontal, 24)
            .padding(.top, insets.top + 64)
            .padding(.bottom, insets.bottom + 100)
            .containerRelativeFrame([.horizontal, .vertical])
            .background(background)
    }
}
