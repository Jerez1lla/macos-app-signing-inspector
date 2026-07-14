# App Signing Inspector 1.0.0

## Highlights

App Signing Inspector 1.0.0 is the first source release of a native macOS utility for inspecting application metadata, signing, and local security information and for building macOS 27 DDM application-execution declarations.

The application provides two independent workspaces in a native macOS sidebar: a focused single-application Inspector and a graphical multi-application Policy Builder.

## Inspector

* Select and inspect one macOS `.app` bundle.
* Review application name, icon, bundle identifier, version, build number, bundle path, and executable path.
* Review signature validity, Signing ID, Team ID, signing authorities, signing flags, hardened runtime status, signature timestamp, and Apple-signing status.
* Retrieve and copy the complete Designated Requirement.
* Review local Gatekeeper and conservatively reported notarization results.
* Review native main-executable architecture information and Universal, Apple silicon-only, Intel-only, or unknown classification.
* Copy individual technical values and review diagnostics without losing available inspection results.

## Policy Builder

* Add multiple applications while keeping Inspector state independent.
* Create Allow and Deny rules for specific applications.
* Create developer Team ID Allow rules and Apple-wide `*APPLE*` Allow rules.
* Verify a selected signed Jamf application's actual Team ID before confirming a developer-wide Allow rule.
* Configure optional absolute `PathPrefix` restrictions and `AlwaysAllowManagedApps`.
* Detect duplicate, redundant, unsupported, and incomplete rules.
* Warn about broad and allow-only policies before export.
* Generate a complete `com.apple.configuration.app.settings` declaration with Identifier and ServerToken UUID values.
* Preview, copy, and export declaration JSON.

## Security and Privacy

Inspection and policy generation occur locally. Version 1.0.0 includes no analytics or telemetry, requests no Jamf credentials, and does not upload application metadata or declarations. It does not modify inspected applications or change signatures, permissions, ownership, quarantine attributes, or security settings.

## Requirements

Version 1.0.0 is currently distributed as source code. Open `AppSigningInspector.xcodeproj` with a compatible version of Xcode on a Mac to build and run the application. No compiled application is attached to this release.

The project uses Swift 6.0, targets macOS 15.0 or later for the application, and currently uses Xcode 27 beta for macOS 27 beta development and validation. End users do not need Xcode or Xcode Command Line Tools for normal use of a built application.

Version 1.0.0 was built, run, and tested on macOS 27 beta with Xcode 27 beta. All automated tests passed during that validation.

## Known Limitations

* No standalone or recursively embedded binary inspection
* No batch folder scanning
* No declaration import or existing-declaration validation
* No persistent policy or inspection history
* No direct Jamf Blueprint upload
* No network-based Team ID or certificate verification
* Local Gatekeeper results are not authoritative remote Apple verification
* Developer-wide Deny rules are not generated until that object shape is explicitly verified in published schema documentation

Direct Jamf Blueprint integration depends on Jamf providing a stable and fully documented public API for Blueprint and custom declaration management.

## macOS 27 Beta Notice

The DDM binary-management model targets macOS 27 and is based on beta documentation. Schema names, accepted values, and enforcement behavior may change before final platform documentation is published. Generated declarations should be compared with current Apple documentation and tested in a controlled environment before deployment.

App Signing Inspector is not endorsed by Apple or Jamf. This release does not claim that any compiled build is signed or notarized.

## Future Direction

Future work may include standalone and embedded-binary inspection, declaration import and validation, policy history, batch inspection, application-version comparison, signed and notarized downloads, and Jamf Blueprint integration if a stable public API becomes available. No dates are promised.
