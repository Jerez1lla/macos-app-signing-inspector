import XCTest
@testable import AppSigningInspector

final class WorkspaceNavigationTests: XCTestCase {
    func testInspectorIsDefaultDestination() {
        XCTAssertEqual(WorkspaceDestination.defaultDestination, .inspector)
    }

    @MainActor
    func testSidebarIsVisibleByDefaultAndRemainsUserControllable() {
        let controller = AppWorkspaceController()

        XCTAssertEqual(controller.columnVisibility, .all)

        controller.columnVisibility = .detailOnly

        XCTAssertEqual(controller.columnVisibility, .detailOnly)
    }

    @MainActor
    func testSwitchingBetweenWorkspacesUpdatesTheActiveDestination() {
        let controller = AppWorkspaceController()

        controller.selectWorkspace(.policyBuilder)
        XCTAssertEqual(controller.activeWorkspace, .policyBuilder)

        controller.selectWorkspace(.inspector)
        XCTAssertEqual(controller.activeWorkspace, .inspector)
    }

    func testStorySixExposesOnlyApprovedSidebarDestinations() {
        XCTAssertEqual(WorkspaceDestination.allCases, [.inspector, .policyBuilder])
        XCTAssertEqual(WorkspaceDestination.inspector.title, "Inspector")
        XCTAssertEqual(WorkspaceDestination.inspector.systemImage, "doc.text.magnifyingglass")
        XCTAssertEqual(WorkspaceDestination.policyBuilder.title, "Policy Builder")
        XCTAssertEqual(WorkspaceDestination.policyBuilder.systemImage, "list.bullet.rectangle")
    }
}
