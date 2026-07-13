import Foundation

struct DDMDeclarationGenerator: DDMDeclarationGenerating {
    static let declarationType = "com.apple.configuration.app.settings"

    func generate(
        entries: [PolicyBinaryCandidate],
        identifier: UUID,
        serverToken: UUID
    ) throws -> GeneratedDDMDeclaration {
        guard !entries.isEmpty else {
            throw DDMDeclarationGenerationError.emptyPolicy
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
                    allowedBinaries: allowedBinaries,
                    deniedBinaries: deniedBinaries
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
        DDMApplicationBinary(
            signingIdentifier: entry.signingIdentifier,
            teamIdentifier: entry.teamIdentifier
        )
    }
}

enum DDMDeclarationGenerationError: Error, Equatable {
    case emptyPolicy
    case invalidEntries
    case invalidEncoding

    var userMessage: String {
        switch self {
        case .emptyPolicy:
            return "Add at least one valid application to generate a declaration."
        case .invalidEntries:
            return "Resolve invalid policy entries before generating or exporting JSON."
        case .invalidEncoding:
            return "The declaration could not be encoded as JSON."
        }
    }
}
