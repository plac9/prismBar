# Native Settings Scene Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the SwiftUI `Settings` scene the sole owner of prismBar Settings and prove every native entry point opens one adaptive, reusable Settings window.

**Architecture:** Keep the existing SwiftUI `Settings` scene and shared `AppModel`, remove every Settings-specific member from `AppWindowController`, restore the system application Settings command, and use `SettingsLink` inside Prism Deck. Preserve AppKit only for the status items, popover presentation boundary, workspace window, and prismCalc utility window.

**Tech Stack:** Swift 6, SwiftUI, AppKit, XCTest/XCUITest, Xcode 27 beta, XcodeGen, bash source-policy audit.

**Spec:** `docs/superpowers/specs/2026-08-27-native-settings-scene-design.md`

## Global Constraints

- Product copy is exactly `prismBar`; technical identifiers remain `com.laclairtech.prismbar`.
- Target macOS 27 only and arm64 only.
- Use only public SwiftUI and AppKit APIs.
- Do not create a Settings fallback `NSWindow`, invoke an undocumented selector, or synthesize the application Settings command.
- Preserve the AppKit status-item and popover boundary.
- Do not change menu-bar observation, movement, or plugin security behavior.
- Add no entitlement, network access, environment variable, telemetry, screen capture, or persistent observed menu label.
- Retain the MPL-2.0 notice on every Swift source file.
- Work in the canonical prismBar repository checkout as explicitly approved.

---

### Task 1: Add the native Settings architecture gate

**Files:**
- Modify: `scripts/test-ui.sh:9-31`

**Interfaces:**
- Consumes: the existing `scripts/test-ui.sh --source-audit` policy gate.
- Produces: a source-policy gate that rejects duplicate Settings ownership and requires the two public SwiftUI Settings entry points.

- [ ] **Step 1: Extend the source audit before changing production code**

Add checks that fail if application sources contain any of these legacy contracts:

```bash
if rg -n 'showSettings\(|settingsWindow|settingsFrameName|CommandGroup\(replacing: \.appSettings\)|openSettings:' App; then
  echo "Legacy Settings ownership or routing remains." >&2
  exit 1
fi
```

Require the declared scene and Prism Deck link:

```bash
if [ "$(rg -l '^[[:space:]]*Settings[[:space:]]*\{' App --glob '*.swift' | wc -l | tr -d ' ')" != '1' ]; then
  echo "Exactly one SwiftUI Settings scene is required." >&2
  exit 1
fi
if ! rg -q 'SettingsLink[[:space:]]*\{' App/Features/Overview/PrismDeckView.swift; then
  echo "Prism Deck must use SettingsLink." >&2
  exit 1
fi
```

- [ ] **Step 2: Run the source audit and verify RED**

Run:

```bash
scripts/test-ui.sh --source-audit
```

Expected: FAIL with `Legacy Settings ownership or routing remains.` and matches in `AppLifecycle.swift`, `PrismBarCommands.swift`, `MenuBarSectionStatusController.swift`, and `PrismDeckView.swift`.

- [ ] **Step 3: Leave the failing gate in place for Task 3**

Do not weaken the patterns to make the audit pass. The production architecture must change.

### Task 2: Add consumer-visible Settings lifecycle acceptance

**Files:**
- Modify: `Tests/prismBarUITests/LaunchTests.swift:196-234`
- Modify: `Tests/prismBarUITests/PrismDeckTests.swift:64-91`

**Interfaces:**
- Consumes: XCUITest access to the real application, application menu commands, status item, and Settings window.
- Produces: lifecycle coverage for singleton presentation, adaptive size, both tabs, workspace independence, close, and status-item recovery.

- [ ] **Step 1: Add a failing Command-comma singleton and content test**

Add this test to `LaunchTests`:

```swift
func testNativeSettingsCommandReusesOneAdaptiveWindow() {
    let application = XCUIApplication()
    application.launch()

    application.typeKey(",", modifierFlags: .command)
    let settingsWindows = application.windows.matching(
        NSPredicate(format: "title CONTAINS %@", "Settings")
    )
    let settings = settingsWindows.firstMatch
    XCTAssertTrue(settings.waitForExistence(timeout: 5), application.debugDescription)
    XCTAssertGreaterThanOrEqual(settings.frame.width, 640)
    XCTAssertGreaterThanOrEqual(settings.frame.height, 500)
    XCTAssertTrue(application.tabs["General"].exists)
    XCTAssertTrue(application.tabs["Privacy"].exists)

    application.typeKey(",", modifierFlags: .command)
    XCTAssertEqual(settingsWindows.count, 1)
}
```

The production change that makes this test pass is replacing the fixed 560 by 420 custom Settings window with the adaptive SwiftUI scene while retaining singleton native presentation.

- [ ] **Step 2: Strengthen the Prism Deck lifecycle test**

After Prism Deck opens Settings, assert the adaptive bounds and tabs. After closing Settings, reopen Prism Deck and open Settings again to prove both public entry points remain operational without reopening the workspace:

```swift
XCTAssertGreaterThanOrEqual(settingsWindow.frame.width, 640)
XCTAssertGreaterThanOrEqual(settingsWindow.frame.height, 500)
XCTAssertTrue(application.tabs["General"].exists)
XCTAssertTrue(application.tabs["Privacy"].exists)

application.typeKey("w", modifierFlags: .command)
XCTAssertTrue(settingsWindow.waitForNonExistence(timeout: 3))
statusItem.click()
XCTAssertTrue(application.buttons["Settings"].waitForExistence(timeout: 3))
application.buttons["Settings"].click()
XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))
XCTAssertFalse(workspace.exists)
```

- [ ] **Step 3: Run the focused tests and verify RED**

Run:

```bash
scripts/test-ui.sh 'prismBarUITests/LaunchTests/testNativeSettingsCommandReusesOneAdaptiveWindow'
scripts/test-ui.sh 'prismBarUITests/PrismDeckTests/testPrismDeckOpensSettingsWithoutWorkspace'
```

Expected: at least the size assertions fail because the current custom window is 560 by 420. If desktop focus interrupts XCUITest, isolate foreground windows and rerun without changing the test expectation.

### Task 3: Make SwiftUI the sole Settings owner

**Files:**
- Modify: `App/prismBarApp.swift:15-23`
- Modify: `App/AppLifecycle.swift:35-87`
- Modify: `App/Features/Shortcuts/PrismBarCommands.swift:11-44`
- Modify: `App/MenuBarSectionStatusController.swift:18-40`
- Modify: `App/Features/Overview/PrismDeckView.swift:10-29,235-255`

**Interfaces:**
- Consumes: `SettingsRootView`, `AppModel.shared`, SwiftUI `Settings`, and SwiftUI `SettingsLink`.
- Produces: one adaptive Settings scene with native Command-comma and Prism Deck presentation.

- [ ] **Step 1: Make the Settings scene adaptive**

Replace the fixed frame in `prismBarApp` with:

```swift
.frame(
    minWidth: 640,
    idealWidth: 680,
    minHeight: 500,
    idealHeight: 540
)
```

Keep `.environment(AppModel.shared)` on `SettingsRootView`.

- [ ] **Step 2: Remove Settings from `AppWindowController`**

Delete `settingsFrameName`, `settingsWindow`, and `showSettings()`. Leave workspace and prismCalc window construction unchanged.

- [ ] **Step 3: Restore the system Settings command**

Delete the complete `CommandGroup(replacing: .appSettings)` block from `PrismBarCommands`. Retain the prismBar domain command menu unchanged.

- [ ] **Step 4: Remove callback routing from the status controller**

Delete the `openSettings` argument passed to `PrismDeckView`. Do not add a replacement callback or selector.

- [ ] **Step 5: Replace Prism Deck injection with `SettingsLink`**

Remove the `openSettings` property and initializer parameter. Replace the footer Settings button with:

```swift
SettingsLink {
    Label("Settings", systemImage: "gearshape")
        .labelStyle(.iconOnly)
}
.help("Open prismBar Settings")
.accessibilityLabel("Settings")
```

Keep the shared `.buttonStyle(.glass)` on the footer.

- [ ] **Step 6: Run the source audit and verify GREEN**

Run:

```bash
scripts/test-ui.sh --source-audit
```

Expected: PASS with the existing glass-policy message and no Settings architecture failure.

- [ ] **Step 7: Regenerate the Xcode project and verify the focused tests GREEN**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodegen generate
scripts/test-ui.sh 'prismBarUITests/LaunchTests/testNativeSettingsCommandReusesOneAdaptiveWindow'
scripts/test-ui.sh 'prismBarUITests/PrismDeckTests/testPrismDeckOpensSettingsWithoutWorkspace'
```

Expected: both tests pass, one Settings window exists, both tabs exist, and the workspace stays closed through Prism Deck presentation.

- [ ] **Step 8: Run lint and hosted tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swiftlint lint --strict
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project prismBar.xcodeproj -scheme prismBar -destination 'platform=macOS,arch=arm64' test -only-testing:prismBarAppTests
```

Expected: zero lint violations and all hosted tests pass.

### Task 4: Verify, document, and commit the migration

**Files:**
- Modify: `docs/IMPLEMENTATION-PLAN.md:92-104`
- Modify: `CHANGELOG.md`
- Modify: `docs/superpowers/plans/2026-08-27-native-settings-scene.md`

**Interfaces:**
- Consumes: the final source revision, focused test evidence, and full verification scripts.
- Produces: revision-bound evidence and one atomic local commit.

- [ ] **Step 1: Run the complete UI suite**

Run:

```bash
scripts/test-ui.sh
```

Expected: all UI tests pass. Overlapping desktop windows are an environmental failure and must be isolated before rerun, not hidden by weaker assertions.

- [ ] **Step 2: Run the complete production verifier**

Run:

```bash
scripts/ci-verify.sh
```

Expected: licensing, SBOM, public safety, history scan, lint, Debug and Release tests, hosted tests, sanitizers, static analysis, builds, and unsigned bundle audit all pass with a revision-bound JSON evidence artifact.

- [ ] **Step 3: Record accurate documentation**

Add the native Settings migration to `CHANGELOG.md`. In `docs/IMPLEMENTATION-PLAN.md`, record only the source and automated UI gates actually proven. Do not mark physical VoiceOver, signed Accessibility, notarization, Gatekeeper, or release-publication gates complete.

- [ ] **Step 4: Self-review the diff**

Run:

```bash
git diff --check
git diff --stat
git status --short
```

Expected: no whitespace errors, no unrelated files, no build products, and only the planned sources, tests, scripts, and documentation are changed.

- [ ] **Step 5: Commit atomically**

Run:

```bash
git add App Tests scripts docs CHANGELOG.md prismBar.xcodeproj/project.pbxproj
git commit -m "Adopt native Settings scene ownership"
```

Expected: one local signed commit. Do not push, publish, merge, notarize, or modify the frozen GPL reference tree.
