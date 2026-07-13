import AppKit
import Foundation
import UniformTypeIdentifiers

struct ApplicationPickerService: ApplicationPicking {
    @MainActor
    func selectApplication() async throws -> ApplicationPickerResult {
        let panel = NSOpenPanel()
        panel.title = "Select Application"
        panel.prompt = "Select Application"
        panel.message = "Choose a macOS application bundle."
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        panel.allowedContentTypes = [.applicationBundle]

        let applicationsURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        if FileManager.default.fileExists(atPath: applicationsURL.path) {
            panel.directoryURL = applicationsURL
        }

        let response = panel.runModal()
        guard response == .OK, let selectedURL = panel.url else {
            return .cancelled
        }

        return .selected(selectedURL)
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
