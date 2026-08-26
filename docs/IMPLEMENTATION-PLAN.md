# Implementation Plan

## Completion rule

The project is complete only when every gate below has authoritative evidence from the current clean-room repository and the signed application installed on physical macOS 27.

## Phase 0: Repository and contracts

- [x] Preserve the GPL reference tree without changing its working state.
- [x] Disable reference-tree push URLs.
- [x] Initialize a new repository and Git history at the canonical path.
- [x] Lock product, architecture, licensing, privacy, security, design, and plugin direction.
- [x] Add the complete MPL-2.0 license and validate its checksum against the published text.
- [x] Register the new repository in workspace metadata.
- [x] Produce and open the interactive execution plan.
- [ ] Commit the contract-only foundation as a signed atomic commit.

## Phase 1: Test-first project scaffold

- [ ] Define XcodeGen project for macOS 27 and arm64 only.
- [ ] Define Swift 6.4 package modules with complete strict concurrency.
- [ ] Add the application, unit-test, UI-test, and sandboxed XPC service targets.
- [ ] Add explicit development and release entitlements.
- [ ] Add privacy manifest and generated Info.plists.
- [ ] Add deterministic fixtures containing synthetic menu items only.
- [ ] Add self-hosted macOS CI with no signing secrets in pull-request jobs.
- [ ] Prove package tests and unsigned app builds with Xcode 27.

## Phase 2: Permission and identity foundation

- [ ] Write failing tests for every permission state and transition.
- [ ] Implement stable-install detection and current signing identity inspection.
- [ ] Implement live Accessibility trust checks without cached truth.
- [ ] Implement correct System Settings deep link and foreground recheck.
- [ ] Implement runtime revocation behavior.
- [ ] Render onboarding and recovery states using native macOS 27 components.
- [ ] Prove grant, revoke, relaunch, and signed-upgrade behavior in `/Applications`.

## Phase 3: Menu bar topology engine

- [ ] Define immutable topology models and synthetic fixtures.
- [ ] Implement public Accessibility discovery behind a dedicated actor.
- [ ] Identify controllable, system-owned, unavailable, and self-owned items.
- [ ] Implement multi-display, full-screen, space, and topology-generation handling.
- [ ] Write property tests for ordering, grouping, and plan validity.
- [ ] Ensure production logs never include observed values.

## Phase 4: Verified actions and recovery

- [ ] Write failing tests for arbitrary-position moves, group moves, stale targets, revocation, rejection, partial movement, and timeout.
- [ ] Implement direct multi-position movement in one action.
- [ ] Implement hide, show, section visibility, and reset semantics.
- [ ] Verify every operation against a fresh topology snapshot before reporting success.
- [ ] Add equivalent keyboard and accessibility actions.
- [ ] Prove pointer and modifier cleanup on cancellation and failure.

## Phase 5: Status item and daily workflow

- [ ] Implement a template-rendered prism status icon.
- [ ] Ensure normal click always opens the command center.
- [ ] Add primary section actions, current state, plugin panels, Settings, and Quit.
- [ ] Add shortcut discovery and conflict detection.
- [ ] Prove menu operation with no main window open.

## Phase 6: Plugin platform

- [ ] Implement versioned `prismPluginKit` value and protocol contracts.
- [ ] Implement manifest and capability validation.
- [ ] Implement bounded declarative panel validation and native rendering.
- [ ] Implement reciprocal XPC code-signing requirements.
- [ ] Add sandboxed service entitlements with no network or file authority.
- [ ] Implement health, timeout, crash-loop, disable, and recovery behavior.
- [ ] Prove hostile descriptor, wrong signature, hang, crash, and version mismatch tests.

## Phase 7: prismCalc plugin

- [ ] Write independent calculator reducer tests from the product contract.
- [ ] Implement everyday arithmetic and deterministic decimal behavior.
- [ ] Implement bounded local recent-result history.
- [ ] Implement compact host-rendered calculator panel.
- [ ] Implement copy-result and explicit open-full-prismCalc actions.
- [ ] Prove the plugin remains useful when the full prismCalc app is absent.
- [ ] Prove it cannot access Accessibility, network, arbitrary files, or proprietary prismCalc app storage.

## Phase 8: Complete macOS 27 experience

- [ ] Build Overview, Menu Bar, Plugins, Shortcuts, Privacy, and About destinations.
- [ ] Build onboarding, empty, unavailable, revoked, error, and recovery surfaces.
- [ ] Adopt system Liquid Glass components and remove decorative legacy styling.
- [ ] Implement full keyboard navigation, VoiceOver, help, focus, and accessibility actions.
- [ ] Verify light, dark, increased contrast, reduced transparency, reduced motion, and text-size variants.
- [ ] Implement original application and template menu bar icons with no thaw imagery.
- [ ] Generate the required HTML UI audit from exact shipping surfaces.

## Phase 9: Security, privacy, and licensing assurance

- [ ] Threat-model review against final code and entitlements.
- [ ] Secret and personal-information scan across Git history, source, tests, logs, build products, and symbols.
- [ ] Dependency license inventory and SBOM.
- [ ] Similarity audit against the frozen GPL reference.
- [ ] Confirm the public source revision exactly matches every distributed MPL-covered binary.
- [ ] Fuzz plugin decoder and calculator parser.
- [ ] Run static analysis, sanitizers, concurrency stress, and long-duration lifecycle tests.
- [ ] Produce the required dark HTML assurance report.

## Phase 10: Signed physical release proof

- [ ] Verify Apple identifier and signing configuration for `com.laclairtech.prismbar`.
- [ ] Archive with Xcode 27 using Developer ID and Hardened Runtime.
- [ ] Verify nested signing order and exact entitlement allowlists.
- [ ] Package, notarize, staple, and validate the distribution artifact.
- [ ] Install through the shipping flow to `/Applications/prismBar.app`.
- [ ] Complete the physical macOS 27 permission, move, status item, plugin, relaunch, upgrade, displays, spaces, full-screen, sleep, wake, logout, and reboot matrix.
- [ ] Verify Gatekeeper behavior on a clean macOS 27 user account.
- [ ] Publish only after owner review of the final diff, evidence, price, license presentation, and release artifact.
