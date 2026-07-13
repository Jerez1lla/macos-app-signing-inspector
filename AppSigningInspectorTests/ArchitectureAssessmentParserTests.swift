import Foundation
import XCTest
@testable import AppSigningInspector

final class ArchitectureAssessmentParserTests: XCTestCase {
    private let parser = ArchitectureAssessmentParser()

    func testArm64IsAppleSiliconOnly() {
        assertArchitectures("arm64", expected: ["arm64"], classification: .appleSiliconOnly)
    }

    func testArm64eIsAppleSiliconOnly() {
        assertArchitectures("arm64e", expected: ["arm64e"], classification: .appleSiliconOnly)
    }

    func testX8664IsIntelOnly() {
        assertArchitectures("x86_64", expected: ["x86_64"], classification: .intelOnly)
    }

    func testArm64AndX8664AreUniversal() {
        assertArchitectures("arm64 x86_64", expected: ["arm64", "x86_64"], classification: .universal)
    }

    func testArm64eAndX8664AreUniversal() {
        assertArchitectures("arm64e x86_64", expected: ["arm64e", "x86_64"], classification: .universal)
    }

    func testDuplicateArchitecturesAreRemovedWithoutReordering() {
        assertArchitectures(
            "arm64 x86_64 arm64",
            expected: ["arm64", "x86_64"],
            classification: .universal
        )
    }

    func testUnknownArchitectureIsPreservedAndClassifiedConservatively() {
        assertArchitectures("ppc64", expected: ["ppc64"], classification: .unknown)
    }

    func testEmptyOutputIsDistinguished() {
        let assessment = parser.parse(result(output: ""))

        XCTAssertEqual(assessment.status, .emptyOutput)
        XCTAssertTrue(assessment.architectures.isEmpty)
    }

    func testMalformedOutputIsDistinguished() {
        let assessment = parser.parse(result(output: "architectures: arm64 and x86_64"))

        XCTAssertEqual(assessment.status, .malformedOutput)
    }

    func testNonMachOOutputIsUnsupportedFormat() {
        let assessment = parser.parse(result(
            output: "fatal error: input file is not a Mach-O file",
            terminationStatus: 1
        ))

        XCTAssertEqual(assessment.status, .unsupportedFormat)
    }

    func testMissingExecutablePathDoesNotRunLipo() async throws {
        let appURL = try makeApplicationBundle()
        let runner = ArchitectureRecordingRunner(result: result(output: "arm64"))
        let inspector = ApplicationArchitectureInspector(processRunner: runner)

        let assessment = await inspector.inspect(applicationAt: appURL, executablePath: nil)
        let invocationCount = await runner.invocationCount

        XCTAssertEqual(assessment.status, .executablePathUnavailable)
        XCTAssertEqual(invocationCount, 0)
    }

    func testProcessFailurePreservesDiagnosticAndExactExecutablePath() async throws {
        let appURL = try makeApplicationBundle()
        let executableURL = appURL.appendingPathComponent("Contents/MacOS/Example")
        try FileManager.default.createDirectory(
            at: executableURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        XCTAssertTrue(FileManager.default.createFile(atPath: executableURL.path, contents: Data()))
        let arguments = ["-archs", executableURL.path]
        let error = ProcessExecutionError.launchFailed(
            executableURL: ApplicationArchitectureInspector.lipoURL,
            arguments: arguments,
            description: "Unable to launch lipo"
        )
        let runner = ArchitectureRecordingRunner(error: error)
        let inspector = ApplicationArchitectureInspector(processRunner: runner)

        let assessment = await inspector.inspect(
            applicationAt: appURL,
            executablePath: executableURL.path
        )

        XCTAssertEqual(assessment.status, .toolFailure)
        XCTAssertTrue(assessment.rawDiagnostics?.contains("Unable to launch lipo") == true)
        let invocation = await runner.invocation
        XCTAssertEqual(invocation?.executableURL, ApplicationArchitectureInspector.lipoURL)
        XCTAssertEqual(invocation?.arguments, arguments)
    }

    func testUnavailableLipoIsDistinguishedFromLaunchFailure() async throws {
        let appURL = try makeApplicationBundle()
        let executableURL = appURL.appendingPathComponent("Contents/MacOS/Example")
        try FileManager.default.createDirectory(
            at: executableURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        XCTAssertTrue(FileManager.default.createFile(atPath: executableURL.path, contents: Data()))
        let arguments = ["-archs", executableURL.path]
        let runner = ArchitectureRecordingRunner(error: .executableUnavailable(
            executableURL: ApplicationArchitectureInspector.lipoURL,
            arguments: arguments
        ))
        let inspector = ApplicationArchitectureInspector(processRunner: runner)

        let assessment = await inspector.inspect(
            applicationAt: appURL,
            executablePath: executableURL.path
        )

        XCTAssertEqual(assessment.status, .toolUnavailable)
    }

    func testMissingExecutableFileDoesNotRunLipo() async throws {
        let appURL = try makeApplicationBundle()
        let executablePath = appURL.appendingPathComponent("Contents/MacOS/Missing").path
        let runner = ArchitectureRecordingRunner(result: result(output: "arm64"))
        let inspector = ApplicationArchitectureInspector(processRunner: runner)

        let assessment = await inspector.inspect(
            applicationAt: appURL,
            executablePath: executablePath
        )
        let invocationCount = await runner.invocationCount

        XCTAssertEqual(assessment.status, .executableMissing)
        XCTAssertEqual(invocationCount, 0)
    }

    private func assertArchitectures(
        _ output: String,
        expected: [String],
        classification: ArchitectureClassification
    ) {
        let assessment = parser.parse(result(output: output))

        XCTAssertEqual(assessment.status, .available)
        XCTAssertEqual(assessment.architectures, expected)
        XCTAssertEqual(assessment.classification, classification)
        XCTAssertEqual(assessment.isUniversalBinary, classification == .universal)
    }

    private func result(output: String, terminationStatus: Int32 = 0) -> ProcessResult {
        ProcessResult(
            executableURL: ApplicationArchitectureInspector.lipoURL,
            arguments: ["-archs", "/Applications/Example.app/Contents/MacOS/Example"],
            terminationStatus: terminationStatus,
            standardOutput: output,
            standardError: ""
        )
    }

    private func makeApplicationBundle() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).app", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private actor ArchitectureRecordingRunner: ProcessRunning {
    private let queuedResult: Result<ProcessResult, ProcessExecutionError>
    private(set) var invocation: ArchitectureProcessInvocation?

    init(result: ProcessResult) {
        queuedResult = .success(result)
    }

    init(error: ProcessExecutionError) {
        queuedResult = .failure(error)
    }

    var invocationCount: Int {
        invocation == nil ? 0 : 1
    }

    func run(executableURL: URL, arguments: [String]) async throws -> ProcessResult {
        invocation = ArchitectureProcessInvocation(executableURL: executableURL, arguments: arguments)
        return try queuedResult.get()
    }
}

private struct ArchitectureProcessInvocation: Equatable, Sendable {
    let executableURL: URL
    let arguments: [String]
}
