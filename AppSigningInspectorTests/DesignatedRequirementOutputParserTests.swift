import XCTest
@testable import AppSigningInspector

final class DesignatedRequirementOutputParserTests: XCTestCase {
    private let parser = DesignatedRequirementOutputParser()

    func testParsesStandardDeveloperIDRequirementWithoutReinterpretation() {
        let requirement = """
        identifier "com.crowdstrike.falcon.Agent" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "X9E956P446"
        """

        let inspection = parser.parse(result(output: "designated => \(requirement)"))

        XCTAssertEqual(inspection.status, .available)
        XCTAssertEqual(inspection.requirement, requirement)
    }

    func testParsesAppleSignedApplicationRequirement() {
        let requirement = "identifier \"com.apple.TextEdit\" and anchor apple"

        let inspection = parser.parse(result(output: "designated => \(requirement)"))

        XCTAssertEqual(inspection.status, .available)
        XCTAssertEqual(inspection.requirement, requirement)
    }

    func testPreservesQuotedValues() {
        let requirement = "identifier \"com.example.app with spaces\" and certificate leaf[subject.CN] = \"Example Application\""

        let inspection = parser.parse(result(output: "designated => \(requirement)"))

        XCTAssertEqual(inspection.requirement, requirement)
    }

    func testPreservesMultilineRequirementContent() {
        let output = """
        designated =>
            identifier "com.example.multiline" and
            anchor apple generic and
            certificate leaf[subject.OU] = "ABCDE12345"
        """
        let expected = """
        identifier "com.example.multiline" and
            anchor apple generic and
            certificate leaf[subject.OU] = "ABCDE12345"
        """

        let inspection = parser.parse(result(output: output))

        XCTAssertEqual(inspection.status, .available)
        XCTAssertEqual(inspection.requirement, expected)
    }

    func testTrimsOnlySurroundingWhitespaceAndLineBreaks() {
        let requirement = "identifier \"com.example.whitespace\"  and  anchor apple generic"
        let output = "  diagnostic header\n  designated =>   \(requirement)  \n\n"

        let inspection = parser.parse(result(output: output))

        XCTAssertEqual(inspection.requirement, requirement)
    }

    func testMissingDesignatedPrefixIsMalformed() {
        let inspection = parser.parse(result(output: "identifier \"com.example.missing-prefix\" and anchor apple"))

        XCTAssertEqual(inspection.status, .malformedOutput)
        XCTAssertNil(inspection.requirement)
    }

    func testEmptyRequirementIsNotPresent() {
        let inspection = parser.parse(result(output: "designated =>    \n"))

        XCTAssertEqual(inspection.status, .notPresent)
        XCTAssertNil(inspection.requirement)
    }

    func testExplicitMissingRequirementIsNotPresent() {
        let inspection = parser.parse(result(output: "code object has no designated requirement"))

        XCTAssertEqual(inspection.status, .notPresent)
        XCTAssertNil(inspection.requirement)
    }

    func testUnsignedApplicationIsDistinguished() {
        let inspection = parser.parse(result(
            output: "/Applications/Unsigned.app: code object is not signed at all",
            terminationStatus: 1
        ))

        XCTAssertEqual(inspection.status, .unsigned)
        XCTAssertNil(inspection.requirement)
    }

    func testNonzeroTerminationIsExecutionFailure() {
        let inspection = parser.parse(result(
            output: "designated => identifier \"com.example.app\" and anchor apple generic",
            terminationStatus: 2
        ))

        XCTAssertEqual(inspection.status, .executionFailed)
        XCTAssertNil(inspection.requirement)
        XCTAssertTrue(inspection.diagnosticDetails?.contains("Termination status: 2") == true)
    }

    func testMalformedOutputPreservesDiagnostics() {
        let inspection = parser.parse(result(output: "unexpected codesign response"))

        XCTAssertEqual(inspection.status, .malformedOutput)
        XCTAssertNil(inspection.requirement)
        XCTAssertTrue(inspection.diagnosticDetails?.contains("unexpected codesign response") == true)
    }

    func testParsesRequirementFromStandardOutputWhenStandardErrorDoesNotContainIt() {
        let requirement = "identifier \"com.example.stdout\" and anchor apple generic"
        let processResult = ProcessResult(
            executableURL: ApplicationCodeSignatureInspector.codesignURL,
            arguments: ["-dr", "-", "/Applications/Example.app"],
            terminationStatus: 0,
            standardOutput: "designated => \(requirement)",
            standardError: ""
        )

        let inspection = parser.parse(processResult)

        XCTAssertEqual(inspection.requirement, requirement)
    }

    private func result(output: String, terminationStatus: Int32 = 0) -> ProcessResult {
        ProcessResult(
            executableURL: ApplicationCodeSignatureInspector.codesignURL,
            arguments: ["-dr", "-", "/Applications/Example.app"],
            terminationStatus: terminationStatus,
            standardOutput: "",
            standardError: output
        )
    }
}
