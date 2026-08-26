# Prism Deck and Tool Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace prismBar's legacy product shell with a native macOS 27 Prism Deck command center, a focused Tools workspace, and a single-instance prismCalc utility window.

**Architecture:** SwiftUI owns the workspace, Settings, primary menu-bar extra, and prismCalc utility scenes. AppKit remains only for the two status items that implement menu-bar section placement and collapse behavior. Existing engine, Accessibility, XPC, signing, and descriptor-validation boundaries remain unchanged.

**Tech Stack:** Swift 6.4, SwiftUI, Observation, AppKit status items, macOS 27 SDK, Swift Testing, XCTest UI automation, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-08-26-prism-deck-plugin-experience-design.md`

## Global Constraints

- Human-facing product name is exactly `prismBar`.
- Bundle identifier remains `com.laclairtech.prismbar`.
- Deployment target is macOS 27, Apple silicon only.
- Build with `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`.
- Use public Apple APIs and standard SwiftUI controls.
- Treat repository-root `DESIGN.md` as the authoritative UI contract.
- Preserve MPL-2.0 headers on every Swift source file.
- Do not inspect or copy from `~/dev/prismBar-gpl-reference`.
- Do not add dependencies, entitlements, URL schemes, network calls, dynamic loading, telemetry, or downloaded plugins.
- Do not log menu labels, process identity, Accessibility values, coordinates, paths, environment values, plugin payloads, or private identifiers.
- User-facing navigation calls extensions **Tools**. The word **plugin** is reserved for trust and architecture explanations.
- Every feature and defect repair begins with a failing test.
- Use small signed conventional commits and do not push without the owner publication gate.

## File Structure

| File | Responsibility |
|---|---|
| `Sources/prismBarCore/PresentationCatalog.swift` | Stable scene, workspace, Prism Deck, and tool identifiers without SwiftUI dependencies |
| `Tests/prismBarCoreTests/PresentationCatalogTests.swift` | Exact naming, ordering, and identifier regression tests |
| `App/prismBarApp.swift` | SwiftUI scene ownership for workspace, menu-bar extra, Settings, and prismCalc utility |
| `App/AppLifecycle.swift` | Activation-only permission refresh through an app delegate, with manual window ownership removed |
| `App/MenuBarSectionStatusController.swift` | AppKit-only section divider and collapsible spacer ownership |
| `App/Design/PrismStatusIcon.swift` | Purpose-drawn monochrome template image for the SwiftUI menu-bar label |
| `App/Features/PrismDeck/PrismDeckView.swift` | Compact command-center shell and mode selection |
| `App/Features/PrismDeck/PrismDeckBarView.swift` | Permission, section, direct movement, and recovery controls |
| `App/Features/PrismDeck/PrismDeckToolsView.swift` | Tool state and launch controls without embedded tool content |
| `App/Features/Tools/ToolsView.swift` | Tool catalog, enablement, health, capability explanation, and launch action |
| `App/Features/Tools/ToolPresentation.swift` | Closed mapping from registry and runtime state to user-facing tool copy |
| `App/Features/Tools/PrismCalcUtilityView.swift` | Dedicated prismCalc utility window and recovery states |
| `App/Features/Plugins/PluginPanelView.swift` | Host-rendered validated plugin elements only, renamed on disk after dependents move |
| `App/Features/Overview/MainWindowView.swift` | Workspace navigation using shared typed destination state |
| `App/Features/Settings/SettingsRootView.swift` | Infrequent preferences and permission recovery only |
| `App/Features/Shortcuts/PrismBarCommands.swift` | Scene-based workspace and tool launch commands |
| `Tests/prismBarUITests/LaunchTests.swift` | Shipping workspace, Prism Deck, Tools, utility, failure recovery, and appearance flows |
| `AGENTS.md` | Durable product-shell and tool-framework usage notes |
| `docs/ARCHITECTURE.md` | Scene ownership and tool presentation flow |
| `docs/PRODUCT-BRIEF.md` | User-facing Prism Deck and Tools product model |
| `docs/SECURITY-MODEL.md` | Confirmed unchanged plugin trust boundary and new launch surface |

---

### Task 1: Add the Typed Presentation Contract

**Files:**
- Create: `Sources/prismBarCore/PresentationCatalog.swift`
- Create: `Tests/prismBarCoreTests/PresentationCatalogTests.swift`

**Interfaces:**
- Produces: `PrismSceneID`, `WorkspaceDestination`, `PrismDeckMode`, and `PrismToolID`.
- Consumes: no UI framework or runtime state.

- [ ] **Step 1: Write the failing presentation catalog tests**

Create `Tests/prismBarCoreTests/PresentationCatalogTests.swift`:

```swift
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
@testable import prismBarCore

@Suite("Presentation catalog")
struct PresentationCatalogTests {
    @Test("uses stable unique scene identifiers")
    func sceneIdentifiers() {
        let identifiers = [
            PrismSceneID.workspace,
            PrismSceneID.prismCalc,
        ]
        #expect(Set(identifiers).count == identifiers.count)
        #expect(PrismSceneID.workspace == "prismbar.workspace")
        #expect(PrismSceneID.prismCalc == "prismbar.tool.prismcalc")
    }

    @Test("presents the approved workspace order and copy")
    func workspaceDestinations() {
        #expect(WorkspaceDestination.primary == [.home, .menuBar, .tools, .automation])
        #expect(WorkspaceDestination.information == [.privacy, .about])
        #expect(WorkspaceDestination.tools.title == "Tools")
        #expect(WorkspaceDestination.automation.title == "Automation")
        #expect(WorkspaceDestination.allCases.map(\.id).allSatisfy { !$0.isEmpty })
    }

    @Test("limits Prism Deck to Bar and Tools")
    func prismDeckModes() {
        #expect(PrismDeckMode.allCases == [.bar, .tools])
        #expect(PrismDeckMode.bar.title == "Bar")
        #expect(PrismDeckMode.tools.title == "Tools")
    }

    @Test("registers prismCalc as the first closed tool identifier")
    func toolIdentifiers() {
        #expect(PrismToolID.allCases == [.prismCalc])
        #expect(PrismToolID.prismCalc.displayName == "prismCalc")
    }
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  swift test --filter PresentationCatalogTests
```

Expected: compilation fails because the presentation types do not exist.

- [ ] **Step 3: Implement the framework-independent catalog**

Create `Sources/prismBarCore/PresentationCatalog.swift` with `public`, `Sendable`, `Hashable`, `CaseIterable`, and `Identifiable` types. Use these exact cases and identifiers:

```swift
public enum PrismSceneID {
    public static let workspace = "prismbar.workspace"
    public static let prismCalc = "prismbar.tool.prismcalc"
}

public enum WorkspaceDestination: String, CaseIterable, Identifiable, Sendable {
    case home
    case menuBar
    case tools
    case automation
    case privacy
    case about

    public var id: String { rawValue }
    public static let primary: [Self] = [.home, .menuBar, .tools, .automation]
    public static let information: [Self] = [.privacy, .about]

    public var title: String {
        switch self {
        case .home: "Home"
        case .menuBar: "Menu Bar"
        case .tools: "Tools"
        case .automation: "Automation"
        case .privacy: "Privacy"
        case .about: "About"
        }
    }

    public var symbol: String {
        switch self {
        case .home: "sparkles"
        case .menuBar: "menubar.rectangle"
        case .tools: "wrench.and.screwdriver"
        case .automation: "bolt.badge.clock"
        case .privacy: "hand.raised"
        case .about: "info.circle"
        }
    }
}

public enum PrismDeckMode: String, CaseIterable, Identifiable, Sendable {
    case bar
    case tools
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum PrismToolID: String, CaseIterable, Identifiable, Sendable {
    case prismCalc = "com.laclairtech.prismbar.plugin.prismcalc"
    public var id: String { rawValue }
    public var displayName: String { "prismCalc" }
}
```

- [ ] **Step 4: Run focused and full core tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  swift test --filter PresentationCatalogTests
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
```

Expected: all tests pass.

- [ ] **Step 5: Commit the contract**

```bash
git add Sources/prismBarCore/PresentationCatalog.swift \
  Tests/prismBarCoreTests/PresentationCatalogTests.swift \
  docs/superpowers/plans/2026-08-26-prism-deck-and-tool-experience.md
git commit -S -m "feat: add typed presentation catalog"
```

---

### Task 2: Move Window and Primary Menu-Bar Ownership to SwiftUI

**Files:**
- Modify: `App/prismBarApp.swift`
- Modify: `App/AppLifecycle.swift`
- Modify: `App/MenuBarSectionStatusController.swift`
- Create: `App/Design/PrismStatusIcon.swift`
- Modify: `App/AppModel+MenuBarActions.swift`
- Modify: `App/Features/Shortcuts/PrismBarCommands.swift`
- Modify: `Tests/prismBarUITests/LaunchTests.swift`

**Interfaces:**
- Consumes: `PrismSceneID`, `WorkspaceDestination`, `PrismDeckView`, and `PrismCalcUtilityView`.
- Produces: one workspace scene, one primary menu-bar extra, one Settings scene, one prismCalc utility scene, and AppKit-only section dividers.

- [ ] **Step 1: Replace legacy-shell UI assertions with scene assertions**

Update the existing UI tests before implementation:

```swift
func testStatusItemOpensPrismDeckWithWorkspaceClosed() {
    let application = XCUIApplication()
    application.launch()
    let workspace = application.windows["prismBar"]
    XCTAssertTrue(workspace.waitForExistence(timeout: 5))
    application.typeKey("w", modifierFlags: .command)
    XCTAssertTrue(workspace.waitForNonExistence(timeout: 3))

    let statusItem = application.descendants(matching: .statusItem)
        .matching(identifier: "prismBar")
        .firstMatch
    XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
    statusItem.click()
    XCTAssertTrue(application.segmentedControls["prismDeck.mode"].waitForExistence(timeout: 3))
    XCTAssertTrue(application.buttons["Open Workspace"].exists)
}

func testKeyboardCommandReopensTheWorkspaceScene() {
    let application = XCUIApplication()
    application.launch()
    let workspace = application.windows["prismBar"]
    XCTAssertTrue(workspace.waitForExistence(timeout: 5))
    application.typeKey("w", modifierFlags: .command)
    XCTAssertTrue(workspace.waitForNonExistence(timeout: 3))
    application.typeKey("o", modifierFlags: [.command, .shift])
    XCTAssertTrue(workspace.waitForExistence(timeout: 3))
}
```

- [ ] **Step 2: Run the focused UI tests and verify they fail**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./scripts/test-ui.sh -only-testing:prismBarUITests/LaunchTests/testStatusItemOpensPrismDeckWithWorkspaceClosed \
  -only-testing:prismBarUITests/LaunchTests/testKeyboardCommandReopensTheWorkspaceScene
```

Expected: the Prism Deck mode control is absent and the old controller still owns the primary item.

- [ ] **Step 3: Extract the template prism icon**

Move the existing purpose-drawn `NSBezierPath` image creation into `PrismStatusIcon.image`. Keep `image.isTemplate = true` and the exact accessibility description `prismBar`. Do not alter the geometry in this task.

- [ ] **Step 4: Reduce the AppKit status controller to dividers**

Remove `primaryItem`, `commandPopover`, expanded-interface delegation, popover delegation, primary icon creation, and `dismissCommandCenter()` from `MenuBarSectionStatusController`. Preserve:

```swift
private var anchorItem: NSStatusItem?
private var spacerItem: NSStatusItem?
private(set) var isCollapsed = false
func installIfNeeded()
func setCollapsed(_ collapsed: Bool, dividerFrame: MenuBarItemFrame?) -> Bool
```

The existing autosave names and menu-section geometry must remain unchanged.

- [ ] **Step 5: Replace manual window ownership with activation observation**

Replace `AppWindowController` with `AppLifecycleDelegate: NSObject, NSApplicationDelegate` and keep only:

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    AppModel.shared.refreshAccessibility()
}

func applicationDidBecomeActive(_ notification: Notification) {
    AppModel.shared.refreshAccessibility()
}
```

Do not create an `NSWindow`, mutate activation policy, or host SwiftUI manually.

- [ ] **Step 6: Declare the SwiftUI scenes**

Change `prismBarApp` to own these scenes:

```swift
@NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var lifecycleDelegate

WindowGroup("prismBar", id: PrismSceneID.workspace) {
    MainWindowView()
        .environment(AppModel.shared)
}
.defaultSize(width: 920, height: 640)
.windowResizability(.contentMinSize)

MenuBarExtra {
    PrismDeckView()
        .environment(AppModel.shared)
} label: {
    Image(nsImage: PrismStatusIcon.image)
        .accessibilityLabel("prismBar")
}
.menuBarExtraStyle(.window)

UtilityWindow("prismCalc", id: PrismSceneID.prismCalc) {
    PrismCalcUtilityView()
        .environment(AppModel.shared)
}
.defaultSize(width: 320, height: 460)
.windowResizability(.contentSize)

Settings {
    SettingsRootView()
        .environment(AppModel.shared)
        .frame(width: 560, height: 420)
}
```

Initialize only `MenuBarSectionStatusController.shared.installIfNeeded()` in the app initializer.

- [ ] **Step 7: Route commands with `openWindow`**

In `PrismBarCommands`, add `@Environment(\.openWindow) private var openWindow` and replace `AppWindowController.shared.show()` with:

```swift
openWindow(id: PrismSceneID.workspace)
```

Preserve the existing keyboard shortcuts and menu-bar engine commands.

- [ ] **Step 8: Generate and compile the project**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodegen generate
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project prismBar.xcodeproj -scheme prismBar \
  -configuration Debug -destination 'platform=macOS,arch=arm64' build
```

Expected: `BUILD SUCCEEDED` with no warnings.

- [ ] **Step 9: Run the focused UI tests and commit**

Run the two tests from Step 2, then:

```bash
git add App/prismBarApp.swift App/AppLifecycle.swift \
  App/MenuBarSectionStatusController.swift App/Design/PrismStatusIcon.swift \
  App/AppModel+MenuBarActions.swift App/Features/Shortcuts/PrismBarCommands.swift \
  Tests/prismBarUITests/LaunchTests.swift prismBar.xcodeproj
git commit -S -m "refactor: adopt native SwiftUI app scenes"
```

---

### Task 3: Build Prism Deck Bar and Tools Modes

**Files:**
- Create: `App/Features/PrismDeck/PrismDeckView.swift`
- Create: `App/Features/PrismDeck/PrismDeckBarView.swift`
- Create: `App/Features/PrismDeck/PrismDeckToolsView.swift`
- Modify: `Tests/prismBarUITests/LaunchTests.swift`

**Interfaces:**
- Consumes: `AppModel`, `PrismDeckMode`, `PrismSceneID`, `MenuBarSnapshot`, `MenuBarActionResult`, and the bundled tool registry.
- Produces: accessibility identifiers `prismDeck.mode`, `prismDeck.bar`, `prismDeck.tools`, `prismDeck.accessibility`, and `tool.prismCalc.open`.

- [ ] **Step 1: Add failing Prism Deck navigation and failure-copy tests**

Add UI coverage that opens the status item and asserts:

```swift
let mode = application.segmentedControls["prismDeck.mode"]
XCTAssertTrue(mode.waitForExistence(timeout: 3))
XCTAssertTrue(application.descendants(matching: .any)["prismDeck.bar"].exists)
mode.buttons["Tools"].click()
XCTAssertTrue(application.descendants(matching: .any)["prismDeck.tools"].exists)
XCTAssertTrue(application.buttons["Open prismCalc"].exists)
XCTAssertFalse(application.staticTexts["Calculator result"].exists)
```

Update the action-result assertion so a failure requires the full accessible message and recovery action, not a symbol-only `!` state.

- [ ] **Step 2: Run the new tests and verify they fail**

Run the specific new UI test names through `./scripts/test-ui.sh`. Expected: Prism Deck mode and tool launcher identifiers are missing.

- [ ] **Step 3: Implement the Prism Deck shell**

`PrismDeckView` owns only mode selection and routing:

```swift
struct PrismDeckView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(AppModel.self) private var model
    @State private var mode: PrismDeckMode = .bar

    var body: some View {
        VStack(spacing: 0) {
            PrismDeckHeader()
            Picker("Prism Deck mode", selection: $mode) {
                ForEach(PrismDeckMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("prismDeck.mode")

            Divider()
            Group {
                switch mode {
                case .bar: PrismDeckBarView()
                case .tools: PrismDeckToolsView()
                }
            }
            Divider()
            HStack {
                Button("Open Workspace") { openWindow(id: PrismSceneID.workspace) }
                Spacer()
                Button("Settings") { openSettings() }
            }
        }
        .frame(width: 340)
        .task { model.loadPluginIfNeeded() }
    }
}
```

Use the standard segmented picker and semantic surfaces. Add a two-point refracted identity edge from `DESIGN.md` only once beneath the header. Do not add custom blur or a full-window background.

- [ ] **Step 4: Implement Bar mode**

Bar mode must include:

- the live Accessibility label and one recovery action
- verified operation progress or specific result message
- hidden-section Fold or Reveal control
- a scrollable list of current movable items
- per-item Show or Hide action
- direct `Move to Position` menu using all validated destinations
- Move Left and Move Right as recovery controls, not the primary movement model
- Show Every Movable Item behind the existing confirmation

Reuse the existing movement calls and result presenter logic from `StatusMenuView`. Keep the entire surface under 520 points tall and mark the root `prismDeck.bar`.

- [ ] **Step 5: Implement Tools mode as launchers only**

Tools mode maps current plugin state to one of these exact states:

| Runtime state | User label | Action |
|---|---|---|
| idle or loading | Verifying | none |
| ready | Ready | Open prismCalc |
| unavailable | Needs attention | Retry |
| paused | Paused for safety | Retry |
| disabled | Off | Open Tools |

The Open action calls `openWindow(id: PrismSceneID.prismCalc)`. The mode must not render `PluginPanelView`, a result value, or keypad controls. Mark the root `prismDeck.tools`.

- [ ] **Step 6: Remove the old status menu implementation**

Delete `App/Features/Overview/StatusMenuView.swift` after all Bar logic, recovery behavior, reset confirmation, Settings, workspace, and Quit access has a tested Prism Deck replacement. Add Quit to the standard application menu or Prism Deck footer only once.

- [ ] **Step 7: Verify Prism Deck behavior and commit**

Run the focused Prism Deck tests, the existing direct-movement engine tests, and a Debug build. Then:

```bash
git add App/Features/PrismDeck Tests/prismBarUITests/LaunchTests.swift \
  App/Features/Overview/StatusMenuView.swift prismBar.xcodeproj
git commit -S -m "feat: add Prism Deck command center"
```

---

### Task 4: Replace the Embedded Plugin Demo with a Tool Manager and Utility

**Files:**
- Create: `App/Features/Tools/ToolPresentation.swift`
- Create: `App/Features/Tools/ToolsView.swift`
- Create: `App/Features/Tools/PrismCalcUtilityView.swift`
- Move: `App/Features/Plugins/PluginPanelView.swift` to `App/Features/Tools/PluginPanelView.swift`
- Modify: `App/Features/Overview/MainWindowView.swift`
- Modify: `App/AppModel.swift`
- Modify: `Tests/prismBarUITests/LaunchTests.swift`

**Interfaces:**
- Consumes: `BundledPluginRegistration`, `PluginCapability`, `PluginLoadingState`, `PluginPanelUpdate`, and `PrismSceneID.prismCalc`.
- Produces: management-only Tools workspace and dedicated host-rendered prismCalc utility.

- [ ] **Step 1: Rewrite plugin UI tests around the real workflow**

Replace `testBundledPrismCalcPluginRunsAcrossTheSignedXPCBoundary` with two tests:

```swift
func testToolsWorkspaceExplainsAndLaunchesPrismCalcWithoutEmbeddingIt() {
    let application = XCUIApplication()
    application.launch()
    sidebarCell(named: "Tools", in: application).click()
    XCTAssertTrue(application.staticTexts["Tools add focused capabilities to prismBar."].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts["prismCalc"].exists)
    XCTAssertTrue(application.buttons["Open prismCalc"].exists)
    XCTAssertFalse(application.buttons["Seven"].exists)
}

func testPrismCalcRunsInOneUtilityWindowAcrossTheSignedBoundary() {
    let application = XCUIApplication()
    application.launch()
    sidebarCell(named: "Tools", in: application).click()
    application.buttons["Open prismCalc"].click()
    let utility = application.windows["prismCalc"]
    XCTAssertTrue(utility.waitForExistence(timeout: 7))
    application.buttons["Seven"].click()
    application.buttons["Add"].click()
    application.buttons["Five"].click()
    application.buttons["Equals"].click()
    XCTAssertEqual(application.staticTexts["Calculator result"].value as? String, "12")
    application.activate()
    sidebarCell(named: "Tools", in: application).click()
    application.buttons["Open prismCalc"].click()
    XCTAssertEqual(application.windows.matching(identifier: "prismCalc").count, 1)
}
```

- [ ] **Step 2: Run both tests and verify they fail**

Expected: the workspace is still named Plugins and the calculator remains embedded there.

- [ ] **Step 3: Create the closed presentation mapping**

`ToolPresentation` maps runtime state to fixed, non-sensitive UI values:

```swift
struct ToolPresentation: Equatable {
    let title: String
    let purpose: String
    let healthTitle: String
    let healthSymbol: String
    let recoveryTitle: String?
    let canOpen: Bool

    static func prismCalc(state: PluginLoadingState, enabled: Bool) -> Self {
        if !enabled {
            return .init(
                title: "prismCalc",
                purpose: "A fast basic calculator that stays available beside your work.",
                healthTitle: "Off",
                healthSymbol: "power",
                recoveryTitle: nil,
                canOpen: false
            )
        }
        switch state {
        case .idle, .loading:
            return .init(title: "prismCalc", purpose: purpose, healthTitle: "Verifying", healthSymbol: "lock.shield", recoveryTitle: nil, canOpen: false)
        case .ready:
            return .init(title: "prismCalc", purpose: purpose, healthTitle: "Ready", healthSymbol: "checkmark.shield", recoveryTitle: nil, canOpen: true)
        case .unavailable:
            return .init(title: "prismCalc", purpose: purpose, healthTitle: "Needs attention", healthSymbol: "exclamationmark.triangle", recoveryTitle: "Retry", canOpen: false)
        case .paused:
            return .init(title: "prismCalc", purpose: purpose, healthTitle: "Paused for safety", healthSymbol: "pause.circle", recoveryTitle: "Retry", canOpen: false)
        case .disabled:
            return .init(title: "prismCalc", purpose: purpose, healthTitle: "Off", healthSymbol: "power", recoveryTitle: nil, canOpen: false)
        }
    }
}
```

Define `purpose` once as a private static constant. Do not include raw service errors, paths, identifiers, or payloads.

- [ ] **Step 4: Build the Tools workspace**

The page header is `Tools`, eyebrow `Capabilities`, symbol `wrench.and.screwdriver`, and accessibility identifier `tools.header.wrench.and.screwdriver`. Present the approved explanation verbatim, then one prismCalc management row containing:

- exact name and version
- one-line purpose
- enable toggle
- fixed health label
- Open prismCalc when ready
- Retry when unavailable or paused
- capability badges with plain-language disclosure
- a trust disclosure that says signed, bundled, isolated, host-rendered, and no Accessibility, files, network, or menu-bar data

Do not render `PluginPanelView` in `ToolsView`.

- [ ] **Step 5: Build the prismCalc utility**

`PrismCalcUtilityView` loads the plugin when the window appears and renders:

```swift
switch model.pluginState {
case .idle, .loading:
    ProgressView("Verifying prismCalc")
case .ready:
    if let update = model.pluginPanel {
        PluginPanelView(update: update, compact: false)
    }
case .unavailable, .paused:
    ContentUnavailableView(
        "prismCalc needs attention",
        systemImage: "exclamationmark.triangle",
        description: Text(model.pluginMessage ?? "The isolated tool is unavailable.")
    )
    Button("Retry") { model.retryPlugin() }
case .disabled:
    ContentUnavailableView(
        "prismCalc is off",
        systemImage: "power",
        description: Text("Enable prismCalc from Tools in the prismBar workspace.")
    )
}
```

Use a semantic content surface, system controls, and the result/keypad accessibility identifiers already validated by tests.

- [ ] **Step 6: Close the utility when the tool is disabled**

Add `@Environment(\.dismissWindow) private var dismissWindow` to the utility and observe `model.isPluginEnabled`. When it becomes false, call:

```swift
dismissWindow(id: PrismSceneID.prismCalc)
```

Do not stop or unload prismCalc merely because its window closes. Existing `setPluginEnabled(false)` remains the authority for stopping the XPC client.

- [ ] **Step 7: Adapt crash and hang recovery tests**

Change `openReadyPlugin(in:)` to open Tools, click Open prismCalc, wait for the utility keypad, and then resolve the isolated service PID. Keep the current SIGSTOP, timeout, SIGKILL, retry, and host-survival assertions unchanged.

- [ ] **Step 8: Run tool, plugin, and UI verification**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter prismPluginKitTests
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter prismCalcPluginTests
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-ui.sh
```

Expected: all existing descriptor, signing-policy, calculator, crash, and hang tests pass in the new utility workflow.

- [ ] **Step 9: Commit the tool experience**

```bash
git add App/Features/Tools App/Features/Plugins App/Features/Overview/MainWindowView.swift \
  App/AppModel.swift Tests/prismBarUITests/LaunchTests.swift prismBar.xcodeproj
git commit -S -m "feat: launch bundled tools as native utilities"
```

---

### Task 5: Clean Settings and Apply the macOS 27 Visual Contract

**Files:**
- Modify: `App/Features/Settings/SettingsRootView.swift`
- Modify: `App/Design/PrismVisuals.swift`
- Modify: `App/Features/Overview/MainWindowView.swift`
- Modify: `App/Features/Overview/OverviewView.swift`
- Modify: `App/Features/MenuBar/MenuBarView.swift`
- Modify: `App/Features/Tools/ToolsView.swift`
- Modify: `App/Features/Privacy/PrivacyView.swift`
- Modify: `App/Features/About/AboutView.swift`
- Modify: `Tests/prismBarUITests/LaunchTests.swift`

**Interfaces:**
- Consumes: `DESIGN.md`, standard SwiftUI materials, system accessibility environment values, and the typed workspace catalog.
- Produces: native adaptive workspace and Settings surfaces with no fake glass or embedded operational tools.

- [ ] **Step 1: Add failing navigation, Settings, and appearance assertions**

Update destination arrays to `Home`, `Menu Bar`, `Tools`, `Automation`, `Privacy`, and `About`. Add a Settings test that presses Command-Comma and asserts:

- Accessibility recovery is present
- privacy boundary copy is present
- no calculator result or keypad exists
- no tool catalog enable toggle exists

Preserve the existing dark, Increase Contrast, Reduce Transparency, and Reduce Motion launch variants, and add `-NSAccessibilityDifferentiateWithoutColor YES`.

- [ ] **Step 2: Run the focused tests and verify they fail**

Expected: old Overview, Plugins, and Shortcuts labels remain, and Settings still contains the obsolete Open Command Center action.

- [ ] **Step 3: Restrict Settings to configuration and recovery**

Remove `AppWindowController.shared.show()` and Open Command Center. Keep General and Privacy tabs, permission request, Check Again, stable-install recovery, and truthful privacy boundary. Use standard Settings scene spacing and controls. Add no preference unless it controls implemented behavior.

- [ ] **Step 4: Apply the app-wide design hierarchy**

Use `NavigationSplitView`, standard toolbar items, semantic system backgrounds, system text styles, and restrained content grouping. Remove decorative full-window gradients, custom blur fields, repeated material cards, hardcoded user-facing font sizes, and forced appearances. Preserve a single contextual SF Symbol for each page and the existing prism product mark only where identity is useful.

Use the root `DESIGN.md` token names for any custom spacing, radius, or refracted edge. If a required token is absent, update `DESIGN.md` first and lint it before Swift changes.

- [ ] **Step 5: Make failures readable without color**

Audit every exclamation, warning color, and status symbol. Each must include a category label, affected action, and relevant recovery control. Retain semantic warning colors only as supplementary cues.

- [ ] **Step 6: Verify design contract and UI variants**

Run:

```bash
npx --yes @google/design.md lint DESIGN.md
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-ui.sh
```

Expected: design lint has zero errors and zero warnings; all UI variants pass.

- [ ] **Step 7: Capture shipping UI evidence**

Install a current signed build in `/Applications/prismBar.app`, capture Home, Menu Bar, Tools, Prism Deck Bar, Prism Deck Tools, prismCalc utility, Settings, Privacy, and About in light and dark appearance, and generate the required dark HTML UI audit under `build/`. Do not commit screenshots containing observed real menu labels or process identity.

- [ ] **Step 8: Commit the visual and Settings pass**

```bash
git add DESIGN.md App/Design App/Features Tests/prismBarUITests/LaunchTests.swift
git commit -S -m "feat: finish native macOS 27 product shell"
```

---

### Task 6: Document, Audit, and Prove the Shipping Workflow

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/PRODUCT-BRIEF.md`
- Modify: `docs/SECURITY-MODEL.md`
- Modify: `docs/IMPLEMENTATION-PLAN.md`
- Modify: `CHANGELOG.md` if present
- Create: `build/prism-deck-ui-audit.html`

**Interfaces:**
- Consumes: the completed source, UI tests, exact source revision, signing scripts, and physical macOS 27 behavior.
- Produces: durable documentation and direct production evidence.

- [ ] **Step 1: Update durable feature documentation**

Document:

- Prism Deck Bar and Tools modes
- workspace versus Settings responsibility
- prismCalc utility launch and single-instance behavior
- user-facing Tool terminology
- sealed first-party plugin architecture
- exact capability exclusions
- SwiftUI scene ownership and AppKit divider exception
- recovery behavior for disabled, unavailable, paused, and interrupted tools

Do not describe third-party installation, downloaded tools, telemetry, or unimplemented controls.

- [ ] **Step 2: Run source, license, and public-safety audits**

Run:

```bash
./scripts/audit-public-safety.sh
./scripts/audit-licensing.sh
./scripts/audit-release-bundle.sh --source-only
git grep -nE 'PrismBar|prismbar|thawBar|thawbar|ice cube|melting' -- \
  ':!LICENSE' ':!NOTICE' ':!CHANGELOG.md'
```

Expected: audit scripts pass and grep finds only explicitly allowed infrastructure identifiers or historical legal context.

- [ ] **Step 3: Run the complete automated gate**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/ci-verify.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-ui.sh
```

Expected: Swift debug, release, sanitizer, static analysis, Xcode build, plugin, public-safety, and UI suites pass.

- [ ] **Step 4: Build and install the exact Developer ID candidate**

Use the existing hardened archive pipeline at the final source revision. Audit reciprocal host and XPC signing requirements, bundle contents, source provenance, and absence of sensitive artifacts before installing the exact archive product at `/Applications/prismBar.app`. Preserve the prior signed app as a rollback bundle under `build/InstalledBackups/`.

- [ ] **Step 5: Complete physical macOS 27 acceptance**

Verify on the exact installed signed app:

1. Accessibility is granted to `/Applications/prismBar.app` and the app recognizes it.
2. Prism Deck opens from a normal click.
3. Fold, Reveal, Show, Hide, direct multi-position movement, refresh, and reset produce verified outcomes.
4. prismCalc opens from Prism Deck and Tools, remains a single utility window, computes `7 + 5 = 12`, and recovers after an isolated-service interruption.
5. Settings contains only configuration, permission recovery, and privacy information.
6. Keyboard traversal, focus restoration, Escape, Command-Comma, and Shift-Command-O work.
7. Light, dark, Reduce Transparency, Increase Contrast, Differentiate Without Color, and Reduce Motion remain usable.

- [ ] **Step 6: Generate the final assurance report**

Run the existing assurance generator against the exact installed revision, then ensure the HTML report links the Prism Deck UI audit and records pass, fail, or hold for every physical gate. A backend-only or test-only green state is not release proof.

- [ ] **Step 7: Commit documentation and evidence pointers**

Do not commit private screenshots, notarization credentials, local paths, menu labels, process identifiers, archives, DMGs, or build logs. Commit only public-safe documentation and deterministic report templates:

```bash
git add AGENTS.md docs CHANGELOG.md
git commit -S -m "docs: record Prism Deck production workflow"
```

- [ ] **Step 8: Preserve external owner gates**

Do not push, publish, notarize, or distribute automatically. Report the exact clean revision, test evidence, installed bundle hash, and remaining owner-only gate. Notarization may proceed only when the existing Keychain profile is available and the owner authorizes that external submission.

## Self-Review

- Spec coverage: every approved Prism Deck, workspace, Settings, tool, utility, trust, accessibility, visual, migration, and physical-acceptance requirement maps to Tasks 1 through 6.
- Security coverage: the plan changes presentation only and explicitly preserves bundled registry allowlisting, reciprocal signing, XPC sandboxing, descriptor validation, and denied capabilities.
- Completeness scan: every code step names its exact types, behavior, test, command, and expected result.
- Type consistency: `PrismSceneID`, `WorkspaceDestination`, `PrismDeckMode`, and `PrismToolID` are defined in Task 1 and consumed with the same names in every later task.
- Surface consistency: Prism Deck launches tools, Tools manages them, the utility runs them, and Settings does neither.
- Execution choice: the owner selected inline autonomous execution in this task, so use `superpowers:executing-plans` with a verification checkpoint after each signed commit.
