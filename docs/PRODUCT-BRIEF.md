# Product Brief

## Promise

prismBar gives macOS 27 users reliable control over a crowded menu bar while keeping everything local and understandable.

## Primary user loop

1. Install prismBar in Applications and open it.
2. Review the local-only privacy promise and grant Accessibility access.
3. See the detected menu bar items grouped by current section.
4. Drag any movable item directly to a destination, hide or reveal a section, or use a keyboard action.
5. Use the status item for everyday changes without reopening the full app.
6. Add capability through trusted bundled plugins, beginning with prismCalc.

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
- Provide recovery when an item disappears, the target is invalid, or macOS rejects the operation.

### Status item

- Normal click opens the prismBar menu.
- Menu shows current section controls, visibility actions, plugin panels, Settings, and Quit.
- Option-click may reveal a diagnostic shortcut only if documented and discoverable.
- The status item cannot be hidden by prismBar itself.

### prismCalc plugin

- Contribute a compact calculator panel rendered by the host.
- Support basic everyday arithmetic, clear, sign, percent, decimal, and parentheses.
- Show and copy the current result.
- Keep a bounded local recent-result list owned by the plugin.
- Open the full prismCalc application through an explicit user action when installed.
- Remain useful when the full application is not installed.
- Do not import the proprietary prismCalc app, StoreKit, CloudKit, themes, history database, widgets, or account state.

## Non-goals for the first production release

- third-party plugin installation
- online plugin catalog
- scripting or arbitrary code execution
- screen capture or icon OCR
- cloud sync
- analytics or crash uploads
- account creation
- Mac App Store distribution
- Intel support
- support for macOS 26 or earlier

## Success criteria

- A new user can install, grant access, and complete a verified multi-position move without intervention.
- A previously granted signed build recognizes permission after relaunch and after a signed upgrade.
- The status item opens every time and exposes the primary actions.
- No test, log, crash report, or artifact contains real menu bar content or secrets.
- A disabled or crashed plugin cannot interrupt menu bar control.
- The entire shipping UI is visually and functionally verified on physical macOS 27 in light, dark, increased contrast, reduced transparency, reduced motion, VoiceOver, keyboard-only, multiple-display, and full-screen scenarios.
