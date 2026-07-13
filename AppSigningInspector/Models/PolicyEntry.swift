import AppKit
import Foundation

enum PolicyAction: String, CaseIterable, Codable, Hashable, Sendable {
    case allow
    case deny

    var displayValue: String {
        switch self {
        case .allow:
            return "Allow"
        case .deny:
            return "Deny"
        }
    }
}

struct PolicyEntry: Identifiable {
    let id: UUID
    let applicationURL: URL
    let displayName: String
    let icon: NSImage
    let signingIdentifier: String?
    let teamIdentifier: String?
    var action: PolicyAction
    let validationState: PolicyEntryValidationState

    var isValid: Bool {
        validationState == .valid
    }

    var signingKey: PolicySigningKey? {
        guard let signingIdentifier, let teamIdentifier else {
            return nil
        }
        return PolicySigningKey(signingIdentifier: signingIdentifier, teamIdentifier: teamIdentifier)
    }

    var binaryCandidate: PolicyBinaryCandidate? {
        guard isValid, let signingIdentifier, let teamIdentifier else {
            return nil
        }
        return PolicyBinaryCandidate(
            signingIdentifier: signingIdentifier,
            teamIdentifier: teamIdentifier,
            action: action
        )
    }
}

enum PolicyEntryValidationState: Equatable {
    case valid
    case missingSigningIdentifier
    case missingTeamIdentifier
    case missingSigningAndTeamIdentifiers
    case signatureInspectionFailed(String)

    var message: String? {
        switch self {
        case .valid:
            return nil
        case .missingSigningIdentifier:
            return "Signing ID is unavailable. This entry cannot be exported."
        case .missingTeamIdentifier:
            return "Team ID is unavailable. This entry cannot be exported."
        case .missingSigningAndTeamIdentifiers:
            return "Signing ID and Team ID are unavailable. This entry cannot be exported."
        case .signatureInspectionFailed:
            return "Code-signature inspection failed. This entry cannot be exported."
        }
    }

    var diagnosticDetails: String? {
        if case .signatureInspectionFailed(let details) = self {
            return details
        }
        return nil
    }
}

struct PolicySigningKey: Hashable, Sendable {
    let signingIdentifier: String
    let teamIdentifier: String
}

struct PolicyBinaryCandidate: Equatable, Sendable {
    let signingIdentifier: String
    let teamIdentifier: String
    let action: PolicyAction
}

enum PolicyBuilderNotice: Equatable {
    case duplicateApplication(String)
    case duplicateSigningEntry(displayName: String, signingIdentifier: String, teamIdentifier: String)
    case applicationInspectionFailed(displayName: String, details: String)

    var message: String {
        switch self {
        case .duplicateApplication(let displayName):
            return "\(displayName) is already in this policy."
        case .duplicateSigningEntry(let displayName, let signingIdentifier, let teamIdentifier):
            return "\(displayName) duplicates signing entry \(signingIdentifier) / \(teamIdentifier)."
        case .applicationInspectionFailed(let displayName, _):
            return "\(displayName) could not be inspected and was not added to the policy."
        }
    }

    var diagnosticDetails: String? {
        if case .applicationInspectionFailed(_, let details) = self {
            return details
        }
        return nil
    }
}
