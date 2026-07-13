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

    private func selectedApplicationView(_ application: SelectedApplication) -> some View {
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

#Preview {
    ContentView()
}
