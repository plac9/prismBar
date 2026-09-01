# Architecture

## System shape

prismBar is a native macOS menu-bar manager with one trusted host process and separately sandboxed bundled Prism Card processes. The full product uses signed, notarized direct distribution because its cross-process Accessibility behavior is incompatible with App Sandbox.

```text
User
  |
  v
prismBar host process
  |  SwiftUI and AppKit UI
  |  permission coordinator
  |  menu bar topology and action engine
  |  plugin registry and declarative renderer
  |
  +---- public Accessibility APIs ----> macOS menu bar processes
  |
  +---- signed NSXPCConnection -------> prismCalc plugin service
                                         calculator state only
                                         no Accessibility
                                         no network
                                         no arbitrary files
```

## Trust zones

### Host

The host is the only component allowed to use Accessibility APIs. It owns the menu bar status item, windows, user preferences, topology model, action verification, and plugin rendering.

The host never passes AX objects, raw process inventory, PIDs, menu titles, application paths, file handles, environment data, or Accessibility-derived values to a plugin.

### Bundled plugins

Plugins run as embedded XPC services. Version 1 accepts only build-time bundled first-party plugins. Each service:

- has a fixed bundle identifier and manifest
- is signed by the same development team
- is sealed inside the signed application bundle
- uses App Sandbox
- has no network or user-selected-file entitlement
- declares bounded capabilities
- receives only the user input addressed to its panel or command
- can be disabled after repeated health failures

### Operating system

macOS owns permission state, menu bar processes, application lifecycle, code signing, Gatekeeper, and notarization. prismBar treats every Accessibility action as fallible and verifies results from a fresh observation.

## Modules

| Module | Responsibility | Forbidden dependencies |
|---|---|---|
| `prismBarCore` | Immutable domain models, topology planning, action outcomes, preferences contracts | AppKit, Accessibility, XPC |
| `prismBarAccessibility` | Public AX wrappers, permission state, element discovery, action execution | UI, plugins, persistence |
| `prismBarEngine` | Reconciliation, move planning, verification, retries, recovery | SwiftUI views, plugin implementation |
| `prismPluginKit` | Manifest, capabilities, commands, declarative panel schema, XPC protocol values | Accessibility, application internals |
| `prismBarApp` | Lifecycle, public AppKit status items, windows, settings, navigation, host renderer | plugin implementation details |
| `prismCalcPluginService` | Basic calculator reducer, bounded history, plugin protocol adapter | Accessibility, host engine, network, proprietary prismCalc app modules |

## Concurrency

- All UI and AppKit lifecycle code is `@MainActor`.
- Accessibility calls run through a dedicated actor that serializes AX access and applies bounded timeouts.
- The engine uses immutable `Sendable` snapshots and explicit action identifiers.
- XPC replies are bridged into checked continuations with timeout and cancellation handling.
- No `@unchecked Sendable` is allowed without an ADR and focused stress tests.

## Permission state machine

```text
unknown
  -> checking
      -> needsStableInstall
      -> notGranted
      -> granted
      -> identityMismatch
      -> unavailable(errorCode)

notGranted -> requesting -> waitingForSystem -> checking
granted -> monitoring -> revoked -> notGranted
```

Permission state is never persisted as truth. Every foreground transition and protected action queries the operating system again.

## Topology and action model

The engine separates observation, planning, execution, verification, and recovery:

1. Observe a fresh topology snapshot.
2. Validate the requested target against the snapshot.
3. Plan the shortest supported movement to the exact destination.
4. Execute through a public input or AX action.
5. Observe a new snapshot.
6. Compare the requested invariant with the observed result.
7. Report success, partial movement, rejection, topology change, permission loss, timeout, or unsupported item.

The user interface never optimistically mutates the authoritative topology. It may show progress tied to the action identifier.

### Action receipts and recovery

Every protected action creates a monotonic process-local identifier and a typed receipt. Receipts move through verifying and one terminal phase: applied, partial, blocked, or recovered. They contain only bounded user-facing results and never enter production logs.

The trusted host owns a bounded recovery ledger with at most ten entries. An entry contains an in-memory before snapshot and its verified after snapshot. Recovery is available only when the current unavailable-source count, observed item identities, ownership, roles, availability, display surfaces, and verified after-order match the retained entry. A stable partial scan may therefore recover the observed layout, but any coverage or topology change fails closed. The ledger is never encoded, persisted, exported, or sent across XPC, and it clears on Accessibility trust loss, signing-identity change, or process termination.

Persistent Scenes are not an extension of this ledger. They require a separate privacy design because stable cross-launch menu identities may reveal application inventory.

## Prism Card protocol

Prism Cards use the existing `prismPluginKit` versioned Codable wire contract with these top-level messages:

- `PluginHandshake`
- `PluginManifest`
- `PluginCapability`
- `PluginCommandDescriptor`
- `PluginPanelDescriptor`
- `PluginEvent`
- `PluginMutation`
- `PluginHealth`
- `PluginError`

Panel descriptors support a bounded set of host-rendered elements: text, result display, button, keypad grid, text field, divider, status, and action group. Descriptors contain data, semantic roles, accessibility labels, and stable identifiers. They cannot contain SwiftUI views, closures, selectors, class names, scripts, attributed HTML, file URLs, or executable payloads.

The host and service enforce reciprocal exact code-signing requirements on every `NSXPCConnection`. The host validates the sealed embedded XPC bundle, exact bundle identifier, Team ID, protocol version, and declared capability set. Protocol version and capabilities are checked during handshake before any panel data is requested. Wire messages, descriptors, request concurrency, response size, timeout, and reconnect behavior are bounded.

The host owns a bounded build-time registry of bundled Card registrations. Each registration fixes the service identifier, display name, version, capability set, allowed application identifiers, default enabled state, and preference key before the app is signed. Duplicate or malformed registrations fail closed. A user can disable a Card at any time, which invalidates its XPC connection and removes its panel without affecting menu bar control. Version 1 does not scan directories or accept downloaded bundles. Card integration remains frozen until the installed core menu-bar product passes physical macOS 27 acceptance.

## Failure behavior

- Accessibility unavailable: keep Settings and privacy explanations functional; disable protected actions.
- Topology changed: discard the stale plan, refresh, and offer the action again.
- Plugin timeout: invalidate the connection, preserve the host, show plugin unavailable, and allow one manual retry.
- Plugin crash loop: disable the plugin for the session and show a recoverable status.
- Corrupt preferences: quarantine the invalid payload locally and restore documented defaults without deleting unrelated files.
- Unknown error: show a stable error code and local recovery action; keep sensitive diagnostics out of the normal UI.

## Distribution

The production bundle uses Developer ID Application signing, Hardened Runtime, secure timestamps, and Apple notarization. Direct distribution uses a signed, notarized, and stapled APFS disk image containing `prismBar.app` plus an Applications-folder link. The application is notarized and stapled before the disk image is assembled, then the disk image is signed, notarized, stapled, and assessed independently. The product must be installed in `/Applications` before asking for Accessibility access.

The Mac App Store is not a target because the required Accessibility behavior is incompatible with App Sandbox. This decision is reviewed if Apple provides a supported sandbox-compatible API that fulfills the complete product contract.
