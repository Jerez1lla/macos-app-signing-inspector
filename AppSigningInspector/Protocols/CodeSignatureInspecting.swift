import Foundation

protocol CodeSignatureInspecting: Sendable {
    func inspect(applicationAt applicationURL: URL) async throws -> CodeSignatureInfo
}
