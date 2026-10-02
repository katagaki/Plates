import CulinaryIntelligence
import SwiftUI

/// The field in the bottom bar where the cook asks for changes to a recipe in their own words.
struct RecipeRevisionBar: ToolbarContent {
    @Binding var text: String
    /// False while the model is out of reach or already at work.
    let isEnabled: Bool
    let canSend: Bool
    let send: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            TextField("Edit.Ask.Label", text: $text, prompt: Text("Edit.Ask.Prompt"))
                .submitLabel(.send)
                .onSubmit { if canSend { send() } }
                .padding(.horizontal, 12)
                .frame(idealWidth: .greatestFiniteMagnitude, maxWidth: .infinity)
                .disabled(!isEnabled)
        }
        ToolbarItem(placement: .bottomBar) {
            Button(action: send) {
                Label("Edit.Ask.Title", systemImage: "arrow.up")
            }
            .buttonStyle(.glassProminent)
            .disabled(!canSend)
        }
    }
}
