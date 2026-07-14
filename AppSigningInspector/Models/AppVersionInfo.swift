import Foundation

struct AppVersionInfo: Equatable {
    let displayName: String
    let marketingVersion: String
    let buildNumber: String

    init(infoDictionary: [String: Any]) {
        displayName = infoDictionary["CFBundleDisplayName"] as? String
            ?? infoDictionary["CFBundleName"] as? String
            ?? "App Signing Inspector"
        marketingVersion = infoDictionary["CFBundleShortVersionString"] as? String ?? "Unknown"
        buildNumber = infoDictionary["CFBundleVersion"] as? String ?? "Unknown"
    }

    static var current: AppVersionInfo {
        AppVersionInfo(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }

    var versionDescription: String {
        "Version \(marketingVersion) (\(buildNumber))"
    }
}
