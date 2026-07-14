import XCTest
@testable import AppSigningInspector

final class ReleaseReadinessTests: XCTestCase {
    @MainActor
    func testWorkspaceControllerDefaultsToInspectorAndPreservesViewModels() {
        let controller = AppWorkspaceController()
        let inspectorViewModel = controller.inspectorViewModel
        let policyBuilderViewModel = controller.policyBuilderViewModel

        XCTAssertEqual(controller.activeWorkspace, .inspector)

        controller.selectWorkspace(.policyBuilder)
        controller.selectWorkspace(.inspector)

        XCTAssertIdentical(controller.inspectorViewModel, inspectorViewModel)
        XCTAssertIdentical(controller.policyBuilderViewModel, policyBuilderViewModel)
    }

    @MainActor
    func testPolicyCommandsAreUnavailableOutsidePolicyBuilder() {
        let controller = AppWorkspaceController()

        XCTAssertFalse(controller.canCopyPolicyJSON)
        XCTAssertFalse(controller.canExportPolicyJSON)

        controller.selectWorkspace(.policyBuilder)

        XCTAssertFalse(controller.canCopyPolicyJSON)
        XCTAssertFalse(controller.canExportPolicyJSON)
    }

    func testVersionInfoReadsGeneratedBundleValues() {
        let versionInfo = AppVersionInfo(infoDictionary: [
            "CFBundleDisplayName": "App Signing Inspector",
            "CFBundleShortVersionString": "1.0.0",
            "CFBundleVersion": "1"
        ])

        XCTAssertEqual(versionInfo.displayName, "App Signing Inspector")
        XCTAssertEqual(versionInfo.marketingVersion, "1.0.0")
        XCTAssertEqual(versionInfo.buildNumber, "1")
        XCTAssertEqual(versionInfo.versionDescription, "Version 1.0.0 (1)")
    }
}
