# App Signing Inspector Vision

## Product Vision

App Signing Inspector will be a native macOS utility designed to help Mac administrators inspect application metadata, code-signing information, security attributes, and binary details without requiring them to manually run and interpret Terminal commands.

The application should make it easy for administrators to identify the values required for application management, security troubleshooting, and Declarative Device Management configurations, especially the `SigningID` and `TeamID` values used by the macOS 27 `com.apple.configuration.app.settings` declaration. It should also help administrators build application execution policies without manually assembling DDM JSON.

## Problem Statement

Mac administrators frequently need to inspect applications using command-line tools such as `codesign` and `spctl`, while other details can be obtained through native macOS APIs.

Although these tools provide the required information, the process has several limitations:

* Administrators must know the correct commands and arguments.
* Relevant information is mixed into large command outputs.
* Values must be manually copied into configuration profiles or DDM declarations.
* Allow and deny policy intent can be difficult to review when declaration JSON is edited by hand.
* Complex applications may contain multiple embedded helpers and executables.
* Manual JSON creation increases the possibility of formatting errors.
* Less experienced administrators may not understand how code-signing information maps to management payloads.

App Signing Inspector will simplify this process by presenting the information in a clear graphical interface and generating usable configuration data automatically.

## Target Audience

The primary audience is:

* Jamf Pro administrators
* Apple platform administrators
* Endpoint engineers
* Desktop administrators
* Security engineers
* macOS application packagers
* IT support teams managing Apple devices

The application should remain understandable for administrators who are comfortable managing macOS but may not have development or advanced command-line experience.

## Version 1.0 Direction

Version 1.0 is intentionally organized around two separate primary workspaces: **Inspector** and **Policy Builder**.

The Inspector should remain a focused, independent workflow for examining one macOS `.app` bundle. The Policy Builder should let administrators combine specific-application, developer Team ID, Apple-binary, path-restricted, and managed-application options supported by the documented macOS 27 schema, review the resulting policy, and generate complete JSON for manual use in an MDM platform such as Jamf Pro.

A compact native macOS sidebar should make both workspaces directly available, with Inspector selected by default. Workspace state should remain separate so inspecting an application never requires beginning a policy, and policy editing does not replace or crowd the Inspector.

The authoritative Version 1.0 scope is maintained in `README.md`.

## Long-Term Goals

Over time, App Signing Inspector should allow an administrator to:

1. Select macOS applications, standalone executables, or groups of binaries.
2. View application metadata and binary details.
3. View code-signing identity, developer Team ID, and signing authority information.
4. Confirm whether applications are properly signed and notarized.
5. View supported processor architectures.
6. Inspect embedded applications, helpers, frameworks, and executables.
7. Generate valid DDM binary-management JSON.
8. Copy, save, or export information without manually formatting it.
9. Troubleshoot application-management and security issues more quickly.

These goals describe the longer-term product direction. They are not all included in Version 1.0.

## Future Capabilities

Planned future releases include:

* **Version 1.1:** Policy-builder refinements based on administrator feedback
* **Version 1.2:** Drag-and-drop application selection and export improvements
* **Version 2.0:** Standalone and recursively embedded binary inspection

Other potential post-Version 1.0 capabilities include:

* Batch inspection of multiple applications
* Export to JSON or CSV
* Previously inspected application history
* Comparison of two application versions
* Existing DDM declaration validation
* Jamf-ready configuration snippets
* Search of installed applications
* Inspection reports for documentation or change management
* Optional command-line companion tool

These features should only be added when they support the application's main purpose and do not make the interface unnecessarily complicated.

## Future Jamf Pro Integration

Post-Version 1.0, App Signing Inspector may integrate directly with Jamf Pro if Jamf provides a stable and fully documented public API for Blueprint and custom declaration management.

Future Jamf Pro integration should support:

* Authenticating securely to Jamf Pro
* Retrieving available Blueprints
* Selecting a target Blueprint
* Creating or updating a custom declaration component
* Uploading the generated `com.apple.configuration.app.settings` declaration directly to Jamf
* Reading back the deployed declaration where supported
* Avoiding storage of Jamf credentials in plaintext
* Supporting Jamf API roles and least-privilege access

Until the required Jamf APIs are available and verified, Version 1.0 will support JSON preview, copy, and export for manual use in Jamf.

## Design Principles

### Native

The application should look and behave like a modern macOS utility. It should use SwiftUI, native macOS controls, standard file pickers, SF Symbols, and familiar interaction patterns.

### Simple

A user should be able to open the application, select apps, assign allowed or denied actions, and understand the resulting DDM policy within a few seconds.

Advanced information may be available, but the most important values should always be easy to locate.

### Accurate

The application must display values exactly as macOS reports them. It should not guess, alter, or substitute signing information.

Generated JSON must be properly formatted, valid, and deterministic.

### Safe

The application should inspect files without modifying them. It should not change application signatures, permissions, ownership, quarantine attributes, or system security settings.

### Transparent

When the application uses Apple command-line tools such as `codesign` or `spctl`, the behavior should be documented. Reliable native APIs should be preferred so end users are not required to install developer tools. Errors should explain what failed rather than hiding the underlying problem.

### Maintainable

The project should use a modular structure so individual inspection, security, and JSON-generation features can be updated independently.

The code should be understandable by someone learning Swift and should avoid unnecessary complexity.

### Useful for Real Administrators

Features should solve real macOS administration problems. The project should avoid adding features only because they are technically interesting.

## User Experience Goal

Version 1.0 should open to the Inspector and present two clear sidebar destinations:

* **Inspector:** Select one macOS `.app` bundle, review its inspection results, and copy individual values.
* **Policy Builder:** Add multiple applications, assign allow or deny actions, review validation and safety warnings, and preview, copy, or export the generated `com.apple.configuration.app.settings` JSON.

Both workflows should require no Terminal usage. Switching between them should feel native, preserve valid state, and avoid mixing single-application inspection state with multi-application policy state.

Post-Version 1.0 workflows may add drag-and-drop, direct Jamf Pro upload, standalone executable inspection, and embedded binary inspection.

## Technical Direction

The application will be:

* Written in Swift
* Built with SwiftUI
* Designed for macOS
* Structured using a clear separation between views, models, and services
* Organized as separate Inspector and Policy Builder workspaces within a native `NavigationSplitView`
* Designed with independent workspace state and shared inspection services
* Built primarily with Apple-provided frameworks
* Free of third-party dependencies unless there is a strong documented reason
* Compatible with light and dark mode
* Designed to support current macOS releases, with initial testing focused on macOS 27

Native APIs should be preferred when they provide reliable results. Apple command-line tools may be used where macOS does not expose equivalent information through a practical public API.

## Success Measures

The project will be successful when:

* An administrator can retrieve signing information without opening Terminal.
* A valid DDM application execution declaration can be generated without manually editing JSON.
* The tool correctly handles signed, unsigned, Apple-signed, and notarized applications.
* The interface remains understandable to administrators who do not write code.
* The application reduces the time and errors involved in creating binary-management configurations.
* The project is documented well enough that it can be maintained and expanded over time.

## Project Identity

**Application Name:** App Signing Inspector

**Repository Name:** `macos-app-signing-inspector`

**Current Release Target:** `1.0.0`

**Platform:** macOS

**Primary Use Case:** Application inspection and DDM binary-policy generation for Mac administrators
