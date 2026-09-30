import CulinaryIntelligence
import SwiftUI

/// The sheet that asks for a new recipe and shows it before it is saved. A named dish the
/// kitchen can make is written straight away. Anything else is offered as five ideas first, and
/// the cook picks one or lets Jev pick it. Granite writes the recipe and Apple Intelligence sorts
/// it, so the sheet waits on both.
struct GenerateRecipeView: View {
    @Environment(\.dismiss) private var dismiss

    let store: RecipeStore

    @State private var generator = RecipeGenerator(observer: GenerationActivity.generation)
    @State private var request: GenerationRequest
    @State private var draft: Recipe?
    /// The dishes offered for a request that did not name one the kitchen can make.
    @State private var ideas: [RecipeIdea] = []
    /// The ID a Decide for me pick of these ideas is sent with.
    @State private var requestID = ""
    /// How many Decide for me picks are left today, once the Worker has said.
    @State private var decisionsRemaining: Int?
    @State private var isDeciding = false
    @State private var decideError: String?

    /// Set by a `plates-debug://` link, so a debug run can go from launch to Jev's pick untouched.
    private let startsAtOnce: Bool
    private let decidesAtOnce: Bool

    /// Opens with the dish already written in when the cook named one before the sheet came
    /// up, as they do at the end of onboarding.
    init(store: RecipeStore, dish: String = "", startsAtOnce: Bool = false, decidesAtOnce: Bool = false) {
        self.store = store
        self.startsAtOnce = startsAtOnce
        self.decidesAtOnce = decidesAtOnce
        _request = State(initialValue: GenerationRequest(
            description: dish,
            ingredients: Pantry.ingredients,
            tools: Pantry.tools
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let draft {
                    RecipeDetailView(recipe: draft)
                } else if isGenerating {
                    progress
                } else if isPlanning {
                    planning
                } else if !ideas.isEmpty {
                    ideaList
                } else {
                    form
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                        .disabled(isBusy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let draft {
                        Button("Shared.Save") {
                            store.save(draft, isNew: true)
                            dismiss()
                        }
                    } else if !ideas.isEmpty, !isBusy {
                        Button("Generate.Ideas.Edit") { ideas = [] }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isBusy)
        // A pass can take a while, and the sheet is not touched while it runs, so the screen
        // is held awake rather than locking part way through a recipe.
        .onChange(of: isBusy) { UIApplication.shared.isIdleTimerDisabled = isBusy }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: request.ingredients) { Pantry.ingredients = request.ingredients }
        .onChange(of: request.tools) { Pantry.tools = request.tools }
        .task { if startsAtOnce, canGenerate { await start() } }
    }

    /// A generated recipe titles itself, so its title is shown as written.
    private var title: Text {
        if let draft {
            Text(verbatim: draft.title)
        } else {
            Text("Generate.Title")
        }
    }

    private var form: some View {
        Form {
            Section {
                TextField(
                    "Generate.Description.Label",
                    text: $request.description,
                    prompt: Text("Generate.Description.Prompt"),
                    axis: .vertical
                )
                .lineLimit(2...5)
                .disabled(!generator.isAvailable)
            } footer: {
                Text("Generate.Description.Footer")
            }

            Section {
                Toggle("Generate.IgnorePicks.Label", isOn: $request.ignoresPicks)
                    .disabled(!generator.isAvailable)
            } footer: {
                Text("Generate.IgnorePicks.Footer")
            }

            picks(
                "Generate.Choose.Ingredients",
                assets: shelf(.fresh),
                path: IconCatalog.ingredientPath
            ) {
                CatalogPickerView.ingredients(selection: shelf(.fresh))
            }
            .disabled(request.ignoresPicks)

            picks(
                "Generate.Choose.Pantry",
                assets: shelf(.pantry),
                path: IconCatalog.ingredientPath
            ) {
                CatalogPickerView.pantry(selection: shelf(.pantry))
            }
            .disabled(request.ignoresPicks)

            picks(
                "Generate.Choose.Tools",
                assets: $request.tools,
                path: IconCatalog.toolPath
            ) {
                CatalogPickerView.tools(selection: $request.tools)
            }
            .disabled(request.ignoresPicks)
        }
        .safeAreaInset(edge: .bottom) { generateBar }
    }

    /// The one thing left to do on this screen, so it floats over the form rather than sitting
    /// at the end of it. Whatever is keeping the model from answering is said above the button.
    private var generateBar: some View {
        VStack(spacing: 8) {
            if let reason = generator.unavailableReason {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if case let .failed(message) = generator.state {
                Text(verbatim: message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await start() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.intelligence")
                    Text("Menu.Generate")
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.accentColor)
            .disabled(!canGenerate)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// One shelf of the picks, so each picker shows and edits its own half while the model is
    /// still handed a single list. Writing back keeps the other shelf as it was.
    private func shelf(_ shelf: IngredientShelf) -> Binding<[String]> {
        Binding(
            get: { request.ingredients.filter { IconCatalog.shelf(of: $0) == shelf } },
            set: { picks in
                request.ingredients =
                    request.ingredients.filter { IconCatalog.shelf(of: $0) != shelf } + picks
            }
        )
    }

    /// What the cook has already picked, with the way back into the catalog under it.
    private func picks(
        _ label: LocalizedStringResource,
        assets: Binding<[String]>,
        path: @escaping (String) -> String,
        @ViewBuilder picker: @escaping () -> some View
    ) -> some View {
        Section {
            if !assets.wrappedValue.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(assets.wrappedValue, id: \.self) { asset in
                            Button {
                                assets.wrappedValue.removeAll { $0 == asset }
                            } label: {
                                VStack(spacing: 2) {
                                    RecipeIcon(path: path(asset), size: 30)
                                    Text(verbatim: IconCatalog.displayName(for: asset))
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                }
                                .frame(width: 66)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .listRowInsets(EdgeInsets())
            }

            NavigationLink {
                picker()
            } label: {
                Text(label)
            }
        }
    }

    /// While the model works, the form goes away and the passes have the screen to themselves.
    /// The recipe grows under them, so it scrolls rather than running off the bottom.
    private var progress: some View {
        ScrollView {
            GenerationProgressView(progress: generator.progress)
                .padding(.listRowInset)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var isGenerating: Bool { generator.state == .generating }

    private var isPlanning: Bool { generator.state == .planning }

    private var isBusy: Bool { isGenerating || isPlanning || isDeciding }

    private var canGenerate: Bool {
        generator.isAvailable && !isBusy && !request.isEmpty
    }

    // MARK: - Ideas

    /// Writes the request as asked, or brings up the ideas for it.
    private func start() async {
        decideError = nil
        guard let plan = await generator.plan(request) else { return }
        switch plan {
        case .write:
            draft = await generator.generate(request)
        case let .ideas(offered, id):
            ideas = offered
            requestID = id
            decisionsRemaining = await generator.decisionsRemaining()
            if decidesAtOnce { decide() }
        }
    }

    private func write(_ idea: RecipeIdea) {
        decideError = nil
        Task { draft = await generator.generate(request, idea: idea) }
    }

    /// Jev picks for the cook. A pick that fails leaves the list as it was, and the cook can
    /// still pick one themselves.
    private func decide() {
        decideError = nil
        isDeciding = true
        Task {
            defer { isDeciding = false }
            do {
                let pick = try await generator.decide(request, ideas: ideas, requestID: requestID)
                decisionsRemaining = pick.remaining
                guard ideas.indices.contains(pick.index) else { return }
                write(ideas[pick.index])
            } catch CloudError.limitReached {
                decisionsRemaining = 0
            } catch {
                decideError = error.localizedDescription
            }
        }
    }

    private var planning: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Generate.Planning")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var ideaList: some View {
        List {
            Section {
                ForEach(ideas) { idea in
                    Button {
                        write(idea)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: idea.title)
                                .font(.headline)
                            if !idea.summary.isEmpty {
                                Text(verbatim: idea.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .tint(.primary)
                    .disabled(isBusy)
                }
            } header: {
                Text("Generate.Ideas.Header")
            } footer: {
                Text("Generate.Ideas.Footer")
            }
        }
        .safeAreaInset(edge: .bottom) { decideBar }
    }

    /// Decide for me, with what is left of today's picks. The line above it says where the
    /// request goes, or why the button is out for the day.
    private var decideBar: some View {
        VStack(spacing: 8) {
            if let message = decideError ?? failedMessage {
                Text(verbatim: message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if decisionsRemaining == 0 {
                Text("Generate.Ideas.Decide.LimitReached")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Generate.Ideas.Decide.Privacy")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                decide()
            } label: {
                HStack(spacing: 8) {
                    if isDeciding {
                        ProgressView()
                    } else {
                        Image(systemName: "dice")
                    }
                    Text("Generate.Ideas.Decide")
                    if let decisionsRemaining, decisionsRemaining > 0 {
                        Text(verbatim: String(
                            format: String(localized: "Generate.Ideas.Decide.Remaining"),
                            decisionsRemaining
                        ))
                        .fontWeight(.regular)
                    }
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.accentColor)
            .disabled(isBusy || decisionsRemaining == 0)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var failedMessage: String? {
        if case let .failed(message) = generator.state { message } else { nil }
    }
}

/// The recipe filling in, stage by stage, while the model writes it. The checklist is on top
/// and the recipe reads under it, so the cook watches the work and the writing in one place.
private struct GenerationProgressView: View {
    let progress: GenerationProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                row("Generate.Progress.Row.Write", count: 0, stage: .write)
                row("Generate.Progress.Row.Ingredients", count: progress.ingredientCount, stage: .shopping)
                row("Generate.Progress.Row.Tools", count: progress.toolCount, stage: .shopping)
                row("Generate.Progress.Row.Steps", count: progress.stepCount, stage: .method)
                row(
                    "Generate.Progress.Row.Troubleshooting",
                    count: progress.troubleshootingCount,
                    stage: .method
                )
            }

            preview
        }
        .animation(.default, value: progress)
    }

    /// The recipe as it stands, under the checklist. While Granite writes, that is its text as
    /// it comes; once Apple Intelligence starts sorting it, it is the recipe the sorting has made.
    @ViewBuilder private var preview: some View {
        if progress.stage == .write {
            if !progress.draft.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    Text(verbatim: progress.draft)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } else if let heading = progress.title, !heading.isEmpty {
            RecipePreview(
                title: heading,
                time: progress.time ?? "",
                serves: progress.serves ?? "",
                steps: progress.outline
            )
        }
    }

    /// Where a line has got to: spinning while its pass is the one running, ticked once that
    /// pass is behind it.
    private func marker(for stage: GenerationProgress.Stage) -> ProgressMarkerState {
        if progress.isFinished { return .done }
        if progress.stage == stage { return .working }
        return progress.stage.rawValue > stage.rawValue ? .done : .waiting
    }

    /// One line of the checklist, spinning while its pass is the one running.
    private func row(
        _ label: LocalizedStringResource,
        count: Int,
        stage: GenerationProgress.Stage
    ) -> some View {
        HStack(spacing: 8) {
            ProgressMarker(state: marker(for: stage))
            Text(label)
            Spacer(minLength: 0)
            if count > 0 {
                Text(count, format: .number)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
    }
}
