import SwiftUI

@main
struct AppSigningInspectorApp: App {
    @StateObject private var workspace = AppWorkspaceController()

    var body: some Scene {
        WindowGroup {
            ContentView(workspace: workspace)
        }
        .commands {
            AppCommands(workspace: workspace)
        }

        Window("About App Signing Inspector", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}
