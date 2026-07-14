import Combine
import Foundation

@MainActor
final class AppWorkspaceController: ObservableObject {
    @Published var selectedWorkspace: WorkspaceDestination? = .defaultDestination

    let inspectorViewModel: ApplicationBrowserViewModel
    let policyBuilderViewModel: PolicyBuilderViewModel

    init(
        inspectorViewModel: ApplicationBrowserViewModel = ApplicationBrowserViewModel(),
        policyBuilderViewModel: PolicyBuilderViewModel = PolicyBuilderViewModel()
    ) {
        self.inspectorViewModel = inspectorViewModel
        self.policyBuilderViewModel = policyBuilderViewModel
    }

    var activeWorkspace: WorkspaceDestination {
        selectedWorkspace ?? .defaultDestination
    }

    var primaryActionTitle: String {
        switch activeWorkspace {
        case .inspector:
            return inspectorViewModel.hasSelectedApplication
                ? "Choose Different Application..."
                : "Select Application..."
        case .policyBuilder:
            return "Add Applications..."
        }
    }

    var canPerformPrimaryAction: Bool {
        switch activeWorkspace {
        case .inspector:
            return !inspectorViewModel.isLoading
                && !inspectorViewModel.isInspectingCodeSignature
                && !inspectorViewModel.isValidatingSecurity
        case .policyBuilder:
            return !policyBuilderViewModel.isPerformingPolicyOperation
        }
    }

    var canCopyPolicyJSON: Bool {
        activeWorkspace == .policyBuilder && policyBuilderViewModel.canExport
    }

    var canExportPolicyJSON: Bool {
        canCopyPolicyJSON
    }

    func selectWorkspace(_ destination: WorkspaceDestination) {
        selectedWorkspace = destination
    }

    func performPrimaryAction() async {
        guard canPerformPrimaryAction else {
            return
        }
        switch activeWorkspace {
        case .inspector:
            await inspectorViewModel.selectApplication()
        case .policyBuilder:
            await policyBuilderViewModel.addApplications()
        }
    }

    func copyPolicyJSON() {
        guard canCopyPolicyJSON else {
            return
        }
        policyBuilderViewModel.copyGeneratedJSON()
    }

    func exportPolicyJSON() async {
        guard canExportPolicyJSON else {
            return
        }
        await policyBuilderViewModel.exportGeneratedJSON()
    }
}
