# prismBar

prismBar is a privacy-first macOS 27 menu bar manager. It discovers, moves, hides, reveals, and recovers menu bar items without capturing or transmitting what the user sees.

Rail provides direct drag-to-place control from the workspace and `prismDeck`. A drop resolves to one verified multi-position Command-drag rather than repeating one-position moves. Every action uses a fresh topology snapshot, one shared hard deadline, and a post-move observation before prismBar reports success. Typed process-local receipts distinguish verifying, applied, partial, blocked, and recovered outcomes.

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
- Reading size: app-local 100%, 125%, 150%, or 200% semantic type and responsive layout
- Shipping scope: menu bar control only; no Prism Card runtime, file access, or network access

## Core-first scope

The shipping app currently includes only the core model, Accessibility adapter, verified menu-bar engine, typed action receipts, and a bounded in-memory recovery ledger. `prismDeck` is its compact status-item control surface. Recovery snapshots are never persisted, logged, or sent across XPC. Persistent Scenes remain future work behind a separate privacy review.

General Settings includes an explicit local reading-size control. Every shipping scene consumes the same semantic type roles and adapts its window, popover, Rail, list, and control geometry through 200% without changing system-wide settings or treating presentation state as security authority.

Prism Cards are the future user-facing capability system. Their framework and prismCalc sources are preserved for later development but are not linked, embedded, launched, or visible in the application. Prism Cards resume only after the installed core menu-bar product passes its physical macOS 27 gates.

## Repository boundary

The historical GPL reference tree is preserved separately at:

`~/dev/prismBar-gpl-reference`

Both remotes in that tree are push-disabled. It is a behavioral and provenance reference only. Implementation work belongs exclusively in this repository.

## Licensing

prismBar and prismPluginKit are licensed under the Mozilla Public License 2.0. This permits commercial distribution while requiring distributed modifications to covered source files to remain available under the same license.

Every application bundle includes the exact MPL-2.0 text, the project NOTICE, and its complete Git source revision. About provides local legal-document access and an explicit link to the matching public source tree.

The independently developed prismCalc application retains its own license. The open-source prismCalc Card source in this repository is an integration surface and compact calculator, not a copy of the prismCalc application.

See [LICENSE](LICENSE), [NOTICE](NOTICE), [dependency and license inventory](docs/DEPENDENCIES.md), [SPDX SBOM](sbom.spdx.json), and [CONTRIBUTING.md](CONTRIBUTING.md).

The repository-grounded [security threat model](prismBar-threat-model.md) covers Accessibility authority, menu movement, XPC isolation, local privacy, and release provenance.

The [macOS 27 compatibility matrix](docs/MACOS-27-COMPATIBILITY.md) maps current Apple guidance and public menu bar failure reports to prismBar safeguards and unresolved physical release gates.

Generate a self-contained dark UI and security assurance report from a clean revision with
`./scripts/generate-assurance-report.sh`. The report is written to ignored `build/` evidence and
contains no screenshots or observed menu metadata.

Run the native UI suite through `./scripts/test-ui.sh`. The wrapper preserves whether the exact
installed `/Applications/prismBar.app` process was running and restores it after XCUITest exits.

Run revision-bound automated lifecycle soak verification with `./scripts/stress-verify.sh`. It
repeats the complete Swift and native UI suites for 15 minutes by default, records only sanitized
aggregate evidence under ignored `build/`, and keeps physical signed-app movement as a separate gate.

After the exact notarized candidate is installed in `/Applications`, initialize physical acceptance
with `./scripts/record-physical-acceptance.sh --initialize`. Record one observed gate at a time with
`--confirm GATE --observed-on-physical-macos-27`, inspect progress with `--status`, and withdraw an
invalid observation with `--invalidate GATE`. Every update revalidates the clean source revision,
Developer ID identity, Team ID, Gatekeeper result, notarization ticket, and installed executable hash.
There is no blanket confirmation mode.

## Release sequence

Release credentials are provisioned out of band in a dedicated, nonsymlink Keychain. The repository
does not import certificates, read 1Password items, accept raw notarization credentials, or consult the
login or System Keychain. Before creating an artifact, run `scripts/release-readiness.sh` with the named
notary profile, dedicated Keychain path, and approved certificate fingerprint. The check is read-only,
non-interactive, and reports only generic gate status; it requires clean `main`, exact-revision CI and
eleven-surface UI evidence, including 200% reading-size captures, source audits, the isolated signing identity, and working Apple notarization
authentication.

After archive and notarization, install only through `scripts/install-release-candidate.sh` using the
matching absolute DMG and evidence paths under ignored `build/Distribution`. The installer mounts the
image read-only, verifies hashes, Developer ID identity, Team ID, embedded source revision, signatures,
staples, Gatekeeper, and the release-bundle allowlist before touching `/Applications`. It stages the new
bundle beside the destination, preserves the prior app under ignored `build/InstallRollback`, and
restores that bundle if post-install verification fails. It never escalates privileges or launches the
application.

The installer does not complete release acceptance. Every physical macOS 27 gate must still be observed
and recorded individually, including clean-account Gatekeeper behavior. Direct distribution remains the
only supported channel because the required cross-process Accessibility behavior is incompatible with
App Sandbox. Publication, pricing, license presentation, source-repository creation, and artifact release
remain owner-gated.

## Status

Architecture is locked and the clean-room implementation is in progress. No release claim should be inferred until the physical macOS 27, signing, notarization, security, privacy, and accessibility gates in `docs/IMPLEMENTATION-PLAN.md` pass.

Release candidates are archived with `scripts/archive-release-candidate.sh`. Both release workflows require an explicit dedicated signing keychain and certificate fingerprint; login and system keychains are rejected. The separate `scripts/notarize-release-candidate.sh` reads its named `notarytool` profile from that same keychain, notarizes and staples the app, creates a signed APFS disk image, notarizes and staples that image, runs Gatekeeper and bundle audits, and writes revision-bound evidence under ignored `build/` output. Repository automation does not accept raw signing or notarization credentials.
