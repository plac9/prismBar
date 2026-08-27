# Changelog

All notable changes to prismBar are documented in this file.

The format follows Keep a Changelog. Versions follow Semantic Versioning after the first public release.

## [Unreleased]

### Added

- Prism Rail drag-to-place controls for direct, verified multi-position menu bar moves.
- Privacy-safe visual audit captures for every shipping workspace surface and the status item.
- Revision-bound CI, visual, endurance, distribution, public-source, and physical acceptance states in the assurance report.
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

- Rebuilt the workspace around one adaptive Prism Field canvas, a native floating sidebar, standard-material content,
  and interactive Liquid Glass reserved for controls and draggable Prism Rail items.
- Added a CI contract that rejects decorative content-layer Liquid Glass regressions.
- Migrated the workspace, prismCalc utility, and Settings lifecycle to native SwiftUI scenes while preserving the AppKit status-item popover boundary.
- Replaced the status-item artwork with a template-rendered prism identity shared by the app UI.

### Fixed

- Made Prism Deck bootstrap the first SwiftUI workspace after a cold, windowless launch.
- Preserved distinct Accessibility identifiers for page headers inside the extended Prism Field canvas.
- Restored the native macOS Settings command and made both Command-comma and Prism Deck reuse one adaptive Settings window.
- Restored Escape-key dismissal and repeat opening for the Prism Deck status-item popover.
- Made visual assurance tolerate persisted user window geometry, enforce the shipping minimum size, and embed the exact audited source revision.
- Replaced deprecated disk-image creation with the native macOS 27 `diskutil image` workflow.
- Enforced a hard observation deadline even when an Accessibility reader does not cooperate with cancellation.
- Made native menu bar movement use a dense bounded Command-drag with guaranteed mouse, modifier, and pointer cleanup.
- Kept same-section direct moves stable while unrelated menu bar sources appear or disappear during preflight.
- Synchronized verified post-move topology directly into the interface instead of waiting for a second refresh.
