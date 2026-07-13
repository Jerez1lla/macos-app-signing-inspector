# Story 6 Implementation Plan: Graphical DDM Policy Builder

## Purpose

Story 6 adds the graphical DDM Policy Builder as a separate primary function within App Signing Inspector. It must preserve the completed single-application Inspector and must not require policy creation to inspect an application.

This document is an implementation plan only. It does not authorize application-code changes outside Story 6 scope.

## Approved Workspace Design

Use a root `NavigationSplitView` with a compact native macOS sidebar and a detail area for the selected workspace.

The sidebar destinations are:

* **Inspector** using `doc.text.magnifyingglass`
* **Policy Builder** using `list.bullet.rectangle`

Inspector is the default destination when the application opens. Follow standard macOS split-view selection, sidebar visibility, keyboard navigation, accessibility, and light/dark appearance behavior.

Do not use a modal, segmented control, tab view, temporary screen-replacement button, or custom navigation system as the primary workspace navigation.

Keep the sidebar compact and visually secondary to the active workspace. Preserve room in the destination model for future additions, but do not display or implement future destinations in Story 6. Validate that the split layout remains usable at the existing minimum window size without compressing or obscuring Inspector content.

## Workspace Responsibilities

### Inspector

The Inspector remains the default and preserves the completed single-application workflow, including metadata, code-signature information, designated requirement, Gatekeeper and notarization status, architecture information, diagnostics, and individual copy actions.

Story 6 must not move Inspector fields into the Policy Builder, require a policy to perform inspection, or fundamentally redesign the Inspector detail interface.

### Policy Builder

The Policy Builder is a separate detail workspace responsible for multi-application policy state, allow or deny assignment, editing and removal, duplicate and required-value validation, declaration generation, JSON preview, copy, local export, and allow-only safety warnings.

The advanced Story 6 scope also includes typed specific-application, developer Team ID, and Apple-binary rules; optional absolute `PathPrefix`; and `AlwaysAllowManagedApps`. These features follow macOS 27 AppleSeed beta test documentation and must remain easy to revise as the schema changes. Only the documented `*APPLE*` special token is supported. Developer Team rules remain Allow-only until a Team-ID-only denied object is explicitly verified.

The Policy Builder may present the application name, icon, Signing ID, Team ID, policy action, and validation status needed for policy editing. It must not become a duplicate of the full Inspector interface.

## Navigation And State Ownership

Introduce a small workspace destination model with only `inspector` and `policyBuilder` cases for Story 6.

The root application workspace should own:

* The selected sidebar destination, initialized to Inspector
* The existing Inspector view model or its current focused equivalent
* A separate Policy Builder view model

Root ownership must keep both view models alive while the user switches destinations so valid state is not destroyed unnecessarily.

The Inspector view model continues to own one selected application and its presentation state. The Policy Builder view model owns its own application collection, policy actions, validation results, generated declaration state, preview state, and export availability. Neither view model should read or mutate the other's selection.

The same application may be selected independently in both workspaces. This does not create shared UI state or an implicit policy entry.

## Shared Services

Reuse the existing service boundaries for:

* Native application selection
* Application metadata inspection
* Application icon loading
* Code-signature and designated-requirement inspection
* Gatekeeper and architecture security assessment where needed
* Process execution
* Clipboard writing

Add policy-specific services only for responsibilities such as structured declaration generation, policy validation, duplicate detection, and local JSON export. Do not copy platform inspection commands, parsers, or process-running code into the Policy Builder.

Use dependency injection or a small composition layer so both workspace view models can receive shared service implementations without becoming coupled to each other's state.

## Planned Implementation Sequence

1. Add the workspace destination model and root `NavigationSplitView` shell.
2. Add the compact sidebar with the approved labels and SF Symbols.
3. Make Inspector the default detail destination and embed the existing Inspector workflow without changing its behavior.
4. Move Inspector view-model ownership high enough to preserve valid state across navigation changes.
5. Add a separate Policy Builder view and Policy Builder view model with an empty state.
6. Add structured policy entry and allow-or-deny action models.
7. Reuse the application picker, metadata, icon, and signing services to add multiple `.app` bundles.
8. Add editing, removal, duplicate detection, and missing Signing ID or Team ID validation.
9. Add deterministic `AllowedBinaries` and `DeniedBinaries` generation.
10. Add complete `com.apple.configuration.app.settings` declaration models and JSON encoding.
11. Add UUID generation for declaration Identifier and ServerToken at the approved lifecycle point.
12. Add JSON preview, clipboard copy, and user-selected local `.json` export.
13. Add validation-gated export and the prominent allow-only policy safety warning.
14. Validate navigation, state preservation, minimum-window usability, accessibility, and light/dark appearance on macOS.

## Testing Plan

Add deterministic tests for:

* Inspector being the default destination
* The sidebar exposing only Inspector and Policy Builder
* Switching destinations without losing valid Inspector state
* Switching destinations without losing valid Policy Builder state
* Inspector and Policy Builder selections remaining independent
* Reuse of inspection services without duplicated platform execution
* Multiple policy entries and allow-or-deny changes
* Entry removal and deterministic ordering
* Duplicate application and signing-entry detection
* Missing Signing ID and Team ID validation
* Exact `AllowedBinaries` and `DeniedBinaries` structures
* Complete declaration encoding and stable JSON formatting
* Export validation and allow-only warning behavior

Perform macOS UI validation for sidebar sizing, split-view behavior, minimum window size, keyboard navigation, VoiceOver labels, state preservation, and light/dark appearance.

## Story 6 Boundaries

Story 6 does not include standalone executable inspection, recursive embedded-binary inspection, batch folder scanning, inspection history, existing declaration import or validation, direct Jamf upload, or network verification.

Do not add speculative sidebar destinations, combine the workspace view models, duplicate existing inspection services, or redesign completed Inspector fields as part of this story.

## Completion Criteria

Story 6 is ready for completion when the two-workspace navigation is native and stable, the existing Inspector remains intact and independent, the Policy Builder satisfies the authoritative Version 1.0 scope in `README.md`, deterministic tests cover policy behavior and JSON generation, and the complete workflow has been validated in Xcode on macOS.
