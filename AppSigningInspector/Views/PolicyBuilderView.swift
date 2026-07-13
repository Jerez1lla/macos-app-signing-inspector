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
                    )
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
                .disabled(viewModel.isAddingApplications || viewModel.isExporting)

                Button {
                    Task { await viewModel.addApplications() }
                } label: {
                    Label("Add Applications", systemImage: "plus")
                }
                .disabled(viewModel.isAddingApplications || viewModel.isExporting)
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

        if viewModel.entries.isEmpty, !viewModel.isAddingApplications {
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

    var body: some View {
        GroupBox("Policy Options") {
            VStack(alignment: .leading, spacing: 14) {
                option(
                    title: "Always Allow Managed Apps",
                    description: "Permits applications that macOS recognizes as managed.",
                    isOn: $alwaysAllowManagedApps
                )

                Divider()

                option(
                    title: "Allow All Apple Binaries",
                    description: "Adds Apple's documented *APPLE* special Team ID rule.",
                    isOn: $allowAllAppleBinaries
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private func option(
        title: String,
        description: String,
        isOn: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(title, isOn: isOn)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct PolicySafetyWarningsView: View {
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
            }

            if let exportStatusMessage {
                Label(exportStatusMessage, systemImage: "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(.green)
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

                Button(action: exportAction) {
                    Label("Export JSON", systemImage: "square.and.arrow.up")
                }
                .disabled(!canExport)
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
