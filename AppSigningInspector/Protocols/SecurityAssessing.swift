import Foundation

protocol SecurityAssessing: Sendable {
    func assess(applicationAt applicationURL: URL, executablePath: String?) async -> ApplicationSecurityAssessment
}

protocol GatekeeperAssessing: Sendable {
    func assess(applicationAt applicationURL: URL) async -> GatekeeperAssessment
}

protocol ArchitectureInspecting: Sendable {
    func inspect(applicationAt applicationURL: URL) async -> ArchitectureAssessment
}

protocol GatekeeperAssessmentParsing: Sendable {
    func parse(_ result: ProcessResult) -> GatekeeperAssessment
}

protocol NativeBundleArchitectureProviding: Sendable {
    func architectureSnapshot(for applicationURL: URL) throws -> NativeBundleArchitectureSnapshot
}
