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
            iconLoader: StubIconLoader()
        )

        await viewModel.selectApplication()
        XCTAssertNotNil(viewModel.errorMessage)

        await viewModel.selectApplication()
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.selectedApplication?.url, appURL)
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

        NSImage(size: NSSize(width: 32, height: 32))
    }
}
