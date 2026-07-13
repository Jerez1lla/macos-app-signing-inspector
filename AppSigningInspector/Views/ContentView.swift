import SwiftUI

struct ContentView: View {
    @State private var selectedWorkspace: WorkspaceDestination? = .defaultDestination
    @StateObject private var inspectorViewModel: ApplicationBrowserViewModel
    @StateObject private var policyBuilderViewModel: PolicyBuilderViewModel

    init(
        inspectorViewModel: ApplicationBrowserViewModel = ApplicationBrowserViewModel(),
        policyBuilderViewModel: PolicyBuilderViewModel = PolicyBuilderViewModel()
    ) {
        _inspectorViewModel = StateObject(wrappedValue: inspectorViewModel)
        _policyBuilderViewModel = StateObject(wrappedValue: policyBuilderViewModel)
    }

    var body: some View {
        NavigationSplitView {
            List(WorkspaceDestination.allCases, selection: $selectedWorkspace) { destination in
                Label(destination.title, systemImage: destination.systemImage)
                    .tag(destination)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 140, ideal: 165, max: 200)
        } detail: {
            switch selectedWorkspace ?? .defaultDestination {
            case .inspector:
                InspectorView(viewModel: inspectorViewModel)
            case .policyBuilder:
                PolicyBuilderView(viewModel: policyBuilderViewModel)
            }
        }
        .frame(minWidth: 620, minHeight: 560)
    }
}

private struct InspectorView: View {
    @ObservedObject var viewModel: ApplicationBrowserViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("App Signing Inspector")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text("Inspect macOS app signing details and prepare DDM binary-management values.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if let selectedApplication = viewModel.selectedApplication {
                ScrollView {
                    selectedApplicationView(selectedApplication)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if viewModel.isLoading {
                loadingStateView
            } else {
                emptyStateView
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Application selection error: \(errorMessage)")
            }

            Button(viewModel.hasSelectedApplication ? "Choose Different Application" : "Select Application") {
                Task {
                    await viewModel.selectApplication()
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(
                viewModel.isLoading
                    || viewModel.isInspectingCodeSignature
                    || viewModel.isValidatingSecurity
            )
            .accessibilityLabel(viewModel.hasSelectedApplication ? "Choose a different application" : "Select an application")

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("No application selected", systemImage: "app.dashed")
                .font(.headline)

            Text("Select a macOS .app bundle to begin.")
                .foregroundStyle(.secondary)
        }
    }

    private var loadingStateView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)

            Text("Reading application metadata...")
                .foregroundStyle(.secondary)
        }
    }

    private func selectedApplicationView(_ application: SelectedApplication) -> some View {
        SelectedApplicationDetailsView(
            application: application,
            copyBundleIdentifier: viewModel.copyBundleIdentifier,
            copyBundlePath: viewModel.copyBundlePath,
            copyExecutablePath: viewModel.copyExecutablePath,
            codeSignatureInfo: viewModel.codeSignatureInfo,
            isInspectingCodeSignature: viewModel.isInspectingCodeSignature,
            signatureErrorMessage: viewModel.signatureErrorMessage,
            signatureErrorDetails: viewModel.signatureErrorDetails,
            copySigningIdentifier: viewModel.copySigningIdentifier,
            copyTeamIdentifier: viewModel.copyTeamIdentifier,
            copyDesignatedRequirement: viewModel.copyDesignatedRequirement,
            copySigningAuthority: viewModel.copySigningAuthority,
            copyRawSigningDiagnostics: viewModel.copyRawSigningDiagnostics,
            copySignatureErrorDetails: viewModel.copySignatureErrorDetails,
            securityAssessment: viewModel.securityAssessment,
            isValidatingSecurity: viewModel.isValidatingSecurity,
            securityErrorMessage: viewModel.securityErrorMessage,
            copyGatekeeperSource: viewModel.copyGatekeeperSource,
            copyGatekeeperRejectionReason: viewModel.copyGatekeeperRejectionReason,
            copyArchitectureList: viewModel.copyArchitectureList,
            copyRawGatekeeperDiagnostics: viewModel.copyRawGatekeeperDiagnostics,
            copyRawArchitectureDiagnostics: viewModel.copyRawArchitectureDiagnostics
        )
    }
}

private struct SelectedApplicationDetailsView: View {
    let application: SelectedApplication
    let copyBundleIdentifier: () -> Void
    let copyBundlePath: () -> Void
    let copyExecutablePath: () -> Void
    let codeSignatureInfo: CodeSignatureInfo?
    let isInspectingCodeSignature: Bool
    let signatureErrorMessage: String?
    let signatureErrorDetails: String?
    let copySigningIdentifier: () -> Void
    let copyTeamIdentifier: () -> Void
    let copyDesignatedRequirement: () -> Void
    let copySigningAuthority: (String) -> Void
    let copyRawSigningDiagnostics: () -> Void
    let copySignatureErrorDetails: () -> Void
    let securityAssessment: ApplicationSecurityAssessment?
    let isValidatingSecurity: Bool
    let securityErrorMessage: String?
    let copyGatekeeperSource: () -> Void
    let copyGatekeeperRejectionReason: () -> Void
    let copyArchitectureList: () -> Void
    let copyRawGatekeeperDiagnostics: () -> Void
    let copyRawArchitectureDiagnostics: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ApplicationHeaderView(application: application)

            MetadataDetailsView(
                metadata: application.metadata,
                copyBundleIdentifier: copyBundleIdentifier,
                copyBundlePath: copyBundlePath,
                copyExecutablePath: copyExecutablePath
            )

            MetadataDiagnosticsView(diagnostics: application.metadata.diagnostics)

            Divider()

            CodeSigningSectionView(
                signatureInfo: codeSignatureInfo,
                isLoading: isInspectingCodeSignature,
                errorMessage: signatureErrorMessage,
                errorDetails: signatureErrorDetails,
                copySigningIdentifier: copySigningIdentifier,
                copyTeamIdentifier: copyTeamIdentifier,
                copyDesignatedRequirement: copyDesignatedRequirement,
                copyAuthority: copySigningAuthority,
                copyRawDiagnostics: copyRawSigningDiagnostics,
                copyErrorDetails: copySignatureErrorDetails
            )

            Divider()

            SecuritySectionView(
                assessment: securityAssessment,
                isLoading: isValidatingSecurity,
                errorMessage: securityErrorMessage,
                copyGatekeeperSource: copyGatekeeperSource,
                copyGatekeeperRejectionReason: copyGatekeeperRejectionReason,
                copyArchitectureList: copyArchitectureList,
                copyRawGatekeeperDiagnostics: copyRawGatekeeperDiagnostics,
                copyRawArchitectureDiagnostics: copyRawArchitectureDiagnostics
            )
        }
    }
}

private struct CodeSigningSectionView: View {
    let signatureInfo: CodeSignatureInfo?
    let isLoading: Bool
    let errorMessage: String?
    let errorDetails: String?
    let copySigningIdentifier: () -> Void
    let copyTeamIdentifier: () -> Void
    let copyDesignatedRequirement: () -> Void
    let copyAuthority: (String) -> Void
    let copyRawDiagnostics: () -> Void
    let copyErrorDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Code Signing")
                .font(.headline)

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Inspecting code signature...")
                        .foregroundStyle(.secondary)
                }
            } else if let signatureInfo {
                CodeSignatureDetailsView(
                    signatureInfo: signatureInfo,
                    copySigningIdentifier: copySigningIdentifier,
                    copyTeamIdentifier: copyTeamIdentifier,
                    copyDesignatedRequirement: copyDesignatedRequirement,
                    copyAuthority: copyAuthority,
                    copyRawDiagnostics: copyRawDiagnostics
                )
            } else if let errorMessage {
                SignatureErrorView(
                    message: errorMessage,
                    details: errorDetails,
                    copyDetails: copyErrorDetails
                )
            }
        }
    }
}

private struct CodeSignatureDetailsView: View {
    let signatureInfo: CodeSignatureInfo
    let copySigningIdentifier: () -> Void
    let copyTeamIdentifier: () -> Void
    let copyDesignatedRequirement: () -> Void
    let copyAuthority: (String) -> Void
    let copyRawDiagnostics: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SignatureStatusView(status: signatureInfo.signatureStatus)

            CodeSignatureSummaryGrid(
                signatureInfo: signatureInfo,
                copySigningIdentifier: copySigningIdentifier,
                copyTeamIdentifier: copyTeamIdentifier
            )

            DesignatedRequirementView(
                inspection: signatureInfo.designatedRequirementInspection,
                copyAction: copyDesignatedRequirement
            )

            SigningAuthoritiesView(
                authorities: signatureInfo.authorities,
                copyAuthority: copyAuthority
            )

            SignatureDiagnosticsView(diagnostics: signatureInfo.diagnostics)

            DiagnosticDetailsView(
                title: "Raw signing diagnostics",
                details: signatureInfo.rawDiagnostics,
                copyAction: copyRawDiagnostics
            )
        }
    }

}

private struct DesignatedRequirementView: View {
    let inspection: DesignatedRequirementInspection?
    let copyAction: () -> Void

    private var statusText: String {
        inspection?.status.displayValue ?? "Unavailable"
    }

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                if let requirement = inspection?.requirement {
                    Text(requirement)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: copyAction) {
                        Label("Copy Designated Requirement", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                } else {
                    Text(statusText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("Designated Requirement")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(statusText)
                    .font(.callout)
            }
        }
    }
}

private struct SignatureStatusView: View {
    let status: CodeSignatureStatus

    var body: some View {
        switch status {
        case .valid:
            Label("The application has a valid code signature.", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
        case .unsigned:
            Label(
                "The application is unsigned. Signing ID and Team ID are unavailable.",
                systemImage: "exclamationmark.triangle"
            )
            .foregroundStyle(.orange)
        case .invalid:
            Label(
                "The application signature is invalid. Review the diagnostic details.",
                systemImage: "xmark.seal.fill"
            )
            .foregroundStyle(.red)
        }
    }
}

private struct CodeSignatureSummaryGrid: View {
    let signatureInfo: CodeSignatureInfo
    let copySigningIdentifier: () -> Void
    let copyTeamIdentifier: () -> Void

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            CopyableMetadataRow(
                label: "Signing ID",
                value: signatureInfo.signingIdentifierDisplayValue,
                copyAction: signatureInfo.signingIdentifier == nil ? nil : copySigningIdentifier
            )
            CopyableMetadataRow(
                label: "Team ID",
                value: signatureInfo.teamIdentifierDisplayValue,
                copyAction: signatureInfo.teamIdentifier == nil ? nil : copyTeamIdentifier
            )
            CopyableMetadataRow(label: "Signed Status", value: signatureInfo.signatureStatus.displayValue)
            CopyableMetadataRow(label: "Signature Format", value: signatureInfo.formatDisplayValue)
            CopyableMetadataRow(
                label: "Code Directory Version",
                value: signatureInfo.codeDirectoryVersionDisplayValue
            )
            CopyableMetadataRow(label: "Code-signing Flags", value: signatureInfo.flagsDisplayValue)
            CopyableMetadataRow(label: "Hardened Runtime", value: signatureInfo.hardenedRuntimeDisplayValue)
            CopyableMetadataRow(label: "Signature Timestamp", value: signatureInfo.timestampDisplayValue)
            CopyableMetadataRow(label: "Signing Origin", value: signatureInfo.signingOrigin.displayValue)
            CopyableMetadataRow(label: "Apple-signed", value: signatureInfo.appleSignedDisplayValue)
        }
    }
}

private struct SigningAuthoritiesView: View {
    let authorities: [String]
    let copyAuthority: (String) -> Void

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            if authorities.isEmpty {
                CopyableMetadataRow(label: "Signing Authority", value: "Unavailable")
            } else {
                ForEach(authorities.indices, id: \.self) { index in
                    AuthorityRow(
                        label: authorityLabel(for: index),
                        authority: authorities[index],
                        copyAction: copyAuthority
                    )
                }
            }
        }
    }

    private func authorityLabel(for index: Int) -> String {
        authorities.count > 1 ? "Signing Authority \(index + 1)" : "Signing Authority"
    }
}

private struct AuthorityRow: View {
    let label: String
    let authority: String
    let copyAction: (String) -> Void

    var body: some View {
        CopyableMetadataRow(
            label: label,
            value: authority,
            copyAction: { copyAction(authority) }
        )
    }
}

private struct SignatureDiagnosticsView: View {
    let diagnostics: [CodeSignatureDiagnostic]

    var body: some View {
        if !diagnostics.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(diagnostics.map(\.message), id: \.self) { message in
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

private struct SignatureErrorView: View {
    let message: String
    let details: String?
    let copyDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)

            if let details, !details.isEmpty {
                DiagnosticDetailsView(
                    title: "Diagnostic details",
                    details: details,
                    copyAction: copyDetails
                )
            }
        }
    }
}

struct DiagnosticDetailsView: View {
    let title: String
    let details: String
    let copyAction: () -> Void

    var body: some View {
        DisclosureGroup(title) {
            VStack(alignment: .leading, spacing: 8) {
                Text(details)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: copyAction) {
                    Label("Copy Diagnostics", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
            }
            .padding(.top, 8)
        }
    }
}

private struct ApplicationHeaderView: View {
    let application: SelectedApplication

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(nsImage: application.icon)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Label("Application selected", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                Text(application.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(application.path)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .accessibilityLabel("Application path: \(application.path)")
            }
        }
    }
}

private struct MetadataDetailsView: View {
    let metadata: ApplicationMetadata
    let copyBundleIdentifier: () -> Void
    let copyBundlePath: () -> Void
    let copyExecutablePath: () -> Void

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            CopyableMetadataRow(
                label: "Bundle Identifier",
                value: metadata.bundleIdentifierDisplayValue,
                copyAction: metadata.bundleIdentifier == nil ? nil : copyBundleIdentifier
            )
            CopyableMetadataRow(label: "Version", value: metadata.versionDisplayValue)
            CopyableMetadataRow(label: "Build", value: metadata.buildDisplayValue)
            CopyableMetadataRow(label: "Executable", value: metadata.executableNameDisplayValue)
            CopyableMetadataRow(
                label: "Executable Path",
                value: metadata.executablePathDisplayValue,
                copyAction: metadata.executablePath == nil ? nil : copyExecutablePath
            )
            CopyableMetadataRow(
                label: "Bundle Path",
                value: metadata.bundlePath,
                copyAction: copyBundlePath
            )
        }
    }
}

struct CopyableMetadataRow: View {
    let label: String
    let value: String
    let copyAction: (() -> Void)?

    init(label: String, value: String, copyAction: (() -> Void)? = nil) {
        self.label = label
        self.value = value
        self.copyAction = copyAction
    }

    var body: some View {
        GridRow {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.callout)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
                .accessibilityLabel("\(label): \(value)")

            copyButton
        }
    }

    @ViewBuilder
    private var copyButton: some View {
        if let copyAction {
            Button("Copy", action: copyAction)
                .buttonStyle(.borderless)
                .accessibilityLabel("Copy \(label)")
        }
    }
}

private struct MetadataDiagnosticsView: View {
    let diagnostics: [ApplicationMetadataDiagnostic]

    private var messages: [String] {
        diagnostics.map(\.message)
    }

    var body: some View {
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(messages, id: \.self) { message in
                    Label(message, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
