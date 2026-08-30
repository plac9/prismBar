# Verified prismBar Rebuild Design

## Status

Approved on 2026-08-29 after competitive research and the physical failure of the Mac App Store spacer experiment.

## Product decision

prismBar remains a real menu-bar manager. It ships through signed, hardened, notarized direct distribution because the Mac App Store sandbox cannot provide the required cross-process menu-bar discovery and control behavior.

The preserved `feature/app-store-organizer` branch is historical feasibility evidence. Its single-status-item command deck is not the shipping product because it cannot organize third-party menu-bar items.

## Promise

prismBar discovers the menu bar, makes direct changes, verifies what macOS actually did, explains any mismatch, and offers a safe route back.

prismDeck is the compact daily control surface. Rail is the direct manipulation surface. Prism Cards are bounded first-party capabilities from the Prism ecosystem.

## Product order

The rebuild follows this strict dependency order:

1. Reliable topology discovery and permission truth.
2. Verified menu-bar actions with explicit receipts.
3. Privacy-bounded recovery and undo.
4. Rail direct manipulation.
5. prismDeck daily control and recovery.
6. Layout Scenes after recovery is trustworthy.
7. Prism Cards after the menu-bar product is complete.

No Prism Card milestone may displace or weaken a menu-bar milestone.

## Verified action model

Every protected operation has one action identifier and one visible lifecycle:

```text
requested
  -> verifying
      -> applied
      -> partial
      -> blocked
      -> recovered
```

The authoritative topology never changes optimistically. The interface may show the requested destination while the action is verifying, but the live topology changes only after a fresh observation.

An action receipt contains:

- a process-local monotonic identifier
- the operation kind
- the current lifecycle state
- a bounded user-facing result
- whether a safe recovery candidate exists

Receipts never enter production logs. They contain no PID, path, environment value, AX value, frame, bundle inventory, or persisted menu-item title.

## Recovery ledger

Version 1 uses an in-memory recovery ledger owned by the trusted host.

- Maximum ten completed entries.
- Never encoded, persisted, exported, logged, or sent to a plugin.
- Stores the exact before and verified-after snapshots only for the current process session.
- Clears when Accessibility is revoked, identity changes, or the app terminates.
- Offers recovery only when current and target snapshots contain the same recoverable item set on the same display surfaces.
- Recovery is itself a verified action with its own receipt.

Persistent Scenes are a later phase. They require a separate privacy design because cross-launch item identity can reveal installed-application inventory.

## Rail

Rail presents one selected display at a time with visible and hidden lanes.

- Dragging an item to another position resolves to one direct move.
- Dragging across lanes resolves to one section move.
- The drop target is validated against the current snapshot generation.
- The item stays visually attached to its authoritative position until verification completes.
- The destination receives a temporary verifying treatment.
- Success, partial movement, and failure use semantic state, text, and symbols.
- Keyboard and VoiceOver actions provide equivalent first, last, previous, next, hide, and show operations.
- Undo appears only when the recovery ledger has a compatible entry.

## prismDeck

prismDeck is an AppKit-owned status-item presentation boundary containing SwiftUI content. It is not a Settings window and not an app launcher.

Its stable structure is:

1. Connection and topology truth.
2. Rail and immediate menu-bar actions.
3. Current action receipt and recovery.
4. Prism Cards, collapsed by default until the core engine is ready.
5. Open Workspace, Settings, and Quit.

Normal click opens prismDeck. Escape dismisses it. Repeated click reopens it. Menu-bar control remains functional with no workspace window open.

## Prism Cards

Prism Cards are the user-facing expression of the bundled plugin framework.

- Cards are sealed inside the submitted prismBar bundle.
- Every Card runs in a sandboxed XPC service.
- The host validates reciprocal code-signing requirements.
- Cards communicate only through `prismPluginKit` values.
- Cards never receive AX objects, menu topology, PID inventory, files, bookmarks, secrets, or inherited network authority.
- prismBar never downloads or loads executable plugin code.

The first Card is prismCalc. It provides an inline explicit-input calculator in prismDeck, copies a result only after a user command, and opens the independent prismCalc app only through an explicit action. It must not become the primary prismDeck experience.

## Design contract

- macOS 27 system Liquid Glass owns navigation, menus, popovers, controls, focus, elevation, and selection.
- The Prism Field supplies restrained refracted color beneath native glass.
- Persistent content does not stack decorative glass cards.
- Status colors remain semantic and never use the prism spectrum.
- Reduce Transparency, Increase Contrast, Differentiate Without Color, Reduce Motion, keyboard navigation, and VoiceOver are first-class acceptance variants.
- User-facing product copy uses exactly `prismBar`, `prismDeck`, and `Rail`.

## Security contract

- Accessibility remains the primary trust boundary and is host-only.
- No screen capture or OCR.
- No production logging of observed values, item titles, process names, paths, frames, environment values, plugin payloads, or user content.
- No new dependency, entitlement, URL scheme, background service, update mechanism, licensing service, or network call without an ADR, threat-model update, and privacy-contract update.
- Tests and fixtures use synthetic identifiers only.
- Recovery snapshots remain process-local memory and are discarded on trust loss.

## Distribution and licensing

- Direct distribution only for the full menu-bar manager.
- Developer ID Application signing, Hardened Runtime, notarization, stapling, and Gatekeeper assessment are required.
- The exact MPL-covered source revision remains public no later than binary availability.
- Every bundle contains MPL-2.0, NOTICE, and the immutable source revision.
- No independent updater is introduced in this rebuild phase.

## Rebuild phases

### Phase A: Verified actions and recovery ledger

Add typed action receipts, bounded in-memory recovery history, compatibility checks, and recovery planning.

### Phase B: Engine integration

Route direct, section, batch, reset, and recovery operations through one action coordinator. Remove duplicated state transitions and ensure every result owns a verified snapshot or an explicit failure.

### Phase C: Rail rebuild

Rebuild direct manipulation around action receipts, stable drag state, destination previews, undo, keyboard parity, and multi-display truth.

### Phase D: prismDeck rebuild

Make Rail and recovery the primary compact experience. Restore reliable status-item opening and remove utility-launcher emphasis.

### Phase E: Workspace and Scenes

Rebuild the full workspace around menu-bar organization, diagnostics, recovery history, and privacy-reviewed Scenes.

### Phase F: Prism Cards

Rename the user-facing tool metaphor to Prism Cards, adapt prismCalc into a compact inline Card, and preserve the existing XPC security boundary.

### Phase G: Production verification

Run package, app, UI, security, signing, secret, similarity, accessibility, visual, endurance, and physical macOS 27 gates against the exact installed candidate.

## Completion rule

No phase is complete because code exists or unit tests pass. Completion requires the direct evidence specified by `docs/IMPLEMENTATION-PLAN.md`, including the exact signed app installed at `/Applications/prismBar.app` and observed successful multi-position movement on physical macOS 27.
