# Contributing

Thank you for helping improve App Signing Inspector.

## Propose an Issue

Use GitHub Issues for reproducible bugs and focused feature proposals. Search existing issues first and include enough sanitized detail to understand the problem. Do not attach proprietary applications, credentials, private signing material, internal URLs, or sensitive certificate data.

Security vulnerabilities require private handling. Follow [SECURITY.md](SECURITY.md) and do not disclose an unpatched vulnerability in a public issue.

## Submit a Pull Request

1. Read [PROJECT_RULES.md](PROJECT_RULES.md), [VISION.md](VISION.md), and the current Version 1.0 scope in [README.md](README.md).
2. Keep each change focused and avoid unrelated refactoring or speculative features.
3. Add or update deterministic tests for changed behavior.
4. Build and run the relevant tests in Xcode on a compatible Mac.
5. Describe the scope, validation, privacy impact, and any remaining macOS-specific checks in the pull request.

Application behavior that depends on Apple platform tools must be validated on macOS. Do not claim successful Xcode validation based only on static review from another platform.

## Fixtures and Privacy

Use synthetic fixtures where practical. Fixtures, screenshots, diagnostics, and issue reports must not contain secrets, personal paths, private application data, credentials, signing certificates, or confidential organization information.

## Conduct

Keep technical discussion respectful, specific, and professional. Focus feedback on the work and help maintain a welcoming environment for contributors with different levels of experience.
