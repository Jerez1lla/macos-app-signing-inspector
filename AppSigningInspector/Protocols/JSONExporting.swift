import Foundation

enum JSONExportResult: Equatable {
    case exported(URL)
    case cancelled
}

protocol JSONExporting: Sendable {
    @MainActor
    func export(json: String, suggestedFilename: String) async throws -> JSONExportResult
}

enum JSONExportError: Error, Equatable {
    case invalidEncoding
    case writeFailed(String)

    var userMessage: String {
        switch self {
        case .invalidEncoding:
            return "The declaration JSON could not be encoded for export."
        case .writeFailed:
            return "The declaration JSON could not be saved. Choose another location and try again."
        }
    }
}
