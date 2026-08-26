# Architecture

## System shape

prismBar is a native macOS application with one trusted host process and separately sandboxed bundled plugin processes.

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

The engine separates observation, planning, execution, and verification:

1. Observe a fresh topology snapshot.
2. Validate the requested target against the snapshot.
3. Plan the shortest supported movement to the exact destination.
4. Execute through a public input or AX action.
5. Observe a new snapshot.
6. Compare the requested invariant with the observed result.
7. Report success, partial movement, rejection, topology change, permission loss, timeout, or unsupported item.

The user interface never optimistically mutates the authoritative topology. It may show progress tied to the action identifier.

## Plugin protocol

`PrismPluginKit` uses a versioned Codable wire contract with these top-level messages:

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

The host sets an exact code-signing requirement on every `NSXPCConnection`. The service applies a reciprocal host requirement before accepting requests. Protocol version and declared capabilities are checked during handshake before any panel data is requested.

## Failure behavior

- Accessibility unavailable: keep Settings and privacy explanations functional; disable protected actions.
- Topology changed: discard the stale plan, refresh, and offer the action again.
- Plugin timeout: invalidate the connection, preserve the host, show plugin unavailable, and allow one manual retry.
- Plugin crash loop: disable the plugin for the session and show a recoverable status.
- Corrupt preferences: quarantine the invalid payload locally and restore documented defaults without deleting unrelated files.
- Unknown error: show a stable error code and local recovery action; keep sensitive diagnostics out of the normal UI.

## Distribution

The production bundle uses Developer ID Application signing, Hardened Runtime, secure timestamps, and Apple notarization. The distribution container is a signed and notarized disk image or installer chosen after physical install testing. The product must be installed in `/Applications` before asking for Accessibility access.

The Mac App Store is not a target because the required Accessibility behavior is incompatible with App Sandbox. This decision is reviewed if Apple provides a supported sandbox-compatible API that fulfills the complete product contract.
