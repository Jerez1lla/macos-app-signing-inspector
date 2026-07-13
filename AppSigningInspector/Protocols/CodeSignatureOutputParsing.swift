import Foundation

protocol CodeSignatureOutputParsing: Sendable {
    func parse(
        displayResult: ProcessResult,
        verificationResult: ProcessResult?
    ) throws -> CodeSignatureInfo
}
