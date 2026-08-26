# ADR-003: Capability-bounded XPC plugins

**Status:** Accepted
**Date:** 2026-08-25
**Deciders:** Patrick LaClair and Codex

## Context

prismBar needs an extensibility model, beginning with prismCalc. The host also holds broad Accessibility authority. Loading arbitrary native bundles into that process would give plugin code the same authority and undermine the privacy and security contract.

## Decision

Create a public `prismPluginKit` protocol. Version 1 supports bundled first-party plugins implemented as separately signed sandboxed XPC services. Plugins declare capabilities and return bounded declarative panel data rendered by the host. The protocol has no Accessibility, generic automation, arbitrary file, environment, or executable UI capability.

The first plugin is prismCalc: an independently authored compact calculator with a recent result and an explicit action to open the separately licensed full prismCalc application.

## Consequences

### Positive

- A plugin failure does not crash the host.
- Plugin code does not inherit host Accessibility authority.
- Host-rendered controls preserve native appearance and accessibility.
- Protocol versioning makes compatibility testable.

### Negative

- Declarative panels are less flexible than arbitrary SwiftUI views.
- Every new panel element or capability requires a reviewed protocol addition.
- XPC signing, sandbox, timeout, and lifecycle testing increase implementation effort.

### Risks

- An overly broad future capability could reintroduce a confused-deputy path.
- Incorrect code-signing requirements could allow an unintended local client or service.
- Descriptor validation bugs could cause denial of service or misleading UI.

## Alternatives Considered

- **In-process Swift modules:** Rejected because plugin code would inherit Accessibility authority and a crash would terminate the host.
- **Arbitrary installable bundles:** Rejected because signing, supply-chain, permission, and compatibility risks are not acceptable for version 1.
- **Web extensions:** Rejected because a web runtime adds attack surface, visual inconsistency, and unnecessary network-shaped capabilities.
