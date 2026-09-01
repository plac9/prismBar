# Changelog

All notable changes to prismBar are documented in this file.

The format follows Keep a Changelog. Versions follow Semantic Versioning after the first public release.

## [Unreleased]

### Added

- Rail drag-to-place controls for direct, verified multi-position menu bar moves.
- A searchable `prismDeck` Applications drawer with current order, role, availability, direct placement, and protected-anchor state.
- VoiceOver actions for Rail show, hide, first-position, and last-position moves without requiring drag input.
- Automated macOS accessibility audits for every workspace destination, native Settings, and Prism Deck.
- Privacy-safe visual audit captures for every shipping workspace surface and the status item.
- Revision-bound CI, visual, endurance, distribution, public-source, and physical acceptance states in the assurance report.
- A source-backed macOS 27 compatibility matrix with explicit safeguards and unresolved physical acceptance gates.
- A dedicated release-keychain contract that prevents archive and notarization workflows from searching the interactive login Keychain.
- A DEBUG-only ad-hoc XPC test seam for noninteractive plugin crash, hang, timeout, and recovery assurance without weakening Release trust.
- Clean-room repository with independent Git history.
- Product, architecture, security, privacy, design, licensing, and plugin contracts.
- MPL-2.0 public-source licensing foundation.
- macOS 27 and Apple-silicon-only XcodeGen project using Swift 6 strict concurrency.
- Native menu bar command center and accessible main-window lifecycle scaffold.
- Sandboxed out-of-process prismCalc plugin service that requires the exact signed host.
- Versioned, bounded plugin wire protocol and independently authored calculator reducer.
- Reciprocal host and plugin code-signing requirements with capability-gated handshakes.
- Host-rendered native prismCalc panel with arithmetic, copy, and explicit open-app actions.
- Plugin request timeout, cancellation, repeated-failure pause, and manual recovery behavior.
- Strict lint boundaries that exclude generated build products.
- Unit and physical-host UI launch tests.
- Live Accessibility authorization state based on a fresh macOS trust check.
- Stable `/Applications/prismBar.app` and exact signing identity validation before requesting Accessibility access.
- Accessible permission recovery controls with foreground refresh behavior.
- Serialized, timeout-bounded menu bar discovery using public Accessibility APIs.
- Privacy-safe topology identifiers that never contain observed menu labels.
- Exact-position move planning with stale-plan rejection and post-action verification.
- Main-window and menu-bar-popover controls backed by the same authoritative topology.
- Public-AppKit status-item control with deterministic section anchors and a native command popover.
- Verified hide, show, fold, reveal, arbitrary-position, and order-preserving recovery plans.
- Safe section expansion before protected movement and automatic restoration after the action.

### Changed

- Replaced repeated material-backed content cards with open native sections and restrained semantic accent rules.
- Let the native macOS list own the Menu Bar inventory surface and reduced Rail chrome to separators.
- Rebuilt the workspace around one adaptive Prism Field canvas, a native floating sidebar, open content sections,
  and interactive Liquid Glass reserved for controls and draggable Rail items.
- Replaced the custom canvas palette and Settings backdrop with native window backgrounds, semantic accent color,
  native Settings forms, macOS title typography, and increased-contrast-aware presentation.
- Added a CI contract that rejects decorative content-layer Liquid Glass regressions.
- Migrated the workspace, prismCalc utility, and Settings lifecycle to native SwiftUI scenes while preserving the AppKit status-item popover boundary.
- Replaced the status-item artwork with a template-rendered prism identity shared by the app UI.

### Fixed

- Kept the compact `prismDeck` permission state visible without allowing it to crowd out menu bar controls.
- Restored process-local Undo after verified moves during stable partial scans while still rejecting changed source coverage, item identity, ownership, role, surface, availability, or order.
- Classified macOS-owned menu bar extras such as Clock, Control Center, and Siri as fixed anchors even when Accessibility reports them as movable.
- Removed drag, keyboard, batch, reset, and recovery move paths for fixed macOS-owned anchors while preserving application-item movement.
- Clarified partial menu bar scans so nonresponsive sources are reported without presenting incomplete inventory as complete.
- Bounded native Accessibility observation retries and fan-out to avoid indefinite refreshes and stale concurrent reads.
- Protected macOS 27 menu bar agent processes from hide, move, reset, and recovery actions.
- Closed the temporary SwiftUI bootstrap workspace after opening prismCalc from a cold, menu-bar-only launch.
- Removed unlabeled app-owned accessibility containers, redundant ownership announcements, and a plugin health role override.
- Explained the auto-hide and full-screen recovery when macOS exposes no safe menu bar input surface.
- Made visual audit tests fail when system UI obscures a shipping surface instead of accepting occluded screenshots.
- Restored the approved user-facing `Rail` name while keeping internal Prism Rail type identifiers stable.
- Made normal launch menu-bar-first and isolated windowless Prism Deck UI tests from workspace restoration.
- Added an explicit, bounded workspace-launch path for UI tests that intentionally exercise the full app scene.
- Made Prism Deck bootstrap the first SwiftUI workspace after a cold, windowless launch.
- Preserved distinct Accessibility identifiers for page headers inside the extended Prism Field canvas.
- Restored the native macOS Settings command and made both Command-comma and Prism Deck reuse one adaptive Settings window.
- Restored Escape-key dismissal and repeat opening for the Prism Deck status-item popover.
- Made visual assurance normalize an isolated 920 x 640 review window, leave normal window restoration untouched, and embed the exact audited source revision.
- Replaced deprecated disk-image creation with the native macOS 27 `diskutil image` workflow.
- Stopped routine UI tests and visual captures from consulting the login Keychain by enforcing local ad-hoc signing.
- Made visual assurance prove the intended ready-state Tools and prismCalc surfaces while keeping the real ad-hoc plugin connection fail closed.
- Captured the prismCalc utility as the active key window so its interactive Liquid Glass state is reviewed at full fidelity.
- Enforced a hard observation deadline even when an Accessibility reader does not cooperate with cancellation.
- Made native menu bar movement use a dense bounded Command-drag with guaranteed mouse, modifier, and pointer cleanup.
- Kept same-section direct moves stable while unrelated menu bar sources appear or disappear during preflight.
- Synchronized verified post-move topology directly into the interface instead of waiting for a second refresh.
