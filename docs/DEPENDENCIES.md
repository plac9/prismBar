# Dependency and license inventory

## Shipped application

| Component | Origin | License | Distribution status |
|---|---|---|---|
| prismBar host and modules | Independently authored in this repository | MPL-2.0 | Shipped as covered source and executable code |
| Bundled prismCalc plugin and XPC service | Independently authored in this repository | MPL-2.0 | Shipped as covered source and executable code |
| Apple system frameworks and Swift runtime | Apple platform | Apple SDK and platform terms | Dynamically linked or supplied by macOS, not redistributed by prismBar |
| Prism artwork and application icon | Original project artwork | Included as part of the MPL-covered source distribution | Shipped in the application asset catalog |

SwiftPM resolves no external package dependencies. The Release bundle contains two executables, no embedded third-party frameworks, and only links libraries supplied by macOS.

The bundled service integrity boundary relies on the sealed application bundle, reciprocal exact code-signing requirements, fixed bundle identifiers and Team ID, protocol version, and a bounded declared capability set. No separately fetched digest catalog or runtime plugin download is used.

## Build and verification tools

These tools run during development or CI and are not included in the application bundle.

| Tool | Verified version | License | Purpose |
|---|---:|---|---|
| Apple Xcode and SDK | 27 | Apple terms | Compiler, SDK, analyzer, asset compilation, and signing tools |
| Swift | 6.4 | Apache-2.0 | Language compiler and SwiftPM test runner |
| XcodeGen | 2.46.0 | MIT | Deterministic Xcode project generation |
| SwiftLint | 0.65.1 | MIT | Source linting |
| Gitleaks | 8.30.1 | MIT | Git secret scanning |
| actionlint | 1.7.12 | MIT | GitHub Actions workflow validation |
| ripgrep | 15.2.0 | Unlicense | Repository and artifact policy checks |
| jq | 1.8.2 | MIT | SBOM and dependency graph validation |
| actions/checkout | 7.0.1, pinned commit digest | MIT | Read-only CI source checkout |

Tool versions are asserted before verification. A version change requires updating this inventory and reviewing the associated source, license, and release notes.

## Explicit exclusions

- No Ice, Thaw, or former GPL-derived prismBar source, configuration, assets, tests, or history are included.
- No separately distributed prismCalc application code is included.
- No analytics, crash-reporting, advertising, update, networking, or telemetry SDK is included.
- No dynamically downloaded or user-installed plugin is accepted.

The machine-readable source SBOM is [`sbom.spdx.json`](../sbom.spdx.json). Release artifacts will add revision-specific checksums and signing evidence at packaging time.
