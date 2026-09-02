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
                } else {
                    form
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Shared.Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let draft {
                        Button("Shared.Save") {
                            store.save(draft, isNew: true)
                            dismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(generator.state == .generating)
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
                    "Generate.Idea.Label",
                    text: $idea,
                    prompt: Text("Generate.Idea.Prompt"),
                    axis: .vertical
                )
                .lineLimit(2...5)
                .disabled(!generator.isAvailable)
            } header: {
                Text("Generate.Idea.Header")
            } footer: {
                Text("Generate.Idea.Footer")
            }

            Section {
                Button {
                    Task { draft = await generator.generate(from: idea) }
                } label: {
                    HStack {
                        Label("Menu.Generate", systemImage: "apple.intelligence")
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
                    Text(verbatim: message)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
