import Foundation

struct DesignatedRequirementOutputParser: DesignatedRequirementOutputParsing {
    private static let prefix = "designated =>"

    func parse(_ result: ProcessResult) -> DesignatedRequirementInspection {
        let combinedOutput = result.combinedOutput
        let lowercaseOutput = combinedOutput.lowercased()

        if Self.indicatesUnsignedApplication(lowercaseOutput) {
            return inspection(status: .unsigned, result: result)
        }

        if Self.indicatesMissingRequirement(lowercaseOutput) {
            return inspection(status: .notPresent, result: result)
        }

        guard result.terminationStatus == 0 else {
            return inspection(status: .executionFailed, result: result)
        }

        for output in [result.standardError, result.standardOutput] {
            guard let prefixRange = output.range(of: Self.prefix) else {
                continue
            }

            let requirement = String(output[prefixRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !requirement.isEmpty else {
                return inspection(status: .notPresent, result: result)
            }

            return DesignatedRequirementInspection(
                requirement: requirement,
                status: .available,
                diagnosticDetails: result.diagnosticText,
                processResult: result
            )
        }

        return inspection(status: .malformedOutput, result: result)
    }

    private func inspection(
        status: DesignatedRequirementStatus,
        result: ProcessResult
    ) -> DesignatedRequirementInspection {
        DesignatedRequirementInspection(
            requirement: nil,
            status: status,
            diagnosticDetails: result.diagnosticText,
            processResult: result
        )
    }

    private static func indicatesUnsignedApplication(_ lowercaseOutput: String) -> Bool {
        lowercaseOutput.contains("code object is not signed at all")
            || lowercaseOutput.contains("is not signed at all")
    }

    private static func indicatesMissingRequirement(_ lowercaseOutput: String) -> Bool {
        lowercaseOutput.contains("no designated requirement")
            || lowercaseOutput.contains("has no designated requirement")
    }
}
