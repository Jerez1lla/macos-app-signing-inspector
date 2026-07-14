import Foundation

struct ApplicationSecurityAssessment: Equatable, Sendable {
    let gatekeeper: GatekeeperAssessment
    let architecture: ArchitectureAssessment

    var validationStatus: SecurityValidationStatus {
        if gatekeeper.status == .rejected {
            return .rejected
        }

        if gatekeeper.status == .accepted,
           architecture.status == .available,
           architecture.classification != .unknown {
            return .accepted
        }

        if gatekeeper.status == .accepted || architecture.status == .available {
            return .partial
        }

        return .unavailable
    }
}

struct GatekeeperAssessment: Equatable, Sendable {
    let status: GatekeeperStatus
    let source: String?
    let rejectionReason: String?
    let notarizationStatus: NotarizationStatus
    let rawDiagnostics: String?
}

struct ArchitectureAssessment: Equatable, Sendable {
    let status: ArchitectureInspectionStatus
    let architectures: [String]
    let classification: ArchitectureClassification
    let rawDiagnostics: String?

    var isUniversalBinary: Bool {
        classification == .universal
    }

    var architectureList: String? {
        architectures.isEmpty ? nil : architectures.joined(separator: ", ")
    }
}

enum GatekeeperStatus: Equatable, Sendable {
    case accepted
    case rejected
    case unavailable
    case toolUnavailable
    case toolFailure
    case applicationUnavailable

    var displayValue: String {
        switch self {
        case .accepted:
            return "Accepted"
        case .rejected:
            return "Rejected"
        case .unavailable:
            return "Assessment unavailable"
        case .toolUnavailable:
            return "Gatekeeper tool unavailable"
        case .toolFailure:
            return "Tool execution failed"
        case .applicationUnavailable:
            return "Application unavailable"
        }
    }
}

enum NotarizationStatus: Equatable, Sendable {
    case notarized
    case applePlatform
    case signedNotConfirmed
    case rejected
    case unknown
    case notApplicable

    var displayValue: String {
        switch self {
        case .notarized:
            return "Notarized"
        case .applePlatform:
            return "Apple system or platform application"
        case .signedNotConfirmed:
            return "Signed; notarization not confirmed"
        case .rejected:
            return "Rejected"
        case .unknown:
            return "Unknown"
        case .notApplicable:
            return "Not applicable"
        }
    }
}

enum ArchitectureInspectionStatus: Equatable, Sendable {
    case available
    case informationUnavailable
    case bundleUnavailable
    case unsupportedArchitecture
    case applicationUnavailable

    var displayValue: String {
        switch self {
        case .available:
            return "Available"
        case .informationUnavailable:
            return "Architecture information unavailable"
        case .bundleUnavailable:
            return "Application bundle could not be inspected"
        case .unsupportedArchitecture:
            return "Unknown or unsupported architecture"
        case .applicationUnavailable:
            return "Application unavailable"
        }
    }
}

enum ArchitectureClassification: Equatable, Sendable {
    case universal
    case appleSiliconOnly
    case intelOnly
    case unknown

    var displayValue: String {
        switch self {
        case .universal:
            return "Universal (Apple silicon and Intel)"
        case .appleSiliconOnly:
            return "Apple silicon only"
        case .intelOnly:
            return "Intel only"
        case .unknown:
            return "Unknown or unsupported"
        }
    }
}

enum SecurityValidationStatus: Equatable, Sendable {
    case accepted
    case rejected
    case partial
    case unavailable

    var displayValue: String {
        switch self {
        case .accepted:
            return "Gatekeeper accepted the app and its architectures were identified."
        case .rejected:
            return "Gatekeeper rejected the app. Review the assessment details."
        case .partial:
            return "Security validation completed with partial results."
        case .unavailable:
            return "Security validation could not produce a usable result."
        }
    }
}
