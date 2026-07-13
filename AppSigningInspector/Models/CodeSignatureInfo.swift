import Foundation

struct CodeSignatureInfo: Equatable, Sendable {
    let signingIdentifier: String?
    let teamIdentifier: String?
    let authorities: [String]
    let format: String?
    let codeDirectoryVersion: String?
    let flags: String?
    let hardenedRuntimeEnabled: Bool?
    let timestamp: String?
    let signatureStatus: CodeSignatureStatus
    let signingOrigin: CodeSigningOrigin
    let diagnostics: [CodeSignatureDiagnostic]
    let processResults: [ProcessResult]

    var isAppleSigned: Bool? {
        switch signingOrigin {
        case .apple:
            return true
        case .thirdParty:
            return false
        case .unknown:
            return nil
        }
    }

    var rawDiagnostics: String {
        processResults.map(\.diagnosticText).joined(separator: "\n\n")
    }

    var signingIdentifierDisplayValue: String {
        signingIdentifier ?? "Unavailable"
    }

    var teamIdentifierDisplayValue: String {
        teamIdentifier ?? "Unavailable"
    }

    var formatDisplayValue: String {
        format ?? "Unavailable"
    }

    var codeDirectoryVersionDisplayValue: String {
        codeDirectoryVersion ?? "Unavailable"
    }

    var flagsDisplayValue: String {
        flags ?? "Unavailable"
    }

    var hardenedRuntimeDisplayValue: String {
        guard let hardenedRuntimeEnabled else {
            return "Unavailable"
        }

        return hardenedRuntimeEnabled ? "Enabled" : "Not enabled"
    }

    var timestampDisplayValue: String {
        timestamp ?? "Unavailable"
    }

    var appleSignedDisplayValue: String {
        guard let isAppleSigned else {
            return "Unavailable"
        }

        return isAppleSigned ? "Yes" : "No"
    }
}

enum CodeSignatureStatus: Equatable, Sendable {
    case valid
    case unsigned
    case invalid

    var displayValue: String {
        switch self {
        case .valid:
            return "Valid signature"
        case .unsigned:
            return "Unsigned"
        case .invalid:
            return "Invalid signature"
        }
    }
}

enum CodeSigningOrigin: Equatable, Sendable {
    case apple
    case thirdParty
    case unknown

    var displayValue: String {
        switch self {
        case .apple:
            return "Apple"
        case .thirdParty:
            return "Third party"
        case .unknown:
            return "Unavailable"
        }
    }
}

enum CodeSignatureDiagnostic: Equatable, Sendable {
    case missingSigningIdentifier
    case missingTeamIdentifier

    var message: String {
        switch self {
        case .missingSigningIdentifier:
            return "Signing ID is unavailable."
        case .missingTeamIdentifier:
            return "Team ID is unavailable."
        }
    }
}
