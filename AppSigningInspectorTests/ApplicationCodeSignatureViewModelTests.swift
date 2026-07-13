import AppKit
import XCTest
@testable import AppSigningInspector

final class ApplicationCodeSignatureViewModelTests: XCTestCase {
    @MainActor
    func testSignatureInspectionStartsAfterSuccessfulMetadataInspection() async throws {
        let appURL = try makeApplicationBundle(named: "Inspected")
        let inspector = QueueViewModelSignatureInspector(results: [
            .success(signatureInfo(identifier: "com.example.inspected"))
        ])
        let viewModel = makeViewModel(
            pickerResults: [.selected(appURL)],
            metadataResults: [metadata(for: appURL, displayName: "Inspected")],
            signatureInspector: inspector
        )

        await viewModel.selectApplication()
        let inspectedURLs = await inspector.recordedURLs()

        XCTAssertEqual(viewModel.selectedApplication?.url, appURL)
        XCTAssertEqual(inspectedURLs, [appURL])
    }

    @MainActor
    func testSuccessfulSignatureResultIsStored() async throws {
        let appURL = try makeApplicationBundle(named: "Signed")
        let expectedInfo = signatureInfo(identifier: "com.example.signed")
        let viewModel = makeViewModel(
            pickerResults: [.selected(appURL)],
            metadataResults: [metadata(for: appURL, displayName: "Signed")],
            signatureInspector: QueueViewModelSignatureInspector(results: [.success(expectedInfo)])
        )

        await viewModel.selectApplication()

        XCTAssertEqual(viewModel.codeSignatureInfo, expectedInfo)
        XCTAssertNil(viewModel.signatureErrorMessage)
        XCTAssertNil(viewModel.signatureErrorDetails)
    }

    @MainActor
    func testSignatureFailureDoesNotRemoveApplicationMetadata() async throws {
        let appURL = try makeApplicationBundle(named: "Malformed")
        let processResult = diagnosticResult(for: appURL)
        let failure = CodeSignatureInspectionError.parsingFailed([processResult])
        let viewModel = makeViewModel(
            pickerResults: [.selected(appURL)],
            metadataResults: [metadata(for: appURL, displayName: "Malformed")],
            signatureInspector: QueueViewModelSignatureInspector(results: [.failure(failure)])
        )

        await viewModel.selectApplication()

        XCTAssertEqual(viewModel.selectedApplication?.metadata.displayName, "Malformed")
        XCTAssertNil(viewModel.codeSignatureInfo)
        XCTAssertEqual(viewModel.signatureErrorMessage, failure.userMessage)
        XCTAssertEqual(viewModel.signatureErrorDetails, failure.diagnosticDetails)
    }

    @MainActor
    func testSelectingAnotherApplicationReplacesSignatureState() async throws {
        let firstURL = try makeApplicationBundle(named: "First")
        let secondURL = try makeApplicationBundle(named: "Second")
        let firstInfo = signatureInfo(identifier: "com.example.first")
        let secondInfo = signatureInfo(identifier: "com.example.second")
        let viewModel = makeViewModel(
            pickerResults: [.selected(firstURL), .selected(secondURL)],
            metadataResults: [
                metadata(for: firstURL, displayName: "First"),
                metadata(for: secondURL, displayName: "Second")
            ],
            signatureInspector: QueueViewModelSignatureInspector(results: [
                .success(firstInfo),
                .success(secondInfo)
            ])
        )

        await viewModel.selectApplication()
        XCTAssertEqual(viewModel.codeSignatureInfo, firstInfo)

        await viewModel.selectApplication()

        XCTAssertEqual(viewModel.selectedApplication?.url, secondURL)
        XCTAssertEqual(viewModel.codeSignatureInfo, secondInfo)
    }

    @MainActor
    func testSignatureErrorClearsAfterLaterSuccessfulInspection() async throws {
        let firstURL = try makeApplicationBundle(named: "Broken")
        let secondURL = try makeApplicationBundle(named: "Recovered")
        let failure = CodeSignatureInspectionError.commandFailed(diagnosticResult(for: firstURL))
        let recoveredInfo = signatureInfo(identifier: "com.example.recovered")
        let viewModel = makeViewModel(
            pickerResults: [.selected(firstURL), .selected(secondURL)],
            metadataResults: [
                metadata(for: firstURL, displayName: "Broken"),
                metadata(for: secondURL, displayName: "Recovered")
            ],
            signatureInspector: QueueViewModelSignatureInspector(results: [
                .failure(failure),
                .success(recoveredInfo)
            ])
        )

        await viewModel.selectApplication()
        XCTAssertNotNil(viewModel.signatureErrorMessage)

        await viewModel.selectApplication()

        XCTAssertEqual(viewModel.codeSignatureInfo, recoveredInfo)
        XCTAssertNil(viewModel.signatureErrorMessage)
        XCTAssertNil(viewModel.signatureErrorDetails)
    }

    @MainActor
    func testSignatureLoadingStateTransitionsAroundInspection() async throws {
        let appURL = try makeApplicationBundle(named: "Loading")
        let inspector = ControlledCodeSignatureInspector()
        let expectedInfo = signatureInfo(identifier: "com.example.loading")
        let viewModel = makeViewModel(
            pickerResults: [.selected(appURL)],
            metadataResults: [metadata(for: appURL, displayName: "Loading")],
            signatureInspector: inspector
        )

        let selectionTask = Task { @MainActor in
            await viewModel.selectApplication()
        }
        await inspector.waitUntilStarted()

        XCTAssertTrue(viewModel.isInspectingCodeSignature)
        XCTAssertNil(viewModel.codeSignatureInfo)

        await inspector.complete(with: expectedInfo)
        await selectionTask.value

        XCTAssertFalse(viewModel.isInspectingCodeSignature)
        XCTAssertEqual(viewModel.codeSignatureInfo, expectedInfo)
    }

    @MainActor
    func testSignatureCopyActionsCopyOnlyAvailableValues() async throws {
        let appURL = try makeApplicationBundle(named: "CopySigning")
        let clipboard = ViewModelClipboardWriter()
        let info = signatureInfo(identifier: "com.example.copy")
        let viewModel = makeViewModel(
            pickerResults: [.selected(appURL)],
            metadataResults: [metadata(for: appURL, displayName: "CopySigning")],
            signatureInspector: QueueViewModelSignatureInspector(results: [.success(info)]),
            clipboardWriter: clipboard
        )

        await viewModel.selectApplication()
        viewModel.copySigningIdentifier()
        viewModel.copyTeamIdentifier()
        viewModel.copySigningAuthority(info.authorities[0])
        viewModel.copyRawSigningDiagnostics()

        XCTAssertEqual(clipboard.copiedValues, [
            "com.example.copy",
            "ABCDE12345",
            "Developer ID Application: Example Corporation (ABCDE12345)",
            info.rawDiagnostics
        ])
    }

    @MainActor
    private func makeViewModel(
        pickerResults: [ApplicationPickerResult],
        metadataResults: [ApplicationMetadata],
        signatureInspector: CodeSignatureInspecting,
        clipboardWriter: ClipboardWriting = ViewModelClipboardWriter()
    ) -> ApplicationBrowserViewModel {
        ApplicationBrowserViewModel(
            picker: ViewModelApplicationPicker(results: pickerResults),
            metadataInspector: ViewModelMetadataInspector(results: metadataResults),
            codeSignatureInspector: signatureInspector,
            iconLoader: ViewModelIconLoader(),
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

    private func signatureInfo(identifier: String) -> CodeSignatureInfo {
        let result = ProcessResult(
            executableURL: ApplicationCodeSignatureInspector.codesignURL,
            arguments: ["--display", "--verbose=4", "/Applications/Example.app"],
            terminationStatus: 0,
            standardOutput: "",
            standardError: "Identifier=\(identifier)"
        )

        return CodeSignatureInfo(
            signingIdentifier: identifier,
            teamIdentifier: "ABCDE12345",
            authorities: [
                "Developer ID Application: Example Corporation (ABCDE12345)",
                "Developer ID Certification Authority",
                "Apple Root CA"
            ],
            format: "app bundle with Mach-O thin (arm64)",
            codeDirectoryVersion: "20500",
            flags: "0x10000(runtime)",
            hardenedRuntimeEnabled: true,
            timestamp: "Jul 13, 2026 at 12:34:56 PM",
            signatureStatus: .valid,
            signingOrigin: .thirdParty,
            diagnostics: [],
            processResults: [result]
        )
    }

    private func diagnosticResult(for appURL: URL) -> ProcessResult {
        ProcessResult(
            executableURL: ApplicationCodeSignatureInspector.codesignURL,
            arguments: ["--display", "--verbose=4", appURL.path],
            terminationStatus: 1,
            standardOutput: "",
            standardError: "Malformed code-signature output"
        )
    }

    private func makeApplicationBundle(named name: String) throws -> URL {
        let appURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(name).app", isDirectory: true)
        try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)
        return appURL
    }
}

private final class ViewModelApplicationPicker: ApplicationPicking {
    private var results: [ApplicationPickerResult]

    init(results: [ApplicationPickerResult]) {
        self.results = results
    }

    @MainActor
    func selectApplication() async throws -> ApplicationPickerResult {
        results.removeFirst()
    }
}

private final class ViewModelMetadataInspector: ApplicationMetadataInspecting {
    private var results: [ApplicationMetadata]

    init(results: [ApplicationMetadata]) {
        self.results = results
    }

    func metadata(for applicationURL: URL) throws -> ApplicationMetadata {
        results.removeFirst()
    }
}

private struct ViewModelIconLoader: ApplicationIconLoading {
    func icon(for applicationURL: URL) throws -> NSImage {
        NSImage(size: NSSize(width: 32, height: 32))
    }
}

private actor QueueViewModelSignatureInspector: CodeSignatureInspecting {
    private var results: [Result<CodeSignatureInfo, CodeSignatureInspectionError>]
    private var inspectedURLs: [URL] = []

    init(results: [Result<CodeSignatureInfo, CodeSignatureInspectionError>]) {
        self.results = results
    }

    func inspect(applicationAt applicationURL: URL) async throws -> CodeSignatureInfo {
        inspectedURLs.append(applicationURL)
        return try results.removeFirst().get()
    }

    func recordedURLs() -> [URL] {
        inspectedURLs
    }
}

private actor ControlledCodeSignatureInspector: CodeSignatureInspecting {
    private var inspectionContinuation: CheckedContinuation<CodeSignatureInfo, Error>?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var hasStarted = false

    func inspect(applicationAt applicationURL: URL) async throws -> CodeSignatureInfo {
        hasStarted = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }

        return try await withCheckedThrowingContinuation { continuation in
            inspectionContinuation = continuation
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

    func complete(with info: CodeSignatureInfo) {
        let continuation = inspectionContinuation
        inspectionContinuation = nil
        continuation?.resume(returning: info)
    }
}

private final class ViewModelClipboardWriter: ClipboardWriting {
    private(set) var copiedValues: [String] = []

    func copy(_ value: String) {
        copiedValues.append(value)
    }
}
