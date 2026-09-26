import CulinaryIntelligence
import SwiftUI

@main
struct PlatesApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        // The recipe model downloads in a background session. When it finishes while the app
        // is not running, the app is woken here, and making the session again is what hands
        // the finished file over.
        .backgroundTask(.urlSession(WriterModelDownload.sessionIdentifier)) {
            await MainActor.run { WriterModelDownload.shared.start() }
        }
    }
}
