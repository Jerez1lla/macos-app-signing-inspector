import Foundation

protocol DDMDeclarationGenerating: Sendable {
    func generate(
        entries: [PolicyBinaryCandidate],
        alwaysAllowManagedApps: Bool,
        identifier: UUID,
        serverToken: UUID
    ) throws -> GeneratedDDMDeclaration
}
