import XCTest
import AppKit
@testable import AppSigningInspector

final class AppSigningInspectorTests: XCTestCase {
    @MainActor
    func testInitialProjectLoadsContentView() {
        _ = ContentView()
    }
}

final class ApplicationBrowserViewModelTests: XCTestCase {
    @MainActor
    func testInitialStateHasNoSelectionOrError() {
        let viewModel = ApplicationBrowserViewModel(
            picker: StubApplicationPicker(result: .cancelled),
            metadataInspector: StubMetadataInspector(),
            codeSignatureInspector: StubCodeSignatureInspector(),
            iconLoader: StubIconLoader()
        )

        XCTAssertNil(viewModel.selectedApplication)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.hasSelectedApplication)
    }

    @MainActor
    func testSuccessfulSelectionStoresApplication() async throws {
        let appURL = try makeApplicationBundle(named: "Example")
        let viewModel = ApplicationBrowserViewModel(
            picker: StubApplicationPicker(result: .selected(appURL)),
            metadataInspector: StubMetadataInspector(metadata: metadata(for: appURL, displayName: "Example")),
            codeSignatureInspector: StubCodeSignatureInspector(),
            iconLoader: StubIconLoader()
        )

        await viewModel.selectApplication()

        XCTAssertEqual(viewModel.selectedApplication?.url, appURL)
        XCTAssertEqual(viewModel.selectedApplication?.name, "Example")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.hasSelectedApplication)
    }

    @MainActor
    func testCancellationPreservesExistingSelection() async throws {
        let appURL = try makeApplicationBundle(named: "Existing")
        let picker = QueueApplicationPicker(results: [
            .selected(appURL),
            .cancelled
        ])
        let viewModel = ApplicationBrowserViewModel(
            picker: picker,
            metadataInspector: StubMetadataInspector(metadata: metadata(for: appURL, displayName: "Existing")),
            codeSignatureInspector: StubCodeSignatureInspector(),
            iconLoader: StubIconLoader()
        )

        await viewModel.selectApplication()
        await viewModel.selectApplication()

        XCTAssertEqual(viewModel.selectedApplication?.url, appURL)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testInvalidSelectionShowsError() async throws {
        let invalidURL = temporaryDirectory().appendingPathComponent("NotAnApp.txt")
        FileManager.default.createFile(atPath: invalidURL.path, contents: Data())
        let viewModel = ApplicationBrowserViewModel(
            picker: StubApplicationPicker(result: .selected(invalidURL)),
            metadataInspector: StubMetadataInspector(),
            codeSignatureInspector: StubCodeSignatureInspector(),
            iconLoader: StubIconLoader()
        )

        await viewModel.selectApplication()

        XCTAssertNil(viewModel.selectedApplication)
        XCTAssertEqual(
            viewModel.errorMessage,
            "The selected item is not a macOS application bundle. Choose a .app bundle."
        )
    }

    @MainActor
    func testMissingApplicationShowsError() async {
        let missingURL = temporaryDirectory().appendingPathComponent("Missing.app", isDirectory: true)
        let viewModel = ApplicationBrowserViewModel(
            picker: StubApplicationPicker(result: .selected(missingURL)),
            metadataInspector: StubMetadataInspector(),
            codeSignatureInspector: StubCodeSignatureInspector(),
            iconLoader: StubIconLoader()
        )

        await viewModel.selectApplication()

        XCTAssertNil(viewModel.selectedApplication)
        XCTAssertEqual(
            viewModel.errorMessage,
            "The selected application could not be found. Choose an existing .app bundle."
        )
    }

    @MainActor
    func testIconFailureShowsError() async throws {
        let appURL = try makeApplicationBundle(named: "NoIcon")
        let viewModel = ApplicationBrowserViewModel(
            picker: StubApplicationPicker(result: .selected(appURL)),
            metadataInspector: StubMetadataInspector(metadata: metadata(for: appURL, displayName: "NoIcon")),
            codeSignatureInspector: StubCodeSignatureInspector(),
            iconLoader: StubIconLoader(error: ApplicationBrowserError.iconUnavailable(appURL))
        )

        await viewModel.selectApplication()

        XCTAssertNil(viewModel.selectedApplication)
        XCTAssertEqual(
            viewModel.errorMessage,
            "The application icon could not be loaded. Choose a different .app bundle."
        )
    }

    @MainActor
    func testErrorClearsAfterSuccessfulSelection() async throws {
        let invalidURL = temporaryDirectory().appendingPathComponent("Invalid.txt")
        FileManager.default.createFile(atPath: invalidURL.path, contents: Data())
        let appURL = try makeApplicationBundle(named: "Valid")
        let picker = QueueApplicationPicker(results: [
            .selected(invalidURL),
            .selected(appURL)
        ])
        let viewModel = ApplicationBrowserViewModel(
            picker: picker,
            metadataInspector: QueueMetadataInspector(metadataResults: [
                metadata(for: appURL, displayName: "Valid")
            ]),
            codeSignatureInspector: StubCodeSignatureInspector(),
            iconLoader: StubIconLoader()
        )

        await viewModel.selectApplication()
        XCTAssertNotNil(viewModel.errorMessage)

        await viewModel.selectApplication()
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.selectedApplication?.url, appURL)
    }

    @MainActor
    func testMetadataInspectionFailureShowsError() async throws {
        let appURL = try makeApplicationBundle(named: "Broken")
        let viewModel = ApplicationBrowserViewModel(
            picker: StubApplicationPicker(result: .selected(appURL)),
            metadataInspector: StubMetadataInspector(error: ApplicationMetadataError.infoPlistUnreadable(appURL)),
            codeSignatureInspector: StubCodeSignatureInspector(),
            iconLoader: StubIconLoader()
        )

        await viewModel.selectApplication()

        XCTAssertNil(viewModel.selectedApplication)
        XCTAssertEqual(
            viewModel.errorMessage,
            "The selected application's Info.plist could not be read. Choose a different app."
        )
    }

    @MainActor
    func testSelectingSecondApplicationReplacesPreviousMetadata() async throws {
        let firstURL = try makeApplicationBundle(named: "First")
        let secondURL = try makeApplicationBundle(named: "Second")
        let picker = QueueApplicationPicker(results: [
            .selected(firstURL),
            .selected(secondURL)
        ])
        let viewModel = ApplicationBrowserViewModel(
            picker: picker,
            metadataInspector: QueueMetadataInspector(metadataResults: [
                metadata(for: firstURL, displayName: "First"),
                metadata(for: secondURL, displayName: "Second")
            ]),
            codeSignatureInspector: StubCodeSignatureInspector(),
            iconLoader: StubIconLoader()
        )

        await viewModel.selectApplication()
        await viewModel.selectApplication()

        XCTAssertEqual(viewModel.selectedApplication?.url, secondURL)
        XCTAssertEqual(viewModel.selectedApplication?.name, "Second")
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testCopyActionsUseAvailableMetadataValues() async throws {
        let appURL = try makeApplicationBundle(named: "Copyable")
        let clipboard = StubClipboardWriter()
        let viewModel = ApplicationBrowserViewModel(
            picker: StubApplicationPicker(result: .selected(appURL)),
            metadataInspector: StubMetadataInspector(metadata: metadata(for: appURL, displayName: "Copyable")),
            codeSignatureInspector: StubCodeSignatureInspector(),
            iconLoader: StubIconLoader(),
            clipboardWriter: clipboard
        )

        await viewModel.selectApplication()
        viewModel.copyBundleIdentifier()
        viewModel.copyBundlePath()
        viewModel.copyExecutablePath()

        XCTAssertEqual(clipboard.copiedValues, [
            "com.example.Copyable",
            appURL.path,
            appURL.appendingPathComponent("Contents/MacOS/Copyable").path
        ])
    }

    private func makeApplicationBundle(named name: String) throws -> URL {
        let appURL = temporaryDirectory().appendingPathComponent("\(name).app", isDirectory: true)
        try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)
        return appURL
    }

    private func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func metadata(for appURL: URL, displayName: String) -> ApplicationMetadata {
        ApplicationMetadata(
            applicationURL: appURL,
            displayName: displayName,
            bundleIdentifier: "com.example.\(displayName)",
            shortVersion: "1.0",
            buildNumber: "100",
            bundlePath: appURL.path,
            executableName: displayName,
            executablePath: appURL.appendingPathComponent("Contents/MacOS/\(displayName)").path,
            executableExists: true,
            diagnostics: []
        )
    }
}

final class ApplicationMetadataInspectorTests: XCTestCase {
    func testDisplayNameUsesBundleDisplayNameFirst() {
        let appURL = applicationURL(named: "Filename")

        let metadata = ApplicationMetadataInspector.metadata(
            applicationURL: appURL,
            infoDictionary: [
                "CFBundleDisplayName": "Display",
                "CFBundleName": "Bundle"
            ]
        )

        XCTAssertEqual(metadata.displayName, "Display")
    }

    func testDisplayNameFallsBackToBundleName() {
        let appURL = applicationURL(named: "Filename")

        let metadata = ApplicationMetadataInspector.metadata(
            applicationURL: appURL,
            infoDictionary: ["CFBundleName": "Bundle"]
        )

        XCTAssertEqual(metadata.displayName, "Bundle")
    }

    func testDisplayNameFallsBackToAppFilename() {
        let appURL = applicationURL(named: "Filename")

        let metadata = ApplicationMetadataInspector.metadata(
            applicationURL: appURL,
            infoDictionary: [:]
        )

        XCTAssertEqual(metadata.displayName, "Filename")
    }

    func testParsesBundleIdentifierVersionBuildAndExecutableName() throws {
        let appURL = try makeApplicationBundle(named: "Example")
        _ = FileManager.default.createFile(
            atPath: appURL.appendingPathComponent("Contents/MacOS/Runner").path,
            contents: Data()
        )

        let metadata = ApplicationMetadataInspector.metadata(
            applicationURL: appURL,
            infoDictionary: [
                "CFBundleIdentifier": "com.example.app",
                "CFBundleShortVersionString": "2.3",
                "CFBundleVersion": "45",
                "CFBundleExecutable": "Runner"
            ]
        )

        XCTAssertEqual(metadata.bundleIdentifier, "com.example.app")
        XCTAssertEqual(metadata.shortVersion, "2.3")
        XCTAssertEqual(metadata.buildNumber, "45")
        XCTAssertEqual(metadata.executableName, "Runner")
    }

    func testConstructsExecutablePathWhenExecutableExists() throws {
        let appURL = try makeApplicationBundle(named: "Executable")
        let executableURL = appURL.appendingPathComponent("Contents/MacOS/ExecutableRunner")
        _ = FileManager.default.createFile(atPath: executableURL.path, contents: Data())

        let metadata = ApplicationMetadataInspector.metadata(
            applicationURL: appURL,
            infoDictionary: ["CFBundleExecutable": "ExecutableRunner"]
        )

        XCTAssertEqual(metadata.executablePath, executableURL.path)
        XCTAssertTrue(metadata.executableExists)
    }

    func testMissingExecutableKeyMarksExecutableUnavailable() {
        let appURL = applicationURL(named: "NoExecutable")

        let metadata = ApplicationMetadataInspector.metadata(
            applicationURL: appURL,
            infoDictionary: [:]
        )

        XCTAssertNil(metadata.executableName)
        XCTAssertNil(metadata.executablePath)
        XCTAssertFalse(metadata.executableExists)
        XCTAssertTrue(metadata.diagnostics.contains(.missingExecutableName))
    }

    func testExecutableFileNotFoundMarksExecutablePathUnavailable() {
        let appURL = applicationURL(named: "MissingExecutable")

        let metadata = ApplicationMetadataInspector.metadata(
            applicationURL: appURL,
            infoDictionary: ["CFBundleExecutable": "MissingRunner"]
        )

        XCTAssertEqual(metadata.executableName, "MissingRunner")
        XCTAssertNil(metadata.executablePath)
        XCTAssertFalse(metadata.executableExists)
        XCTAssertTrue(metadata.diagnostics.contains(.executableNotFound("MissingRunner")))
    }

    func testMissingOptionalMetadataIsUnavailableWithDiagnostics() {
        let appURL = applicationURL(named: "Sparse")

        let metadata = ApplicationMetadataInspector.metadata(
            applicationURL: appURL,
            infoDictionary: [:]
        )

        XCTAssertNil(metadata.bundleIdentifier)
        XCTAssertNil(metadata.shortVersion)
        XCTAssertNil(metadata.buildNumber)
        XCTAssertEqual(metadata.bundleIdentifierDisplayValue, "Unavailable")
        XCTAssertEqual(metadata.versionDisplayValue, "Unavailable")
        XCTAssertEqual(metadata.buildDisplayValue, "Unavailable")
        XCTAssertTrue(metadata.diagnostics.contains(.missingBundleIdentifier))
        XCTAssertTrue(metadata.diagnostics.contains(.missingShortVersion))
        XCTAssertTrue(metadata.diagnostics.contains(.missingBuildNumber))
    }

    func testInvalidBundleThrowsMetadataError() throws {
        let inspector = ApplicationMetadataInspector()
        let invalidURL = temporaryDirectory().appendingPathComponent("NotAnApp.txt")
        FileManager.default.createFile(atPath: invalidURL.path, contents: Data())

        XCTAssertThrowsError(try inspector.metadata(for: invalidURL)) { error in
            XCTAssertEqual(error as? ApplicationMetadataError, .invalidBundle(invalidURL))
        }
    }

    private func applicationURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(name).app", isDirectory: true)
    }

    private func makeApplicationBundle(named name: String) throws -> URL {
        let appURL = temporaryDirectory().appendingPathComponent("\(name).app", isDirectory: true)
        let executableDirectory = appURL.appendingPathComponent("Contents/MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: executableDirectory, withIntermediateDirectories: true)
        return appURL
    }

    private func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private struct StubApplicationPicker: ApplicationPicking {
    let result: ApplicationPickerResult

    @MainActor
    func selectApplication() async throws -> ApplicationPickerResult {
        result
    }
}

private final class QueueApplicationPicker: ApplicationPicking {
    private var results: [ApplicationPickerResult]

    init(results: [ApplicationPickerResult]) {
        self.results = results
    }

    @MainActor
    func selectApplication() async throws -> ApplicationPickerResult {
        results.removeFirst()
    }
}

private struct StubIconLoader: ApplicationIconLoading {
    var error: Error?

    func icon(for applicationURL: URL) throws -> NSImage {
        if let error {
            throw error
        }

        return NSImage(size: NSSize(width: 32, height: 32))
    }
}

private struct StubCodeSignatureInspector: CodeSignatureInspecting {
    func inspect(applicationAt applicationURL: URL) async throws -> CodeSignatureInfo {
        CodeSignatureInfo(
            signingIdentifier: nil,
            teamIdentifier: nil,
            authorities: [],
            format: nil,
            codeDirectoryVersion: nil,
            flags: nil,
            hardenedRuntimeEnabled: nil,
            timestamp: nil,
            signatureStatus: .unsigned,
            signingOrigin: .unknown,
            diagnostics: [],
            processResults: []
        )
    }
}

private struct StubMetadataInspector: ApplicationMetadataInspecting {
    var metadata: ApplicationMetadata?
    var error: Error?

    func metadata(for applicationURL: URL) throws -> ApplicationMetadata {
        if let error {
            throw error
        }

        return metadata ?? ApplicationMetadata(
            applicationURL: applicationURL,
            displayName: applicationURL.deletingPathExtension().lastPathComponent,
            bundleIdentifier: nil,
            shortVersion: nil,
            buildNumber: nil,
            bundlePath: applicationURL.path,
            executableName: nil,
            executablePath: nil,
            executableExists: false,
            diagnostics: []
        )
    }
}

private final class QueueMetadataInspector: ApplicationMetadataInspecting {
    private var metadataResults: [ApplicationMetadata]

    init(metadataResults: [ApplicationMetadata]) {
        self.metadataResults = metadataResults
    }

    func metadata(for applicationURL: URL) throws -> ApplicationMetadata {
        metadataResults.removeFirst()
    }
}

private final class StubClipboardWriter: ClipboardWriting {
    private(set) var copiedValues: [String] = []

    func copy(_ value: String) {
        copiedValues.append(value)
    }
}
