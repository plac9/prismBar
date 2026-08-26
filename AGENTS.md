# prismBar Agent Guide

Follow `~/dev/.standards/AGENT-STANDARDS.md`, `~/dev/.standards/UNIVERSAL-CONTEXT.md`, and `~/dev/ios/AGENTS.md`.

## Identity

- Human-facing product name is exactly `prismBar`.
- Use this exact casing for every human-facing product reference without exception.
- Bundle identifier is `com.laclairtech.prismbar` because Apple identifiers are case-insensitive infrastructure identifiers, not product copy.
- Copyright owner is Patrick LaClair and LaClair Technologies.

## Clean-room boundary

- `~/dev/prismBar-gpl-reference` is reference-only and push-disabled.
- Never copy or adapt source, tests, assets, strings, symbols, configuration, or documentation from that tree.
- Implement from product behavior, Apple documentation, original specifications, and independently authored tests.
- Record provenance for every third-party dependency and generated asset.

## Platform and implementation

- macOS 27 or later, Apple silicon only.
- Xcode 27 must be selected per command with `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` until it is the stable selected toolchain.
- Swift 6.4 with complete strict concurrency.
- SwiftUI-first, with AppKit only where macOS-specific lifecycle, status-item, window, Accessibility, or XPC integration requires it.
- Use public Apple APIs only.
- Prefer system components and behaviors. Document any Apple behavior override using the workspace-standard `MARK` block.

## Security and privacy

- Treat Accessibility access as the primary trust boundary.
- Never log AX values, item titles, process names, environment variables, paths, or user content in production.
- Tests and fixtures use synthetic identifiers only.
- No screen capture or OCR.
- No arbitrary plugin installation or dynamic library loading.
- Plugins are bundled sandboxed XPC services and communicate through `prismPluginKit` value types.
- The host sets a code-signing requirement on every XPC connection.
- Plugins never receive `AXUIElement`, PID inventory, file handles, bookmarks, secrets, or network authority.
- Do not add a dependency, entitlement, URL scheme, background service, update mechanism, licensing service, or network call without updating the threat model and privacy contract first.

## Verification

- Write failing tests before implementation for every feature or bug fix.
- Run Swift package tests, unsigned build tests, code-signing checks, secret scans, static analysis, and physical macOS 27 UI tests appropriate to the change.
- A permission check passing in a unit test is not proof. Verify the signed app installed at `/Applications/prismBar.app` on a physical Mac.
- UI completion requires screenshots of the shipping surface and an HTML audit report in `build/`.
- Do not claim release readiness until every gate in `docs/IMPLEMENTATION-PLAN.md` has direct evidence.

## Git

- Preserve unrelated user work.
- Use small signed conventional commits.
- Do not push, publish, replace the GitHub repository, notarize, or distribute without the owner gate required by workspace instructions.
