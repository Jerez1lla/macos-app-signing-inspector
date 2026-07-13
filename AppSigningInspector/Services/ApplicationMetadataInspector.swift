import Foundation

struct ApplicationMetadataInspector: ApplicationMetadataInspecting {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func metadata(for applicationURL: URL) throws -> ApplicationMetadata {
        guard fileManager.fileExists(atPath: applicationURL.path) else {
            throw ApplicationMetadataError.applicationUnavailable(applicationURL)
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: applicationURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              applicationURL.pathExtension.lowercased() == "app" else {
            throw ApplicationMetadataError.invalidBundle(applicationURL)
        }

        guard fileManager.isReadableFile(atPath: applicationURL.path) else {
            throw ApplicationMetadataError.bundleUnreadable(applicationURL)
        }

        let infoPlistURL = applicationURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")

        guard fileManager.isReadableFile(atPath: infoPlistURL.path) else {
            throw ApplicationMetadataError.infoPlistUnreadable(infoPlistURL)
        }

        guard let bundle = Bundle(url: applicationURL),
              let infoDictionary = bundle.infoDictionary else {
            throw ApplicationMetadataError.infoPlistUnreadable(infoPlistURL)
        }

        return Self.metadata(
            applicationURL: applicationURL,
            infoDictionary: infoDictionary,
            fileManager: fileManager
        )
    }

    static func metadata(
        applicationURL: URL,
        infoDictionary: [String: Any],
        fileManager: FileManager = .default
    ) -> ApplicationMetadata {
        let bundlePath = applicationURL.path
        let displayName = firstNonEmptyString(
            keys: ["CFBundleDisplayName", "CFBundleName"],
            in: infoDictionary
        ) ?? applicationURL.deletingPathExtension().lastPathComponent

        let bundleIdentifier = nonEmptyString(for: "CFBundleIdentifier", in: infoDictionary)
        let shortVersion = nonEmptyString(for: "CFBundleShortVersionString", in: infoDictionary)
        let buildNumber = nonEmptyString(for: "CFBundleVersion", in: infoDictionary)
        let executableName = nonEmptyString(for: "CFBundleExecutable", in: infoDictionary)

        var diagnostics: [ApplicationMetadataDiagnostic] = []
        if bundleIdentifier == nil {
            diagnostics.append(.missingBundleIdentifier)
        }
        if shortVersion == nil {
            diagnostics.append(.missingShortVersion)
        }
        if buildNumber == nil {
            diagnostics.append(.missingBuildNumber)
        }

        let executableURL = executableName.map {
            applicationURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("MacOS", isDirectory: true)
                .appendingPathComponent($0)
        }

        let executableExists = executableURL.map { fileManager.fileExists(atPath: $0.path) } ?? false
        let executablePath: String?

        if let executableURL, executableExists {
            executablePath = executableURL.path
        } else {
            executablePath = nil
            if executableName == nil {
                diagnostics.append(.missingExecutableName)
            } else if let executableName {
                diagnostics.append(.executableNotFound(executableName))
            }
        }

        return ApplicationMetadata(
            applicationURL: applicationURL,
            displayName: displayName,
            bundleIdentifier: bundleIdentifier,
            shortVersion: shortVersion,
            buildNumber: buildNumber,
            bundlePath: bundlePath,
            executableName: executableName,
            executablePath: executablePath,
            executableExists: executableExists,
            diagnostics: diagnostics
        )
    }

    private static func firstNonEmptyString(
        keys: [String],
        in dictionary: [String: Any]
    ) -> String? {
        for key in keys {
            if let value = nonEmptyString(for: key, in: dictionary) {
                return value
            }
        }
        return nil
    }

    private static func nonEmptyString(for key: String, in dictionary: [String: Any]) -> String? {
        guard let value = dictionary[key] as? String else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

enum ApplicationMetadataError: Error, Equatable {
    case applicationUnavailable(URL)
    case invalidBundle(URL)
    case bundleUnreadable(URL)
    case infoPlistUnreadable(URL)

    var userMessage: String {
        switch self {
        case .applicationUnavailable:
            return "The selected application is no longer available. Choose an existing .app bundle."
        case .invalidBundle:
            return "The selected item cannot be opened as a macOS application bundle."
        case .bundleUnreadable:
            return "The selected application cannot be read. Check permissions or choose a different app."
        case .infoPlistUnreadable:
            return "The selected application's Info.plist could not be read. Choose a different app."
        }
    }
}
