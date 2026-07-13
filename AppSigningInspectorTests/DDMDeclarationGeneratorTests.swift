import Foundation
import XCTest
@testable import AppSigningInspector

final class DDMDeclarationGeneratorTests: XCTestCase {
    private let generator = DDMDeclarationGenerator()
    private let identifier = UUID(uuid: (
        0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11,
        0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11
    ))
    private let serverToken = UUID(uuid: (
        0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22,
        0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22
    ))

    func testGeneratesCompleteApplicationSettingsDeclaration() throws {
        let generated = try generator.generate(
            entries: [
                candidate("com.example.allowed", "ALLOWTEAM", .allow),
                candidate("com.example.denied", "DENYTEAM", .deny)
            ],
            identifier: identifier,
            serverToken: serverToken
        )

        XCTAssertEqual(generated.declaration.type, "com.apple.configuration.app.settings")
        XCTAssertEqual(generated.declaration.identifier, identifier.uuidString)
        XCTAssertEqual(generated.declaration.serverToken, serverToken.uuidString)
        XCTAssertEqual(generated.declaration.payload.allowed.allowedBinaries, [
            DDMApplicationBinary(
                signingIdentifier: "com.example.allowed",
                teamIdentifier: "ALLOWTEAM",
                pathPrefix: nil
            )
        ])
        XCTAssertEqual(generated.declaration.payload.allowed.deniedBinaries, [
            DDMApplicationBinary(
                signingIdentifier: "com.example.denied",
                teamIdentifier: "DENYTEAM",
                pathPrefix: nil
            )
        ])
    }

    func testJSONUsesRequiredCaseSensitiveKeysAndNesting() throws {
        let generated = try generator.generate(
            entries: [candidate("com.example.app", "TEAMID1234", .deny)],
            identifier: identifier,
            serverToken: serverToken
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(generated.json.utf8)) as? [String: Any]
        )
        let payload = try XCTUnwrap(object["Payload"] as? [String: Any])
        let allowed = try XCTUnwrap(payload["Allowed"] as? [String: Any])
        let denied = try XCTUnwrap(allowed["DeniedBinaries"] as? [[String: String]])

        XCTAssertEqual(Set(object.keys), Set(["Type", "Identifier", "ServerToken", "Payload"]))
        XCTAssertNotNil(allowed["AllowedBinaries"] as? [[String: String]])
        XCTAssertEqual(denied, [["SigningID": "com.example.app", "TeamID": "TEAMID1234"]])
    }

    func testPreservesEntryOrderWithinAllowedAndDeniedArrays() throws {
        let generated = try generator.generate(
            entries: [
                candidate("allow.one", "TEAM1", .allow),
                candidate("deny.one", "TEAM2", .deny),
                candidate("allow.two", "TEAM3", .allow),
                candidate("deny.two", "TEAM4", .deny)
            ],
            identifier: identifier,
            serverToken: serverToken
        )

        XCTAssertEqual(
            generated.declaration.payload.allowed.allowedBinaries?.compactMap(\.signingIdentifier),
            ["allow.one", "allow.two"]
        )
        XCTAssertEqual(
            generated.declaration.payload.allowed.deniedBinaries?.compactMap(\.signingIdentifier),
            ["deny.one", "deny.two"]
        )
    }

    func testEquivalentInputProducesStableJSON() throws {
        let entries = [candidate("com.example.app", "TEAMID1234", .allow)]

        let first = try generator.generate(
            entries: entries,
            identifier: identifier,
            serverToken: serverToken
        )
        let second = try generator.generate(
            entries: entries,
            identifier: identifier,
            serverToken: serverToken
        )

        XCTAssertEqual(first.json, second.json)
    }

    func testEmptyPolicyIsRejected() {
        XCTAssertThrowsError(try generator.generate(
            entries: [],
            identifier: identifier,
            serverToken: serverToken
        )) { error in
            XCTAssertEqual(error as? DDMDeclarationGenerationError, .emptyPolicy)
        }
    }

    func testManagedAppsOnlyProducesTrueAndOmitsBinaryArrays() throws {
        let generated = try generator.generate(
            entries: [],
            alwaysAllowManagedApps: true,
            identifier: identifier,
            serverToken: serverToken
        )
        let allowed = generated.declaration.payload.allowed

        XCTAssertEqual(allowed.alwaysAllowManagedApps, true)
        XCTAssertNil(allowed.allowedBinaries)
        XCTAssertNil(allowed.deniedBinaries)
    }

    func testDisabledManagedAppsOmitsKey() throws {
        let generated = try generator.generate(
            entries: [candidate("app.id", "TEAM1", .deny)],
            identifier: identifier,
            serverToken: serverToken
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(generated.json.utf8)) as? [String: Any]
        )
        let payload = try XCTUnwrap(object["Payload"] as? [String: Any])
        let allowed = try XCTUnwrap(payload["Allowed"] as? [String: Any])

        XCTAssertNil(allowed["AlwaysAllowManagedApps"])
    }

    func testManagedAppsCombinesWithAllowedAndDeniedRules() throws {
        let generated = try generator.generate(
            entries: [
                candidate("allow.id", "TEAM1", .allow),
                candidate("deny.id", "TEAM2", .deny)
            ],
            alwaysAllowManagedApps: true,
            identifier: identifier,
            serverToken: serverToken
        )
        let allowed = generated.declaration.payload.allowed

        XCTAssertEqual(allowed.alwaysAllowManagedApps, true)
        XCTAssertEqual(allowed.allowedBinaries?.count, 1)
        XCTAssertEqual(allowed.deniedBinaries?.count, 1)
    }

    func testAppleAndDeveloperRulesUseTeamIDOnly() throws {
        let generated = try generator.generate(
            entries: [
                PolicyBinaryCandidate(rule: .appleBinaries, action: .allow),
                PolicyBinaryCandidate(rule: .developerTeam(teamIdentifier: "EQHXZ8M8AV"), action: .allow)
            ],
            identifier: identifier,
            serverToken: serverToken
        )
        let binaries = try XCTUnwrap(generated.declaration.payload.allowed.allowedBinaries)

        XCTAssertEqual(binaries.map(\.teamIdentifier), ["*APPLE*", "EQHXZ8M8AV"])
        XCTAssertTrue(binaries.allSatisfy { $0.signingIdentifier == nil && $0.pathPrefix == nil })
        XCTAssertFalse(generated.json.contains("null"))
    }

    func testSpecificApplicationIncludesOptionalAbsolutePathWithSpaces() throws {
        let path = "/Applications/Example App.app"
        let generated = try generator.generate(
            entries: [PolicyBinaryCandidate(
                rule: .specificApplication(
                    signingIdentifier: "com.example.app",
                    teamIdentifier: "TEAM1",
                    pathPrefix: path
                ),
                action: .allow
            )],
            identifier: identifier,
            serverToken: serverToken
        )
        let binary = try XCTUnwrap(generated.declaration.payload.allowed.allowedBinaries?.first)

        XCTAssertEqual(binary.pathPrefix, path)
        XCTAssertTrue(generated.json.contains(path))
    }

    func testTeamOnlyDenyRuleIsRejectedUntilSchemaIsVerified() {
        XCTAssertThrowsError(try generator.generate(
            entries: [PolicyBinaryCandidate(
                rule: .developerTeam(teamIdentifier: "TEAM1"),
                action: .deny
            )],
            identifier: identifier,
            serverToken: serverToken
        )) { error in
            XCTAssertEqual(error as? DDMDeclarationGenerationError, .invalidEntries)
        }
    }

    private func candidate(
        _ signingIdentifier: String,
        _ teamIdentifier: String,
        _ action: PolicyAction
    ) -> PolicyBinaryCandidate {
        PolicyBinaryCandidate(
            rule: .specificApplication(
                signingIdentifier: signingIdentifier,
                teamIdentifier: teamIdentifier,
                pathPrefix: nil
            ),
            action: action
        )
    }
}
