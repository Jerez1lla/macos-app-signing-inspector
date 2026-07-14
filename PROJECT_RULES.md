# App Signing Inspector Project Rules

## Purpose

This document defines enforceable architecture, coding, testing, privacy, security, and development requirements for App Signing Inspector.

The product scope for Version 1.0 is defined in `README.md`. Long-term product direction and future capabilities are described in `VISION.md`.

## Architecture

* Use Swift and SwiftUI.
* Use a clear separation between views, models, view models, and services.
* SwiftUI views should be responsible primarily for presentation and user interaction.
* Keep business logic out of SwiftUI views.
* Keep platform inspection and shell execution behind dedicated services and protocols.
* Make parsing, policy modeling, validation, duplicate detection, and JSON-generation logic independently testable.
* Prefer dependency injection where it improves testing and maintainability.
* Avoid unnecessary abstraction or architectural complexity.
* Do not use third-party libraries unless they are reviewed and approved.
* Keep Inspector state and Policy Builder state in separate view models or equivalent focused state owners.
* Reuse metadata, signing, security, process-execution, and clipboard services across workspaces rather than duplicating platform logic.
* Do not introduce a single oversized view model that owns both Inspector and Policy Builder state.

## Project Structure

Organize source code into logical areas such as:

* `Models`
* `Views`
* `ViewModels`
* `Services`
* `Protocols`
* `Utilities`
* `Resources`
* `Tests`
* `Fixtures`

The exact structure may evolve as the project grows, but files should be grouped by responsibility.

## Code Style

* Use clear and descriptive names.
* Prefer small, focused types and functions.
* Avoid force unwraps.
* Avoid force casts.
* Prefer Swift concurrency and `async/await` where appropriate.
* Use access control intentionally.
* Document public or non-obvious behavior.
* Remove unused code and temporary debugging output before completing a story.
* Keep files reasonably sized and split them when they develop multiple responsibilities.
* Follow standard Swift naming and formatting conventions.

## User Interface

* Follow Apple's macOS Human Interface Guidelines.
* Use native macOS controls and interaction patterns.
* Use SwiftUI and SF Symbols where appropriate.
* Use `NavigationSplitView` as the primary navigation container for the Version 1.0 Inspector and Policy Builder workspaces.
* Use a compact native sidebar with **Inspector** (`doc.text.magnifyingglass`) and **Policy Builder** (`list.bullet.rectangle`) destinations.
* Select Inspector by default when the application opens.
* Keep the sidebar visually unobtrusive, preserve standard macOS split-view behavior, and keep the current minimum window size usable.
* Preserve valid workspace state when switching destinations; do not merge Inspector and Policy Builder selection or presentation state.
* Do not replace the required sidebar with a modal, segmented control, tab view, temporary screen-replacement button, or custom navigation pattern.
* Leave room for future destinations without implementing empty or speculative destinations.
* Support light and dark appearance.
* Support keyboard navigation where practical.
* Display important signing values clearly and make them easy to copy.
* Keep advanced details available without overwhelming the primary workflow.
* Make multi-application policy state clear, editable, and reviewable before JSON is copied or exported.
* Clearly distinguish allowed and denied policy actions.
* Display duplicate entries, missing required values, and allow-only policy safety warnings before export.
* Use progress indicators for inspection work that may take noticeable time.
* Ensure empty, loading, success, and failure states are represented clearly.

## System Integration

* Do not call shell tools directly from SwiftUI views.
* Wrap platform calls behind services and protocols.
* Use absolute paths for Apple command-line tools where practical.
* Avoid invoking a general-purpose shell when a process can be launched directly.
* Capture standard output, standard error, termination status, and executed arguments.
* Do not modify inspected applications.
* Do not change signatures, permissions, ownership, quarantine attributes, or security settings.
* Prefer native Apple APIs when they provide reliable and maintainable results.
* Use Apple command-line tools when an equivalent practical public API is unavailable.
* End-user features must not depend on Xcode, Xcode Command Line Tools, developer-license acceptance, or developer commands when a reliable native macOS API exists.
* Main-executable architecture inspection must use Foundation bundle architecture information and must not invoke `lipo`, `file`, `xcrun`, or `xcodebuild`.
* Keep command-output parsing separate from process execution.
* Treat selected files, paths, and command outputs as untrusted input.

Potential system tools may include:

* `/usr/bin/codesign`
* `/usr/sbin/spctl`

Use of these tools must be isolated in service code and covered by parsing tests where practical.

## Error Handling

* Use typed or domain-specific errors where practical.
* Do not silently ignore failures.
* User-facing errors must explain what failed and what the user can do next.
* Avoid exposing unnecessarily technical output in the primary error message.
* Preserve raw command output and diagnostic details for troubleshooting.
* Expected conditions, such as selecting an unsigned app, should not cause the application to crash.

Clearly distinguish between:

* Unsupported files
* Unsigned binaries
* Invalid signatures
* Tool execution failures
* Parsing failures
* Permission failures
* Security-assessment failures

## Testing

* Unit test parsing, validation, and payload generation.
* Unit test policy models, allow/deny assignment, duplicate detection, and required-value validation.
* Test code-signing output parsing independently from live system commands.
* Avoid unit tests that depend on applications installed on the developer's machine.
* Mark tests that invoke live macOS tools as integration tests.
* Keep integration tests separate from deterministic unit tests.
* Add UI or snapshot tests only when they provide meaningful value.
* Payload-generation tests should verify exact expected JSON structure.
* Payload-generation tests should verify deterministic ordering and stable formatting.
* Tests must not require network access unless explicitly documented.

Use fixtures representing:

* Properly signed applications
* Unsigned applications
* Apple-signed applications
* Notarized applications
* Rejected applications
* Malformed command output
* Missing signing identifiers
* Missing Team IDs
* Multiple signing authorities
* Universal and single-architecture binaries

## Security and Privacy

* Perform application inspection locally by default.
* Do not upload or transmit inspected application metadata.
* Do not add analytics, telemetry, or network communication without explicit review and documentation.
* Avoid persisting application paths, signing certificates, Team IDs, or inspection history unless required by an approved feature.
* Do not log sensitive local paths unnecessarily.
* Clearly distinguish local inspection results from authoritative verification performed by Apple or another external service.
* Treat all selected paths and command outputs as untrusted input.
* Do not construct shell command strings using unescaped user-controlled values.
* Do not automatically add management tools, security tools, agents, or background services to generated policies without clear user action.
* Do not store future MDM or Jamf credentials in plaintext.
* Keep future network integrations behind explicit service boundaries and least-privilege permission assumptions.

## Third-Party Dependencies

Third-party packages are not permitted unless approved.

Approval requires:

* A documented reason the dependency is needed
* An explanation of why native APIs are insufficient
* Review of the dependency's license
* Review of its maintenance status
* Review of its security history where applicable
* Consideration of the long-term maintenance cost
* Documentation in the README or project decisions

Prefer Apple frameworks and small internal implementations when reasonable.

## DDM Payload Generation

* Generated payload data must follow Apple's documented schema.
* Model DDM policies as structured data before encoding JSON.
* Support multiple selected applications with explicit allowed or denied policy actions.
* Keep payload models separate from UI code.
* Use `Codable` and `JSONEncoder` where practical.
* Do not build JSON through manual string concatenation.
* Generate valid UUID values for declaration identifiers and server tokens.
* Generate `AllowedBinaries` and `DeniedBinaries` arrays from validated policy state.
* Detect duplicate applications and duplicate signing entries before generation or export.
* Format exported JSON for readability.
* Keep generated JSON deterministic so equivalent policy state produces equivalent JSON except for intentionally generated UUID values.
* Validate required fields before generating payload content.
* Validate required fields according to typed rule scope; do not require `SigningID` for documented Team-ID-only allow rules.
* Omit optional payload keys when they are not selected or required; do not emit `null` or explicit `false` values merely for convenience.
* Preserve `PathPrefix` capitalization and spaces exactly, require an absolute path, and do not use a shell to process it.
* Validate required values before allowing local JSON export.
* Export JSON only to user-selected local file destinations.
* Clearly label payload functionality that is specific to macOS 27.
* Do not imply that generating valid JSON guarantees successful enforcement by an MDM server or device.
* Do not invent undocumented payload fields or behaviors.
* Support only documented special tokens. Do not generate company-name wildcard tokens; the current AppleSeed-based exception is the exact `*APPLE*` Team ID token.
* Third-party developer-wide rules must use an actual Team ID obtained from inspected signing information or deliberately entered by the administrator.
* Do not derive Team IDs from bundle identifier prefixes, company names, application names, or signing-authority display text.
* Treat macOS 27 beta schema behavior conservatively and document unverified rule shapes rather than inferring symmetry between allowed and denied rules.

## Future Integration Boundaries

* Direct Jamf Pro integration is outside Version 1.0.
* Do not add Jamf API calls, credential storage, or remote declaration upload without an approved feature.
* Future Jamf integration must depend on stable and fully documented public Jamf APIs for Blueprint and custom declaration management.
* Future Jamf integration must support secure authentication, avoid plaintext credential storage, and respect least-privilege API roles.

## Definition of Done

A story is complete when:

* Its acceptance criteria are satisfied.
* The project builds without errors.
* Relevant tests are added and passing.
* Errors and edge cases are handled.
* No unrelated functionality is broken.
* New public or non-obvious behavior is documented.
* Temporary debug code is removed.
* Changes follow these project rules.
* The implementation has been manually tested where appropriate.
* The related Jira work item, or other approved project work item, can be updated with what was implemented and how it was validated.
