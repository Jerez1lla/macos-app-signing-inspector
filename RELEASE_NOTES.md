# App Signing Inspector 1.0.0

App Signing Inspector 1.0.0 is the first planned release of the native macOS utility for inspecting application signing details and building macOS 27 DDM application execution declarations.

This is release-candidate documentation. Version 1.0.0 must be built, tested, and validated on macOS before a tag or GitHub release is created.

## Inspector

* Select and inspect one macOS `.app` bundle.
* Review application metadata, bundle and executable paths, and architectures.
* Review signature validity, Signing ID, Team ID, authorities, signing flags, hardened runtime status, timestamps, Apple-signing status, and the designated requirement.
* Review local Gatekeeper and conservative notarization results.
* Copy individual technical values and advanced diagnostics.

## Policy Builder

* Build a policy from multiple applications while keeping Inspector state independent.
* Create Allow and Deny rules for specific applications.
* Create developer Team ID Allow rules and Apple-wide `*APPLE*` Allow rules.
* Configure optional `PathPrefix` restrictions and `AlwaysAllowManagedApps`.
* Detect duplicate, redundant, unsupported, and incomplete rules.
* Generate a complete `com.apple.configuration.app.settings` declaration.
* Preview, copy, and export declaration JSON.
* Review conservative warnings for broad or allow-only policies.

## Security and Privacy

Inspection and policy generation are local. Version 1.0 does not transmit application paths, signing data, Team IDs, certificates, or generated declarations. It does not store Jamf credentials or upload directly to Jamf Pro.

## Compatibility Note

The DDM binary-management model targets macOS 27 and is based on AppleSeed beta documentation. Schema names and enforcement behavior may change before final platform documentation is published. Generated JSON must be revalidated against the current Apple documentation before deployment.

## Known Limitations

* No direct Jamf Blueprint upload
* No standalone or recursively embedded binary inspection
* No declaration import or remote declaration validation
* No persistent policy or inspection history
* No network-based Team ID or certificate verification
* Local Gatekeeper results are not authoritative remote Apple verification
