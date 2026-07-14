import Foundation

enum PolicyApplicationPickerResult: Equatable {
    case selected([URL])
    case cancelled
}

enum DeveloperApplicationPickerResult: Equatable {
    case selected(URL)
    case cancelled
}

protocol PolicyApplicationPicking {
    @MainActor
    func selectApplications() async throws -> PolicyApplicationPickerResult

    @MainActor
    func selectDeveloperApplication() async throws -> DeveloperApplicationPickerResult
}

extension PolicyApplicationPicking {
    @MainActor
    func selectDeveloperApplication() async throws -> DeveloperApplicationPickerResult {
        let result = try await selectApplications()
        guard case .selected(let urls) = result, let firstURL = urls.first else {
            return .cancelled
        }
        return .selected(firstURL)
    }
}
