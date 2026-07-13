import SwiftUI

@MainActor
struct AppCommands: Commands {
    @ObservedObject var workspace: AppWorkspaceController
    @ObservedObject private var inspectorViewModel: ApplicationBrowserViewModel
    @ObservedObject private var policyBuilderViewModel: PolicyBuilderViewModel
    @Environment(\.openWindow) private var openWindow

    init(workspace: AppWorkspaceController) {
        self.workspace = workspace
        _inspectorViewModel = ObservedObject(wrappedValue: workspace.inspectorViewModel)
        _policyBuilderViewModel = ObservedObject(wrappedValue: workspace.policyBuilderViewModel)
    }

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About App Signing Inspector") {
                openWindow(id: "about")
            }
        }

        CommandGroup(replacing: .newItem) {
            Button(workspace.primaryActionTitle) {
                Task { await workspace.performPrimaryAction() }
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(!workspace.canPerformPrimaryAction)
        }

        CommandMenu("Workspace") {
            Button("Inspector") {
                workspace.selectWorkspace(.inspector)
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Policy Builder") {
                workspace.selectWorkspace(.policyBuilder)
            }
            .keyboardShortcut("2", modifiers: .command)
        }

        CommandMenu("Policy") {
            Button("Copy Declaration JSON") {
                workspace.copyPolicyJSON()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(!workspace.canCopyPolicyJSON)

            Button("Export Declaration JSON...") {
                Task { await workspace.exportPolicyJSON() }
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(!workspace.canExportPolicyJSON)
        }
    }
}
