import Foundation

struct ProcessResult: Equatable, Sendable {
    let executableURL: URL
    let arguments: [String]
    let terminationStatus: Int32
    let standardOutput: String
    let standardError: String

    var combinedOutput: String {
        [standardError, standardOutput]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    var diagnosticText: String {
        let argumentText = arguments.isEmpty
            ? "  (none)"
            : arguments.map { "  \($0)" }.joined(separator: "\n")
        let outputText = standardOutput.isEmpty ? "(empty)" : standardOutput
        let errorText = standardError.isEmpty ? "(empty)" : standardError

        return """
        Tool: \(executableURL.path)
        Arguments:
        \(argumentText)
        Termination status: \(terminationStatus)
        Standard output:
        \(outputText)
        Standard error:
        \(errorText)
        """
    }
}

enum ProcessExecutionError: Error, Equatable, Sendable {
    case executableUnavailable(executableURL: URL, arguments: [String])
    case launchFailed(executableURL: URL, arguments: [String], description: String)
    case outputCaptureFailed(executableURL: URL, arguments: [String], description: String)

    var diagnosticText: String {
        switch self {
        case .executableUnavailable(let executableURL, let arguments):
            return Self.diagnosticText(
                executableURL: executableURL,
                arguments: arguments,
                description: "The executable is unavailable or cannot be executed."
            )
        case .launchFailed(let executableURL, let arguments, let description),
             .outputCaptureFailed(let executableURL, let arguments, let description):
            return Self.diagnosticText(
                executableURL: executableURL,
                arguments: arguments,
                description: description
            )
        }
    }

    private static func diagnosticText(
        executableURL: URL,
        arguments: [String],
        description: String
    ) -> String {
        let argumentText = arguments.isEmpty
            ? "  (none)"
            : arguments.map { "  \($0)" }.joined(separator: "\n")

        return """
        Tool: \(executableURL.path)
        Arguments:
        \(argumentText)
        Error: \(description)
        """
    }
}
