import Foundation

struct GatekeeperAssessmentParser: GatekeeperAssessmentParsing {
    func parse(_ result: ProcessResult) -> GatekeeperAssessment {
        let output = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else {
            return assessment(status: .unavailable, result: result)
        }

        let lines = output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let source = value(after: "source=", in: lines)
        let lowercaseOutput = output.lowercased()

        if indicatesRejection(lowercaseOutput) {
            return GatekeeperAssessment(
                status: .rejected,
                source: source,
                rejectionReason: rejectionReason(in: lines),
                notarizationStatus: .rejected,
                rawDiagnostics: result.diagnosticText
            )
        }

        if result.terminationStatus == 0, indicatesAcceptance(lowercaseOutput) {
            return GatekeeperAssessment(
                status: .accepted,
                source: source,
                rejectionReason: nil,
                notarizationStatus: notarizationStatus(for: source),
                rawDiagnostics: result.diagnosticText
            )
        }

        return assessment(status: .unavailable, source: source, result: result)
    }

    private func assessment(
        status: GatekeeperStatus,
        source: String? = nil,
        result: ProcessResult
    ) -> GatekeeperAssessment {
        GatekeeperAssessment(
            status: status,
            source: source,
            rejectionReason: nil,
            notarizationStatus: .unknown,
            rawDiagnostics: result.diagnosticText
        )
    }

    private func value(after prefix: String, in lines: [String]) -> String? {
        guard let line = lines.first(where: { $0.lowercased().hasPrefix(prefix) }) else {
            return nil
        }

        let value = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func rejectionReason(in lines: [String]) -> String? {
        let indicators = ["rejected", "denied", "damaged", "not accepted", "unable to assess"]
        return lines.first { line in
            let lowercaseLine = line.lowercased()
            return indicators.contains(where: lowercaseLine.contains)
        }
    }

    private func notarizationStatus(for source: String?) -> NotarizationStatus {
        guard let source else {
            return .signedNotConfirmed
        }

        let lowercaseSource = source.lowercased()
        if lowercaseSource.contains("notarized developer id") {
            return .notarized
        }
        if lowercaseSource.contains("apple system") || lowercaseSource.contains("apple platform") {
            return .applePlatform
        }
        if lowercaseSource.contains("mac app store") {
            return .notApplicable
        }
        return .signedNotConfirmed
    }

    private func indicatesAcceptance(_ output: String) -> Bool {
        output.contains("accepted")
    }

    private func indicatesRejection(_ output: String) -> Bool {
        output.contains("rejected") || output.contains("denied") || output.contains("not accepted")
    }
}
