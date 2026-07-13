import XCTest
@testable import AppSigningInspector

final class CodeSignatureOutputParserTests: XCTestCase {
    private let parser = CodeSignatureOutputParser()

    func testParsesSignedThirdPartyApplicationWithMultipleAuthorities() throws {
        let result = fixtureResult(output: CodeSignatureFixtures.thirdPartySigned)

        let info = try parser.parse(displayResult: result)

        XCTAssertEqual(info.signingIdentifier, "com.example.signed")
        XCTAssertEqual(info.teamIdentifier, "ABCDE12345")
        XCTAssertEqual(info.authorities, [
            "Developer ID Application: Example Corporation (ABCDE12345)",
            "Developer ID Certification Authority",
            "Apple Root CA"
        ])
        XCTAssertEqual(info.format, "app bundle with Mach-O thin (arm64)")
        XCTAssertEqual(info.codeDirectoryVersion, "20500")
        XCTAssertEqual(info.flags, "0x10000(runtime)")
        XCTAssertEqual(info.hardenedRuntimeEnabled, true)
        XCTAssertEqual(info.timestamp, "Jul 13, 2026 at 12:34:56 PM")
        XCTAssertEqual(info.signatureStatus, .valid)
        XCTAssertEqual(info.signingOrigin, .thirdParty)
        XCTAssertEqual(info.isAppleSigned, false)
    }

    func testIdentifiesKnownAppleSigningAuthorityWithoutUsingTeamID() throws {
        let result = fixtureResult(output: CodeSignatureFixtures.appleSigned)

        let info = try parser.parse(displayResult: result)

        XCTAssertEqual(info.signingOrigin, .apple)
        XCTAssertEqual(info.isAppleSigned, true)
        XCTAssertNil(info.teamIdentifier)
        XCTAssertTrue(info.diagnostics.contains(.missingTeamIdentifier))
    }

    func testReportsMissingTeamIdentifier() throws {
        let output = CodeSignatureFixtures.thirdPartySigned.replacingOccurrences(
            of: "TeamIdentifier=ABCDE12345",
            with: "TeamIdentifier=not set"
        )

        let info = try parser.parse(displayResult: fixtureResult(output: output))

        XCTAssertNil(info.teamIdentifier)
        XCTAssertTrue(info.diagnostics.contains(.missingTeamIdentifier))
    }

    func testReportsMissingSigningIdentifier() throws {
        let output = CodeSignatureFixtures.thirdPartySigned.replacingOccurrences(
            of: "Identifier=com.example.signed\n",
            with: ""
        )

        let info = try parser.parse(displayResult: fixtureResult(output: output))

        XCTAssertNil(info.signingIdentifier)
        XCTAssertTrue(info.diagnostics.contains(.missingSigningIdentifier))
    }

    func testReportsHardenedRuntimeNotEnabled() throws {
        let output = CodeSignatureFixtures.thirdPartySigned.replacingOccurrences(
            of: "flags=0x10000(runtime)",
            with: "flags=0x0(none)"
        )

        let info = try parser.parse(displayResult: fixtureResult(output: output))

        XCTAssertEqual(info.hardenedRuntimeEnabled, false)
    }

    func testReportsMissingTimestamp() throws {
        let output = CodeSignatureFixtures.thirdPartySigned.replacingOccurrences(
            of: "Timestamp=Jul 13, 2026 at 12:34:56 PM\n",
            with: ""
        )

        let info = try parser.parse(displayResult: fixtureResult(output: output))

        XCTAssertNil(info.timestamp)
        XCTAssertEqual(info.timestampDisplayValue, "Unavailable")
    }

    func testParsesUnsignedApplicationFromNonzeroResult() throws {
        let result = fixtureResult(
            output: CodeSignatureFixtures.unsigned,
            terminationStatus: 1
        )

        let info = try parser.parse(displayResult: result)

        XCTAssertEqual(info.signatureStatus, .unsigned)
        XCTAssertNil(info.signingIdentifier)
        XCTAssertNil(info.teamIdentifier)
        XCTAssertTrue(info.authorities.isEmpty)
        XCTAssertTrue(info.rawDiagnostics.contains("Termination status: 1"))
    }

    func testVerificationFailureProducesInvalidSignatureStatus() throws {
        let displayResult = fixtureResult(output: CodeSignatureFixtures.thirdPartySigned)
        let verificationResult = fixtureResult(
            output: CodeSignatureFixtures.invalid,
            terminationStatus: 1,
            arguments: ["--verify", "--verbose=4", "/Applications/Example.app"]
        )

        let info = try parser.parse(
            displayResult: displayResult,
            verificationResult: verificationResult
        )

        XCTAssertEqual(info.signatureStatus, .invalid)
        XCTAssertEqual(info.processResults.count, 2)
        XCTAssertTrue(info.rawDiagnostics.contains("a sealed resource is missing or invalid"))
    }

    func testInvalidDisplayOutputProducesInvalidSignatureStatus() throws {
        let result = fixtureResult(
            output: CodeSignatureFixtures.invalid,
            terminationStatus: 1
        )

        let info = try parser.parse(displayResult: result)

        XCTAssertEqual(info.signatureStatus, .invalid)
        XCTAssertNil(info.signingIdentifier)
        XCTAssertNil(info.teamIdentifier)
    }

    func testMalformedOutputThrowsParsingFailure() {
        let result = fixtureResult(output: CodeSignatureFixtures.malformed)

        XCTAssertThrowsError(try parser.parse(displayResult: result)) { error in
            XCTAssertEqual(
                error as? CodeSignatureInspectionError,
                .parsingFailed([result])
            )
        }
    }

    func testUnexpectedNonzeroTerminationThrowsCommandFailure() {
        let result = fixtureResult(
            output: "codesign failed unexpectedly",
            terminationStatus: 2
        )

        XCTAssertThrowsError(try parser.parse(displayResult: result)) { error in
            XCTAssertEqual(
                error as? CodeSignatureInspectionError,
                .commandFailed(result)
            )
        }
    }

    func testEmptyOutputThrowsEmptyOutputFailure() {
        let result = fixtureResult(output: "")

        XCTAssertThrowsError(try parser.parse(displayResult: result)) { error in
            XCTAssertEqual(
                error as? CodeSignatureInspectionError,
                .emptyOutput([result])
            )
        }
    }

    func testRawDiagnosticsPreserveInvocationAndBothOutputStreams() throws {
        let result = ProcessResult(
            executableURL: ApplicationCodeSignatureInspector.codesignURL,
            arguments: ["--display", "--verbose=4", "/Applications/Example.app"],
            terminationStatus: 0,
            standardOutput: "stdout diagnostic",
            standardError: CodeSignatureFixtures.thirdPartySigned
        )

        let info = try parser.parse(displayResult: result)

        XCTAssertTrue(info.rawDiagnostics.contains("Tool: /usr/bin/codesign"))
        XCTAssertTrue(info.rawDiagnostics.contains("--display"))
        XCTAssertTrue(info.rawDiagnostics.contains("stdout diagnostic"))
        XCTAssertTrue(info.rawDiagnostics.contains("Identifier=com.example.signed"))
    }

    private func fixtureResult(
        output: String,
        terminationStatus: Int32 = 0,
        arguments: [String] = ["--display", "--verbose=4", "/Applications/Example.app"]
    ) -> ProcessResult {
        ProcessResult(
            executableURL: ApplicationCodeSignatureInspector.codesignURL,
            arguments: arguments,
            terminationStatus: terminationStatus,
            standardOutput: "",
            standardError: output
        )
    }
}

final class ApplicationCodeSignatureInspectorTests: XCTestCase {
    func testInspectorRunsDisplayVerificationAndRequirementWithoutShellOrDeepInspection() async throws {
        let appURL = try makeApplicationBundle(named: "Signed")
        let displayArguments = ["--display", "--verbose=4", appURL.path]
        let verificationArguments = ["--verify", "--verbose=4", appURL.path]
        let requirementArguments = ["-dr", "-", appURL.path]
        let runner = QueueProcessRunner(results: [
            .success(ProcessResult(
                executableURL: ApplicationCodeSignatureInspector.codesignURL,
                arguments: displayArguments,
                terminationStatus: 0,
                standardOutput: "",
                standardError: CodeSignatureFixtures.thirdPartySigned
            )),
            .success(ProcessResult(
                executableURL: ApplicationCodeSignatureInspector.codesignURL,
                arguments: verificationArguments,
                terminationStatus: 0,
                standardOutput: "",
                standardError: "\(appURL.path): valid on disk"
            )),
            .success(ProcessResult(
                executableURL: ApplicationCodeSignatureInspector.codesignURL,
                arguments: requirementArguments,
                terminationStatus: 0,
                standardOutput: "",
                standardError: "designated => \(CodeSignatureFixtures.designatedRequirement)"
            ))
        ])
        let inspector = ApplicationCodeSignatureInspector(processRunner: runner)

        let info = try await inspector.inspect(applicationAt: appURL)
        let invocations = await runner.recordedInvocations()

        XCTAssertEqual(info.signatureStatus, .valid)
        XCTAssertEqual(info.designatedRequirement, CodeSignatureFixtures.designatedRequirement)
        XCTAssertEqual(invocations, [
            ProcessInvocation(
                executableURL: ApplicationCodeSignatureInspector.codesignURL,
                arguments: displayArguments
            ),
            ProcessInvocation(
                executableURL: ApplicationCodeSignatureInspector.codesignURL,
                arguments: verificationArguments
            ),
            ProcessInvocation(
                executableURL: ApplicationCodeSignatureInspector.codesignURL,
                arguments: requirementArguments
            )
        ])
        XCTAssertFalse(invocations.flatMap(\.arguments).contains("--deep"))
    }

    func testInspectorDoesNotVerifyUnsignedApplication() async throws {
        let appURL = try makeApplicationBundle(named: "Unsigned")
        let displayArguments = ["--display", "--verbose=4", appURL.path]
        let runner = QueueProcessRunner(results: [
            .success(ProcessResult(
                executableURL: ApplicationCodeSignatureInspector.codesignURL,
                arguments: displayArguments,
                terminationStatus: 1,
                standardOutput: "",
                standardError: CodeSignatureFixtures.unsigned
            ))
        ])
        let inspector = ApplicationCodeSignatureInspector(processRunner: runner)

        let info = try await inspector.inspect(applicationAt: appURL)
        let invocations = await runner.recordedInvocations()

        XCTAssertEqual(info.signatureStatus, .unsigned)
        XCTAssertEqual(info.designatedRequirementInspection?.status, .unsigned)
        XCTAssertEqual(invocations.count, 1)
        XCTAssertEqual(invocations.first?.arguments, displayArguments)
    }

    func testInspectorPreservesProcessExecutionFailure() async throws {
        let appURL = try makeApplicationBundle(named: "UnavailableTool")
        let arguments = ["--display", "--verbose=4", appURL.path]
        let processError = ProcessExecutionError.executableUnavailable(
            executableURL: ApplicationCodeSignatureInspector.codesignURL,
            arguments: arguments
        )
        let runner = QueueProcessRunner(results: [.failure(processError)])
        let inspector = ApplicationCodeSignatureInspector(processRunner: runner)

        do {
            _ = try await inspector.inspect(applicationAt: appURL)
            XCTFail("Expected process execution failure")
        } catch {
            XCTAssertEqual(
                error as? CodeSignatureInspectionError,
                .processExecution(processError)
            )
        }
    }

    func testRequirementExecutionFailurePreservesCoreSignatureInformation() async throws {
        let appURL = try makeApplicationBundle(named: "RequirementFailure")
        let displayArguments = ["--display", "--verbose=4", appURL.path]
        let verificationArguments = ["--verify", "--verbose=4", appURL.path]
        let requirementArguments = ["-dr", "-", appURL.path]
        let requirementError = ProcessExecutionError.launchFailed(
            executableURL: ApplicationCodeSignatureInspector.codesignURL,
            arguments: requirementArguments,
            description: "Unable to launch requirement inspection"
        )
        let runner = QueueProcessRunner(results: [
            .success(ProcessResult(
                executableURL: ApplicationCodeSignatureInspector.codesignURL,
                arguments: displayArguments,
                terminationStatus: 0,
                standardOutput: "",
                standardError: CodeSignatureFixtures.thirdPartySigned
            )),
            .success(ProcessResult(
                executableURL: ApplicationCodeSignatureInspector.codesignURL,
                arguments: verificationArguments,
                terminationStatus: 0,
                standardOutput: "",
                standardError: "\(appURL.path): valid on disk"
            )),
            .failure(requirementError)
        ])
        let inspector = ApplicationCodeSignatureInspector(processRunner: runner)

        let info = try await inspector.inspect(applicationAt: appURL)

        XCTAssertEqual(info.signingIdentifier, "com.example.signed")
        XCTAssertEqual(info.teamIdentifier, "ABCDE12345")
        XCTAssertEqual(info.signatureStatus, .valid)
        XCTAssertNil(info.designatedRequirement)
        XCTAssertEqual(info.designatedRequirementInspection?.status, .executionFailed)
        XCTAssertTrue(info.rawDiagnostics.contains("Unable to launch requirement inspection"))
    }

    private func makeApplicationBundle(named name: String) throws -> URL {
        let appURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(name).app", isDirectory: true)
        try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)
        return appURL
    }
}

private struct ProcessInvocation: Equatable, Sendable {
    let executableURL: URL
    let arguments: [String]
}

private actor QueueProcessRunner: ProcessRunning {
    private var results: [Result<ProcessResult, ProcessExecutionError>]
    private var invocations: [ProcessInvocation] = []

    init(results: [Result<ProcessResult, ProcessExecutionError>]) {
        self.results = results
    }

    func run(executableURL: URL, arguments: [String]) async throws -> ProcessResult {
        invocations.append(ProcessInvocation(executableURL: executableURL, arguments: arguments))
        return try results.removeFirst().get()
    }

    func recordedInvocations() -> [ProcessInvocation] {
        invocations
    }
}

private enum CodeSignatureFixtures {
    static let thirdPartySigned = """
    Executable=/Applications/Example.app/Contents/MacOS/Example
    Identifier=com.example.signed
    Format=app bundle with Mach-O thin (arm64)
    CodeDirectory v=20500 size=1234 flags=0x10000(runtime) hashes=31+7 location=embedded
    Signature size=9055
    Authority=Developer ID Application: Example Corporation (ABCDE12345)
    Authority=Developer ID Certification Authority
    Authority=Apple Root CA
    Timestamp=Jul 13, 2026 at 12:34:56 PM
    Info.plist entries=24
    TeamIdentifier=ABCDE12345
    Runtime Version=27.0.0
    """

    static let appleSigned = """
    Executable=/System/Applications/Example.app/Contents/MacOS/Example
    Identifier=com.apple.example
    Format=app bundle with Mach-O universal (arm64 x86_64)
    CodeDirectory v=20500 size=2345 flags=0x10000(runtime) hashes=44+7 location=embedded
    Authority=Software Signing
    Authority=Apple Code Signing Certification Authority
    Authority=Apple Root CA
    TeamIdentifier=not set
    """

    static let unsigned = "/Applications/Unsigned.app: code object is not signed at all"
    static let invalid = "/Applications/Example.app: a sealed resource is missing or invalid"
    static let malformed = "Unexpected output with no recognized code-signature fields"
    static let designatedRequirement = "identifier \"com.example.signed\" and anchor apple generic and certificate leaf[subject.OU] = \"ABCDE12345\""
}
