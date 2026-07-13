import XCTest
@testable import AppSigningInspector

final class WorkspaceNavigationTests: XCTestCase {
    func testInspectorIsDefaultDestination() {
        XCTAssertEqual(WorkspaceDestination.defaultDestination, .inspector)
    }

    func testStorySixExposesOnlyApprovedSidebarDestinations() {
        XCTAssertEqual(WorkspaceDestination.allCases, [.inspector, .policyBuilder])
        XCTAssertEqual(WorkspaceDestination.inspector.title, "Inspector")
        XCTAssertEqual(WorkspaceDestination.inspector.systemImage, "doc.text.magnifyingglass")
        XCTAssertEqual(WorkspaceDestination.policyBuilder.title, "Policy Builder")
        XCTAssertEqual(WorkspaceDestination.policyBuilder.systemImage, "list.bullet.rectangle")
    }
}
