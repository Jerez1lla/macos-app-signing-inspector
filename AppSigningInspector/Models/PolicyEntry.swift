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
    let applicationURL: URL?
    let displayName: String
    let icon: NSImage?
    let signingAuthority: String?
    let sourceApplicationName: String?
    let applicationSigningIdentifier: String?
    let applicationTeamIdentifier: String?
    var rule: PolicyRule
    var action: PolicyAction
    var validationState: PolicyEntryValidationState

    init(
        id: UUID,
        applicationURL: URL?,
        displayName: String,
        icon: NSImage?,
        signingAuthority: String?,
        sourceApplicationName: String? = nil,
        applicationSigningIdentifier: String?,
        applicationTeamIdentifier: String?,
        rule: PolicyRule,
        action: PolicyAction,
        validationState: PolicyEntryValidationState
    ) {
        self.id = id
        self.applicationURL = applicationURL
        self.displayName = displayName
        self.icon = icon
        self.signingAuthority = signingAuthority
        self.sourceApplicationName = sourceApplicationName
        self.applicationSigningIdentifier = applicationSigningIdentifier
        self.applicationTeamIdentifier = applicationTeamIdentifier
        self.rule = rule
        self.action = action
        self.validationState = validationState
    }

    var isValid: Bool {
        validationState == .valid
    }

    var signingIdentifier: String? { rule.signingIdentifier }
    var teamIdentifier: String? { rule.teamIdentifier }
    var pathPrefix: String? { rule.pathPrefix }

    var binaryCandidate: PolicyBinaryCandidate? {
        guard isValid else {
            return nil
        }
        return PolicyBinaryCandidate(rule: rule, action: action)
    }
}

struct JamfDeveloperTeamRuleCandidate: Identifiable, Equatable {
    let applicationURL: URL
    let sourceApplicationName: String
    let teamIdentifier: String
    let signingAuthority: String?

    var id: URL { applicationURL }
}

enum PolicyEntryValidationState: Equatable {
    case valid
    case missingSigningIdentifier
    case missingTeamIdentifier
    case missingSigningAndTeamIdentifiers
    case invalidPathPrefix
    case invalidSpecialTeamIdentifier
    case unsupportedRuleAction
    case signatureInspectionFailed(String)

    var message: String? {
        switch self {
        case .valid:
            return nil
        case .missingSigningIdentifier:
            return "Signing ID is unavailable. This rule cannot be exported."
        case .missingTeamIdentifier:
            return "Team ID is required. This rule cannot be exported."
        case .missingSigningAndTeamIdentifiers:
            return "Signing ID and Team ID are unavailable. This rule cannot be exported."
        case .invalidPathPrefix:
            return "Path Prefix must be an absolute path beginning with /."
        case .invalidSpecialTeamIdentifier:
            return "Only the documented *APPLE* special Team ID token is supported."
        case .unsupportedRuleAction:
            return "This rule type does not support the selected action."
        case .signatureInspectionFailed:
            return "Code-signature inspection failed. This rule cannot be exported."
        }
    }

    var diagnosticDetails: String? {
        if case .signatureInspectionFailed(let details) = self {
            return details
        }
        return nil
    }
}

struct PolicyBinaryCandidate: Equatable, Sendable {
    let rule: PolicyRule
    let action: PolicyAction
}

enum PolicyBuilderNotice: Equatable {
    case duplicateApplication(String)
    case duplicateRule(String)
    case applicationInspectionFailed(displayName: String, details: String)

    var message: String {
        switch self {
        case .duplicateApplication(let displayName):
            return "\(displayName) is already in this policy."
        case .duplicateRule(let description):
            return "A matching \(description) rule is already in this policy."
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
