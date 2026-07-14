# Version 1.0 macOS Validation Record

App Signing Inspector 1.0.0 was validated on macOS 27 Golden Gate beta with Xcode 27 beta.

## Build and Launch

* The application target built successfully.
* The application launched successfully.
* All automated tests passed.
* No compiler warnings, test failures, or runtime errors remained.

## Inspector

* Application selection and metadata inspection worked end to end.
* Code-signature and complete Designated Requirement inspection worked.
* Local Gatekeeper and notarization assessment worked.
* Native architecture inspection worked without requiring Xcode for end users.
* Important values and diagnostics remained available through the Inspector interface.

## Navigation and Appearance

* Inspector and Policy Builder navigation worked.
* Inspector remained the default workspace.
* The sidebar was visible by default and remained manually collapsible.
* Inspector and Policy Builder state remained independent when switching destinations.
* Light and dark appearances worked.
* Version and About information displayed correctly.

## Policy Builder

* The Policy Builder worked end to end.
* Specific application Allow and Deny rules worked.
* Developer Team ID, documented `*APPLE*`, and Jamf convenience rules worked.
* `AlwaysAllowManagedApps` and optional `PathPrefix` values worked.
* Duplicate and redundancy warnings worked.
* JSON preview, clipboard copy, and local export worked.

## Distribution Scope

Version 1.0.0 is published as source code. This validation record does not claim that a downloadable application bundle is signed or notarized, and no compiled application artifact is included in the release.
