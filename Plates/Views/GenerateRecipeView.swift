import SwiftUI

/// The sheet that asks Apple Intelligence for a new recipe and shows it before it is saved.
struct GenerateRecipeView: View {
    @Environment(\.dismiss) private var dismiss

    let store: RecipeStore

    @State private var generator = RecipeGenerator()
    @State private var idea = ""
    @State private var draft: Recipe?

    var body: some View {
        NavigationStack {
            Group {
                if let draft {
                    RecipeDetailView(recipe: draft)
                        .navigationTitle(draft.title)
                } else {
                    form
                }
            }
            .navigationTitle(draft == nil ? "New Recipe" : draft?.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let draft {
                        Button("Save") {
                            store.save(draft, isNew: true)
                            dismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(generator.state == .generating)
    }

    private var form: some View {
        Form {
            Section {
                TextField(
                    "What do you feel like eating?",
                    text: $idea,
                    prompt: Text("Something with kimchi and eggs"),
                    axis: .vertical
                )
                .lineLimit(2...5)
                .disabled(!generator.isAvailable)
            } header: {
                Text("Idea")
            } footer: {
                Text("Leave it empty and Apple Intelligence will pick something.")
            }

            Section {
                Button {
                    Task { draft = await generator.generate(from: idea) }
                } label: {
                    HStack {
                        Label("Generate Recipe", systemImage: "apple.intelligence")
                        Spacer()
                        if generator.state == .generating {
                            ProgressView()
                        }
                    }
                }
                .disabled(!generator.isAvailable || generator.state == .generating)
            } footer: {
                if let reason = generator.unavailableReason {
                    Text(reason)
                } else if case let .failed(message) = generator.state {
                    Text(message)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
