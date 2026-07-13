# App Signing Inspector

App Signing Inspector is a native macOS utility for inspecting application metadata, code-signing information, security attributes, and generating Declarative Device Management configuration data.

Its Version 1.0 focus is generating the `SigningID` and `TeamID` values required for macOS 27 `com.apple.configuration.app.settings` binary-management declarations, then formatting those values as a DDM `DeniedBinaries` JSON entry.

## Project Status

App Signing Inspector is currently in early development.

Current version:

`0.1.0`

The initial development focus is project setup and the Version 1.0 application-inspection workflow.

## Platform Support

The application itself is intended to support the earliest practical macOS version permitted by the APIs and tools it requires.

Initial testing is focused on macOS 27 because the DDM binary-management functionality targeted by the project is associated with macOS 27.

The application and the payloads it generates have separate compatibility requirements:

* **Application compatibility:** The macOS versions on which App Signing Inspector can run.
* **Payload compatibility:** The macOS versions that support the generated DDM declaration data.

Generating a payload does not guarantee that an MDM server or target device supports or successfully enforces it.

DDM payload models should be reviewed against Apple's official documentation as the macOS 27 beta and related management schemas evolve.

## Version 1.0 Scope

Version 1.0 is a focused minimum viable release for inspecting macOS `.app` bundles and generating a DDM `DeniedBinaries` entry.

Version 1.0 includes:

* Selecting one macOS `.app` bundle through a native file picker
* Displaying the application name and icon
* Displaying bundle identifier
* Displaying version and build number
* Displaying bundle and executable paths
* Displaying Signing ID
* Displaying Team ID
* Displaying signing authority or certificate chain
* Displaying relevant code-signing flags
* Detecting hardened runtime status
* Displaying signature validity
* Displaying signature timestamp where available
* Identifying whether the application is Apple-signed
* Displaying supported architectures
* Assessing Gatekeeper or notarization status where reliably supported
* Generating a valid `DeniedBinaries` JSON entry containing `SigningID` and `TeamID`
* Copying the generated JSON
* Handling unsigned, malformed, and unsupported applications gracefully

Version 1.0 does not include:

* Standalone executable inspection
* Recursive embedded-binary inspection
* Helper, framework, or nested app inspection
* Drag-and-drop selection
* Batch inspection
* Inspection history
* Complete DDM declaration generation
* DDM declaration validation
* Jamf API integration
* Network-based Team ID or certificate verification

## Future Scope

Planned future releases include:

* **Version 1.1:** Complete DDM declaration generation, including declaration identifiers and server tokens
* **Version 1.2:** Drag-and-drop application selection and export improvements
* **Version 2.0:** Standalone and recursively embedded binary inspection

These versions are planning guidance and may change based on development findings.

## Privacy

Application inspection is performed locally.

The project must not transmit application paths, signing information, certificate details, Team IDs, or other inspected metadata unless a future networked feature is explicitly designed, documented, and approved.

## Prerequisites

Expected prerequisites include:

* A Mac capable of running the selected Xcode version
* Xcode 16.0 or later
* Swift 6.0, as provided by the selected Xcode toolchain
* macOS 15.0 or later for the initial deployment target
* Git, recommended for source control

The application cannot be compiled on Windows because native macOS applications require Apple's macOS and Xcode toolchain.

## Repository Layout

The expected project layout is:

```text
AppSigningInspector/
|-- README.md
|-- PROJECT_RULES.md
|-- VISION.md
|-- LICENSE
|-- AppSigningInspector.xcodeproj
|-- AppSigningInspector/
|   |-- AppSigningInspectorApp.swift
|   |-- Models/
|   |-- Views/
|   |-- ViewModels/
|   |-- Services/
|   |-- Protocols/
|   |-- Utilities/
|   `-- Resources/
`-- AppSigningInspectorTests/
    `-- Fixtures/
```

The Xcode project is located at:

`AppSigningInspector.xcodeproj`

The final structure may change as the project grows.

## Building the Application

1. Open `AppSigningInspector.xcodeproj` in Xcode.
2. Select the App Signing Inspector scheme.
3. Select a compatible Mac destination.
4. Choose **Product > Build**, or press `Command-B`.

The initial project uses manual local code signing for development. If Xcode prompts for signing changes on a Mac, review the signing settings before accepting generated changes.

## Running the Application

1. Open the project in Xcode.
2. Select the App Signing Inspector scheme.
3. Choose **Product > Run**, or press `Command-R`.
4. Confirm the placeholder window opens and shows that no application is selected.

## Running Tests

1. Open the project in Xcode.
2. Select the App Signing Inspector scheme.
3. Select a compatible Mac destination.
4. Choose **Product > Test**, or press `Command-U`.

From Terminal on a Mac with Xcode installed, the project can also be tested with:

```sh
xcodebuild test -project AppSigningInspector.xcodeproj -scheme AppSigningInspector -destination 'platform=macOS'
```

Current test targets:

* `AppSigningInspectorTests`

Future tests should be separated into:

* Deterministic unit tests
* Parsing and payload-generation tests
* Platform integration tests
* UI tests only where valuable

Integration tests that rely on live macOS tools or local files should be clearly identified.

## Project Settings

Current initial project settings:

* Application name: App Signing Inspector
* Product/module name: `AppSigningInspector`
* Swift language version: Swift 6.0
* Minimum deployment target: macOS 15.0
* Marketing version: `0.1.0`
* Build number: `1`
* Application target: `AppSigningInspector`
* Unit test target: `AppSigningInspectorTests`

## Windows Development Note

The project files may be edited on Windows, but the application must be opened, built, run, and tested on a Mac with Xcode.

On Windows, validation is limited to static inspection of the project files and source layout.

## System Tools

The application may use Apple-provided command-line tools when equivalent public APIs are unavailable or impractical.

Potential tools include:

* `codesign`
* `spctl`
* `lipo`
* `file`

Shell and platform interactions must be isolated behind services. SwiftUI views must not execute these tools directly.

## Development Guidelines

Contributors must review:

* `VISION.md` for the long-term product direction, intended audience, guiding principles, and future capabilities
* `PROJECT_RULES.md` for enforceable architecture, testing, security, privacy, and implementation requirements

## DDM Documentation

Generated declaration data must track Apple's official Declarative Device Management schema and documentation.

Because the project is initially being developed against beta operating-system functionality, payload structure and behavior may change before the final macOS 27 release.

Any payload-schema assumptions should be documented in the source code and updated when Apple publishes revised guidance.

## License

The planned license is MIT. The final license file should be added during initial project setup.
