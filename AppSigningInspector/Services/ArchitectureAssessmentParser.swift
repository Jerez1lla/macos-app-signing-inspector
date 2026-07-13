import Foundation

struct ArchitectureAssessmentParser: ArchitectureAssessmentParsing {
    func parse(_ result: ProcessResult) -> ArchitectureAssessment {
        let output = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)

        if result.terminationStatus != 0 {
            let status: ArchitectureInspectionStatus = indicatesUnsupportedFormat(output)
                ? .unsupportedFormat
                : .toolFailure
            return assessment(status: status, result: result)
        }

        guard !output.isEmpty else {
            return assessment(status: .emptyOutput, result: result)
        }

        let values = output.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !values.isEmpty, values.allSatisfy(isArchitectureToken) else {
            return assessment(status: .malformedOutput, result: result)
        }

        var seen = Set<String>()
        let architectures = values.filter { seen.insert($0).inserted }
        return ArchitectureAssessment(
            status: .available,
            architectures: architectures,
            classification: classification(for: architectures),
            rawDiagnostics: result.diagnosticText
        )
    }

    private func assessment(
        status: ArchitectureInspectionStatus,
        result: ProcessResult
    ) -> ArchitectureAssessment {
        ArchitectureAssessment(
            status: status,
            architectures: [],
            classification: .unknown,
            rawDiagnostics: result.diagnosticText
        )
    }

    private func isArchitectureToken(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9_]+$"#, options: .regularExpression) != nil
    }

    private func classification(for architectures: [String]) -> ArchitectureClassification {
        let knownArchitectures = Set(["arm64", "arm64e", "x86_64"])
        guard architectures.allSatisfy(knownArchitectures.contains) else {
            return .unknown
        }

        let supportsAppleSilicon = architectures.contains("arm64") || architectures.contains("arm64e")
        let supportsIntel = architectures.contains("x86_64")

        switch (supportsAppleSilicon, supportsIntel) {
        case (true, true):
            return .universal
        case (true, false):
            return .appleSiliconOnly
        case (false, true):
            return .intelOnly
        case (false, false):
            return .unknown
        }
    }

    private func indicatesUnsupportedFormat(_ output: String) -> Bool {
        let lowercaseOutput = output.lowercased()
        return lowercaseOutput.contains("not a mach-o file")
            || lowercaseOutput.contains("not an object file")
            || lowercaseOutput.contains("can't figure out the architecture type")
    }
}
