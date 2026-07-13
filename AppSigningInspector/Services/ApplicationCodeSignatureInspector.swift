import Foundation

struct ApplicationCodeSignatureInspector: CodeSignatureInspecting {
    static let codesignURL = URL(fileURLWithPath: "/usr/bin/codesign")

    private let processRunner: ProcessRunning
    private let outputParser: CodeSignatureOutputParsing

    init(
        processRunner: ProcessRunning = FoundationProcessRunner(),
        outputParser: CodeSignatureOutputParsing = CodeSignatureOutputParser()
    ) {
        self.processRunner = processRunner
        self.outputParser = outputParser
    }

    func inspect(applicationAt applicationURL: URL) async throws -> CodeSignatureInfo {
        guard FileManager.default.fileExists(atPath: applicationURL.path) else {
            throw CodeSignatureInspectionError.applicationUnavailable(applicationURL)
        }

        let displayArguments = ["--display", "--verbose=4", applicationURL.path]
        let displayResult = try await run(arguments: displayArguments)
        let displayInfo = try outputParser.parse(
            displayResult: displayResult,
            verificationResult: nil
        )

        guard displayInfo.signatureStatus == .valid else {
            return displayInfo
        }

        guard FileManager.default.fileExists(atPath: applicationURL.path) else {
            throw CodeSignatureInspectionError.applicationUnavailable(applicationURL)
        }

        let verificationArguments = ["--verify", "--verbose=4", applicationURL.path]
        let verificationResult = try await run(arguments: verificationArguments)
        return try outputParser.parse(
            displayResult: displayResult,
            verificationResult: verificationResult
        )
    }

    private func run(arguments: [String]) async throws -> ProcessResult {
        do {
            return try await processRunner.run(
                executableURL: Self.codesignURL,
                arguments: arguments
            )
        } catch let error as ProcessExecutionError {
            throw CodeSignatureInspectionError.processExecution(error)
        } catch {
            throw CodeSignatureInspectionError.unexpectedProcessFailure(
                executableURL: Self.codesignURL,
                arguments: arguments,
                description: error.localizedDescription
            )
        }
    }
}

enum CodeSignatureInspectionError: Error, Equatable, Sendable {
    case applicationUnavailable(URL)
    case processExecution(ProcessExecutionError)
    case unexpectedProcessFailure(executableURL: URL, arguments: [String], description: String)
    case commandFailed(ProcessResult)
    case emptyOutput([ProcessResult])
    case parsingFailed([ProcessResult])

    var userMessage: String {
        switch self {
        case .applicationUnavailable:
            return "The selected application is no longer available. Choose an existing .app bundle."
        case .processExecution(.executableUnavailable):
            return "The codesign tool is unavailable. Verify this Mac's system tools and try again."
        case .processExecution(.launchFailed), .unexpectedProcessFailure:
            return "Code-signature inspection could not start. Try again or choose another application."
        case .processExecution(.outputCaptureFailed):
            return "Code-signature output could not be captured. Try again."
        case .commandFailed:
            return "codesign could not inspect this application. Review the diagnostic details."
        case .emptyOutput, .parsingFailed:
            return "The code-signature output could not be interpreted. Review the diagnostic details."
        }
    }

    var diagnosticDetails: String {
        switch self {
        case .applicationUnavailable(let applicationURL):
            return "Application path: \(applicationURL.path)"
        case .processExecution(let error):
            return error.diagnosticText
        case .unexpectedProcessFailure(let executableURL, let arguments, let description):
            let error = ProcessExecutionError.launchFailed(
                executableURL: executableURL,
                arguments: arguments,
                description: description
            )
            return error.diagnosticText
        case .commandFailed(let result):
            return result.diagnosticText
        case .emptyOutput(let results), .parsingFailed(let results):
            return results.map(\.diagnosticText).joined(separator: "\n\n")
        }
    }
}
