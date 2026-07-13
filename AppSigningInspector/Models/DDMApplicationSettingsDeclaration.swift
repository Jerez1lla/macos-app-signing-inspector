import Foundation

struct DDMApplicationSettingsDeclaration: Codable, Equatable, Sendable {
    let type: String
    let identifier: String
    let serverToken: String
    let payload: DDMApplicationSettingsPayload

    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case identifier = "Identifier"
        case serverToken = "ServerToken"
        case payload = "Payload"
    }
}

struct DDMApplicationSettingsPayload: Codable, Equatable, Sendable {
    let allowed: DDMAllowedApplicationSettings

    enum CodingKeys: String, CodingKey {
        case allowed = "Allowed"
    }
}

struct DDMAllowedApplicationSettings: Codable, Equatable, Sendable {
    let alwaysAllowManagedApps: Bool?
    let allowedBinaries: [DDMApplicationBinary]?
    let deniedBinaries: [DDMApplicationBinary]?

    enum CodingKeys: String, CodingKey {
        case alwaysAllowManagedApps = "AlwaysAllowManagedApps"
        case allowedBinaries = "AllowedBinaries"
        case deniedBinaries = "DeniedBinaries"
    }
}

struct DDMApplicationBinary: Codable, Equatable, Sendable {
    let signingIdentifier: String?
    let teamIdentifier: String
    let pathPrefix: String?

    enum CodingKeys: String, CodingKey {
        case signingIdentifier = "SigningID"
        case teamIdentifier = "TeamID"
        case pathPrefix = "PathPrefix"
    }
}

struct GeneratedDDMDeclaration: Equatable, Sendable {
    let declaration: DDMApplicationSettingsDeclaration
    let json: String
}
