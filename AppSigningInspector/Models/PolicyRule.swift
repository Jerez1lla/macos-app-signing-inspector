import Foundation

enum PolicyRuleType: String, CaseIterable, Hashable, Sendable {
    case specificApplication
    case developerTeam
    case appleBinaries

    var displayValue: String {
        switch self {
        case .specificApplication:
            return "Specific Application"
        case .developerTeam:
            return "Developer Team"
        case .appleBinaries:
            return "Apple Binaries"
        }
    }
}

enum PolicyRule: Equatable, Sendable {
    // The macOS 27 AppleSeed test plan specifies this exact beta token.
    static let appleTeamIdentifier = "*APPLE*"

    case specificApplication(
        signingIdentifier: String?,
        teamIdentifier: String?,
        pathPrefix: String?
    )
    case developerTeam(teamIdentifier: String)
    case appleBinaries

    var type: PolicyRuleType {
        switch self {
        case .specificApplication:
            return .specificApplication
        case .developerTeam:
            return .developerTeam
        case .appleBinaries:
            return .appleBinaries
        }
    }

    var signingIdentifier: String? {
        guard case .specificApplication(let signingIdentifier, _, _) = self else {
            return nil
        }
        return signingIdentifier
    }

    var teamIdentifier: String? {
        switch self {
        case .specificApplication(_, let teamIdentifier, _):
            return teamIdentifier
        case .developerTeam(let teamIdentifier):
            return teamIdentifier
        case .appleBinaries:
            return Self.appleTeamIdentifier
        }
    }

    var pathPrefix: String? {
        guard case .specificApplication(_, _, let pathPrefix) = self else {
            return nil
        }
        return pathPrefix
    }

    var supportsDeniedAction: Bool {
        type == .specificApplication
    }

    var semanticIdentity: PolicyRuleIdentity? {
        switch self {
        case .specificApplication(let signingIdentifier, let teamIdentifier, let pathPrefix):
            guard let signingIdentifier, !signingIdentifier.isEmpty,
                  let teamIdentifier, !teamIdentifier.isEmpty else {
                return nil
            }
            return .specificApplication(
                signingIdentifier: signingIdentifier,
                teamIdentifier: teamIdentifier,
                pathPrefix: pathPrefix
            )
        case .developerTeam(let teamIdentifier):
            guard !teamIdentifier.isEmpty else {
                return nil
            }
            return .developerTeam(teamIdentifier: teamIdentifier)
        case .appleBinaries:
            return .appleBinaries
        }
    }
}

enum PolicyRuleIdentity: Hashable, Sendable {
    case specificApplication(signingIdentifier: String, teamIdentifier: String, pathPrefix: String?)
    case developerTeam(teamIdentifier: String)
    case appleBinaries
}
