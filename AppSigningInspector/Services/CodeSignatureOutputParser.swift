import Foundation

struct CodeSignatureOutputParser: CodeSignatureOutputParsing {
    func parse(
        displayResult: ProcessResult,
        verificationResult: ProcessResult? = nil
    ) throws -> CodeSignatureInfo {
        let processResults = [displayResult] + [verificationResult].compactMap { $0 }
        let allOutput = processResults.map(\.combinedOutput).joined(separator: "\n")

        guard !allOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CodeSignatureInspectionError.emptyOutput(processResults)
        }

        if Self.indicatesUnsignedApplication(allOutput) {
            return CodeSignatureInfo(
                signingIdentifier: nil,
                teamIdentifier: nil,
                authorities: [],
                format: nil,
                codeDirectoryVersion: nil,
                flags: nil,
                hardenedRuntimeEnabled: nil,
                timestamp: nil,
                signatureStatus: .unsigned,
                signingOrigin: .unknown,
                diagnostics: [],
                processResults: processResults
            )
        }

        let lines = displayResult.combinedOutput
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let signingIdentifier = Self.normalizedValue(Self.value(after: "Identifier=", in: lines))
        let teamIdentifier = Self.normalizedValue(Self.value(after: "TeamIdentifier=", in: lines))
        let authorities = Self.values(after: "Authority=", in: lines)
        let format = Self.normalizedValue(Self.value(after: "Format=", in: lines))
        let codeDirectoryVersion = Self.codeDirectoryVersion(in: lines)
        let flags = Self.flags(in: lines)
        let timestamp = Self.normalizedValue(Self.value(after: "Timestamp=", in: lines))

        let recognizedFieldCount = [
            signingIdentifier,
            teamIdentifier,
            format,
            codeDirectoryVersion,
            flags,
            timestamp
        ].compactMap { $0 }.count + authorities.count

        let signatureStatus = try Self.signatureStatus(
            displayResult: displayResult,
            verificationResult: verificationResult
        )

        guard recognizedFieldCount > 0 || signatureStatus == .invalid else {
            if displayResult.terminationStatus != 0 {
                throw CodeSignatureInspectionError.commandFailed(displayResult)
            }
            throw CodeSignatureInspectionError.parsingFailed(processResults)
        }
        var diagnostics: [CodeSignatureDiagnostic] = []
        if signingIdentifier == nil {
            diagnostics.append(.missingSigningIdentifier)
        }
        if teamIdentifier == nil {
            diagnostics.append(.missingTeamIdentifier)
        }

        return CodeSignatureInfo(
            signingIdentifier: signingIdentifier,
            teamIdentifier: teamIdentifier,
            authorities: authorities,
            format: format,
            codeDirectoryVersion: codeDirectoryVersion,
            flags: flags,
            hardenedRuntimeEnabled: Self.hardenedRuntimeEnabled(flags: flags),
            timestamp: timestamp,
            signatureStatus: signatureStatus,
            signingOrigin: Self.signingOrigin(authorities: authorities),
            diagnostics: diagnostics,
            processResults: processResults
        )
    }

    private static func signatureStatus(
        displayResult: ProcessResult,
        verificationResult: ProcessResult?
    ) throws -> CodeSignatureStatus {
        if displayResult.terminationStatus != 0 {
            if indicatesInvalidSignature(displayResult.combinedOutput) {
                return .invalid
            }
            throw CodeSignatureInspectionError.commandFailed(displayResult)
        }

        if let verificationResult, verificationResult.terminationStatus != 0 {
            return .invalid
        }

        return .valid
    }

    private static func value(after prefix: String, in lines: [String]) -> String? {
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }

        return String(line.dropFirst(prefix.count))
    }

    private static func values(after prefix: String, in lines: [String]) -> [String] {
        lines.compactMap { line in
            guard line.hasPrefix(prefix) else {
                return nil
            }
            return normalizedValue(String(line.dropFirst(prefix.count)))
        }
    }

    private static func normalizedValue(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercaseValue = trimmedValue.lowercased()
        guard !trimmedValue.isEmpty,
              lowercaseValue != "not set",
              lowercaseValue != "none" else {
            return nil
        }

        return trimmedValue
    }

    private static func codeDirectoryVersion(in lines: [String]) -> String? {
        guard let line = lines.first(where: { $0.hasPrefix("CodeDirectory v=") }) else {
            return nil
        }

        let value = line.dropFirst("CodeDirectory v=".count)
        return value.split(whereSeparator: \.isWhitespace).first.map(String.init)
    }

    private static func flags(in lines: [String]) -> String? {
        for line in lines {
            guard let range = line.range(of: "flags=") else {
                continue
            }

            let value = line[range.upperBound...]
            if let token = value.split(whereSeparator: \.isWhitespace).first {
                return normalizedValue(String(token))
            }
        }

        return nil
    }

    private static func hardenedRuntimeEnabled(flags: String?) -> Bool? {
        guard let flags else {
            return nil
        }

        let lowercaseFlags = flags.lowercased()
        if lowercaseFlags.contains("runtime") {
            return true
        }

        let hexadecimalValue = lowercaseFlags
            .split(separator: "(", maxSplits: 1)
            .first
            .map(String.init) ?? lowercaseFlags

        guard hexadecimalValue.hasPrefix("0x"),
              let numericValue = UInt64(hexadecimalValue.dropFirst(2), radix: 16) else {
            return false
        }

        // CS_RUNTIME is the 0x10000 code-signing flag represented by codesign as "runtime".
        return numericValue & 0x10000 != 0
    }

    private static func signingOrigin(authorities: [String]) -> CodeSigningOrigin {
        guard let leafAuthority = authorities.first else {
            return .unknown
        }

        let knownAppleLeafAuthorities = [
            "Software Signing",
            "Apple Mac OS Application Signing",
            "Apple iPhone OS Application Signing"
        ]
        if knownAppleLeafAuthorities.contains(leafAuthority) {
            return .apple
        }

        let knownThirdPartyPrefixes = [
            "Developer ID Application:",
            "Apple Development:",
            "Apple Distribution:",
            "Mac Developer:"
        ]
        if knownThirdPartyPrefixes.contains(where: { leafAuthority.hasPrefix($0) }) {
            return .thirdParty
        }

        return .unknown
    }

    private static func indicatesUnsignedApplication(_ output: String) -> Bool {
        let lowercaseOutput = output.lowercased()
        return lowercaseOutput.contains("code object is not signed at all")
            || lowercaseOutput.contains("is not signed at all")
    }

    private static func indicatesInvalidSignature(_ output: String) -> Bool {
        let lowercaseOutput = output.lowercased()
        let indicators = [
            "invalid signature",
            "a sealed resource is missing or invalid",
            "resource envelope is obsolete",
            "code has no resources but signature indicates they must be present"
        ]
        return indicators.contains(where: lowercaseOutput.contains)
    }
}
