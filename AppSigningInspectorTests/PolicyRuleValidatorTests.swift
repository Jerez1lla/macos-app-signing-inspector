import XCTest
@testable import AppSigningInspector

final class PolicyRuleValidatorTests: XCTestCase {
    private let validator = PolicyRuleValidator()

    func testSpecificApplicationRequiresSigningAndTeamIdentifiers() {
        XCTAssertEqual(
            validator.validate(
                .specificApplication(signingIdentifier: nil, teamIdentifier: nil, pathPrefix: nil),
                action: .deny
            ),
            .missingSigningAndTeamIdentifiers
        )
        XCTAssertEqual(
            validator.validate(
                .specificApplication(signingIdentifier: "app.id", teamIdentifier: nil, pathPrefix: nil),
                action: .allow
            ),
            .missingTeamIdentifier
        )
    }

    func testSpecificApplicationAcceptsOptionalAbsolutePath() {
        XCTAssertEqual(
            validator.validate(
                .specificApplication(
                    signingIdentifier: "app.id",
                    teamIdentifier: "TEAM1",
                    pathPrefix: "/Applications/Example App.app"
                ),
                action: .allow
            ),
            .valid
        )
    }

    func testRelativePathIsInvalid() {
        XCTAssertEqual(
            validator.validate(
                .specificApplication(
                    signingIdentifier: "app.id",
                    teamIdentifier: "TEAM1",
                    pathPrefix: "Applications/Example.app"
                ),
                action: .allow
            ),
            .invalidPathPrefix
        )
    }

    func testDeveloperRuleRequiresTeamIDAndRejectsWildcards() {
        XCTAssertEqual(
            validator.validate(.developerTeam(teamIdentifier: ""), action: .allow),
            .missingTeamIdentifier
        )
        XCTAssertEqual(
            validator.validate(.developerTeam(teamIdentifier: "*GOOGLE*"), action: .allow),
            .invalidSpecialTeamIdentifier
        )
    }

    func testDeveloperDenyIsUnsupported() {
        XCTAssertEqual(
            validator.validate(.developerTeam(teamIdentifier: "TEAM1"), action: .deny),
            .unsupportedRuleAction
        )
    }

    func testManualTeamIDNormalizationOnlyTrimsSurroundingWhitespace() {
        XCTAssertEqual(
            validator.normalizedManualTeamIdentifier("  AbCd1234  \n"),
            "AbCd1234"
        )
    }
}
