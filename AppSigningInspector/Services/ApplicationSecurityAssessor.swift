import Foundation

struct ApplicationSecurityAssessor: SecurityAssessing {
    private let gatekeeperAssessor: GatekeeperAssessing
    private let architectureInspector: ArchitectureInspecting

    init(
        gatekeeperAssessor: GatekeeperAssessing = ApplicationGatekeeperAssessor(),
        architectureInspector: ArchitectureInspecting = ApplicationArchitectureInspector()
    ) {
        self.gatekeeperAssessor = gatekeeperAssessor
        self.architectureInspector = architectureInspector
    }

    func assess(
        applicationAt applicationURL: URL,
        executablePath _: String?
    ) async -> ApplicationSecurityAssessment {
        async let gatekeeper = gatekeeperAssessor.assess(applicationAt: applicationURL)
        async let architecture = architectureInspector.inspect(applicationAt: applicationURL)

        return await ApplicationSecurityAssessment(
            gatekeeper: gatekeeper,
            architecture: architecture
        )
    }
}

struct ApplicationGatekeeperAssessor: GatekeeperAssessing {
    static let spctlURL = URL(fileURLWithPath: "/usr/sbin/spctl")

    private let processRunner: ProcessRunning
    private let parser: GatekeeperAssessmentParsing

    init(
        processRunner: ProcessRunning = FoundationProcessRunner(),
        parser: GatekeeperAssessmentParsing = GatekeeperAssessmentParser()
    ) {
        self.processRunner = processRunner
        self.parser = parser
    }

    func assess(applicationAt applicationURL: URL) async -> GatekeeperAssessment {
        guard FileManager.default.fileExists(atPath: applicationURL.path) else {
            return GatekeeperAssessment(
                status: .applicationUnavailable,
                source: nil,
                rejectionReason: nil,
                notarizationStatus: .unknown,
                rawDiagnostics: "Application path: \(applicationURL.path)"
            )
        }

        let arguments = ["--assess", "--type", "execute", "--verbose=4", applicationURL.path]
        do {
            let result = try await processRunner.run(executableURL: Self.spctlURL, arguments: arguments)
            return parser.parse(result)
        } catch {
            return GatekeeperAssessment(
                status: gatekeeperFailureStatus(for: error),
                source: nil,
                rejectionReason: nil,
                notarizationStatus: .unknown,
                rawDiagnostics: diagnosticText(for: error, arguments: arguments)
            )
        }
    }

    private func diagnosticText(for error: Error, arguments: [String]) -> String {
        if let processError = error as? ProcessExecutionError {
            return processError.diagnosticText
        }
        return ProcessExecutionError.launchFailed(
            executableURL: Self.spctlURL,
            arguments: arguments,
            description: error.localizedDescription
        ).diagnosticText
    }

    private func gatekeeperFailureStatus(for error: Error) -> GatekeeperStatus {
        if let processError = error as? ProcessExecutionError,
           case .executableUnavailable = processError {
            return .toolUnavailable
        }
        return .toolFailure
    }
}
