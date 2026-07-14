import Foundation
import XCTest
@testable import AppSigningInspector

final class NativeArchitectureInspectorTests: XCTestCase {
    func testFoundationConstantsMapToReadableArchitectures() {
        XCTAssertEqual(
            NativeExecutableArchitecture(rawValue: NSBundleExecutableArchitectureARM64),
            .arm64
        )
        XCTAssertEqual(
            NativeExecutableArchitecture(rawValue: NSBundleExecutableArchitectureX86_64),
            .x86_64
        )
    }

    func testArm64IsAppleSiliconOnly() async {
        await assertArchitectures([.arm64], expected: ["arm64"], classification: .appleSiliconOnly)
    }

    func testArm64eIsAppleSiliconOnly() async {
        await assertArchitectures([.arm64e], expected: ["arm64e"], classification: .appleSiliconOnly)
    }

    func testX8664IsIntelOnly() async {
        await assertArchitectures([.x86_64], expected: ["x86_64"], classification: .intelOnly)
    }

    func testArm64AndX8664AreUniversal() async {
        await assertArchitectures(
            [.arm64, .x86_64],
            expected: ["arm64", "x86_64"],
            classification: .universal
        )
    }

    func testArm64eAndX8664AreUniversal() async {
        await assertArchitectures(
            [.arm64e, .x86_64],
            expected: ["arm64e", "x86_64"],
            classification: .universal
        )
    }

    func testDuplicateValuesAreRemovedWithStableOrdering() async {
        await assertArchitectures(
            [.x86_64, .arm64, .x86_64, .arm64],
            expected: ["x86_64", "arm64"],
            classification: .universal
        )
    }

    func testUnknownValueIsPreservedAndClassifiedConservatively() async {
        let assessment = await inspect([.unknown(12345)])

        XCTAssertEqual(assessment.status, .unsupportedArchitecture)
        XCTAssertEqual(assessment.architectures, ["unknown(12345)"])
        XCTAssertEqual(assessment.classification, .unknown)
    }

    func testEmptyArchitectureListIsUnavailable() async {
        let assessment = await inspect([])

        XCTAssertEqual(assessment.status, .informationUnavailable)
        XCTAssertTrue(assessment.architectures.isEmpty)
    }

    func testMissingArchitectureInformationIsUnavailable() async {
        let assessment = await inspect(nil)

        XCTAssertEqual(assessment.status, .informationUnavailable)
        XCTAssertTrue(assessment.architectures.isEmpty)
    }

    func testRemovedApplicationIsReportedWithoutDiscardingDiagnostics() async {
        let inspector = ApplicationArchitectureInspector(
            provider: StubNativeBundleArchitectureProvider(result: .failure(.applicationUnavailable))
        )

        let assessment = await inspector.inspect(applicationAt: applicationURL)

        XCTAssertEqual(assessment.status, .applicationUnavailable)
        XCTAssertTrue(assessment.rawDiagnostics?.contains(applicationURL.path) == true)
    }

    func testUnreadableBundleIsReported() async {
        let inspector = ApplicationArchitectureInspector(
            provider: StubNativeBundleArchitectureProvider(result: .failure(.bundleUnavailable))
        )

        let assessment = await inspector.inspect(applicationAt: applicationURL)

        XCTAssertEqual(assessment.status, .bundleUnavailable)
        XCTAssertEqual(assessment.classification, .unknown)
    }

    func testNativeDiagnosticsContainBundleValuesMappingAndClassification() async {
        let assessment = await inspect([.arm64, .x86_64])
        let details = assessment.rawDiagnostics ?? ""

        XCTAssertTrue(details.contains("Application bundle path:"))
        XCTAssertTrue(details.contains("Resolved executable path:"))
        XCTAssertTrue(details.contains("Native architecture values:"))
        XCTAssertTrue(details.contains("Mapped architecture names: arm64, x86_64"))
        XCTAssertTrue(details.contains("Classification: Universal"))
        XCTAssertFalse(details.lowercased().contains("tool termination"))
    }

    private var applicationURL: URL {
        URL(fileURLWithPath: "/Applications/Example.app", isDirectory: true)
    }

    private func inspect(_ architectures: [NativeExecutableArchitecture]?) async -> ArchitectureAssessment {
        let rawValues = architectures?.enumerated().map { $0.offset + 100 }
        let provider = StubNativeBundleArchitectureProvider(result: .success(
            NativeBundleArchitectureSnapshot(
                executablePath: "/Applications/Example.app/Contents/MacOS/Example",
                rawArchitectureValues: rawValues,
                architectures: architectures
            )
        ))
        return await ApplicationArchitectureInspector(provider: provider)
            .inspect(applicationAt: applicationURL)
    }

    private func assertArchitectures(
        _ architectures: [NativeExecutableArchitecture],
        expected: [String],
        classification: ArchitectureClassification
    ) async {
        let assessment = await inspect(architectures)

        XCTAssertEqual(assessment.status, .available)
        XCTAssertEqual(assessment.architectures, expected)
        XCTAssertEqual(assessment.classification, classification)
        XCTAssertEqual(assessment.isUniversalBinary, classification == .universal)
    }
}

private struct StubNativeBundleArchitectureProvider: NativeBundleArchitectureProviding {
    let result: Result<NativeBundleArchitectureSnapshot, NativeBundleArchitectureError>

    func architectureSnapshot(for applicationURL: URL) throws -> NativeBundleArchitectureSnapshot {
        try result.get()
    }
}
