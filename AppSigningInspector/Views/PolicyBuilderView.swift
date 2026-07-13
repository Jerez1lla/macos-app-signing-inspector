import SwiftUI

struct PolicyBuilderView: View {
    @ObservedObject var viewModel: PolicyBuilderViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let warning = viewModel.allowOnlySafetyWarning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

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
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Policy Builder")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("macOS application execution declaration")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await viewModel.addApplications() }
            } label: {
                Label("Add Applications", systemImage: "plus")
            }
            .disabled(viewModel.isAddingApplications || viewModel.isExporting)
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
                Label("No applications in this policy", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Text("Add one or more macOS applications to begin.")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
        } else {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.entries) { entry in
                    PolicyEntryRow(
                        entry: entry,
                        setAction: { viewModel.setAction($0, for: entry.id) },
                        removeAction: { viewModel.removeEntry(id: entry.id) }
                    )
                }
            }
        }
    }
}

private struct PolicyEntryRow: View {
    let entry: PolicyEntry
    let setAction: (PolicyAction) -> Void
    let removeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(nsImage: entry.icon)
                    .resizable()
                    .frame(width: 42, height: 42)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(entry.applicationURL.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 8)

                Picker("Action", selection: Binding(
                    get: { entry.action },
                    set: setAction
                )) {
                    ForEach(PolicyAction.allCases, id: \.self) { action in
                        Text(action.displayValue).tag(action)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 130)

                Button(action: removeAction) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove application")
                .accessibilityLabel("Remove \(entry.displayName)")
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
                PolicyValueRow(label: "Signing ID", value: entry.signingIdentifier ?? "Unavailable")
                PolicyValueRow(label: "Team ID", value: entry.teamIdentifier ?? "Unavailable")
            }

            if let message = entry.validationState.message {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
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
                        .foregroundStyle(.orange)
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
