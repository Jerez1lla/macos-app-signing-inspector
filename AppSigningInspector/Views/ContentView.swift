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
        VStack(alignment: .leading, spacing: 16) {
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

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                metadataRow(
                    label: "Bundle Identifier",
                    value: application.metadata.bundleIdentifierDisplayValue,
                    copyAction: application.metadata.bundleIdentifier == nil ? nil : viewModel.copyBundleIdentifier
                )
                metadataRow(label: "Version", value: application.metadata.versionDisplayValue)
                metadataRow(label: "Build", value: application.metadata.buildDisplayValue)
                metadataRow(label: "Executable", value: application.metadata.executableNameDisplayValue)
                metadataRow(
                    label: "Executable Path",
                    value: application.metadata.executablePathDisplayValue,
                    copyAction: application.metadata.executablePath == nil ? nil : viewModel.copyExecutablePath
                )
                metadataRow(
                    label: "Bundle Path",
                    value: application.metadata.bundlePath,
                    copyAction: viewModel.copyBundlePath
                )
            }

            if !application.metadata.diagnostics.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(application.metadata.diagnostics.map(\.message), id: \.self) { message in
                        Label(message, systemImage: "info.circle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func metadataRow(
        label: String,
        value: String,
        copyAction: (() -> Void)? = nil
    ) -> some View {
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

            if let copyAction {
                Button("Copy", action: copyAction)
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Copy \(label)")
            } else {
                EmptyView()
            }
        }
    }
}

#Preview {
    ContentView()
}
