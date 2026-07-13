import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ApplicationBrowserViewModel()

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
                selectedApplicationView(selectedApplication)
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
            .accessibilityLabel(viewModel.hasSelectedApplication ? "Choose a different application" : "Select an application")

            Spacer()
        }
        .padding(32)
        .frame(minWidth: 520, minHeight: 320)
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
            copyExecutablePath: viewModel.copyExecutablePath
        )
    }
}

private struct SelectedApplicationDetailsView: View {
    let application: SelectedApplication
    let copyBundleIdentifier: () -> Void
    let copyBundlePath: () -> Void
    let copyExecutablePath: () -> Void

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

private struct CopyableMetadataRow: View {
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
