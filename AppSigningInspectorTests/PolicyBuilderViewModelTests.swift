import AppKit
import Foundation
import XCTest
@testable import AppSigningInspector

final class PolicyBuilderViewModelTests: XCTestCase {
    private let declarationIdentifier = UUID(uuid: (
        0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA,
        0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA
    ))
    private let serverToken = UUID(uuid: (
        0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB,
        0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB
    ))

    @MainActor
    func testAddsMultipleApplicationsAndInspectsSigningValues() async {
        let firstURL = appURL("First")
        let secondURL = appURL("Second")
        let inspector = PolicySignatureInspector(results: [
            .success(signatureInfo(signingIdentifier: "com.example.first", teamIdentifier: "TEAMONE")),
            .success(signatureInfo(signingIdentifier: "com.example.second", teamIdentifier: "TEAMTWO"))
        ])
        let viewModel = makeViewModel(
            pickerResults: [.selected([firstURL, secondURL])],
            metadataResults: [
                .success(metadata(for: firstURL, name: "First")),
                .success(metadata(for: secondURL, name: "Second"))
            ],
            signatureInspector: inspector
        )

        await viewModel.addApplications()
        let inspectedURLs = await inspector.inspectedURLs

        XCTAssertEqual(viewModel.entries.map(\.displayName), ["First", "Second"])
        XCTAssertEqual(viewModel.entries.map(\.signingIdentifier), ["com.example.first", "com.example.second"])
        XCTAssertEqual(viewModel.entries.map(\.teamIdentifier), ["TEAMONE", "TEAMTWO"])
        XCTAssertEqual(viewModel.entries.map(\.action), [.deny, .deny])
        XCTAssertEqual(inspectedURLs, [firstURL, secondURL])
        XCTAssertNotNil(viewModel.jsonPreview)
        XCTAssertTrue(viewModel.canExport)
    }

    @MainActor
    func testAddsApplicationsOverTimeWithoutReplacingExistingEntries() async {
        let firstURL = appURL("First")
        let secondURL = appURL("Second")
        let viewModel = makeViewModel(
            pickerResults: [.selected([firstURL]), .selected([secondURL])],
            metadataResults: [
                .success(metadata(for: firstURL, name: "First")),
                .success(metadata(for: secondURL, name: "Second"))
            ],
            signatureResults: [
                .success(signatureInfo(signingIdentifier: "first", teamIdentifier: "TEAM1")),
                .success(signatureInfo(signingIdentifier: "second", teamIdentifier: "TEAM2"))
            ]
        )

        await viewModel.addApplications()
        await viewModel.addApplications()

        XCTAssertEqual(viewModel.entries.map(\.displayName), ["First", "Second"])
    }

    @MainActor
    func testChangingActionRegeneratesAllowedAndDeniedArrays() async throws {
        let url = appURL("Action")
        let viewModel = makeViewModel(
            pickerResults: [.selected([url])],
            metadataResults: [.success(metadata(for: url, name: "Action"))],
            signatureResults: [.success(signatureInfo(signingIdentifier: "action.id", teamIdentifier: "ACTIONTEAM"))]
        )
        await viewModel.addApplications()
        let entryID = try XCTUnwrap(viewModel.entries.first?.id)

        viewModel.setAction(.allow, for: entryID)

        let object = try jsonObject(from: XCTUnwrap(viewModel.jsonPreview))
        let allowed = try allowedObject(from: object)
        XCTAssertEqual((allowed["AllowedBinaries"] as? [[String: String]])?.count, 1)
        XCTAssertEqual((allowed["DeniedBinaries"] as? [[String: String]])?.count, 0)
        XCTAssertNotNil(viewModel.allowOnlySafetyWarning)
    }

    @MainActor
    func testRemovingEntryUpdatesPolicyAndGenerationState() async throws {
        let firstURL = appURL("First")
        let secondURL = appURL("Second")
        let viewModel = makeViewModel(
            pickerResults: [.selected([firstURL, secondURL])],
            metadataResults: [
                .success(metadata(for: firstURL, name: "First")),
                .success(metadata(for: secondURL, name: "Second"))
            ],
            signatureResults: [
                .success(signatureInfo(signingIdentifier: "first", teamIdentifier: "TEAM1")),
                .success(signatureInfo(signingIdentifier: "second", teamIdentifier: "TEAM2"))
            ]
        )
        await viewModel.addApplications()

        viewModel.removeEntry(id: viewModel.entries[0].id)

        XCTAssertEqual(viewModel.entries.map(\.displayName), ["Second"])
        XCTAssertTrue(viewModel.jsonPreview?.contains("second") == true)
        XCTAssertFalse(viewModel.jsonPreview?.contains("first") == true)
    }

    @MainActor
    func testDuplicateApplicationPathIsNotAddedOrReinspected() async {
        let url = appURL("DuplicatePath")
        let inspector = PolicySignatureInspector(results: [
            .success(signatureInfo(signingIdentifier: "duplicate.path", teamIdentifier: "TEAM1"))
        ])
        let viewModel = makeViewModel(
            pickerResults: [.selected([url, url])],
            metadataResults: [.success(metadata(for: url, name: "DuplicatePath"))],
            signatureInspector: inspector
        )

        await viewModel.addApplications()
        let inspectedURLs = await inspector.inspectedURLs

        XCTAssertEqual(viewModel.entries.count, 1)
        XCTAssertEqual(inspectedURLs, [url])
        XCTAssertTrue(viewModel.notices.contains { notice in
            if case .duplicateApplication = notice { return true }
            return false
        })
    }

    @MainActor
    func testDuplicateSigningPairIsNotAdded() async {
        let firstURL = appURL("First")
        let secondURL = appURL("Second")
        let duplicateInfo = signatureInfo(signingIdentifier: "same.id", teamIdentifier: "SAMETEAM")
        let viewModel = makeViewModel(
            pickerResults: [.selected([firstURL, secondURL])],
            metadataResults: [
                .success(metadata(for: firstURL, name: "First")),
                .success(metadata(for: secondURL, name: "Second"))
            ],
            signatureResults: [.success(duplicateInfo), .success(duplicateInfo)]
        )

        await viewModel.addApplications()

        XCTAssertEqual(viewModel.entries.count, 1)
        XCTAssertTrue(viewModel.notices.contains { notice in
            if case .duplicateRule = notice { return true }
            return false
        })
    }

    @MainActor
    func testMissingSigningIdentifierRemainsVisibleButBlocksExport() async {
        let url = appURL("MissingSigning")
        let viewModel = makeViewModel(
            pickerResults: [.selected([url])],
            metadataResults: [.success(metadata(for: url, name: "MissingSigning"))],
            signatureResults: [.success(signatureInfo(signingIdentifier: nil, teamIdentifier: "TEAM1"))]
        )

        await viewModel.addApplications()

        XCTAssertEqual(viewModel.entries.count, 1)
        XCTAssertEqual(viewModel.entries.first?.validationState, .missingSigningIdentifier)
        XCTAssertNil(viewModel.jsonPreview)
        XCTAssertFalse(viewModel.canExport)
    }

    @MainActor
    func testMissingTeamIdentifierRemainsVisibleButBlocksExport() async {
        let url = appURL("MissingTeam")
        let viewModel = makeViewModel(
            pickerResults: [.selected([url])],
            metadataResults: [.success(metadata(for: url, name: "MissingTeam"))],
            signatureResults: [.success(signatureInfo(signingIdentifier: "missing.team", teamIdentifier: nil))]
        )

        await viewModel.addApplications()

        XCTAssertEqual(viewModel.entries.count, 1)
        XCTAssertEqual(viewModel.entries.first?.validationState, .missingTeamIdentifier)
        XCTAssertNil(viewModel.jsonPreview)
        XCTAssertFalse(viewModel.canExport)
    }

    @MainActor
    func testFailedApplicationPreservesPreviouslyAddedValidEntry() async {
        let validURL = appURL("Valid")
        let failedURL = appURL("Failed")
        let failure = CodeSignatureInspectionError.applicationUnavailable(failedURL)
        let viewModel = makeViewModel(
            pickerResults: [.selected([validURL, failedURL])],
            metadataResults: [
                .success(metadata(for: validURL, name: "Valid")),
                .success(metadata(for: failedURL, name: "Failed"))
            ],
            signatureResults: [
                .success(signatureInfo(signingIdentifier: "valid.id", teamIdentifier: "VALIDTEAM")),
                .failure(failure)
            ]
        )

        await viewModel.addApplications()

        XCTAssertEqual(viewModel.entries.count, 2)
        XCTAssertTrue(viewModel.entries[0].isValid)
        XCTAssertEqual(
            viewModel.entries[1].validationState,
            .signatureInspectionFailed(failure.diagnosticDetails)
        )
        XCTAssertFalse(viewModel.canExport)
    }

    @MainActor
    func testMetadataFailureDoesNotRemoveValidEntry() async {
        let validURL = appURL("Valid")
        let failedURL = appURL("Unreadable")
        let viewModel = makeViewModel(
            pickerResults: [.selected([validURL, failedURL])],
            metadataResults: [
                .success(metadata(for: validURL, name: "Valid")),
                .failure(.infoPlistUnreadable(failedURL))
            ],
            signatureResults: [
                .success(signatureInfo(signingIdentifier: "valid.id", teamIdentifier: "VALIDTEAM"))
            ]
        )

        await viewModel.addApplications()

        XCTAssertEqual(viewModel.entries.map(\.displayName), ["Valid"])
        XCTAssertTrue(viewModel.notices.contains { notice in
            if case .applicationInspectionFailed = notice { return true }
            return false
        })
    }

    @MainActor
    func testCopyAndExportUseGeneratedJSON() async throws {
        let url = appURL("Export")
        let clipboard = PolicyClipboardWriter()
        let exporter = PolicyJSONExporter(result: .exported(URL(fileURLWithPath: "/tmp/declaration.json")))
        let viewModel = makeViewModel(
            pickerResults: [.selected([url])],
            metadataResults: [.success(metadata(for: url, name: "Export"))],
            signatureResults: [.success(signatureInfo(signingIdentifier: "export.id", teamIdentifier: "EXPORTTEAM"))],
            clipboard: clipboard,
            exporter: exporter
        )
        await viewModel.addApplications()
        let expectedJSON = try XCTUnwrap(viewModel.jsonPreview)

        viewModel.copyGeneratedJSON()
        await viewModel.exportGeneratedJSON()

        XCTAssertEqual(clipboard.copiedValues, [expectedJSON])
        XCTAssertEqual(exporter.exportedJSON, expectedJSON)
        XCTAssertEqual(exporter.suggestedFilename, "app-settings-declaration.json")
        XCTAssertEqual(viewModel.exportStatusMessage, "Exported declaration.json.")
    }

    @MainActor
    func testManagedAppsToggleGeneratesValidPolicyWithoutBinaryRules() throws {
        let viewModel = makeViewModel(pickerResults: [], metadataResults: [])

        viewModel.setAlwaysAllowManagedApps(true)

        let object = try jsonObject(from: XCTUnwrap(viewModel.jsonPreview))
        let allowed = try allowedObject(from: object)
        XCTAssertEqual(allowed["AlwaysAllowManagedApps"] as? Bool, true)
        XCTAssertNil(allowed["AllowedBinaries"])
        XCTAssertNil(allowed["DeniedBinaries"])
        XCTAssertTrue(viewModel.canExport)

        viewModel.setAlwaysAllowManagedApps(false)
        XCTAssertNil(viewModel.jsonPreview)
        XCTAssertFalse(viewModel.canExport)
    }

    @MainActor
    func testAppleRuleUsesDocumentedTokenAndRejectsDuplicate() throws {
        let viewModel = makeViewModel(pickerResults: [], metadataResults: [])

        viewModel.setAllowAllAppleBinaries(true)
        viewModel.setAllowAllAppleBinaries(true)

        XCTAssertEqual(viewModel.entries.count, 1)
        XCTAssertEqual(viewModel.entries.first?.rule, .appleBinaries)
        XCTAssertTrue(viewModel.notices.contains { notice in
            if case .duplicateRule = notice { return true }
            return false
        })
        let object = try jsonObject(from: XCTUnwrap(viewModel.jsonPreview))
        let allowed = try allowedObject(from: object)
        let binary = try XCTUnwrap((allowed["AllowedBinaries"] as? [[String: String]])?.first)
        XCTAssertEqual(binary, ["TeamID": "*APPLE*"])
    }

    @MainActor
    func testManualDeveloperTeamRuleTrimsOnlySurroundingWhitespace() {
        let viewModel = makeViewModel(pickerResults: [], metadataResults: [])

        XCTAssertTrue(viewModel.addDeveloperTeamRule(teamIdentifier: "  AbCd1234  "))

        XCTAssertEqual(viewModel.entries.first?.rule, .developerTeam(teamIdentifier: "AbCd1234"))
        XCTAssertEqual(viewModel.entries.first?.action, .allow)
        XCTAssertTrue(viewModel.safetyWarnings.contains { $0.contains("AbCd1234") })
    }

    @MainActor
    func testManualDeveloperRuleRejectsDuplicateAndUndocumentedWildcard() {
        let viewModel = makeViewModel(pickerResults: [], metadataResults: [])

        XCTAssertTrue(viewModel.addDeveloperTeamRule(teamIdentifier: "TEAM1"))
        XCTAssertFalse(viewModel.addDeveloperTeamRule(teamIdentifier: "TEAM1"))
        XCTAssertFalse(viewModel.addDeveloperTeamRule(teamIdentifier: "*GOOGLE*"))

        XCTAssertEqual(viewModel.entries.count, 1)
        XCTAssertEqual(
            viewModel.workflowErrorMessage,
            "Only the documented *APPLE* special Team ID token is supported."
        )
    }

    @MainActor
    func testManualAppleTokenCreatesTypedAppleRule() {
        let viewModel = makeViewModel(pickerResults: [], metadataResults: [])

        XCTAssertTrue(viewModel.addDeveloperTeamRule(teamIdentifier: "  *APPLE*  "))

        XCTAssertEqual(viewModel.entries.map(\.rule), [.appleBinaries])
        XCTAssertTrue(viewModel.allowsAllAppleBinaries)
    }

    @MainActor
    func testSelectedApplicationCanBecomeDeveloperWideRuleUsingActualTeamID() async {
        let url = appURL("Developer")
        let viewModel = makeViewModel(
            pickerResults: [.selected([url])],
            metadataResults: [.success(metadata(for: url, name: "Developer"))],
            signatureResults: [.success(signatureInfo(signingIdentifier: "developer.app", teamIdentifier: "ACTUALTEAM"))]
        )
        await viewModel.addApplications()
        let entryID = viewModel.entries[0].id

        viewModel.convertToDeveloperTeamRule(entryID: entryID)

        XCTAssertEqual(viewModel.entries[0].rule, .developerTeam(teamIdentifier: "ACTUALTEAM"))
        XCTAssertEqual(viewModel.entries[0].action, .allow)
        XCTAssertNil(viewModel.entries[0].signingIdentifier)
    }

    @MainActor
    func testPathPrefixCanBeEnabledEditedAndDisabled() async {
        let url = appURL("Path App")
        let viewModel = makeViewModel(
            pickerResults: [.selected([url])],
            metadataResults: [.success(metadata(for: url, name: "Path App"))],
            signatureResults: [.success(signatureInfo(signingIdentifier: "path.app", teamIdentifier: "PATHTEAM"))]
        )
        await viewModel.addApplications()
        let entryID = viewModel.entries[0].id
        let editedPath = "/Applications/Custom Folder/Path App.app"

        viewModel.setPathPrefix(editedPath, for: entryID)
        XCTAssertEqual(viewModel.entries[0].pathPrefix, editedPath)
        XCTAssertTrue(viewModel.canExport)

        viewModel.setPathPrefix("relative/path", for: entryID)
        XCTAssertEqual(viewModel.entries[0].validationState, .invalidPathPrefix)
        XCTAssertFalse(viewModel.canExport)

        viewModel.setPathPrefix(nil, for: entryID)
        XCTAssertNil(viewModel.entries[0].pathPrefix)
        XCTAssertTrue(viewModel.canExport)
    }

    @MainActor
    func testBroadTeamRuleCreatesAndClearsRedundancyWarning() async throws {
        let url = appURL("Redundant")
        let viewModel = makeViewModel(
            pickerResults: [.selected([url])],
            metadataResults: [.success(metadata(for: url, name: "Redundant"))],
            signatureResults: [.success(signatureInfo(signingIdentifier: "redundant.app", teamIdentifier: "TEAM1"))]
        )
        await viewModel.addApplications()
        let specificID = viewModel.entries[0].id
        viewModel.setAction(.allow, for: specificID)
        XCTAssertTrue(viewModel.addDeveloperTeamRule(teamIdentifier: "TEAM1"))

        XCTAssertTrue(viewModel.safetyWarnings.contains { $0.contains("may already include") })

        let broadID = try XCTUnwrap(viewModel.entries.first { $0.rule.type == .developerTeam }?.id)
        viewModel.removeEntry(id: broadID)
        XCTAssertFalse(viewModel.safetyWarnings.contains { $0.contains("may already include") })
    }

    @MainActor
    func testDifferentDeveloperTeamIDsRemainDistinct() {
        let viewModel = makeViewModel(pickerResults: [], metadataResults: [])

        XCTAssertTrue(viewModel.addDeveloperTeamRule(teamIdentifier: "TEAM1"))
        XCTAssertTrue(viewModel.addDeveloperTeamRule(teamIdentifier: "TEAM2"))

        XCTAssertEqual(viewModel.entries.count, 2)
    }

    @MainActor
    func testCopyUsesJSONRegeneratedAfterOptionChanges() throws {
        let clipboard = PolicyClipboardWriter()
        let viewModel = makeViewModel(
            pickerResults: [],
            metadataResults: [],
            clipboard: clipboard
        )

        viewModel.setAlwaysAllowManagedApps(true)
        let expectedJSON = try XCTUnwrap(viewModel.jsonPreview)
        viewModel.copyGeneratedJSON()

        XCTAssertEqual(clipboard.copiedValues, [expectedJSON])
        XCTAssertTrue(expectedJSON.contains("AlwaysAllowManagedApps"))
    }

    @MainActor
    func testDeclarationIdentifiersRemainStableWhenPolicyChanges() async throws {
        let url = appURL("Stable")
        let viewModel = makeViewModel(
            pickerResults: [.selected([url])],
            metadataResults: [.success(metadata(for: url, name: "Stable"))],
            signatureResults: [.success(signatureInfo(signingIdentifier: "stable.id", teamIdentifier: "STABLETEAM"))]
        )
        await viewModel.addApplications()
        let entryID = try XCTUnwrap(viewModel.entries.first?.id)
        let firstObject = try jsonObject(from: XCTUnwrap(viewModel.jsonPreview))

        viewModel.setAction(.allow, for: entryID)
        let secondObject = try jsonObject(from: XCTUnwrap(viewModel.jsonPreview))

        XCTAssertEqual(firstObject["Identifier"] as? String, secondObject["Identifier"] as? String)
        XCTAssertEqual(firstObject["ServerToken"] as? String, secondObject["ServerToken"] as? String)
    }

    @MainActor
    private func makeViewModel(
        pickerResults: [PolicyApplicationPickerResult],
        metadataResults: [Result<ApplicationMetadata, ApplicationMetadataError>],
        signatureResults: [Result<CodeSignatureInfo, CodeSignatureInspectionError>] = [],
        signatureInspector: PolicySignatureInspector? = nil,
        clipboard: PolicyClipboardWriter = PolicyClipboardWriter(),
        exporter: PolicyJSONExporter = PolicyJSONExporter(result: .cancelled)
    ) -> PolicyBuilderViewModel {
        PolicyBuilderViewModel(
            picker: PolicyApplicationPicker(results: pickerResults),
            metadataInspector: PolicyMetadataInspector(results: metadataResults),
            codeSignatureInspector: signatureInspector ?? PolicySignatureInspector(results: signatureResults),
            iconLoader: PolicyIconLoader(),
            clipboardWriter: clipboard,
            declarationGenerator: DDMDeclarationGenerator(),
            exporter: exporter,
            declarationIdentifier: declarationIdentifier,
            serverToken: serverToken
        )
    }

    private func appURL(_ name: String) -> URL {
        URL(fileURLWithPath: "/Applications/\(name).app", isDirectory: true)
    }

    private func metadata(for url: URL, name: String) -> ApplicationMetadata {
        ApplicationMetadata(
            applicationURL: url,
            displayName: name,
            bundleIdentifier: "com.example.\(name)",
            shortVersion: "1.0",
            buildNumber: "1",
            bundlePath: url.path,
            executableName: name,
            executablePath: url.appendingPathComponent("Contents/MacOS/\(name)").path,
            executableExists: true,
            diagnostics: []
        )
    }

    private func signatureInfo(signingIdentifier: String?, teamIdentifier: String?) -> CodeSignatureInfo {
        CodeSignatureInfo(
            signingIdentifier: signingIdentifier,
            teamIdentifier: teamIdentifier,
            authorities: [],
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

    private func jsonObject(from json: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    private func allowedObject(from object: [String: Any]) throws -> [String: Any] {
        let payload = try XCTUnwrap(object["Payload"] as? [String: Any])
        return try XCTUnwrap(payload["Allowed"] as? [String: Any])
    }
}

private final class PolicyApplicationPicker: PolicyApplicationPicking {
    private var results: [PolicyApplicationPickerResult]

    init(results: [PolicyApplicationPickerResult]) {
        self.results = results
    }

    @MainActor
    func selectApplications() async throws -> PolicyApplicationPickerResult {
        results.removeFirst()
    }
}

private final class PolicyMetadataInspector: ApplicationMetadataInspecting {
    private var results: [Result<ApplicationMetadata, ApplicationMetadataError>]

    init(results: [Result<ApplicationMetadata, ApplicationMetadataError>]) {
        self.results = results
    }

    func metadata(for applicationURL: URL) throws -> ApplicationMetadata {
        try results.removeFirst().get()
    }
}

private struct PolicyIconLoader: ApplicationIconLoading {
    func icon(for applicationURL: URL) throws -> NSImage {
        NSImage(size: NSSize(width: 32, height: 32))
    }
}

private actor PolicySignatureInspector: CodeSignatureInspecting {
    private var results: [Result<CodeSignatureInfo, CodeSignatureInspectionError>]
    private(set) var inspectedURLs: [URL] = []

    init(results: [Result<CodeSignatureInfo, CodeSignatureInspectionError>]) {
        self.results = results
    }

    func inspect(applicationAt applicationURL: URL) async throws -> CodeSignatureInfo {
        inspectedURLs.append(applicationURL)
        return try results.removeFirst().get()
    }
}

private final class PolicyClipboardWriter: ClipboardWriting {
    private(set) var copiedValues: [String] = []

    func copy(_ value: String) {
        copiedValues.append(value)
    }
}

@MainActor
private final class PolicyJSONExporter: JSONExporting {
    private let result: JSONExportResult
    private(set) var exportedJSON: String?
    private(set) var suggestedFilename: String?

    init(result: JSONExportResult) {
        self.result = result
    }

    func export(json: String, suggestedFilename: String) async throws -> JSONExportResult {
        exportedJSON = json
        self.suggestedFilename = suggestedFilename
        return result
    }
}
