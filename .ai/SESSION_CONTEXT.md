# prismBar Session Context

## Current objective

Build a production-quality, independent prismBar implementation for macOS 27 using modern Swift, native Liquid Glass UI, public Apple APIs, a reliable Accessibility permission flow, secure menu bar control, and a capability-bounded plugin system whose first plugin is prismCalc.

## Locked decisions

- New repository and Git history at `~/dev/prismBar`.
- GPL reference preserved at `~/dev/prismBar-gpl-reference` with push disabled.
- MPL-2.0 for prismBar and prismPluginKit.
- Direct Developer ID distribution with Hardened Runtime and notarization.
- macOS 27 or later and Apple silicon only.
- Host retains Accessibility authority.
- Plugins are bundled, allowlisted, sandboxed XPC services with code-signing requirements.
- prismCalc is the first plugin: compact calculator panel, recent result, copy, and open-full-app action.
- No screen capture, OCR, telemetry, analytics, arbitrary plugin loading, or private Apple APIs.

## Current phase

Architecture and repository foundation. Implementation begins only after the design contracts and ADRs are committed.

## Physical validation requirement

The signed candidate must be installed at `/Applications/prismBar.app`. Accessibility permission must be removed, granted, detected, survive relaunch, and remain valid after a signed upgrade. Menu item movement must be proven across multiple positions in one action, not one space at a time.
