import SwiftUI

@main
struct AppSigningInspectorApp: App {
    @StateObject private var workspace = AppWorkspaceController()

    var body: some Scene {
        WindowGroup {
            ContentView(workspace: workspace)
        }
        .defaultSize(width: 840, height: 640)
        .commands {
            AppCommands(workspace: workspace)
        }

        Window("About App Signing Inspector", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}
