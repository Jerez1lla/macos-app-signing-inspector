import Foundation

struct ApplicationMetadata: Equatable {
    let applicationURL: URL
    let displayName: String
    let bundleIdentifier: String?
    let shortVersion: String?
    let buildNumber: String?
    let bundlePath: String
    let executableName: String?
    let executablePath: String?
    let executableExists: Bool
    let diagnostics: [ApplicationMetadataDiagnostic]

    var versionDisplayValue: String {
        shortVersion ?? "Unavailable"
    }

    var buildDisplayValue: String {
        buildNumber ?? "Unavailable"
    }

    var bundleIdentifierDisplayValue: String {
        bundleIdentifier ?? "Unavailable"
    }

    var executableNameDisplayValue: String {
        executableName ?? "Unavailable"
    }

    var executablePathDisplayValue: String {
        executablePath ?? "Unavailable"
    }
}

enum ApplicationMetadataDiagnostic: Equatable {
    case missingBundleIdentifier
    case missingShortVersion
    case missingBuildNumber
    case missingExecutableName
    case executableNotFound(String)

    var message: String {
        switch self {
        case .missingBundleIdentifier:
            return "Bundle identifier is unavailable."
        case .missingShortVersion:
            return "Version is unavailable."
        case .missingBuildNumber:
            return "Build number is unavailable."
        case .missingExecutableName:
            return "Executable name is unavailable."
        case .executableNotFound:
            return "Executable file could not be found."
        }
    }
}
