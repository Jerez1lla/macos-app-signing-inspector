import SwiftUI

struct ContentView: View {
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

            VStack(alignment: .leading, spacing: 12) {
                Label("No application selected", systemImage: "app.dashed")
                    .font(.headline)

                Text("Application inspection will be added in a later story.")
                    .foregroundStyle(.secondary)
            }

            Button("Select Application") { }
                .disabled(true)

            Spacer()
        }
        .padding(32)
        .frame(minWidth: 520, minHeight: 320)
    }
}

#Preview {
    ContentView()
}
