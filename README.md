# App Signing Inspector

App Signing Inspector is a native macOS utility for inspecting macOS `.app` signing details and building Declarative Device Management application execution declarations.

Its Version 1.0 focus is helping administrators collect Signing ID and Team ID values from multiple selected applications, assign each application an allowed or denied action, and use a graphical policy builder to generate a complete `com.apple.configuration.app.settings` declaration.

Version 1.0 supports JSON preview, clipboard copy, and local `.json` export for manual use in Jamf or another MDM platform. Direct Jamf upload is planned only as a future capability and depends on Jamf providing a stable and fully documented Blueprint API.

## Project Status

App Signing Inspector is currently in early development.

Current version:

`0.2.0`

The initial development focus is the Version 1.0 application-inspection and DDM policy-builder workflow.

## Platform Support

The application itself is intended to support the earliest practical macOS version permitted by the APIs and tools it requires.

Initial testing is focused on macOS 27 because the DDM binary-management functionality targeted by the project is associated with macOS 27.

The application and the payloads it generates have separate compatibility requirements:

* **Application compatibility:** The macOS versions on which App Signing Inspector can run.
* **Payload compatibility:** The macOS versions that support the generated DDM declaration data.

Generating a payload does not guarantee that an MDM server or target device supports or successfully enforces it.

DDM payload models should be reviewed against Apple's official documentation as the macOS 27 beta and related management schemas evolve.

## Version 1.0 Scope

Version 1.0 is a focused minimum viable release for inspecting macOS `.app` bundles and building a complete DDM application execution declaration.

Version 1.0 includes:

* Opening a dedicated graphical DDM policy builder
* Adding multiple macOS `.app` bundles through a native file picker
* Automatically inspecting each selected application
* Retrieving and storing each selected application's name, icon, Signing ID, and Team ID
* Choosing whether each selected application is allowed or denied
* Displaying selected applications in a clear editable list
* Changing an application between allowed and denied
* Removing an application from the policy
* Detecting duplicate applications or duplicate signing entries
* Warning when a selected application is unsigned or missing a Signing ID or Team ID
* Generating appropriate `AllowedBinaries` and `DeniedBinaries` arrays
* Generating a complete `com.apple.configuration.app.settings` declaration
* Generating valid UUID values for the declaration `Identifier` and `ServerToken`
* Previewing the generated JSON
* Copying the complete JSON to the clipboard
* Exporting the generated JSON to a local `.json` file
* Validating required values before allowing export
* Displaying a prominent warning when an allow-only policy could block management agents, security tools, background services, or other required software
* Handling unsigned, malformed, and unsupported applications gracefully

The interface must not automatically add management or security applications without the user's knowledge.

Version 1.0 does not include:

* Standalone executable inspection
* Recursive embedded-binary inspection
* Helper, framework, or nested application inspection
* Drag-and-drop selection
* Batch folder scanning
* Inspection history
* Existing DDM declaration import or validation
* Jamf API integration
* Network-based Team ID or certificate verification

## Future Scope

Planned future releases include:

* **Version 1.1:** Policy-builder refinements based on administrator feedback
* **Version 1.2:** Drag-and-drop application selection and export improvements
* **Version 2.0:** Standalone and recursively embedded binary inspection

These versions are planning guidance and may change based on development findings.

Future Jamf Pro integration may allow direct upload of generated declarations when Jamf provides a stable and fully documented public API for Blueprint and custom declaration management. Until that API is available and verified, Version 1.0 supports JSON copy and export for manual use in Jamf.

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
4. Use **Select Application** to choose one macOS `.app` bundle.
5. Confirm the selected application's icon, name, bundle identifier, version, build number, bundle path, executable name, and executable path are displayed where available.

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
