import AppKit
import SwiftUI

struct AboutView: View {
    let versionInfo: AppVersionInfo
    private let repositoryURL = URL(string: "https://github.com/Jerez1lla/macos-app-signing-inspector")

    init(versionInfo: AppVersionInfo = .current) {
        self.versionInfo = versionInfo
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(versionInfo.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(versionInfo.versionDescription)
                    .foregroundStyle(.secondary)
            }

            Text("Inspect macOS application signing details and build DDM application execution declarations.")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Platform")
                        .foregroundStyle(.secondary)
                    Text("macOS")
                }
                GridRow {
                    Text("License")
                        .foregroundStyle(.secondary)
                    Text("MIT")
                }
            }

            if let repositoryURL {
                Link("View Public Repository", destination: repositoryURL)
            }

            Text("Copyright 2026 Jerez1lla. Released under the MIT License.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 420)
    }
}
