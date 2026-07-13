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
    let designatedRequirementInspection: DesignatedRequirementInspection?

    init(
        signingIdentifier: String?,
        teamIdentifier: String?,
        authorities: [String],
        format: String?,
        codeDirectoryVersion: String?,
        flags: String?,
        hardenedRuntimeEnabled: Bool?,
        timestamp: String?,
        signatureStatus: CodeSignatureStatus,
        signingOrigin: CodeSigningOrigin,
        diagnostics: [CodeSignatureDiagnostic],
        processResults: [ProcessResult],
        designatedRequirementInspection: DesignatedRequirementInspection? = nil
    ) {
        self.signingIdentifier = signingIdentifier
        self.teamIdentifier = teamIdentifier
        self.authorities = authorities
        self.format = format
        self.codeDirectoryVersion = codeDirectoryVersion
        self.flags = flags
        self.hardenedRuntimeEnabled = hardenedRuntimeEnabled
        self.timestamp = timestamp
        self.signatureStatus = signatureStatus
        self.signingOrigin = signingOrigin
        self.diagnostics = diagnostics
        self.processResults = processResults
        self.designatedRequirementInspection = designatedRequirementInspection
    }

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
        var details = processResults.map(\.diagnosticText)
        if let inspection = designatedRequirementInspection,
           inspection.processResult == nil,
           let diagnosticDetails = inspection.diagnosticDetails,
           !diagnosticDetails.isEmpty {
            details.append(diagnosticDetails)
        }
        return details.joined(separator: "\n\n")
    }

    var designatedRequirement: String? {
        designatedRequirementInspection?.requirement
    }

    func includingDesignatedRequirement(
        _ inspection: DesignatedRequirementInspection
    ) -> CodeSignatureInfo {
        let requirementResults = inspection.processResult.map { [$0] } ?? []
        return CodeSignatureInfo(
            signingIdentifier: signingIdentifier,
            teamIdentifier: teamIdentifier,
            authorities: authorities,
            format: format,
            codeDirectoryVersion: codeDirectoryVersion,
            flags: flags,
            hardenedRuntimeEnabled: hardenedRuntimeEnabled,
            timestamp: timestamp,
            signatureStatus: signatureStatus,
            signingOrigin: signingOrigin,
            diagnostics: diagnostics,
            processResults: processResults + requirementResults,
            designatedRequirementInspection: inspection
        )
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

struct DesignatedRequirementInspection: Equatable, Sendable {
    let requirement: String?
    let status: DesignatedRequirementStatus
    let diagnosticDetails: String?
    let processResult: ProcessResult?
}

enum DesignatedRequirementStatus: Equatable, Sendable {
    case available
    case unsigned
    case notPresent
    case malformedOutput
    case executionFailed
    case applicationUnavailable

    var displayValue: String {
        switch self {
        case .available:
            return "Available"
        case .unsigned:
            return "Not applicable (unsigned)"
        case .notPresent:
            return "Not present"
        case .malformedOutput:
            return "Unavailable (output could not be parsed)"
        case .executionFailed:
            return "Unavailable (codesign failed)"
        case .applicationUnavailable:
            return "Unavailable (application removed)"
        }
    }
}
