# Native Settings Scene Design

## Status

Approved direction awaiting written-spec review.

## Purpose

Replace prismBar's duplicate Settings-window ownership with one native SwiftUI `Settings` scene. Every entry point must open the same system-managed Settings window without manually constructing an `NSWindow`, invoking private selectors, or coupling feature views to `AppWindowController`.

This corrects a regression from the approved Prism Deck design, which required native Settings presentation, and advances the macOS 27-only rewrite toward Apple platform conventions.

## Current-State Problem

`prismBarApp` declares a SwiftUI `Settings` scene, but the application also creates and retains a second Settings window in `AppWindowController`. Three routes currently bypass the native scene:

1. The application Settings command calls `AppWindowController.shared.showSettings()`.
2. Prism Deck receives an `openSettings` closure that calls the same method.
3. `MenuBarSectionStatusController` wires that closure while constructing its hosted SwiftUI popover.

The duplicate path owns window geometry, activation, title-bar styling, and lifetime manually. It also fixes the content at 560 by 420 points, which produces the cramped Settings presentation identified during visual review.

## Scope

This change covers Settings ownership, presentation routing, lifecycle behavior, sizing, accessibility, and test evidence.

It does not convert the workspace, prismCalc utility, or the custom status-item divider machinery to new scene types. Those remain separate modernization work because they have distinct lifecycle and menu-bar-control constraints.

## Approaches Considered

### 1. One SwiftUI Settings scene with native entry points

Use the existing `Settings` scene as the only owner. Let SwiftUI provide the standard application Settings command and Command-comma behavior. Use `SettingsLink` in Prism Deck so the user-facing control uses the public Settings presentation contract. Remove the Settings closure from Prism Deck and remove all Settings state and construction from `AppWindowController`.

This is the selected approach. It removes duplicate ownership, follows the macOS scene model, and leaves testable public entry points.

### 2. Keep the custom AppKit window and enlarge it

This would improve the immediate layout but preserve two Settings systems, custom activation behavior, custom restoration, and future drift. It is rejected because it treats the symptom while retaining the architectural defect.

### 3. Convert every application window to SwiftUI scenes in one change

This would also replace workspace and prismCalc window ownership. It is rejected for this change because the workspace reopen contract, independent prismCalc lifecycle, and custom multi-item menu-bar controller require separate acceptance work. Combining them would make failures harder to isolate and review.

## Architecture

### Scene ownership

`prismBarApp` remains the single declaration point for Settings:

```swift
Settings {
    SettingsRootView()
        .environment(AppModel.shared)
        .frame(
            minWidth: 640,
            idealWidth: 680,
            minHeight: 500,
            idealHeight: 540
        )
}
```

The final values may be adjusted by visual acceptance within these bounds, but the content must never return to a fixed 560 by 420 frame. SwiftUI and AppKit retain responsibility for the actual window chrome, restoration, and placement.

### Application command

The app will no longer replace the `.appSettings` command group. Declaring the `Settings` scene allows macOS to supply the standard Settings menu item and Command-comma shortcut. `PrismBarCommands` will retain only prismBar's domain commands.

No custom command may call `showSettings()`, create a Settings window, or use a selector to simulate the native command.

### Prism Deck entry point

`PrismDeckView` will replace its injected `openSettings` closure with `SettingsLink`. The footer remains a compact icon-only control with an explicit accessibility label and help text.

`MenuBarSectionStatusController` will stop wiring a Settings callback. It will continue to own only the AppKit status items and popover required by prismBar's menu-bar section engine.

If `SettingsLink` cannot present the declared Settings scene from the manually hosted popover on macOS 27, that is an architectural test failure. The accepted response is to move the popover root into a scene-backed environment in a separate reviewed design, not to restore a custom Settings window or invoke an undocumented selector.

### AppWindowController boundary

`AppWindowController` will own only the workspace and prismCalc utility windows during this migration. The following Settings-specific members will be deleted:

- `settingsFrameName`
- `settingsWindow`
- `showSettings()`

The shared window creation helper remains for the two surviving windows until their dedicated scene migrations.

## Settings Information Architecture

The existing General and Privacy tabs remain because they represent preferences and trust recovery rather than primary application work.

### General

- Current Accessibility state
- State-specific recovery action
- Authoritative Check Again action
- Open Workspace action
- Explicit list of permissions prismBar never requests

### Privacy

- Local menu-bar observation explanation
- Data-boundary summary
- No screen capture or OCR
- No analytics or telemetry
- No network requests
- Sandboxed tool permissions
- Memory-only observed labels

The content uses standard `TabView`, `Form`, `Section`, `LabeledContent`, `Label`, and `Button` controls. Native controls and window materials provide the macOS 27 appearance. Custom glass remains limited to deliberate action emphasis and must respect Reduce Transparency, Increase Contrast, and Reduce Motion.

## Lifecycle and State

Opening Settings from Command-comma or Prism Deck must:

1. Present exactly one Settings window.
2. Bring an existing Settings window forward rather than duplicate it.
3. Leave the workspace closed when invoked from Prism Deck with the workspace closed.
4. Preserve the status item and permit Prism Deck to reopen after Settings closes.
5. Read live `AppModel` permission state through the shared environment.
6. Avoid changing the activation policy directly in Settings-specific code.

Closing Settings must not terminate prismBar or remove its menu-bar controls.

## Failure and Recovery Behavior

Settings presentation has no custom fallback window. A missing native Settings window is reported by UI acceptance as a product failure.

Permission recovery remains state-specific:

- Stable install missing: direct the user to the installed application location.
- Signing identity mismatch: require the current signed application.
- Not requested: request Accessibility through the public system prompt.
- Denied: open the public system Settings destination and offer Check Again.
- Granted: show Ready and keep Check Again available.

Permission truth is always refreshed from macOS. prismBar must not cache a successful state as authoritative.

## Accessibility

- The Prism Deck Settings control has the visible or accessible name `Settings`.
- Icon-only presentation includes help text.
- General and Privacy tabs use native tab semantics.
- Permission state is expressed in text and symbol, never color alone.
- Keyboard navigation reaches every action in a predictable order.
- Command-comma opens Settings through the standard macOS command.

## Security and Privacy

- No new entitlement, network access, environment variable, secret, telemetry, screen capture, or persistent observed menu label is introduced.
- Settings state remains local and derives from `AppModel` and public system APIs.
- No private API, undocumented selector, or synthetic menu-command dispatch is permitted.
- Swift source additions retain the MPL-2.0 notice.
- Public-safety and Git-history secret scans remain release gates.

## Test Strategy

Implementation follows red, green, refactor.

### Source contract tests

Add a focused source audit that fails while any of these remain:

- `AppWindowController.shared.showSettings()`
- a retained `settingsWindow`
- a Settings-specific frame autosave name
- `CommandGroup(replacing: .appSettings)`
- an injected `openSettings` closure in `PrismDeckView`

The audit must also require one declared SwiftUI `Settings` scene and one native `SettingsLink` in Prism Deck.

### UI lifecycle tests

Add or strengthen UI tests to prove:

1. Command-comma opens a Settings window.
2. Repeating Command-comma does not create a duplicate window.
3. Prism Deck opens Settings while the workspace remains closed.
4. Closing Settings leaves the status item operational.
5. The Settings content is at least 640 points wide and 500 points high.
6. General and Privacy tabs both exist and expose their expected content.
7. Visual-audit evidence captures the native Settings surface.

### Regression gates

- `swiftlint lint --strict`
- Debug and Release Swift tests
- Hosted application-state tests
- Complete UI test suite in an isolated desktop session
- AddressSanitizer and ThreadSanitizer
- Xcode static analysis
- Licensing, SBOM, public-safety, and Git-history secret audits
- Unsigned release-bundle audit

## Migration Sequence

1. Add the source and UI tests and observe the expected failures.
2. Remove Settings ownership from `AppWindowController`.
3. Restore the standard application Settings command.
4. Replace Prism Deck's callback with `SettingsLink`.
5. Remove the callback wiring from the status controller.
6. Adopt adaptive Settings content sizing.
7. Run focused lifecycle and visual tests.
8. Run the full clean-revision verification pipeline and commit the implementation.

Each step must leave the plugin security boundary and menu-bar movement engine unchanged.

## Acceptance Criteria

The migration is complete only when:

- One SwiftUI `Settings` scene is the sole Settings owner.
- No Settings-specific `NSWindow` construction or retention remains.
- Command-comma and Prism Deck both open the same native Settings window.
- Duplicate Settings windows cannot be produced.
- The workspace remains closed when Settings is opened from Prism Deck.
- Settings closes and reopens without disrupting the status item.
- The window meets the minimum usable content size and passes visual review on macOS 27.
- All security, privacy, licensing, sanitizer, static-analysis, UI, and release-bundle gates pass.

## Authoritative Platform References

- [Apple Human Interface Guidelines: Settings](https://developer.apple.com/design/human-interface-guidelines/settings)
- [SwiftUI Settings](https://developer.apple.com/documentation/swiftui/settings)
- [SwiftUI SettingsLink](https://developer.apple.com/documentation/swiftui/settingslink)
- Local macOS 27 SwiftUI SDK interface for `SettingsLink` and `OpenSettingsAction`
