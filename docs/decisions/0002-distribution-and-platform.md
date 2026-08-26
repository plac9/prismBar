# ADR-002: macOS 27 direct distribution

**Status:** Accepted
**Date:** 2026-08-25
**Deciders:** Patrick LaClair and Codex

## Context

The product requires Accessibility APIs to discover and manipulate menu bar elements. Apple's App Sandbox documentation lists assistive Accessibility API use among incompatible activities, while Mac App Store distribution requires App Sandbox. Patrick explicitly prioritizes complete macOS 27 behavior over backward compatibility.

## Decision

Target macOS 27 or later on Apple silicon. Distribute outside the Mac App Store as a Developer ID signed, Hardened Runtime enabled, notarized application. Install the shipping app in `/Applications` before requesting Accessibility consent.

## Consequences

### Positive

- The full product contract can use supported public Accessibility APIs.
- The application can adopt macOS 27 APIs and native Liquid Glass without compatibility branches.
- Stable installation and signing identity improve TCC permission continuity.

### Negative

- The existing App Store Connect record is not the distribution channel for this product.
- Payment, updates, taxes, license delivery, and customer support need a direct-sales workflow.
- Developer ID packaging and notarization become first-class release gates.

### Risks

- Users may be cautious about granting Accessibility to a directly distributed application.
- A future macOS change may alter menu bar Accessibility behavior.

## Alternatives Considered

- **Mac App Store:** Rejected because the required Accessibility behavior is incompatible with App Sandbox.
- **macOS 26 support:** Rejected because compatibility code would dilute the explicit macOS 27 product and design target.
- **Private or undocumented APIs:** Rejected for security, stability, and Apple-guideline compliance.
