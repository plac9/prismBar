# Changelog

All notable changes to prismBar are documented in this file.

The format follows Keep a Changelog. Versions follow Semantic Versioning after the first public release.

## [Unreleased]

### Added

- Clean-room repository with independent Git history.
- Product, architecture, security, privacy, design, licensing, and plugin contracts.
- MPL-2.0 public-source licensing foundation.
- macOS 27 and Apple-silicon-only XcodeGen project using Swift 6 strict concurrency.
- Native menu bar command center and accessible main-window lifecycle scaffold.
- Sandboxed out-of-process prismCalc plugin service that requires the exact signed host.
- Versioned, bounded plugin wire protocol and independently authored calculator reducer.
- Unit and physical-host UI launch tests.
- Live Accessibility authorization state based on a fresh macOS trust check.
- Stable `/Applications/prismBar.app` and exact signing identity validation before requesting Accessibility access.
- Accessible permission recovery controls with foreground refresh behavior.
