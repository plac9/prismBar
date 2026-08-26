# prismBar Prism Deck and Tool Experience Design

## Status

Approved product direction for the macOS 27 command center, main workspace, and bundled tool experience.

This specification turns the existing plugin framework into a useful product surface. It replaces the calculator embedded in Settings-style pages with a menu-bar-launched utility, makes the plugin boundary understandable to nontechnical users, and gives prismBar a distinctive native identity without imitating Liquid Glass.

## Product goal

prismBar should make frequent menu bar actions available from one click while keeping deeper organization and trust information easy to find. Bundled tools should feel like focused parts of prismBar, not demonstrations hidden in a configuration screen.

The result must provide:

- a compact menu-bar command center named Prism Deck
- a Bar mode for everyday visibility and movement controls
- a Tools mode for launching focused bundled utilities
- an independent prismCalc utility window
- a main workspace for deeper menu bar organization, tool management, automation, privacy, and product information
- a clear explanation of what the plugin framework adds and what it cannot access
- native macOS 27 materials, controls, window behavior, keyboard access, and accessibility adaptation

## User language

The user-facing product noun is **Tools**. A tool is a focused capability available from prismBar, such as prismCalc.

The technical noun **plugin** appears only in trust and architecture explanations. This prevents a framework term from becoming the navigation model while still communicating how isolation works.

Approved explanatory copy:

> Tools add focused capabilities to prismBar. Each tool runs in its own signed service, and prismBar renders only a small set of validated controls. Tools cannot access menu bar data, Accessibility, files, the network, or other app content unless a future capability explicitly says so.

The first release supports sealed first-party tools bundled with prismBar. It does not support browsing, downloading, or installing third-party plugins.

## Information architecture

### Prism Deck

Clicking the primary prism menu-bar icon opens Prism Deck. It is a compact, keyboard-navigable command center with a standard segmented mode control.

```text
Prism Deck
  Bar
    live permission and engine state
    hidden-section control
    recently or currently actionable menu items
    direct movement and recovery actions
  Tools
    enabled tool launchers
    concise tool health
    prismCalc launch action
  Footer
    Open Workspace
    Settings
```

Prism Deck is transient. It does not host a full calculator, long-form plugin management, onboarding, or dense multi-display arrangement controls.

### Main workspace

The main app window remains a standard macOS workspace with `NavigationSplitView` and these destinations:

| Destination | Purpose |
|---|---|
| Home | Readiness, quick status, and relevant next action |
| Menu Bar | Full organization, direct destination movement, section management, and display context |
| Tools | Bundled tool catalog, enable state, health, capabilities, trust explanation, and launch action |
| Automation | Supported Shortcuts and command discovery |
| Privacy | Accessibility boundary, local data behavior, and recovery |
| About | Identity, version, legal terms, releases, and source provenance |

The current Plugins destination becomes Tools. The Tools page does not embed a live calculator. It explains and manages tools, then launches each tool in its intended surface.

### Settings

Settings contains only infrequently changed preferences:

- launch behavior
- menu-bar control behavior
- appearance choices that prismBar genuinely owns
- permission recovery entry points

Settings does not contain the menu bar workspace, live calculator, plugin catalog, or routine commands. It uses the standard Settings scene and Command-Comma behavior.

## Window architecture

### SwiftUI scenes

Use SwiftUI scene ownership for user-facing windows:

- a standard primary window scene for the workspace
- a standard Settings scene
- a `UtilityWindow` scene for prismCalc

The prismCalc utility behaves like a secondary tool palette. It can float as the system defines, closes with Escape when appropriate, and does not force the main workspace to remain open.

### Menu bar ownership

Keep AppKit status items only where lower-level placement and menu-section behavior require them. The primary control should present SwiftUI content with standard window or popover behavior and normal click semantics.

Do not replace the section dividers with `MenuBarExtra` if doing so breaks the placement contract. Do not keep manual `NSWindow` ownership merely to preserve historical structure when SwiftUI scenes can express the required behavior.

### Presentation routing

Introduce one typed presentation router shared by Prism Deck, workspace commands, and tool launchers. It opens these destinations by stable identifiers:

- workspace destination
- Settings
- tool utility window

Views must not reach into `NSApplication`, `NSWindow`, or singleton controllers directly when a typed router can express the action.

## Prism Deck behavior

### Bar mode

Bar mode prioritizes the current action:

1. Show a concise readiness row for Accessibility and engine state.
2. Show the hidden-section state and its reveal or hide action.
3. Show actionable menu items with direct destination movement.
4. Provide one specific recovery action for a failed operation.

Movement must preserve the existing verified engine contract. The interface does not optimistically reorder before the engine verifies the real menu bar. Long movement is a direct destination action, never a sequence of one-position moves.

### Tools mode

Tools mode shows enabled tools as launchers. Each launcher contains:

- tool icon and exact display name
- one-line purpose
- current state such as Ready, Verifying, Paused, or Off
- Open action when usable
- one relevant recovery action when unusable

Selecting prismCalc dismisses Prism Deck and opens or focuses the prismCalc utility window. Reopening the tool focuses the existing instance rather than creating duplicates.

### Failure communication

An unexplained red exclamation mark is prohibited. Every failure state provides:

- a human-readable category
- the affected action
- one relevant recovery action
- an accessible value that does not depend on color

Internal process names, paths, Accessibility values, geometry, identifiers, and raw errors remain private.

## Tool framework experience

### What a tool is

A tool is a sealed, first-party capability bundled with prismBar. Its implementation runs as an isolated XPC service. The host validates the service identity, protocol version, capability declaration, descriptor limits, and every response before rendering anything.

### What crosses the boundary

The host sends explicit local actions defined by `prismPluginKit`. The service returns a closed panel description made from validated native elements. prismBar renders those elements. A tool never sends executable SwiftUI, AppKit views, HTML, scripts, dynamic libraries, or arbitrary commands.

### What does not cross the boundary

Tools do not receive:

- Accessibility objects or observed menu bar data
- process inventory
- pointer or keyboard control
- file handles, bookmarks, paths, or environment values
- network authority
- application secrets
- arbitrary URL or shell execution

These are architectural limits, not merely permission copy.

### Capability explanation

The Tools page presents declared capabilities in plain language. For prismCalc:

| Capability | User explanation |
|---|---|
| Panel | prismBar can render the calculator controls returned by the verified service |
| Commands | prismBar can send only the calculator actions defined by the protocol |
| Open application | prismBar may open the separately installed verified prismCalc app when that explicit action is available |

The page also presents the service state and exact recovery behavior. It never claims a cryptographic control that is not implemented.

## prismCalc utility

The prismCalc tool opens in a dedicated compact utility window. The first version preserves the validated basic calculator panel and existing crash, hang, timeout, validation, and circuit-breaker behavior.

The utility window provides:

- a clear numeric result
- a keyboard-accessible keypad
- visible service health only when attention is needed
- retry when paused or unavailable
- an optional Open prismCalc action only when a separately installed, correctly signed app is verified

The utility does not display menu bar state or request Accessibility. Closing it does not stop prismBar.

## Visual system

`DESIGN.md` at the repository root is authoritative for tokens and guardrails.

### Native Liquid Glass

Use standard macOS 27 components so the platform supplies current Liquid Glass behavior. Liquid Glass belongs to system navigation and interactive layers. Static content uses semantic system backgrounds, separators, and restrained grouping.

Do not build fake glass with custom blur, translucent full-window fills, shine, or repeated material cards. This remains true even when the result looks more dramatic in a static mockup.

### Distinctive identity

prismBar's identity comes from three elements:

1. the purpose-drawn prism application and menu-bar marks
2. glacier-blue action tint
3. a rare, narrow refracted-light edge used only to mark a product mode or tool identity

Spectral color is decorative and never communicates success, warning, selection, or failure by itself.

### Adaptation

The interface follows system light and dark appearance. It honors Reduce Transparency, Increase Contrast, Differentiate Without Color, and Reduce Motion. Standard control borders and focus behavior remain available on macOS 27.

## State model

Tool presentation derives from the existing shared app model and adds no duplicate plugin engine.

```text
disabled -> enable -> verifying -> ready
                         |          |
                         v          v
                    unavailable <- interrupted
                         |
                         v
                       paused -> explicit retry -> verifying
```

Window presence is separate from service state. Opening the utility requests loading if needed. Closing the utility does not disable or unload the registered tool. Disabling a tool closes its utility and prevents launch until re-enabled.

## Security and privacy

This design does not add a dependency, network call, entitlement, URL scheme, dynamic loading path, downloaded code, telemetry, or diagnostic upload.

All new production copy and logs follow the existing public-safety rules:

- no observed menu labels or process names
- no Accessibility values or coordinates
- no filesystem paths or environment values
- no plugin request or response payloads
- no private identifiers, secrets, or personal data

Tool launch routing accepts only identifiers from the sealed bundled registry. Unrecognized identifiers fail closed.

## Accessibility

- Every tool and menu action has a textual accessibility label.
- State has text and symbol representation and never relies on color alone.
- Keyboard traversal follows visual order.
- Prism Deck supports Escape dismissal and predictable focus restoration.
- The utility exposes calculator results as values and keypad actions as buttons.
- Motion and numeric transitions become nonspatial when Reduce Motion is enabled.
- Text uses system styles and supports localization expansion.

## Testing and acceptance

### Unit and integration tests

- presentation routing accepts only registered destinations and tools
- repeated tool launch focuses one utility instance
- disabling prismCalc prevents launch and dismisses its utility
- plugin state maps to exact user-facing health and recovery models
- descriptor validation and XPC isolation tests remain green
- no tool capability gains Accessibility, files, environment, network, shell, or generic URL access

### UI automation

- primary menu-bar icon opens Prism Deck
- Bar and Tools modes are keyboard and pointer accessible
- prismCalc launches from Tools mode into its own window
- the Tools workspace page manages and explains prismCalc without embedding its keypad
- Settings contains preferences and recovery only
- error states expose readable labels and actions instead of a bare exclamation mark
- light, dark, Reduce Transparency, Increase Contrast, and Reduce Motion variants remain usable

### Physical macOS 27 acceptance

- the exact signed `/Applications/prismBar.app` is granted Accessibility
- Prism Deck opens reliably from the shipping menu-bar icon
- direct movement works across more than one position and verifies the result
- prismCalc opens, calculates `7 + 5 = 12`, survives close and reopen, and recovers from a forced isolated-service interruption
- no duplicate utility windows appear
- keyboard focus and Escape behavior match standard macOS expectations
- shipping screenshots and an HTML UI audit report are captured in `build/`

## Migration

1. Add the typed presentation model and tests without changing the current surface.
2. Move the main workspace and Settings to SwiftUI scene ownership.
3. Add the prismCalc utility scene and route existing validated panel rendering into it.
4. Replace the embedded calculator in the Tools workspace page with management, trust explanation, and launch behavior.
5. Recompose the status command surface into Prism Deck with Bar and Tools modes.
6. Preserve AppKit-only menu divider behavior and remove obsolete manual window ownership.
7. Update commands, documentation, UI automation, screenshots, and acceptance evidence.

Each migration step must leave the app buildable and the plugin security boundary unchanged.

## Alternatives rejected

### Keep prismCalc embedded in the Plugins page

Rejected because a working calculator inside a management surface is hard to discover and inconvenient to reuse. It proves rendering but does not create a useful daily workflow.

### Put the full calculator inside Prism Deck

Rejected because the menu-bar command center is transient and already owns menu organization. A full keypad would crowd routine controls, increase accidental dismissal, and make the popover do too many jobs.

### Support downloaded third-party plugins now

Rejected because discovery, trust, update, notarization, revocation, capability consent, and compatibility policy require a separate security architecture. The current framework is valuable without claiming an unsafe ecosystem.

### Hand-build a glass dashboard

Rejected because it would fight macOS 27 adaptation and confuse visual spectacle with platform quality. Standard controls receive the current system appearance automatically.

### Make the full app only a Settings window

Rejected because menu organization, tool management, privacy explanation, and operational status are product tasks, not infrequently changed preferences.

## Apple references

- [Settings](https://developer.apple.com/design/human-interface-guidelines/settings)
- [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
- [UtilityWindow](https://developer.apple.com/documentation/swiftui/utilitywindow)
- [Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers)
- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
