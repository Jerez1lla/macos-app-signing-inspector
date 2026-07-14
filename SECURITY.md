# Security Policy

## Supported Versions

Security fixes are considered for the current `1.0.x` release line. Beta macOS behavior may change, and the project cannot guarantee compatibility or support for unpublished platform behavior.

## Reporting a Vulnerability

Do not open a public GitHub issue for an undisclosed security vulnerability. Do not include credentials, private binaries, proprietary application data, sensitive signing information, internal URLs, or personal data in a report.

GitHub private vulnerability reporting is not currently enabled for this repository. The repository owner should enable **Private vulnerability reporting** under the repository security settings before requesting confidential reports. Until a private channel is configured, do not publish vulnerability details in the issue tracker.

When private reporting becomes available, include:

* The affected App Signing Inspector version
* The macOS version
* A concise impact assessment
* Reproduction steps using synthetic or sanitized data
* Suggested mitigations, if known

## Security Design

Normal inspection and policy generation are local and require no network connection. The application includes no analytics or telemetry, requests no Jamf credentials, and does not modify inspected applications. Selected paths and tool output are treated as untrusted input.
