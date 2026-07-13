import AppKit
import Foundation
import UniformTypeIdentifiers

struct JSONExportService: JSONExporting {
    @MainActor
    func export(json: String, suggestedFilename: String) async throws -> JSONExportResult {
        let panel = NSSavePanel()
        panel.title = "Export DDM Declaration"
        panel.prompt = "Export"
        panel.nameFieldStringValue = suggestedFilename
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return .cancelled
        }
        guard let data = json.data(using: .utf8) else {
            throw JSONExportError.invalidEncoding
        }

        do {
            try data.write(to: destinationURL, options: .atomic)
            return .exported(destinationURL)
        } catch {
            throw JSONExportError.writeFailed(error.localizedDescription)
        }
    }
}
