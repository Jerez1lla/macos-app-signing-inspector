import AppKit
import Foundation
import UniformTypeIdentifiers

struct ApplicationPickerService: ApplicationPicking, PolicyApplicationPicking {
    @MainActor
    func selectApplication() async throws -> ApplicationPickerResult {
        let panel = applicationPanel(
            title: "Select Application",
            prompt: "Select Application",
            message: "Choose a macOS application bundle.",
            allowsMultipleSelection: false
        )

        let response = panel.runModal()
        guard response == .OK, let selectedURL = panel.url else {
            return .cancelled
        }

        return .selected(selectedURL)
    }

    @MainActor
    func selectApplications() async throws -> PolicyApplicationPickerResult {
        let panel = applicationPanel(
            title: "Add Applications",
            prompt: "Add Applications",
            message: "Choose one or more macOS application bundles.",
            allowsMultipleSelection: true
        )

        guard panel.runModal() == .OK, !panel.urls.isEmpty else {
            return .cancelled
        }
        return .selected(panel.urls)
    }

    @MainActor
    private func applicationPanel(
        title: String,
        prompt: String,
        message: String,
        allowsMultipleSelection: Bool
    ) -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = prompt
        panel.message = message
        panel.allowsMultipleSelection = allowsMultipleSelection
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        panel.allowedContentTypes = [.applicationBundle]

        let applicationsURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        if FileManager.default.fileExists(atPath: applicationsURL.path) {
            panel.directoryURL = applicationsURL
        }
        return panel
    }
}

struct WorkspaceApplicationIconLoader: ApplicationIconLoading {
    func icon(for applicationURL: URL) throws -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
        guard icon.isValid else {
            throw ApplicationBrowserError.iconUnavailable(applicationURL)
        }

        return icon
    }
}
