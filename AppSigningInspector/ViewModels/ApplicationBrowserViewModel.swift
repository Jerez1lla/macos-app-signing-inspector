import Combine
import Foundation

@MainActor
final class ApplicationBrowserViewModel: ObservableObject {
    @Published private(set) var selectedApplication: SelectedApplication?
    @Published private(set) var errorMessage: String?

    private let picker: ApplicationPicking
    private let iconLoader: ApplicationIconLoading
    private let fileManager: FileManager

    init(
        picker: ApplicationPicking = ApplicationPickerService(),
        iconLoader: ApplicationIconLoading = WorkspaceApplicationIconLoader(),
        fileManager: FileManager = .default
    ) {
        self.picker = picker
        self.iconLoader = iconLoader
        self.fileManager = fileManager
    }

    var hasSelectedApplication: Bool {
        selectedApplication != nil
    }

    func selectApplication() async {
        do {
            let result = try await picker.selectApplication()
            switch result {
            case .cancelled:
                return
            case .selected(let url):
                selectedApplication = try application(from: url)
                errorMessage = nil
            }
        } catch let error as ApplicationBrowserError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Unable to select the application. Try choosing a different .app bundle."
        }
    }

    func application(from url: URL) throws -> SelectedApplication {
        guard fileManager.fileExists(atPath: url.path) else {
            throw ApplicationBrowserError.applicationDoesNotExist(url)
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ApplicationBrowserError.notApplicationBundle(url)
        }

        guard url.pathExtension.lowercased() == "app" else {
            throw ApplicationBrowserError.notApplicationBundle(url)
        }

        guard fileManager.isReadableFile(atPath: url.path) else {
            throw ApplicationBrowserError.applicationNotReadable(url)
        }

        let icon = try iconLoader.icon(for: url)
        let name = url.deletingPathExtension().lastPathComponent

        return SelectedApplication(url: url, name: name, icon: icon)
    }
}

enum ApplicationBrowserError: Error, Equatable {
    case applicationDoesNotExist(URL)
    case notApplicationBundle(URL)
    case applicationNotReadable(URL)
    case iconUnavailable(URL)

    var userMessage: String {
        switch self {
        case .applicationDoesNotExist:
            return "The selected application could not be found. Choose an existing .app bundle."
        case .notApplicationBundle:
            return "The selected item is not a macOS application bundle. Choose a .app bundle."
        case .applicationNotReadable:
            return "The selected application cannot be read. Check permissions or choose a different app."
        case .iconUnavailable:
            return "The application icon could not be loaded. Choose a different .app bundle."
        }
    }
}
