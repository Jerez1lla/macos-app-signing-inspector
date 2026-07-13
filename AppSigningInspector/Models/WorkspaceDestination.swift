import Foundation

enum WorkspaceDestination: String, CaseIterable, Hashable, Identifiable {
    case inspector
    case policyBuilder

    static let defaultDestination: WorkspaceDestination = .inspector

    var id: Self { self }

    var title: String {
        switch self {
        case .inspector:
            return "Inspector"
        case .policyBuilder:
            return "Policy Builder"
        }
    }

    var systemImage: String {
        switch self {
        case .inspector:
            return "doc.text.magnifyingglass"
        case .policyBuilder:
            return "list.bullet.rectangle"
        }
    }
}
