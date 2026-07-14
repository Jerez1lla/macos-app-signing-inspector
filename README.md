# App Signing Inspector

[![Platform: macOS 15+](https://img.shields.io/badge/platform-macOS%2015%2B-black)](https://www.apple.com/macos/)
[![Language: Swift 6](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![UI: SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0D96F6)](https://developer.apple.com/xcode/swiftui/)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A native macOS utility for inspecting application metadata, code-signing details, security information, and building macOS 27 Declarative Device Management application-execution declarations.

App Signing Inspector has two independent workspaces. **Inspector** examines one macOS application in depth. **Policy Builder** assembles multi-application Allow and Deny rules and generates a complete `com.apple.configuration.app.settings` declaration.

## Version and Project Status

The current version is **1.0.0** (build **1**). Version 1.0.0 has been built, run, and tested on macOS 27 Golden Gate beta with Xcode 27 beta.

Version 1.0.0 is distributed as source code. No prebuilt, signed, or notarized application is included in the current release.

## Screenshots

Release screenshots have not yet been added. Any future screenshots must be reviewed before publication to ensure they contain no private application names, internal paths, credentials, organization information, or personal data.

## Version 1.0 Features

### Inspector

* Select one macOS `.app` bundle with the native file picker.
* Display the application name, icon, bundle identifier, version, and build number.
* Display bundle and executable paths.
* Display Signing ID, Team ID, signing authorities, code-signing flags, hardened runtime status, signature timestamp, and Apple-signed or third-party-signed status.
* Retrieve and display the complete Designated Requirement.
* Display local Gatekeeper assessment and notarization status where macOS reports it.
* Display processor architectures and classify the application as Universal, Apple silicon-only, Intel-only, or unknown.
* Copy important values individually.
* Preserve available results and display technical diagnostics when part of an inspection is unavailable.

### Policy Builder

* Use a separate graphical workspace while preserving Inspector state.
* Add multiple macOS applications and assign Allow or Deny actions.
* Build specific-application rules and developer Team-ID-wide Allow rules.
* Allow Apple binaries with Apple's documented `*APPLE*` Team ID token.
* Build a Jamf developer-wide Allow rule by inspecting a selected signed Jamf application and confirming its actual Team ID.
* Enable `AlwaysAllowManagedApps` and add optional absolute `PathPrefix` restrictions.
* Detect duplicate applications and duplicate signing rules.
* Warn about potentially redundant broad rules and allow-only policies.
* Generate Identifier and ServerToken UUID values.
* Preview, copy, and export the complete declaration JSON.

## Inspector Workflow

1. Open **Inspector** from the sidebar. It is selected by default.
2. Choose **Select Application** and select a `.app` bundle.
3. Review metadata, signing, Designated Requirement, Gatekeeper, notarization, and architecture results.
4. Copy individual values as needed.

Inspection does not require creating or modifying a policy.

## Policy Builder Workflow

1. Open **Policy Builder** from the sidebar.
2. Add one or more applications or add an approved broad rule.
3. Assign each specific application an Allow or Deny action.
4. Review validation, duplicate, redundancy, and allow-only warnings.
5. Preview the generated `com.apple.configuration.app.settings` declaration.
6. Copy the JSON or export it to a user-selected local `.json` file.

Version 1.0 does not upload declarations directly to Jamf Pro.

## Supported DDM Rule Types

* Specific application Allow or Deny rules using Signing ID and Team ID
* Developer-wide Allow rules using an actual signing Team ID
* Apple-wide Allow rules using the documented `*APPLE*` Team ID token
* Jamf convenience workflow that verifies a selected signed application's Team ID before creating a developer-wide Allow rule
* Optional absolute `PathPrefix` restrictions for specific application rules
* Optional `AlwaysAllowManagedApps`

The project does not invent company-name wildcard values. Third-party broad rules use actual Team IDs.

## Requirements

### Application Runtime

* A compatible Mac running macOS 15.0 or later
* macOS 27 for the DDM application-execution declaration behavior targeted by Version 1.0
* No Xcode or Xcode Command Line Tools for normal inspection and policy generation
* No Apple developer account where local macOS security policy permits the application to run
* No network connection for normal inspection and policy generation

### Development

* A Mac with a compatible version of Xcode
* Xcode 27 beta for the current macOS 27 beta development and validation environment
* Swift 6.0 language mode
* macOS 15.0 deployment target
* Git for source control

Native macOS applications require Apple's macOS and Xcode toolchain. This project cannot be compiled on Windows.

## Installation and Running

Version 1.0.0 is currently available as source code:

1. Clone or download the repository source.
2. Open `AppSigningInspector.xcodeproj` in Xcode on a Mac.
3. Select the `AppSigningInspector` scheme and a compatible Mac destination.
4. Choose **Product > Run**, or press `Command-R`.

A prebuilt signed application may be provided in a later release. Do not disable Gatekeeper or bypass macOS security protections to run the project.

## Building From Source

1. Open `AppSigningInspector.xcodeproj` in Xcode.
2. Select the `AppSigningInspector` scheme.
3. Select a compatible Mac destination.
4. Choose **Product > Build**, or press `Command-B`.

The project uses manual local signing for development. Review any signing changes proposed by Xcode before accepting them.

## Running Tests

In Xcode, select the `AppSigningInspector` scheme and choose **Product > Test**, or press `Command-U`.

From Terminal on a Mac with Xcode installed:

```sh
xcodebuild test -project AppSigningInspector.xcodeproj -scheme AppSigningInspector -destination 'platform=macOS'
```

The `AppSigningInspectorTests` target contains deterministic unit tests for metadata, signing, security assessment, architecture inspection, policy validation, navigation state, and DDM JSON generation.

## Privacy and Security

* Inspection and policy generation occur locally.
* Application metadata and generated declarations are not uploaded.
* No analytics or telemetry are included.
* No Jamf credentials are requested or stored.
* No network connection is required for normal inspection and policy generation.
* Inspected applications are not modified or launched.
* The app does not change signatures, permissions, ownership, quarantine attributes, or security settings.
* Selected paths and command output are treated as untrusted input.

Security issues should be handled according to [SECURITY.md](SECURITY.md).

## Known Limitations

* Inspection currently focuses on `.app` bundles.
* Standalone executable inspection is not included.
* Recursive embedded-binary, helper, framework, and nested-app inspection are not included.
* Existing declarations cannot be imported or validated.
* Policy and inspection history are not persisted.
* Batch folder scanning is not included.
* Direct Jamf Blueprint upload is not included.
* Direct Jamf integration depends on a stable and documented public Blueprint API.
* Local Gatekeeper results are not authoritative remote Apple verification.
* The documented `*APPLE*` value is treated as a specific schema token.
* Third-party broad rules use actual Team IDs rather than invented company-name wildcard values.

## macOS 27 Beta Schema Warning

Version 1.0 targets DDM application-execution behavior documented for macOS 27 beta. Declaration names, accepted values, and enforcement behavior may change before Apple publishes final documentation.

Generating valid JSON does not guarantee that an MDM server or target device supports or enforces the declaration. Administrators should compare generated declarations with current Apple documentation and test them in a controlled environment before deployment.

App Signing Inspector is not endorsed by Apple or Jamf.

## Roadmap

Potential future directions include:

* Standalone binary inspection
* Embedded helper and framework inspection
* Declaration import and validation
* Policy and inspection history
* Batch inspection
* Comparison between application versions
* Jamf Blueprint integration if a stable public API becomes available
* Signed and notarized downloadable releases

Roadmap items are planning guidance and have no promised dates.

## Contributing

Contributions and reproducible issue reports are welcome. Review [CONTRIBUTING.md](CONTRIBUTING.md), [PROJECT_RULES.md](PROJECT_RULES.md), and [VISION.md](VISION.md) before proposing changes.

## License

App Signing Inspector is available under the [MIT License](LICENSE).
