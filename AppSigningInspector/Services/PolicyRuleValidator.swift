import Foundation

struct PolicyRuleValidator {
    func validate(_ rule: PolicyRule, action: PolicyAction) -> PolicyEntryValidationState {
        guard rule.supportsDeniedAction || action == .allow else {
            return .unsupportedRuleAction
        }

        switch rule {
        case .specificApplication(let signingIdentifier, let teamIdentifier, let pathPrefix):
            let missingSigningIdentifier = signingIdentifier?.isEmpty != false
            let missingTeamIdentifier = teamIdentifier?.isEmpty != false

            if missingSigningIdentifier && missingTeamIdentifier {
                return .missingSigningAndTeamIdentifiers
            }
            if missingSigningIdentifier {
                return .missingSigningIdentifier
            }
            if missingTeamIdentifier {
                return .missingTeamIdentifier
            }
            if let pathPrefix, !pathPrefix.hasPrefix("/") {
                return .invalidPathPrefix
            }
            return .valid

        case .developerTeam(let teamIdentifier):
            if teamIdentifier.isEmpty {
                return .missingTeamIdentifier
            }
            if teamIdentifier.contains("*") {
                return .invalidSpecialTeamIdentifier
            }
            return .valid

        case .appleBinaries:
            return .valid
        }
    }

    func normalizedManualTeamIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
