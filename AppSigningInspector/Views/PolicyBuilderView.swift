import SwiftUI

struct PolicyBuilderView: View {
    @ObservedObject var viewModel: PolicyBuilderViewModel
    @State private var editingEntry: PolicyEntry?
    @State private var isAddingDeveloperTeam = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                PolicyOptionsView(
                    alwaysAllowManagedApps: Binding(
                        get: { viewModel.alwaysAllowManagedApps },
                        set: viewModel.setAlwaysAllowManagedApps
                    ),
                    allowAllAppleBinaries: Binding(
                        get: { viewModel.allowsAllAppleBinaries },
                        set: viewModel.setAllowAllAppleBinaries
                    ),
                    isBusy: viewModel.isPerformingPolicyOperation,
                    addJamfRule: {
                        Task { await viewModel.selectJamfDeveloperApplication() }
                    }
                )

                PolicySafetyWarningsView(warnings: viewModel.safetyWarnings)

                PolicyBuilderMessagesView(
                    notices: viewModel.notices,
                    workflowErrorMessage: viewModel.workflowErrorMessage,
                    exportStatusMessage: viewModel.exportStatusMessage
                )

                policyEntries

                Divider()

                DeclarationPreviewView(
                    json: viewModel.jsonPreview,
                    errorMessage: viewModel.generationErrorMessage,
                    canExport: viewModel.canExport,
                    isExporting: viewModel.isExporting,
                    copyAction: viewModel.copyGeneratedJSON,
                    exportAction: {
                        Task { await viewModel.exportGeneratedJSON() }
                    }
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $editingEntry) { entry in
            PolicyRuleEditorView(entry: entry) { rule, action in
                viewModel.updateRule(rule, action: action, for: entry.id)
            }
        }
        .sheet(isPresented: $isAddingDeveloperTeam) {
            DeveloperTeamRuleSheet { teamIdentifier in
                viewModel.addDeveloperTeamRule(teamIdentifier: teamIdentifier)
            }
        }
        .sheet(item: Binding(
            get: { viewModel.pendingJamfTeamRule },
            set: { candidate in
                if candidate == nil {
                    viewModel.cancelJamfDeveloperTeamRule()
                }
            }
        )) { candidate in
            JamfDeveloperRuleConfirmationView(
                candidate: candidate,
                confirm: viewModel.confirmJamfDeveloperTeamRule,
                cancel: viewModel.cancelJamfDeveloperTeamRule
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Policy Builder")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("macOS application execution declaration")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    isAddingDeveloperTeam = true
                } label: {
                    Label("Add Developer Team", systemImage: "person.2.badge.plus")
                }
                .disabled(viewModel.isPerformingPolicyOperation)

                Button {
                    Task { await viewModel.addApplications() }
                } label: {
                    Label("Add Applications", systemImage: "plus")
                }
                .disabled(viewModel.isPerformingPolicyOperation)
                .accessibilityIdentifier("policyBuilder.addApplications")
            }
        }
    }

    @ViewBuilder
    private var policyEntries: some View {
        if viewModel.isAddingApplications {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Inspecting selected applications...")
                    .foregroundStyle(.secondary)
            }
        }

        if viewModel.isPreparingJamfRule {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Inspecting the selected application's signing identity...")
                    .foregroundStyle(.secondary)
            }
        }

        if viewModel.entries.isEmpty,
           !viewModel.isAddingApplications,
           !viewModel.isPreparingJamfRule {
            VStack(alignment: .leading, spacing: 8) {
                Label("No binary rules in this policy", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Text("Add applications, a developer Team ID, or a supported policy option.")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
        } else {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.entries) { entry in
                    PolicyEntryRow(
                        entry: entry,
                        editAction: { editingEntry = entry },
                        removeAction: { viewModel.removeEntry(id: entry.id) }
                    )
                }
            }
        }
    }
}

private struct PolicyOptionsView: View {
    @Binding var alwaysAllowManagedApps: Bool
    @Binding var allowAllAppleBinaries: Bool
    let isBusy: Bool
    let addJamfRule: () -> Void

    var body: some View {
        GroupBox("Policy Options") {
            VStack(alignment: .leading, spacing: 14) {
                option(
                    title: "Always Allow Managed Apps",
                    visibleDescription: "Permits applications that macOS recognizes as managed.",
                    isOn: $alwaysAllowManagedApps
                )

                Divider()

                option(
                    title: "Allow All Apple Binaries",
                    visibleDescription: PolicyBuilderCopy.allowAllAppleVisibleDescription,
                    isOn: $allowAllAppleBinaries,
                    accessibilityHelp: PolicyBuilderCopy.allowAllAppleAccessibilityHelp
                )

                Divider()

                VStack(alignment: .leading, spacing: 3) {
                    Button(action: addJamfRule) {
                        Label("Allow All Jamf Binaries", systemImage: "building.2")
                    }
                    .disabled(isBusy)
                    .accessibilityIdentifier("policyBuilder.allowAllJamfBinaries")

                    Text("Select a signed Jamf application to detect and confirm its actual Team ID.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private func option(
        title: String,
        visibleDescription: String?,
        isOn: Binding<Bool>,
        accessibilityHelp: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(title, isOn: isOn)
                .help(accessibilityHelp ?? visibleDescription ?? "Changes this policy option.")
            if let visibleDescription {
                Text(visibleDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PolicyEntryRow: View {
    let entry: PolicyEntry
    let editAction: () -> Void
    let removeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                entryIcon

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    if let sourceApplicationName = entry.sourceApplicationName {
                        Text("Source application: \(sourceApplicationName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if let applicationURL = entry.applicationURL {
                        Text(applicationURL.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }

                Spacer(minLength: 8)

                Text(entry.action.displayValue)
                    .font(.caption)
                    .fontWeight(.semibold)

                Button(action: editAction) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Edit rule")
                .accessibilityLabel("Edit \(entry.displayName)")

                Button(action: removeAction) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove rule")
                .accessibilityLabel("Remove \(entry.displayName)")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
                PolicyValueRow(label: "Rule Type", value: entry.rule.type.displayValue)
                if let signingIdentifier = entry.signingIdentifier {
                    PolicyValueRow(label: "Signing ID", value: signingIdentifier)
                }
                if let teamIdentifier = entry.teamIdentifier {
                    PolicyValueRow(label: "Team ID", value: teamIdentifier)
                }
                if let pathPrefix = entry.pathPrefix {
                    PolicyValueRow(label: "Path Prefix", value: pathPrefix)
                }
                if let signingAuthority = entry.signingAuthority {
                    PolicyValueRow(label: "Signing Authority", value: signingAuthority)
                }
            }

            if let message = entry.validationState.message {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .accessibilityLabel("Invalid policy rule: \(message)")
            }

            if let details = entry.validationState.diagnosticDetails, !details.isEmpty {
                DisclosureGroup("Inspection diagnostics") {
                    Text(details)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }
                .font(.caption)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var entryIcon: some View {
        if let icon = entry.icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 42, height: 42)
                .accessibilityHidden(true)
        } else {
            Image(systemName: entry.rule.type == .appleBinaries ? "apple.logo" : "person.2")
                .font(.title2)
                .frame(width: 42, height: 42)
                .accessibilityHidden(true)
        }
    }
}

enum PolicyBuilderCopy {
    static let allowAllAppleVisibleDescription: String? = nil
    static let allowAllAppleAccessibilityHelp = "Uses Apple's documented *APPLE* special Team ID rule."
}

private struct JamfDeveloperRuleConfirmationView: View {
    let candidate: JamfDeveloperTeamRuleCandidate
    let confirm: () -> Bool
    let cancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Allow All Jamf Binaries")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Allow all binaries signed by Team ID \(candidate.teamIdentifier)?")
                    .fixedSize(horizontal: false, vertical: true)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                PolicyValueRow(label: "Team ID", value: candidate.teamIdentifier)
                PolicyValueRow(label: "Source Application", value: candidate.sourceApplicationName)
                PolicyValueRow(
                    label: "Signing Authority",
                    value: candidate.signingAuthority ?? "Unavailable"
                )
            }

            Label(
                "This Team-ID-only rule may allow every binary signed by that developer, not only the selected application.",
                systemImage: "exclamationmark.triangle"
            )
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Cancel") {
                    cancel()
                    dismiss()
                }
                Button("Add Rule") {
                    if confirm() {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}

private struct PolicyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }
}

private struct PolicySafetyWarningsView: View {
    let warnings: [String]

    @ViewBuilder
    var body: some View {
        if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Policy safety warnings: \(warnings.joined(separator: " "))")
        }
    }
}

private struct PolicyBuilderMessagesView: View {
    let notices: [PolicyBuilderNotice]
    let workflowErrorMessage: String?
    let exportStatusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(notices.indices, id: \.self) { index in
                let notice = notices[index]
                VStack(alignment: .leading, spacing: 3) {
                    Label(notice.message, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                    if let details = notice.diagnosticDetails {
                        Text(details)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }

            if let workflowErrorMessage {
                Label(workflowErrorMessage, systemImage: "xmark.circle")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Policy builder error: \(workflowErrorMessage)")
            }

            if let exportStatusMessage {
                Label(exportStatusMessage, systemImage: "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(.green)
                    .accessibilityLabel("Policy builder status: \(exportStatusMessage)")
            }
        }
    }
}

private struct DeclarationPreviewView: View {
    let json: String?
    let errorMessage: String?
    let canExport: Bool
    let isExporting: Bool
    let copyAction: () -> Void
    let exportAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Declaration JSON")
                    .font(.headline)
                Spacer()
                Button(action: copyAction) {
                    Label("Copy JSON", systemImage: "doc.on.doc")
                }
                .disabled(!canExport)
                .accessibilityIdentifier("policyBuilder.copyJSON")

                Button(action: exportAction) {
                    Label("Export JSON", systemImage: "square.and.arrow.up")
                }
                .disabled(!canExport)
                .accessibilityIdentifier("policyBuilder.exportJSON")
            }

            if let json {
                ScrollView([.horizontal, .vertical]) {
                    Text(json)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(minHeight: 150, maxHeight: 240)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
            } else if let errorMessage {
                Label(errorMessage, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if isExporting {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}
