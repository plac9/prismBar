# Implementation Plan

## Completion rule

The project is complete only when every gate below has authoritative evidence from the current clean-room repository and the signed application installed on physical macOS 27.

## Current scope lock

The shipping application is intentionally limited to menu bar discovery, hide and reveal, direct arbitrary-position ordering, process-local recovery, and the `prismDeck` status-item control surface. The Prism Card framework and prismCalc sources remain preserved and tested in the repository, but they are not linked, embedded, launched, or presented by the application. Prism Card work resumes only after the installed core passes the physical macOS 27 gates in Phases 2 through 5.

## Phase 0: Repository and contracts

- [x] Preserve the GPL reference tree without changing its working state.
- [x] Disable reference-tree push URLs.
- [x] Initialize a new repository and Git history at the canonical path.
- [x] Lock product, architecture, licensing, privacy, security, design, and plugin direction.
- [x] Add the complete MPL-2.0 license and validate its checksum against the published text.
- [x] Register the new repository in workspace metadata.
- [x] Produce and open the interactive execution plan.
- [x] Commit the contract-only foundation as a signed atomic commit.

## Phase 1: Test-first project scaffold

- [x] Define XcodeGen project for macOS 27 and arm64 only.
- [x] Define Swift 6.4 package modules with complete strict concurrency.
- [x] Add the application, unit-test, UI-test, and sandboxed XPC service targets.
- [x] Add explicit host and sandboxed-service entitlements.
- [x] Add privacy manifest and generated Info.plists.
- [x] Add deterministic fixtures containing synthetic menu items only.
- [x] Add ephemeral GitHub-hosted Xcode 27 CI with no signing or repository secrets.
- [x] Prove package tests and unsigned app builds with Xcode 27.

## Phase 2: Permission and identity foundation

- [x] Write failing tests for every permission state and transition.
- [x] Implement stable-install detection and current signing identity inspection.
- [x] Implement live Accessibility trust checks without cached truth.
- [x] Use Apple's documented Accessibility prompt and recheck whenever the app returns to the foreground.
- [x] Reject undocumented System Settings URL schemes from the product.
- [x] Implement runtime revocation behavior.
- [x] Render onboarding and recovery states using native macOS 27 components.
- [x] Prove relaunch and signed-upgrade behavior in `/Applications` with installed Development revision `96be5046ab3b00cb15572d7feb3e8fc4bdce1520` while preserving live Accessibility trust.
- [ ] Prove fresh grant and runtime revoke behavior in `/Applications` on the final notarized candidate.

## Phase 3: Menu bar topology engine

- [x] Define immutable topology models and synthetic fixtures.
- [x] Implement public Accessibility discovery behind a dedicated actor.
- [x] Identify controllable, system-owned, unavailable, and self-owned items.
- [x] Implement multi-display, full-screen, space, and topology-generation handling.
- [x] Write exhaustive invariant tests for ordering, grouping, and direct-move plan validity.
- [x] Ensure production logs never include observed values.

## Phase 4: Verified actions and recovery

- [x] Write tests for arbitrary-position moves, group moves, stale targets, revocation, rejection, partial movement, and bounded timeout.
- [x] Implement direct multi-position movement in one action.
- [x] Implement order-preserving multi-item Hide and Show with a fresh verification for every item.
- [x] Implement hide, show, section visibility, and reset semantics.
- [x] Verify every operation against a fresh topology snapshot before reporting success.
- [x] Reject input when the target display has no reserved menu bar area or geometry crosses displays.
- [x] Add equivalent keyboard and accessibility actions.
- [x] Prove mouse-up, Command-up, and pointer restoration on cancellation and failure after one bounded Command-drag.
- [x] Define typed action identifiers, kinds, phases, and receipts.
- [x] Add a ten-entry process-local recovery ledger with topology compatibility checks.
- [x] Route direct moves through receipt-backed application state.
- [x] Route section, batch, reset, and recovery operations through the same receipt coordinator.
- [x] Implement verified recovery execution against the latest compatible entry.
- [x] Clear recovery history on every live trust or signing-identity transition, not only protected-call revocation.

## Phase 4A: Verified rebuild sequence

- [x] Confirm signed, hardened, notarized direct distribution as the required channel for the full menu-bar manager.
- [x] Reject the physically disproven Mac App Store organizer experiment as a shipping alternative.
- [x] Land the typed receipt and bounded in-memory recovery foundation.
- [x] Rebuild Rail around stable drag state, destination previews, typed receipts, recovery, keyboard parity, and multi-display truth.
- [x] Rebuild `prismDeck` with topology truth, Rail, a searchable Applications drawer, current receipt, recovery, Settings, and Quit as the primary compact workflow.
- [ ] Design persistent Scenes only after a separate privacy review of cross-launch item identity.
- [ ] Resume Prism Cards only after the installed core passes physical macOS 27 acceptance.

## Phase 5: Status item and daily workflow

- [x] Implement a template-rendered prism status icon.
- [x] Use the native macOS 27 expanded-interface session for the command center.
- [x] Ensure normal click opens the command center, Escape dismisses it, and the same item reopens it.
- [x] Add primary section actions, current state, Settings, and Quit.
- [x] Add shortcut discovery and conflict detection without global keyboard monitoring.
- [x] Prove menu operation with no main window open through a native XCUITest.

## Phase 6: Plugin platform

Repository work is preserved, but this phase is frozen and excluded from the shipping application until core physical acceptance passes.

- [x] Implement versioned `prismPluginKit` value and protocol contracts.
- [x] Implement a bounded bundled-plugin registry and persistent user enable/disable lifecycle.
- [x] Implement manifest and capability validation.
- [x] Implement bounded declarative panel validation and native rendering.
- [x] Implement reciprocal XPC code-signing requirements.
- [x] Add sandboxed service entitlements with no network or file authority.
- [x] Implement bounded timeout, failure-budget disable, stale-callback suppression, and manual recovery behavior.
- [x] Prove hostile descriptor, hang, crash, and version mismatch behavior.
- [x] Prove the preserved host and plugin requirements reject identically named, ad-hoc signed impostors before freezing Card integration out of the shipping target.
- [x] Finish the user-facing plugin health state for off, verifying, ready, interrupted, and safety-paused conditions.

## Phase 7: prismCalc plugin

Repository work is preserved, but this phase is frozen and excluded from the shipping application until core physical acceptance passes.

- [x] Write independent calculator reducer tests from the product contract.
- [x] Implement everyday arithmetic and deterministic decimal behavior.
- [x] Implement bounded local recent-result history.
- [x] Implement compact host-rendered calculator panel.
- [x] Implement copy-result and explicit open-full-prismCalc actions.
- [x] Prove the plugin remains useful when the full prismCalc app is absent.
- [x] Prove it cannot access Accessibility, network, arbitrary files, or proprietary prismCalc app storage.

## Phase 8: Complete macOS 27 experience

- [x] Build Home, Menu Bar, Automation, Privacy, and About destinations.
- [x] Preserve the main-window frame and restore its native keyboard focus loop.
- [x] Replace manual AppKit workspace, utility, and Settings windows with macOS 27 SwiftUI scene ownership.
- [x] Prove native Command-comma and `prismDeck` Settings entry points reuse one adaptive Settings window.
- [x] Build onboarding, empty, unavailable, revoked, error, and recovery surfaces.
- [x] Integrate the native system window background, semantic content surfaces, and standard interactive glass controls.
- [x] Adopt system Liquid Glass components and remove decorative legacy styling.
- [x] Record current Apple guidance and public macOS 27 menu bar failure reports in a maintained compatibility matrix with explicit safeguards and physical gates.
- [x] Implement keyboard navigation, help, focus, and accessibility actions.
- [x] Run automated action, non-text contrast, element-detection, hit-region, hierarchy, and description audits across every shipping workspace destination, native Settings, and `prismDeck`. Xcode 27 beta static-text contrast false positives remain covered by semantic-color source policy and visual review.
- [x] Verify every shipping destination remains operational in light, dark, increased contrast, reduced transparency, and reduced motion launch variants.
- [ ] Complete physical VoiceOver, text-size, and visual accessibility verification.
- [x] Implement original application and template menu bar icons with no thaw imagery.
- [x] Generate and visually inspect the required HTML UI audit from exact shipping surfaces.

## Phase 9: Security, privacy, and licensing assurance

- [x] Establish a repository-grounded threat model for the runtime, entitlements, build system, and direct-distribution model.
- [x] Reconcile the threat model against the current working-tree code and Development artifact.
- [ ] Reconcile the threat model against the final clean revision and notarized artifact.
- [x] Declare app-local `UserDefaults` access with Apple required reason `CA92.1`.
- [x] Audit release executables, linked libraries, local paths, credential-shaped strings, bundle identifiers, and entitlement allowlists in CI.
- [x] Scan Git history, source, tests, tracked artifacts, public metadata, release products, and symbols for secrets and personal information.
- [x] Dependency license inventory, build-tool inventory, and SPDX 2.3 source SBOM.
- [ ] Similarity audit against the frozen GPL reference.
- [ ] Confirm the public source revision exactly matches every distributed MPL-covered binary.
- [x] Exercise plugin decoding and calculator commands with deterministic hostile-input corpora.
- [x] Run static analysis plus Address Sanitizer and Thread Sanitizer across the Swift modules.
- [x] Reconcile the current source controls against the threat model and verify the preserved dormant reciprocal-signing implementation independently of the core-only release.
- [x] Repeat long-duration host, permission, movement, and plugin lifecycle stress tests on clean revision `2a3c087fda0faddcd1e7ee33d67900b0d0e5681c`: 2 complete cycles across 1,130 seconds, including 40 UI-test executions with zero failures. Physical signed-app movement stress remains a release gate.
- [x] Produce and inspect the revision-bound dark HTML assurance report for clean revision `2a3c087fda0faddcd1e7ee33d67900b0d0e5681c`; automated and visual evidence pass while physical, distribution, and publication gates remain on hold.

## Phase 10: Signed physical release proof

Exact revision `ed4b6b8f4b3fa196f14c290f44b9b4fed4cb256e` passed the full core-only CI contract on September 1, 2026. Its first secure release run was intentionally stopped at the interactive certificate-transfer passphrase gate during session wrap-up; no current archive, notarized distribution, or installed release candidate was produced.

- [x] Verify Apple identifier and signing configuration for `com.laclairtech.prismbar`.
- [x] Require an explicit dedicated release keychain containing only the approved certificate fingerprint so archive and notarization cannot fall back to the interactive login Keychain or another signing identity.
- [x] Add a fail-closed physical acceptance recorder that revalidates exact installed provenance and requires one explicit physical observation per gate.
- [x] Prove a direct multi-position application-item move and process-local Undo during a stable partial scan on physical macOS 27 using signed installed Development revision `96be5046ab3b00cb15572d7feb3e8fc4bdce1520`; RocketSim moved directly from position 1 to the last movable position, Undo restored the exact original order, relaunch preserved that order and Accessibility trust, and the protected macOS-owned anchors remained fixed.
- [ ] Archive the final clean revision with Xcode 27 using Developer ID and Hardened Runtime.
- [ ] Verify nested signing order and exact entitlement allowlists on that archive.
- [ ] Package, notarize, staple, and validate the distribution artifact.
- [ ] Install through the shipping flow to `/Applications/prismBar.app`.
- [ ] Complete the physical macOS 27 permission, move, status item, relaunch, upgrade, displays, spaces, full-screen, sleep, wake, logout, and reboot matrix.
- [ ] Verify Gatekeeper behavior on a clean macOS 27 user account.
- [ ] Publish only after owner review of the final diff, evidence, price, license presentation, and release artifact.
