import Foundation
import XCTest
@testable import AppSigningInspector

final class GatekeeperAssessmentParserTests: XCTestCase {
    private let parser = GatekeeperAssessmentParser()

    func testAcceptedNotarizedThirdPartyApplication() {
        let assessment = parser.parse(result(
            output: "/Applications/Example.app: accepted\nsource=Notarized Developer ID\norigin=Developer ID Application: Example"
        ))

        XCTAssertEqual(assessment.status, .accepted)
        XCTAssertEqual(assessment.source, "Notarized Developer ID")
        XCTAssertEqual(assessment.notarizationStatus, .notarized)
    }

    func testAcceptedAppleSystemApplication() {
        let assessment = parser.parse(result(
            output: "/System/Applications/TextEdit.app: accepted\nsource=Apple System"
        ))

        XCTAssertEqual(assessment.status, .accepted)
        XCTAssertEqual(assessment.notarizationStatus, .applePlatform)
    }

    func testAcceptedSignedApplicationDoesNotClaimNotarization() {
        let assessment = parser.parse(result(
            output: "/Applications/Example.app: accepted\nsource=Developer ID"
        ))

        XCTAssertEqual(assessment.status, .accepted)
        XCTAssertEqual(assessment.notarizationStatus, .signedNotConfirmed)
    }

    func testRejectedApplicationPreservesReasonAndSource() {
        let reason = "/Applications/Rejected.app: rejected (the code is invalid)"
        let assessment = parser.parse(result(
            output: "\(reason)\nsource=Unnotarized Developer ID",
            terminationStatus: 3
        ))

        XCTAssertEqual(assessment.status, .rejected)
        XCTAssertEqual(assessment.source, "Unnotarized Developer ID")
        XCTAssertEqual(assessment.rejectionReason, reason)
        XCTAssertEqual(assessment.notarizationStatus, .rejected)
    }

    func testAssessmentUnavailableIsNotReportedAsRejection() {
        let assessment = parser.parse(result(
            output: "assessment unavailable",
            terminationStatus: 1
        ))

        XCTAssertEqual(assessment.status, .unavailable)
        XCTAssertEqual(assessment.notarizationStatus, .unknown)
    }

    func testAcceptedOutputWithoutSourceRemainsAccepted() {
        let assessment = parser.parse(result(output: "/Applications/Example.app: accepted"))

        XCTAssertEqual(assessment.status, .accepted)
        XCTAssertNil(assessment.source)
        XCTAssertEqual(assessment.notarizationStatus, .signedNotConfirmed)
    }

    func testMalformedOutputIsUnavailable() {
        let assessment = parser.parse(result(output: "unexpected assessment response"))

        XCTAssertEqual(assessment.status, .unavailable)
    }

    func testEmptyOutputIsUnavailable() {
        let assessment = parser.parse(result(output: ""))

        XCTAssertEqual(assessment.status, .unavailable)
        XCTAssertTrue(assessment.rawDiagnostics?.contains("Termination status: 0") == true)
    }

    func testNonzeroTerminationWithRejectedOutputIsValidAssessment() {
        let assessment = parser.parse(result(
            output: "/Applications/Example.app: rejected",
            terminationStatus: 1
        ))

        XCTAssertEqual(assessment.status, .rejected)
    }

    func testProcessLaunchFailureBecomesToolFailure() async throws {
        let appURL = try makeApplicationBundle()
        let arguments = ["--assess", "--type", "execute", "--verbose=4", appURL.path]
        let runner = GatekeeperFailureRunner(error: .launchFailed(
            executableURL: ApplicationGatekeeperAssessor.spctlURL,
            arguments: arguments,
            description: "Launch failed"
        ))
        let assessor = ApplicationGatekeeperAssessor(processRunner: runner)

        let assessment = await assessor.assess(applicationAt: appURL)

        XCTAssertEqual(assessment.status, .toolFailure)
        XCTAssertTrue(assessment.rawDiagnostics?.contains("Launch failed") == true)
        let invocation = await runner.invocation
        XCTAssertEqual(invocation?.executableURL, ApplicationGatekeeperAssessor.spctlURL)
        XCTAssertEqual(invocation?.arguments, arguments)
    }

    func testUnavailableSpctlIsDistinguishedFromLaunchFailure() async throws {
        let appURL = try makeApplicationBundle()
        let arguments = ["--assess", "--type", "execute", "--verbose=4", appURL.path]
        let runner = GatekeeperFailureRunner(error: .executableUnavailable(
            executableURL: ApplicationGatekeeperAssessor.spctlURL,
            arguments: arguments
        ))
        let assessor = ApplicationGatekeeperAssessor(processRunner: runner)

        let assessment = await assessor.assess(applicationAt: appURL)

        XCTAssertEqual(assessment.status, .toolUnavailable)
    }

    func testRemovedApplicationDoesNotRunSpctl() async {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).app", isDirectory: true)
        let runner = GatekeeperFailureRunner(error: .executableUnavailable(
            executableURL: ApplicationGatekeeperAssessor.spctlURL,
            arguments: []
        ))
        let assessor = ApplicationGatekeeperAssessor(processRunner: runner)

        let assessment = await assessor.assess(applicationAt: missingURL)
        let invocation = await runner.invocation

        XCTAssertEqual(assessment.status, .applicationUnavailable)
        XCTAssertNil(invocation)
    }

    private func result(output: String, terminationStatus: Int32 = 0) -> ProcessResult {
        ProcessResult(
            executableURL: ApplicationGatekeeperAssessor.spctlURL,
            arguments: ["--assess", "--type", "execute", "--verbose=4", "/Applications/Example.app"],
            terminationStatus: terminationStatus,
            standardOutput: "",
            standardError: output
        )
    }

    private func makeApplicationBundle() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).app", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private actor GatekeeperFailureRunner: ProcessRunning {
    let error: ProcessExecutionError
    private(set) var invocation: SecurityProcessInvocation?

    init(error: ProcessExecutionError) {
        self.error = error
    }

    func run(executableURL: URL, arguments: [String]) async throws -> ProcessResult {
        invocation = SecurityProcessInvocation(executableURL: executableURL, arguments: arguments)
        throw error
    }
}

private struct SecurityProcessInvocation: Equatable, Sendable {
    let executableURL: URL
    let arguments: [String]
}
