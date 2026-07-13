# Version 1.0 macOS Validation Checklist

Complete this checklist on macOS 27 with Xcode 27 beta before creating a Version 1.0 tag or GitHub release.

## Build and Launch

- [ ] Project opens in Xcode 27 beta
- [ ] Application target builds
- [ ] Application launches
- [ ] All automated tests pass
- [ ] No compiler warnings
- [ ] No runtime errors
- [ ] Archive can be created successfully
- [ ] Exported application launches outside Xcode where local signing permits

## Inspector

- [ ] Inspector is the default workspace
- [ ] Inspector empty state works
- [ ] App selection works
- [ ] Metadata displays correctly
- [ ] Code-signature information displays correctly
- [ ] Designated Requirement displays and copies
- [ ] Gatekeeper and architecture results display correctly
- [ ] Partial inspection failures preserve successful results

## Policy Builder

- [ ] Policy Builder empty state works
- [ ] App rules can be added
- [ ] Allow and Deny can be changed
- [ ] Developer-wide rules work
- [ ] `*APPLE*` rule works
- [ ] `AlwaysAllowManagedApps` works
- [ ] `PathPrefix` works
- [ ] Duplicate and redundancy warnings work
- [ ] Invalid additions do not remove valid entries
- [ ] JSON preview updates correctly
- [ ] Copy JSON works
- [ ] Export JSON works
- [ ] Export cancellation is silent and harmless
- [ ] Generated JSON matches the current AppleSeed documentation

## Interface and Accessibility

- [ ] Workspace state survives sidebar switching
- [ ] Layout remains usable at the minimum window size
- [ ] Long technical values remain readable and selectable
- [ ] Light appearance works
- [ ] Dark appearance works
- [ ] Keyboard navigation and focus order work
- [ ] VoiceOver exposes controls, warnings, errors, and statuses clearly
- [ ] Command-O performs the active workspace's application action
- [ ] Command-1 opens Inspector
- [ ] Command-2 opens Policy Builder
- [ ] Command-Shift-C copies declaration JSON when available
- [ ] Command-E exports declaration JSON when available
- [ ] Disabled menu commands match unavailable actions

## Release Identity

- [ ] About window displays the correct name, version, build, platform, license, and repository link
- [ ] App icon displays correctly in the app, Dock, Finder, and About window
- [ ] App icon remains recognizable at small sizes
- [ ] Marketing version is `1.0.0`
- [ ] Build number is `1`
- [ ] No machine-specific paths or user-specific Xcode data are present
- [ ] No signing identity changes are required beyond approved local signing
