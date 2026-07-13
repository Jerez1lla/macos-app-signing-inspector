import AppKit
import Foundation
import XCTest
@testable import AppSigningInspector

final class ApplicationSecurityViewModelTests: XCTestCase {
    @MainActor
    func testSecurityInspectionStartsAfterCodeSignatureInspection() async throws {
        let appURL = try makeApplicationBundle(named: "Ordered")
        let recorder = SecurityInspectionOrderRecorder()
        let viewModel = makeViewModel(
            pickerResults: [.selected(appURL)],
            metadataResults: [metadata(for: appURL, displayName: "Ordered")],
            signatureInspector: SecurityTestSignatureInspector(recorder: recorder),
            securityAssessor: QueueSecurityAssessor(results: [successfulAssessment()], recorder: recorder)
        )

        await viewModel.selectApplication()
        let events = await recorder.recordedEvents()

        XCTAssertEqual(events, ["signature", "security"])
    }

    @MainActor
    func testSecurityLoadingStateTransitionsAroundAssessment() async throws {
        let appURL = try makeApplicationBundle(named: "Loading")
        let assessor = ControlledSecurityAssessor()
        let viewModel = makeViewModel(
            pickerResults: [.selected(appURL)],
            metadataResults: [metadata(for: appURL, displayName: "Loading")],
            securityAssessor: assessor
        )

        let selectionTask = Task { await viewModel.selectApplication() }
        await assessor.waitUntilStarted()

        XCTAssertTrue(viewModel.isValidatingSecurity)
        XCTAssertNil(viewModel.securityAssessment)

        await assessor.complete(with: successfulAssessment())
        await selectionTask.value

        XCTAssertFalse(viewModel.isValidatingSecurity)
        XCTAssertNotNil(viewModel.securityAssessment)
    }

    @MainActor
    func testGatekeeperSuccessIsStored() async throws {
        let appURL = try makeApplicationBundle(named: "Gatekeeper")
        let expected = successfulAssessment()
        let viewModel = makeViewModel(
            pickerResults: [.selected(appURL)],
            metadataResults: [metadata(for: appURL, displayName: "Gatekeeper")],
            securityAssessor: QueueSecurityAssessor(results: [expected])
        )

        await viewModel.selectApplication()

        XCTAssertEqual(viewModel.securityAssessment?.gatekeeper, expected.gatekeeper)
        XCTAssertNil(viewModel.securityErrorMessage)
    }

    @MainActor
    func testArchitectureSuccessIsStored() async throws {
        let appURL = try makeApplicationBundle(named: "Architecture")
        let expected = successfulAssessment()
        let viewModel = makeViewModel(
            pickerResults: [.selected(appURL)],
            metadataResults: [metadata(for: appURL, displayName: "Architecture")],
            securityAssessor: QueueSecurityAssessor(results: [expected])
        )

        await viewModel.selectApplication()

        XCTAssertEqual(viewModel.securityAssessment?.architecture, expected.architecture)
        XCTAssertEqual(viewModel.securityAssessment?.validationStatus, .accepted)
    }

    @MainActor
    func testPartialFailurePreservesSuccessfulGatekeeperResult() async throws {
        let appURL = try makeApplicationBundle(named: "Partial")
        let assessment = ApplicationSecurityAssessment(
            gatekeeper: acceptedGatekeeper(),
            architecture: unavailableArchitecture(status: .toolFailure)
        )
        let viewModel = makeViewModel(
            pickerResults: [.selected(appURL)],
            metadataResults: [metadata(for: appURL, displayName: "Partial")],
            securityAssessor: QueueSecurityAssessor(results: [assessment])
        )

        await viewModel.selectApplication()

        XCTAssertEqual(viewModel.securityAssessment?.gatekeeper.status, .accepted)
        XCTAssertEqual(viewModel.securityAssessment?.architecture.status, .toolFailure)
        XCTAssertEqual(viewModel.securityAssessment?.validationStatus, .partial)
        XCTAssertNil(viewModel.securityErrorMessage)
    }

    @MainActor
    func testGatekeeperFailurePreservesSuccessfulArchitectureResult() async throws {
        let appURL = try makeApplicationBundle(named: "ArchitecturePartial")
        let assessment = ApplicationSecurityAssessment(
            gatekeeper: GatekeeperAssessment(
                status: .toolFailure,
                source: nil,
                rejectionReason: nil,
                notarizationStatus: .unknown,
                rawDiagnostics: "spctl failed"
            ),
            architecture: availableArchitecture()
        )
        let viewModel = makeViewModel(
            pickerResults: [.selected(appURL)],
            metadataResults: [metadata(for: appURL, displayName: "ArchitecturePartial")],
            securityAssessor: QueueSecurityAssessor(results: [assessment])
        )

        await viewModel.selectApplication()

        XCTAssertEqual(viewModel.securityAssessment?.gatekeeper.status, .toolFailure)
        XCTAssertEqual(viewModel.securityAssessment?.architecture.status, .available)
        XCTAssertEqual(viewModel.securityAssessment?.validationStatus, .partial)
    }

    @MainActor
    func testTotalFailurePreservesMetadataAndSignatureData() async throws {
        let appURL = try makeApplicationBundle(named: "TotalFailure")
        let assessment = unavailableAssessment()
        let viewModel = makeViewModel(
            pickerResults: [.selected(appURL)],
            metadataResults: [metadata(for: appURL, displayName: "TotalFailure")],
            securityAssessor: QueueSecurityAssessor(results: [assessment])
        )

        await viewModel.selectApplication()

        XCTAssertEqual(viewModel.selectedApplication?.name, "TotalFailure")
        XCTAssertEqual(viewModel.codeSignatureInfo?.signingIdentifier, "com.example.signed")
        XCTAssertEqual(viewModel.securityAssessment, assessment)
        XCTAssertNotNil(viewModel.securityErrorMessage)
    }

    @MainActor
    func testSelectingSecondApplicationReplacesSecurityState() async throws {
        let firstURL = try makeApplicationBundle(named: "First")
        let secondURL = try makeApplicationBundle(named: "Second")
        let first = unavailableAssessment()
        let second = successfulAssessment(architectures: ["x86_64"], classification: .intelOnly)
        let viewModel = makeViewModel(
            pickerResults: [.selected(firstURL), .selected(secondURL)],
            metadataResults: [
                metadata(for: firstURL, displayName: "First"),
                metadata(for: secondURL, displayName: "Second")
            ],
            securityAssessor: QueueSecurityAssessor(results: [first, second])
        )

        await viewModel.selectApplication()
        await viewModel.selectApplication()

        XCTAssertEqual(viewModel.selectedApplication?.url, secondURL)
        XCTAssertEqual(viewModel.securityAssessment, second)
        XCTAssertEqual(viewModel.securityAssessment?.architecture.classification, .intelOnly)
    }

    @MainActor
    func testPriorSecurityErrorClearsAfterLaterSuccess() async throws {
        let firstURL = try makeApplicationBundle(named: "Failure")
        let secondURL = try makeApplicationBundle(named: "Recovery")
        let viewModel = makeViewModel(
            pickerResults: [.selected(firstURL), .selected(secondURL)],
            metadataResults: [
                metadata(for: firstURL, displayName: "Failure"),
                metadata(for: secondURL, displayName: "Recovery")
            ],
            securityAssessor: QueueSecurityAssessor(results: [
                unavailableAssessment(),
                successfulAssessment()
            ])
        )

        await viewModel.selectApplication()
        XCTAssertNotNil(viewModel.securityErrorMessage)

        await viewModel.selectApplication()

        XCTAssertNil(viewModel.securityErrorMessage)
        XCTAssertEqual(viewModel.securityAssessment?.validationStatus, .accepted)
    }

    @MainActor
    func testGatekeeperRejectionIsStoredAsAssessmentInsteadOfFailure() async throws {
        let appURL = try makeApplicationBundle(named: "Rejected")
        let assessment = ApplicationSecurityAssessment(
            gatekeeper: GatekeeperAssessment(
                status: .rejected,
                source: "Unnotarized Developer ID",
                rejectionReason: "Rejected by Gatekeeper",
                notarizationStatus: .rejected,
                rawDiagnostics: "spctl rejection"
            ),
            architecture: availableArchitecture()
        )
        let viewModel = makeViewModel(
            pickerResults: [.selected(appURL)],
            metadataResults: [metadata(for: appURL, displayName: "Rejected")],
            securityAssessor: QueueSecurityAssessor(results: [assessment])
        )

        await viewModel.selectApplication()

        XCTAssertEqual(viewModel.securityAssessment?.gatekeeper.status, .rejected)
        XCTAssertEqual(viewModel.securityAssessment?.validationStatus, .rejected)
        XCTAssertNil(viewModel.securityErrorMessage)
        XCTAssertNotNil(viewModel.selectedApplication)
    }

    @MainActor
    func testSecurityCopyActionsCopyOnlyAvailableValues() async throws {
        let appURL = try makeApplicationBundle(named: "Copy")
        let clipboard = SecurityClipboardWriter()
        let assessment = ApplicationSecurityAssessment(
            gatekeeper: GatekeeperAssessment(
                status: .rejected,
                source: "Unnotarized Developer ID",
                rejectionReason: "Rejected by Gatekeeper",
                notarizationStatus: .rejected,
                rawDiagnostics: "Gatekeeper diagnostics"
            ),
            architecture: ArchitectureAssessment(
                status: .available,
                architectures: ["arm64", "x86_64"],
                classification: .universal,
                rawDiagnostics: "Architecture diagnostics"
            )
        )
        let viewModel = makeViewModel(
            pickerResults: [.selected(appURL)],
            metadataResults: [metadata(for: appURL, displayName: "Copy")],
            securityAssessor: QueueSecurityAssessor(results: [assessment]),
            clipboardWriter: clipboard
        )

        await viewModel.selectApplication()
        viewModel.copyGatekeeperSource()
        viewModel.copyGatekeeperRejectionReason()
        viewModel.copyArchitectureList()
        viewModel.copyRawGatekeeperDiagnostics()
        viewModel.copyRawArchitectureDiagnostics()

        XCTAssertEqual(clipboard.copiedValues, [
            "Unnotarized Developer ID",
            "Rejected by Gatekeeper",
            "arm64, x86_64",
            "Gatekeeper diagnostics",
            "Architecture diagnostics"
        ])
    }

    @MainActor
    private func makeViewModel(
        pickerResults: [ApplicationPickerResult],
        metadataResults: [ApplicationMetadata],
        signatureInspector: CodeSignatureInspecting = SecurityTestSignatureInspector(),
        securityAssessor: SecurityAssessing,
        clipboardWriter: ClipboardWriting = SecurityClipboardWriter()
    ) -> ApplicationBrowserViewModel {
        ApplicationBrowserViewModel(
            picker: SecurityApplicationPicker(results: pickerResults),
            metadataInspector: SecurityMetadataInspector(results: metadataResults),
            codeSignatureInspector: signatureInspector,
            securityAssessor: securityAssessor,
            iconLoader: SecurityIconLoader(),
            clipboardWriter: clipboardWriter
        )
    }

    private func metadata(for appURL: URL, displayName: String) -> ApplicationMetadata {
        ApplicationMetadata(
            applicationURL: appURL,
            displayName: displayName,
            bundleIdentifier: "com.example.\(displayName)",
            shortVersion: "1.0",
            buildNumber: "1",
            bundlePath: appURL.path,
            executableName: displayName,
            executablePath: appURL.appendingPathComponent("Contents/MacOS/\(displayName)").path,
            executableExists: true,
            diagnostics: []
        )
    }

    private func successfulAssessment(
        architectures: [String] = ["arm64", "x86_64"],
        classification: ArchitectureClassification = .universal
    ) -> ApplicationSecurityAssessment {
        ApplicationSecurityAssessment(
            gatekeeper: acceptedGatekeeper(),
            architecture: availableArchitecture(
                architectures: architectures,
                classification: classification
            )
        )
    }

    private func unavailableAssessment() -> ApplicationSecurityAssessment {
        ApplicationSecurityAssessment(
            gatekeeper: GatekeeperAssessment(
                status: .toolFailure,
                source: nil,
                rejectionReason: nil,
                notarizationStatus: .unknown,
                rawDiagnostics: "spctl failed"
            ),
            architecture: unavailableArchitecture(status: .toolFailure)
        )
    }

    private func acceptedGatekeeper() -> GatekeeperAssessment {
        GatekeeperAssessment(
            status: .accepted,
            source: "Notarized Developer ID",
            rejectionReason: nil,
            notarizationStatus: .notarized,
            rawDiagnostics: "spctl accepted"
        )
    }

    private func availableArchitecture(
        architectures: [String] = ["arm64", "x86_64"],
        classification: ArchitectureClassification = .universal
    ) -> ArchitectureAssessment {
        ArchitectureAssessment(
            status: .available,
            architectures: architectures,
            classification: classification,
            rawDiagnostics: "lipo architectures"
        )
    }

    private func unavailableArchitecture(status: ArchitectureInspectionStatus) -> ArchitectureAssessment {
        ArchitectureAssessment(
            status: status,
            architectures: [],
            classification: .unknown,
            rawDiagnostics: "lipo failed"
        )
    }

    private func makeApplicationBundle(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(name).app", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private final class SecurityApplicationPicker: ApplicationPicking {
    private var results: [ApplicationPickerResult]

    init(results: [ApplicationPickerResult]) {
        self.results = results
    }

    @MainActor
    func selectApplication() async throws -> ApplicationPickerResult {
        results.removeFirst()
    }
}

private final class SecurityMetadataInspector: ApplicationMetadataInspecting {
    private var results: [ApplicationMetadata]

    init(results: [ApplicationMetadata]) {
        self.results = results
    }

    func metadata(for applicationURL: URL) throws -> ApplicationMetadata {
        results.removeFirst()
    }
}

private struct SecurityIconLoader: ApplicationIconLoading {
    func icon(for applicationURL: URL) throws -> NSImage {
        NSImage(size: NSSize(width: 32, height: 32))
    }
}

private struct SecurityTestSignatureInspector: CodeSignatureInspecting {
    let recorder: SecurityInspectionOrderRecorder?

    init(recorder: SecurityInspectionOrderRecorder? = nil) {
        self.recorder = recorder
    }

    func inspect(applicationAt applicationURL: URL) async throws -> CodeSignatureInfo {
        await recorder?.record("signature")
        return CodeSignatureInfo(
            signingIdentifier: "com.example.signed",
            teamIdentifier: "ABCDE12345",
            authorities: ["Developer ID Application: Example (ABCDE12345)"],
            format: "app bundle with Mach-O thin (arm64)",
            codeDirectoryVersion: "20500",
            flags: "0x10000(runtime)",
            hardenedRuntimeEnabled: true,
            timestamp: nil,
            signatureStatus: .valid,
            signingOrigin: .thirdParty,
            diagnostics: [],
            processResults: []
        )
    }
}

private actor QueueSecurityAssessor: SecurityAssessing {
    private var results: [ApplicationSecurityAssessment]
    private let recorder: SecurityInspectionOrderRecorder?

    init(
        results: [ApplicationSecurityAssessment],
        recorder: SecurityInspectionOrderRecorder? = nil
    ) {
        self.results = results
        self.recorder = recorder
    }

    func assess(
        applicationAt applicationURL: URL,
        executablePath: String?
    ) async -> ApplicationSecurityAssessment {
        await recorder?.record("security")
        return results.removeFirst()
    }
}

private actor ControlledSecurityAssessor: SecurityAssessing {
    private var continuation: CheckedContinuation<ApplicationSecurityAssessment, Never>?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var hasStarted = false

    func assess(
        applicationAt applicationURL: URL,
        executablePath: String?
    ) async -> ApplicationSecurityAssessment {
        hasStarted = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilStarted() async {
        if hasStarted {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func complete(with assessment: ApplicationSecurityAssessment) {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(returning: assessment)
    }
}

private actor SecurityInspectionOrderRecorder {
    private var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }

    func recordedEvents() -> [String] {
        events
    }
}

private final class SecurityClipboardWriter: ClipboardWriting {
    private(set) var copiedValues: [String] = []

    func copy(_ value: String) {
        copiedValues.append(value)
    }
}
