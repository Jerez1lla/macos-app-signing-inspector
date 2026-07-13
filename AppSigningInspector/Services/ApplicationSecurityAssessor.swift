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
        executablePath: String?
    ) async -> ApplicationSecurityAssessment {
        async let gatekeeper = gatekeeperAssessor.assess(applicationAt: applicationURL)
        async let architecture = architectureInspector.inspect(
            applicationAt: applicationURL,
            executablePath: executablePath
        )

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

struct ApplicationArchitectureInspector: ArchitectureInspecting {
    static let lipoURL = URL(fileURLWithPath: "/usr/bin/lipo")

    private let processRunner: ProcessRunning
    private let parser: ArchitectureAssessmentParsing

    init(
        processRunner: ProcessRunning = FoundationProcessRunner(),
        parser: ArchitectureAssessmentParsing = ArchitectureAssessmentParser()
    ) {
        self.processRunner = processRunner
        self.parser = parser
    }

    func inspect(
        applicationAt applicationURL: URL,
        executablePath: String?
    ) async -> ArchitectureAssessment {
        guard FileManager.default.fileExists(atPath: applicationURL.path) else {
            return unavailableAssessment(
                status: .applicationUnavailable,
                details: "Application path: \(applicationURL.path)"
            )
        }
        guard let executablePath, !executablePath.isEmpty else {
            return unavailableAssessment(status: .executablePathUnavailable, details: nil)
        }
        guard FileManager.default.fileExists(atPath: executablePath) else {
            return unavailableAssessment(
                status: .executableMissing,
                details: "Executable path: \(executablePath)"
            )
        }

        let arguments = ["-archs", executablePath]
        do {
            let result = try await processRunner.run(executableURL: Self.lipoURL, arguments: arguments)
            return parser.parse(result)
        } catch {
            return unavailableAssessment(
                status: architectureFailureStatus(for: error),
                details: diagnosticText(for: error, arguments: arguments)
            )
        }
    }

    private func unavailableAssessment(
        status: ArchitectureInspectionStatus,
        details: String?
    ) -> ArchitectureAssessment {
        ArchitectureAssessment(
            status: status,
            architectures: [],
            classification: .unknown,
            rawDiagnostics: details
        )
    }

    private func diagnosticText(for error: Error, arguments: [String]) -> String {
        if let processError = error as? ProcessExecutionError {
            return processError.diagnosticText
        }
        return ProcessExecutionError.launchFailed(
            executableURL: Self.lipoURL,
            arguments: arguments,
            description: error.localizedDescription
        ).diagnosticText
    }

    private func architectureFailureStatus(for error: Error) -> ArchitectureInspectionStatus {
        if let processError = error as? ProcessExecutionError,
           case .executableUnavailable = processError {
            return .toolUnavailable
        }
        return .toolFailure
    }
}
