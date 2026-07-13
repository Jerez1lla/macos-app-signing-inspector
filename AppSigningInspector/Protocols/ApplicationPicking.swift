import Foundation

enum ApplicationPickerResult: Equatable {
    case selected(URL)
    case cancelled
}

protocol ApplicationPicking {
    @MainActor
    func selectApplication() async throws -> ApplicationPickerResult
}
