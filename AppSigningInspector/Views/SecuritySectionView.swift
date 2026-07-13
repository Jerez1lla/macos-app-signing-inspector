import SwiftUI

struct SecuritySectionView: View {
    let assessment: ApplicationSecurityAssessment?
    let isLoading: Bool
    let errorMessage: String?
    let copyGatekeeperSource: () -> Void
    let copyGatekeeperRejectionReason: () -> Void
    let copyArchitectureList: () -> Void
    let copyRawGatekeeperDiagnostics: () -> Void
    let copyRawArchitectureDiagnostics: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Security")
                .font(.headline)

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Validating Gatekeeper and architecture support...")
                        .foregroundStyle(.secondary)
                }
            } else if let assessment {
                SecurityAssessmentDetailsView(
                    assessment: assessment,
                    errorMessage: errorMessage,
                    copyGatekeeperSource: copyGatekeeperSource,
                    copyGatekeeperRejectionReason: copyGatekeeperRejectionReason,
                    copyArchitectureList: copyArchitectureList,
                    copyRawGatekeeperDiagnostics: copyRawGatekeeperDiagnostics,
                    copyRawArchitectureDiagnostics: copyRawArchitectureDiagnostics
                )
            }
        }
    }
}

private struct SecurityAssessmentDetailsView: View {
    let assessment: ApplicationSecurityAssessment
    let errorMessage: String?
    let copyGatekeeperSource: () -> Void
    let copyGatekeeperRejectionReason: () -> Void
    let copyArchitectureList: () -> Void
    let copyRawGatekeeperDiagnostics: () -> Void
    let copyRawArchitectureDiagnostics: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SecurityValidationSummaryView(status: assessment.validationStatus)

            SecurityAssessmentGrid(
                assessment: assessment,
                copyGatekeeperSource: copyGatekeeperSource,
                copyGatekeeperRejectionReason: copyGatekeeperRejectionReason,
                copyArchitectureList: copyArchitectureList
            )

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Security assessment warning: \(errorMessage)")
            }

            if let diagnostics = assessment.gatekeeper.rawDiagnostics, !diagnostics.isEmpty {
                DiagnosticDetailsView(
                    title: "Raw Gatekeeper diagnostics",
                    details: diagnostics,
                    copyAction: copyRawGatekeeperDiagnostics
                )
            }

            if let diagnostics = assessment.architecture.rawDiagnostics, !diagnostics.isEmpty {
                DiagnosticDetailsView(
                    title: "Raw architecture diagnostics",
                    details: diagnostics,
                    copyAction: copyRawArchitectureDiagnostics
                )
            }
        }
    }
}

private struct SecurityValidationSummaryView: View {
    let status: SecurityValidationStatus

    private var symbolName: String {
        switch status {
        case .accepted:
            return "checkmark.shield.fill"
        case .rejected:
            return "xmark.shield.fill"
        case .partial:
            return "exclamationmark.shield.fill"
        case .unavailable:
            return "questionmark.diamond.fill"
        }
    }

    private var color: Color {
        switch status {
        case .accepted:
            return .green
        case .rejected:
            return .red
        case .partial:
            return .orange
        case .unavailable:
            return .secondary
        }
    }

    var body: some View {
        Label(status.displayValue, systemImage: symbolName)
            .foregroundStyle(color)
            .accessibilityLabel("Security validation status: \(status.displayValue)")
    }
}

private struct SecurityAssessmentGrid: View {
    let assessment: ApplicationSecurityAssessment
    let copyGatekeeperSource: () -> Void
    let copyGatekeeperRejectionReason: () -> Void
    let copyArchitectureList: () -> Void

    private var universalDisplayValue: String {
        guard assessment.architecture.status == .available else {
            return "Unavailable"
        }
        switch assessment.architecture.classification {
        case .universal:
            return "Yes"
        case .appleSiliconOnly, .intelOnly:
            return "No"
        case .unknown:
            return "Unknown"
        }
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            CopyableMetadataRow(label: "Gatekeeper", value: assessment.gatekeeper.status.displayValue)
            CopyableMetadataRow(
                label: "Gatekeeper Source",
                value: assessment.gatekeeper.source ?? "Unavailable",
                copyAction: assessment.gatekeeper.source == nil ? nil : copyGatekeeperSource
            )
            CopyableMetadataRow(
                label: "Rejection Reason",
                value: assessment.gatekeeper.rejectionReason ?? "Unavailable",
                copyAction: assessment.gatekeeper.rejectionReason == nil
                    ? nil
                    : copyGatekeeperRejectionReason
            )
            CopyableMetadataRow(
                label: "Notarization",
                value: assessment.gatekeeper.notarizationStatus.displayValue
            )
            CopyableMetadataRow(
                label: "Architectures",
                value: assessment.architecture.architectureList ?? "Unavailable",
                copyAction: assessment.architecture.architectureList == nil ? nil : copyArchitectureList
            )
            CopyableMetadataRow(
                label: "Architecture Inspection",
                value: assessment.architecture.status.displayValue
            )
            CopyableMetadataRow(
                label: "Architecture Classification",
                value: assessment.architecture.classification.displayValue
            )
            CopyableMetadataRow(label: "Universal Binary", value: universalDisplayValue)
        }
    }
}
