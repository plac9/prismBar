# prismBar

prismBar is a privacy-first macOS 27 menu bar workspace. It makes menu bar items manageable, discoverable, and recoverable without capturing or transmitting what the user sees.

This repository is an independent clean-room implementation. It does not contain source code, tests, assets, strings, project configuration, or history from Ice, Thaw, or the former GPL-derived prismBar fork.

## Product contract

- Exact product name: `prismBar`
- Platform: macOS 27 or later
- Architecture: Apple silicon only
- Toolchain: Xcode 27, Swift 6.4, strict concurrency
- UI: SwiftUI and AppKit using system Liquid Glass components
- Distribution: Developer ID signed, hardened, notarized direct distribution
- Privacy: local-only operation, no analytics, telemetry, screen capture, OCR, or content upload
- Accessibility: public macOS Accessibility APIs, requested only after the app is installed in a stable location
- Plugins: bundled, separately signed, sandboxed XPC services with explicit capabilities

## Repository boundary

The historical GPL reference tree is preserved separately at:

`~/dev/prismBar-gpl-reference`

Both remotes in that tree are push-disabled. It is a behavioral and provenance reference only. Implementation work belongs exclusively in this repository.

## Licensing

prismBar and prismPluginKit are licensed under the Mozilla Public License 2.0. This permits commercial distribution while requiring distributed modifications to covered source files to remain available under the same license.

The independently developed prismCalc application retains its own license. The open-source prismCalc plugin in this repository is an integration surface and compact calculator, not a copy of the prismCalc application.

See [LICENSE](LICENSE), [NOTICE](NOTICE), [dependency and license inventory](docs/DEPENDENCIES.md), [SPDX SBOM](sbom.spdx.json), and [CONTRIBUTING.md](CONTRIBUTING.md).

The repository-grounded [security threat model](prismBar-threat-model.md) covers Accessibility authority, menu movement, XPC isolation, local privacy, and release provenance.

Generate a self-contained dark UI and security assurance report from a clean revision with
`./scripts/generate-assurance-report.sh`. The report is written to ignored `build/` evidence and
contains no screenshots or observed menu metadata.

Run the native UI suite through `./scripts/test-ui.sh`. The wrapper preserves whether the exact
installed `/Applications/prismBar.app` process was running and restores it after XCUITest exits.

## Status

Architecture is locked and the clean-room implementation is in progress. No release claim should be inferred until the physical macOS 27, signing, notarization, security, privacy, and accessibility gates in `docs/IMPLEMENTATION-PLAN.md` pass.
