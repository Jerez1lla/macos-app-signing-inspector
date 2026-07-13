import Foundation

protocol DDMDeclarationGenerating: Sendable {
    func generate(
        entries: [PolicyBinaryCandidate],
        identifier: UUID,
        serverToken: UUID
    ) throws -> GeneratedDDMDeclaration
}
