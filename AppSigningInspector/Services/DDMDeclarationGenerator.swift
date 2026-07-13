import Foundation

struct DDMDeclarationGenerator: DDMDeclarationGenerating {
    static let declarationType = "com.apple.configuration.app.settings"

    func generate(
        entries: [PolicyBinaryCandidate],
        alwaysAllowManagedApps: Bool = false,
        identifier: UUID,
        serverToken: UUID
    ) throws -> GeneratedDDMDeclaration {
        guard !entries.isEmpty || alwaysAllowManagedApps else {
            throw DDMDeclarationGenerationError.emptyPolicy
        }
        let validator = PolicyRuleValidator()
        guard entries.allSatisfy({ validator.validate($0.rule, action: $0.action) == .valid }) else {
            throw DDMDeclarationGenerationError.invalidEntries
        }

        let allowedBinaries = entries
            .filter { $0.action == .allow }
            .map(Self.binary)
        let deniedBinaries = entries
            .filter { $0.action == .deny }
            .map(Self.binary)
        let declaration = DDMApplicationSettingsDeclaration(
            type: Self.declarationType,
            identifier: identifier.uuidString,
            serverToken: serverToken.uuidString,
            payload: DDMApplicationSettingsPayload(
                allowed: DDMAllowedApplicationSettings(
                    alwaysAllowManagedApps: alwaysAllowManagedApps ? true : nil,
                    allowedBinaries: entries.isEmpty ? nil : allowedBinaries,
                    deniedBinaries: entries.isEmpty ? nil : deniedBinaries
                )
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(declaration)
        guard let json = String(data: data, encoding: .utf8) else {
            throw DDMDeclarationGenerationError.invalidEncoding
        }

        return GeneratedDDMDeclaration(declaration: declaration, json: json)
    }

    private static func binary(_ entry: PolicyBinaryCandidate) -> DDMApplicationBinary {
        switch entry.rule {
        case .specificApplication(let signingIdentifier, let teamIdentifier, let pathPrefix):
            return DDMApplicationBinary(
                signingIdentifier: signingIdentifier,
                teamIdentifier: teamIdentifier ?? "",
                pathPrefix: pathPrefix
            )
        case .developerTeam(let teamIdentifier):
            return DDMApplicationBinary(
                signingIdentifier: nil,
                teamIdentifier: teamIdentifier,
                pathPrefix: nil
            )
        case .appleBinaries:
            return DDMApplicationBinary(
                signingIdentifier: nil,
                teamIdentifier: PolicyRule.appleTeamIdentifier,
                pathPrefix: nil
            )
        }
    }
}

enum DDMDeclarationGenerationError: Error, Equatable {
    case emptyPolicy
    case invalidEntries
    case invalidEncoding

    var userMessage: String {
        switch self {
        case .emptyPolicy:
            return "Add at least one valid rule or enable Always Allow Managed Apps to generate a declaration."
        case .invalidEntries:
            return "Resolve invalid policy entries before generating or exporting JSON."
        case .invalidEncoding:
            return "The declaration could not be encoded as JSON."
        }
    }
}
