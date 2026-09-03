# prismBar Production Usability Hardening Design

## Status

Approved for autonomous execution by Patrick LaClair on September 2, 2026. This design narrows the production run to the core menu-bar product. Prism Cards, prismCalc integration, persistent Scenes, and unrelated expansion remain frozen.

## Outcome

prismBar must feel like a trustworthy macOS 27 control surface, not a diagnostic tool. A user should understand what the app sees, make one direct change, know whether macOS accepted it, and recover without interpreting implementation language. The shipping experience must remain responsive and useful when Accessibility is denied, a scan is incomplete, another application stops responding, the menu bar changes mid-action, or a display cannot safely accept synthesized input.

## Primary user journeys

### 1. Install and establish trust

1. Open the signed application from `/Applications/prismBar.app`.
2. Read one concise explanation of why Accessibility and event-posting authority are required.
3. Grant access in the system-owned interface.
4. Return to prismBar and see the live result without relaunching or repeating the explanation.

The primary state uses plain outcomes: `Ready`, `Access needed`, `Move to Applications`, or `Check access again`. Signing-path and permission diagnostics remain available only in a disclosure. prismBar never claims access from cached state.

### 2. Understand the current menu bar

The Menu Bar workspace and prismDeck show the same authoritative snapshot. They distinguish:

- items that are visible on the current display;
- items in the tucked-away section;
- macOS-owned items that cannot move;
- a limited scan where one or more running applications did not answer.

A limited scan is usable, not an error. Its inline explanation states that shown items can still be managed and every change will be verified. The interface may use amber as supporting status, but text carries the meaning.

### 3. Reorder, tuck away, and reveal

Movable Rail items expose both direct drag and deterministic menu/accessibility actions. A user can move an item several positions in one operation. Horizontal overflow must be discoverable without requiring a trackpad gesture guess: the current lane indicates that more items are available and offers a standard scroll path while preserving native momentum and accessibility scrolling.

Section language is consistent everywhere:

- `On Bar` is the always-visible lane.
- `Tucked Away` is the hidden lane.
- `Tuck Away` collapses the hidden section.
- `Reveal` opens it.
- Moving an item between lanes uses `Move to Tucked Away` or `Move to On Bar`.

The UI never optimistically reorders the authoritative snapshot. During an operation, the affected item and global action state show progress. Completion reports one of: applied, applied differently, stopped safely, access needed, or unavailable.

### 4. Recover confidently

Undo appears only for a verified compatible recovery entry. It describes what it will recover without persisting or logging observed menu-bar identities. If the live topology is no longer compatible, recovery fails closed and tells the user to refresh; it never replays against stale coordinates.

### 5. Use prismDeck every day

A normal status-item click opens prismDeck every time. Bar remains the default task. The surface keeps topology truth, the Rail, current action feedback, Undo, workspace, Settings, and Quit reachable at 100–200% reading sizes and on a 640-point visible display height. Escape dismisses it and the next click reopens it. No Tools or plugin promotion displaces menu-bar control.

## Interaction hierarchy

### Workspace

The full workspace is for inspection, bulk changes, permission recovery, and explanations. The initial Home screen answers only three questions: Is prismBar ready? What can I do next? What does it not collect?

The Menu Bar screen owns detailed organization. Rail is the primary control. Bulk organization remains collapsed by default. Refresh and recovery are secondary to direct manipulation.

### prismDeck

prismDeck is the fast path. It uses one scrolling content region between a stable header and footer. The fixed chrome never forces actions offscreen. The footer contains only the current section visibility action, `Open prismBar`, and the More menu.

### Settings

Settings contains infrequent preferences and access status. General owns reading size and live access state. Privacy is explanatory and contains no controls that duplicate the workspace.

## State and copy contract

User-visible state must describe consequence rather than implementation:

| Internal condition | User presentation |
| --- | --- |
| complete snapshot | `<count> items ready` |
| incomplete snapshot | `<count> items ready · limited scan` plus inline explanation |
| observation in progress | `Checking your menu bar…` |
| verified action | `Moved <item>.` or `Moved <item> to <section>.` |
| partial movement | `<item> moved, but macOS placed it at position <n>.` |
| topology changed | `Your menu bar changed before the move finished.` |
| permission lost | `Access changed. Check prismBar in System Settings.` |
| unsafe display state | `Exit full screen or show the menu bar, then refresh.` |

Production logs continue to omit item names, process names, paths, coordinates, topology, environment values, and Accessibility values. Item names may appear only in the live local interface and process-local receipts.

## Responsiveness and resource contract

- No Accessibility operation runs on the main actor.
- Every observation and move uses an existing bounded deadline and releases synthesized input state on cancellation or failure.
- Refresh coalesces while a scan is already active; repeated user input must not create unbounded tasks.
- prismDeck opens from cached verified presentation state immediately, then refreshes without blanking usable content.
- Idle CPU should settle below 1% on the acceptance Mac.
- Idle physical footprint should remain below 100 MiB after the workspace and prismDeck have both been exercised.
- A ten-minute refresh/action soak must not show monotonic task, memory, or window growth.

These are acceptance budgets, not telemetry. prismBar does not add analytics or background reporting.

## Accessibility and visual acceptance

Every shipping surface is reviewed in light and dark appearance at Standard and Accessibility reading sizes. The full matrix additionally covers Increase Contrast, Reduce Transparency, Reduce Motion, Differentiate Without Color, VoiceOver, keyboard-only navigation, a 640-point visible screen height, multiple displays, menu-bar auto-hide, full screen, Spaces, sleep/wake, logout, and reboot.

Acceptance requires:

- no clipped or overlapping text;
- no inaccessible offscreen fixed action;
- no icon-only action without a label and help text;
- no color-only status;
- no unexplained warning glyph;
- no decorative animation or material stacking;
- visible keyboard focus and deterministic traversal;
- every destructive or broad reset action explicitly confirmed;
- screenshots contain only the app's opaque pixels and synthetic test data.

## Security, privacy, and distribution boundaries

- Public Apple APIs only.
- No screen capture, OCR, network access, arbitrary plugin loading, file browsing, analytics, or crash-upload dependency.
- The shipping bundle contains one executable and no plugin runtime or XPC service.
- Accessibility remains host-only and is never delegated.
- MPL-covered binaries map to the exact public source revision.
- Release credentials stay outside the repository and are consumed only through the dedicated release Keychain and named notarization profile.
- Installation remains transactional with a verified rollback bundle.

## Verification layers

1. Domain and presentation tests prove copy, normalization, planning, verification, and recovery contracts with synthetic identities.
2. App tests prove lifecycle, action-state, permission, and scene-routing behavior.
3. Native UI tests prove keyboard traversal, hit targets, status-item lifecycle, Rail actions, error states, reading sizes, and constrained geometry.
4. Source and release audits prove privacy, licensing, entitlements, bundle shape, dependency inventory, and absence of credential-shaped content.
5. A signed exact-revision candidate is installed and exercised on physical macOS 27. Metadata and automated tests never substitute for observed movement, relaunch, display, and system-transition behavior.

## Out of scope

- Prism Cards and prismCalc UI
- third-party extensions
- persistent layout Scenes
- cloud sync or accounts
- telemetry
- Intel and macOS 26 support
- publication or pricing changes
