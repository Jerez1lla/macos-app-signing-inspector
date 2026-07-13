import Foundation

enum PolicyApplicationPickerResult: Equatable {
    case selected([URL])
    case cancelled
}

protocol PolicyApplicationPicking {
    @MainActor
    func selectApplications() async throws -> PolicyApplicationPickerResult
}
