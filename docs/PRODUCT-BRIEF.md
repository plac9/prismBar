# Product Brief

## Promise

prismBar is a real macOS 27 menu bar manager. It gives users reliable control over a crowded menu bar while keeping every observation and action local and understandable.

## Primary user loop

1. Install prismBar in Applications and open it.
2. Review the local-only privacy promise and grant Accessibility access.
3. See the detected menu bar items grouped by current section.
4. Drag any movable item directly to a destination, hide or reveal a section, or use a keyboard action.
5. See whether the action is verifying, applied, partial, or blocked, then recover the last compatible change when needed.
6. Use `prismDeck` for everyday changes without reopening the full workspace.

## Product requirements

### Onboarding and permission

- Never request Accessibility before explaining the exact need.
- Detect whether the running app is installed at `/Applications/prismBar.app` before requesting access.
- Show current app path, bundle identity, signing team state, and permission result in an optional diagnostic disclosure without exposing them to logs.
- Open the correct System Settings privacy pane.
- Recheck automatically when the app becomes active and manually on command.
- Detect revoked access during runtime and degrade safely.
- Survive relaunch and a properly signed upgrade without requiring permission removal and re-addition.

### Menu bar control

- Inventory only the metadata required for control.
- Classify controllable, system-owned, unavailable, and prismBar-owned elements truthfully.
- Move an item across multiple positions in one command or drag.
- Preserve relative order when moving a selected group.
- Detect topology changes caused by displays, spaces, full-screen apps, and system rearrangement.
- Never claim a move succeeded until the observed topology matches the requested result.
- Give every protected operation a typed process-local receipt.
- Keep at most ten verified recovery candidates in memory and clear them when Accessibility trust is lost.
- Never persist, log, export, or send recovery snapshots across XPC.
- Keep persistent layout Scenes behind a separate privacy design and acceptance phase.

### Status item

- Normal click opens `prismDeck`.
- `prismDeck` shows topology truth, Rail, immediate visibility actions, the current receipt, compatible recovery, Settings, and Quit.
- Option-click may reveal a diagnostic shortcut only if documented and discoverable.
- The status item cannot be hidden by prismBar itself.

### Prism Cards

Prism Cards are a later capability layer and cannot displace core menu-bar work. They resume only after the signed installed menu-bar product passes physical macOS 27 acceptance. Cards are build-time bundled, sandboxed XPC services that expose bounded host-rendered values and never receive Accessibility-derived topology.

The first Card is prismCalc. It must:

- Contribute a compact calculator panel rendered by the host.
- Support basic everyday arithmetic, clear, sign, percent, decimal, and parentheses.
- Show and copy the current result.
- Keep a bounded local recent-result list owned by the Card.
- Open the full prismCalc application through an explicit user action when installed.
- Remain useful when the full application is not installed.
- Do not import the proprietary prismCalc app, StoreKit, CloudKit, themes, history database, widgets, or account state.

## Non-goals for the first production release

- third-party Prism Card installation
- online plugin catalog
- scripting or arbitrary code execution
- screen capture or icon OCR
- cloud sync
- analytics or crash uploads
- account creation
- Mac App Store distribution, because the full menu-bar manager requires non-sandboxed Accessibility control
- Intel support
- support for macOS 26 or earlier

## Success criteria

- A new user can install, grant access, and complete a verified multi-position move without intervention.
- A previously granted signed build recognizes permission after relaunch and after a signed upgrade.
- The status item opens every time and exposes the primary actions.
- No test, log, crash report, or artifact contains real menu bar content or secrets.
- A disabled or crashed Prism Card cannot interrupt menu bar control.
- The entire shipping UI is visually and functionally verified on physical macOS 27 in light, dark, increased contrast, reduced transparency, reduced motion, VoiceOver, keyboard-only, multiple-display, and full-screen scenarios.
