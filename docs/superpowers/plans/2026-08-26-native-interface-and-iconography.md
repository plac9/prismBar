# Native Interface and Iconography Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild prismBar surfaces around native macOS 27 material hierarchy, clear verified actions, and final prism iconography.

**Architecture:** Let AppKit and SwiftUI provide Liquid Glass for navigation, status items, popovers, and interactive controls while static content uses semantic system surfaces. Replace raster page marks with contextual SF Symbols, make command results typed and accessible, and prove the application and menu bar assets contain only the prism identity.

**Tech Stack:** SwiftUI, AppKit, macOS 27 Liquid Glass APIs, SF Symbols, Icon Composer assets, XCTest UI tests

**Spec:** `docs/superpowers/specs/2026-08-26-production-remediation-design.md`

## Global Constraints

- The deployment target is exactly macOS 27.0.
- Human-facing product casing is exactly `prismBar`.
- Native navigation and controls own Liquid Glass behavior.
- Static content must not use simulated blur stacks or repeated glass cards.
- Reduce Transparency, Increase Contrast, Reduce Motion, keyboard navigation, and VoiceOver remain functional.
- The application and menu bar icons contain no thaw, ice cube, melting cube, snow, or droplet imagery.
- No user-visible failure may be represented only by color or an unexplained symbol.
- MPL 2.0 notices remain on every covered Swift source file.

---

### Task 1: Stable display presentation order

**Files:**
- Modify: `Sources/prismBarCore/MenuBarTopology.swift`
- Modify: `Tests/prismBarAccessibilityTests/TopologyAssemblerTests.swift`
- Modify: `Tests/prismBarCoreTests/ProductIdentityTests.swift` only if shared fixtures belong there

**Interfaces:**
- Consumes: item order established by `TopologyAssembler`
- Produces: `MenuBarSnapshot.surfaceIDs` in first-seen item order

- [ ] **Step 1: Write the failing cross-session order test**

```swift
@Test("keeps display presentation order stable across private sessions")
func stableDisplayOrderAcrossSessions() {
    let observations = [
        observation(token: "second", horizontalPosition: 100, surfaceToken: "display.1"),
        observation(token: "first", horizontalPosition: 100, surfaceToken: "display.0"),
    ]
    let first = TopologyAssembler().assemble(generation: 1, observations: observations)
    let second = TopologyAssembler().assemble(generation: 1, observations: observations)

    #expect(first.surfaceIDs.map { id in first.items.firstIndex { $0.surfaceID == id } } == [0, 1])
    #expect(second.surfaceIDs.map { id in second.items.firstIndex { $0.surfaceID == id } } == [0, 1])
    #expect(first.surfaceIDs != second.surfaceIDs)
}
```

- [ ] **Step 2: Run the test and confirm randomized sorting fails**

```bash
xcrun swift test --filter stableDisplayOrderAcrossSessions
```

Expected: the presentation-order assertion fails because `surfaceIDs` sorts random HMAC values.

- [ ] **Step 3: Preserve first-seen order**

Replace Set sorting with ordered uniqueness:

```swift
public var surfaceIDs: [MenuBarSurfaceID] {
    var seen: Set<MenuBarSurfaceID> = []
    let ordered = items.compactMap { item in
        guard item.surfaceID != .unknown, seen.insert(item.surfaceID).inserted else { return nil }
        return item.surfaceID
    }
    return ordered.isEmpty ? [.unknown] : ordered
}
```

- [ ] **Step 4: Run topology and package tests**

```bash
xcrun swift test --filter TopologyAssemblerTests
xcrun swift test
```

Expected: display labels remain stable while private IDs differ by assembler session.

- [ ] **Step 5: Commit stable presentation order**

```bash
git add Sources/prismBarCore/MenuBarTopology.swift Tests/prismBarAccessibilityTests/TopologyAssemblerTests.swift
git commit -S -m "ui: stabilize display presentation order"
```

### Task 2: Replace decorative atmosphere with semantic content surfaces

**Files:**
- Modify: `App/Design/PrismVisuals.swift`
- Modify: `App/Features/Overview/MainWindowView.swift`
- Modify: `App/Features/Settings/SettingsRootView.swift`
- Modify: all files returned by `rg -l 'PrismBackdrop|GlassCard' App`
- Modify: `Tests/prismBarUITests/LaunchTests.swift`

**Interfaces:**
- Consumes: SwiftUI semantic colors and accessibility environment values
- Produces: `ContentCard` and `PageHeader(symbol:eyebrow:title:message:)`

- [ ] **Step 1: Add failing source and UI assertions**

Add a source audit test or shell assertion to the UI test harness:

```bash
if rg -n 'PrismBackdrop|PrismLightField|\.glassEffect\(' App/Features App/Design/PrismVisuals.swift; then
  echo "decorative content glass remains" >&2
  exit 1
fi
```

Retain allowed native control styles such as `.buttonStyle(.glass)` outside this source check. Add launch assertions that every main destination renders its contextual header symbol.

- [ ] **Step 2: Run the UI source assertion and verify failure**

```bash
./scripts/test-ui.sh --source-audit
```

Expected: failure lists `PrismBackdrop`, `PrismLightField`, and static content `.glassEffect` usage.

- [ ] **Step 3: Implement semantic content primitives**

Delete `PrismBackdrop`, `PrismLightField`, `PrismRay`, raster `PrismMark`, and `GlassCard`. Add:

```swift
struct ContentCard<Content: View>: View {
    @Environment(\.colorSchemeContrast) private var contrast
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(20)
            .background(.background.secondary, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.separator, lineWidth: contrast == .increased ? 1.5 : 0.5)
            }
    }
}

struct PageHeader: View {
    let symbol: String
    let eyebrow: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
                .background(.background.secondary, in: .rect(cornerRadius: 10))
                .accessibilityHidden(true)
            headerText
        }
    }
}
```

Use `.containerBackground(.window, for: .window)` or the native window default once at the root. Remove duplicated backdrops from `MainWindowView` and `SettingsRootView`. Replace every static `GlassCard` call with `ContentCard`. Keep system glass button styles on genuinely interactive controls.

- [ ] **Step 4: Run the source audit and build**

```bash
./scripts/test-ui.sh --source-audit
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project prismBar.xcodeproj -scheme prismBar -configuration Debug build
```

Expected: no decorative-content-glass finding and a successful Debug build.

- [ ] **Step 5: Commit native surface hierarchy**

```bash
git add App Tests scripts/test-ui.sh
git commit -S -m "ui: restore native material hierarchy"
```

### Task 3: Give every page contextual identity

**Files:**
- Modify: `App/Features/Overview/OverviewView.swift`
- Modify: `App/Features/MenuBar/MenuBarView.swift`
- Modify: `App/Features/Plugins/PluginPanelView.swift`
- Modify: `App/Features/Shortcuts/ShortcutsView.swift`
- Modify: `App/Features/Privacy/PrivacyView.swift`
- Modify: `App/Features/About/AboutView.swift`
- Modify: `Tests/prismBarUITests/LaunchTests.swift`

**Interfaces:**
- Consumes: `PageHeader(symbol:eyebrow:title:message:)`
- Produces: one stable accessibility identifier per page header

- [ ] **Step 1: Write failing page-header UI checks**

Add launch coverage for these identifiers:

```swift
let headers = [
    "overview.header.sparkles",
    "menuBar.header.menubar.rectangle",
    "plugins.header.puzzlepiece.extension",
    "shortcuts.header.keyboard",
    "privacy.header.hand.raised",
    "about.header.info.circle",
]
for identifier in headers {
    XCTAssertTrue(application.descendants(matching: .any)[identifier].waitForExistence(timeout: 2))
}
```

- [ ] **Step 2: Run the UI test and verify missing identifiers**

```bash
./scripts/test-ui.sh --only prismBarUITests/LaunchTests/testPrimaryDestinations
```

Expected: failure because contextual header identifiers do not exist.

- [ ] **Step 3: Apply the approved symbol map**

Call `PageHeader` with the exact section symbols from the specification and attach `sectionName.header.symbolName` accessibility identifiers. Preserve native text styles and remove forced uppercase tracking from the header eyebrow.

```swift
PageHeader(
    symbol: "hand.raised",
    eyebrow: "Private by construction",
    title: "Your menu bar stays on your Mac.",
    message: privacySummary
)
.accessibilityIdentifier("privacy.header.hand.raised")
```

- [ ] **Step 4: Build and run focused UI tests**

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project prismBar.xcodeproj -scheme prismBar -configuration Debug build
./scripts/test-ui.sh --only prismBarUITests/LaunchTests/testPrimaryDestinations
```

Expected: all six destinations expose their contextual header.

- [ ] **Step 5: Commit contextual headers**

```bash
git add App/Features Tests/prismBarUITests/LaunchTests.swift
git commit -S -m "ui: add contextual native page headers"
```

### Task 4: Replace string-classified action feedback with typed results

**Files:**
- Create: `Sources/prismBarEngine/MenuBarActionResult.swift`
- Create: `Tests/prismBarEngineTests/MenuBarActionResultTests.swift`
- Modify: `App/AppModel.swift`
- Modify: `App/AppModel+MenuBarActions.swift`
- Modify: `App/Features/MenuBar/MenuBarView.swift`
- Modify: `App/Features/Overview/StatusMenuView.swift`
- Modify: `Tests/prismBarUITests/LaunchTests.swift`

**Interfaces:**
- Consumes: `MoveExecutionOutcome`
- Produces: `MenuBarActionResult` with `kind`, `message`, `symbol`, and `recovery`

- [ ] **Step 1: Write failing result-mapping tests**

Define tests against an internal pure mapper:

```swift
@Test("timeout has a named recovery action")
func timeoutRecovery() {
    let result = MenuBarActionResult.move(.timedOut, itemName: "Fixture")
    #expect(result.kind == .failure)
    #expect(result.symbol == "clock.badge.exclamationmark")
    #expect(result.recovery == .refresh)
    #expect(result.message.contains("Fixture"))
}
```

Cover success, partial, topology changed, item unavailable, permission revoked, menu bar unavailable, observation failure, input failure, and timeout.

- [ ] **Step 2: Run tests and verify the missing typed model failure**

```bash
xcrun swift test --filter MenuBarActionResult
```

Expected: compilation fails because action feedback is still an untyped message string.

- [ ] **Step 3: Implement typed feedback and recovery**

Use:

```swift
public enum MenuBarActionResultKind: Equatable, Sendable { case success, warning, failure }
public enum MenuBarRecoveryAction: Equatable, Sendable { case refresh, recheckPermission, none }

public struct MenuBarActionResult: Equatable, Sendable {
    public let kind: MenuBarActionResultKind
    public let message: String
    public let symbol: String
    public let recovery: MenuBarRecoveryAction

    public static func move(
        _ outcome: MoveExecutionOutcome,
        itemName: String
    ) -> MenuBarActionResult {
        switch outcome {
        case .success:
            return .init(kind: .success, message: "Move verified for \(itemName).", symbol: "checkmark.circle.fill", recovery: .none)
        case let .partial(observedIndex):
            return .init(kind: .warning, message: "\(itemName) moved to position \(observedIndex + 1), but not the requested position.", symbol: "arrow.trianglehead.2.clockwise.rotate.90", recovery: .refresh)
        case .topologyChanged:
            return .init(kind: .warning, message: "The menu bar changed before \(itemName) could move.", symbol: "arrow.clockwise", recovery: .refresh)
        case .itemUnavailable:
            return .init(kind: .failure, message: "\(itemName) is no longer available.", symbol: "questionmark.app", recovery: .refresh)
        case .permissionRevoked:
            return .init(kind: .failure, message: "Accessibility access is not currently available.", symbol: "hand.raised.slash", recovery: .recheckPermission)
        case .menuBarUnavailable:
            return .init(kind: .failure, message: "The current menu bar surface is unavailable.", symbol: "menubar.dock.rectangle.badge.questionmark", recovery: .refresh)
        case .observationFailed:
            return .init(kind: .failure, message: "prismBar could not verify the current menu bar.", symbol: "eye.slash", recovery: .refresh)
        case .inputFailed:
            return .init(kind: .failure, message: "macOS did not accept the move for \(itemName).", symbol: "cursorarrow.slash", recovery: .refresh)
        case .timedOut:
            return .init(kind: .failure, message: "The move for \(itemName) timed out safely.", symbol: "clock.badge.exclamationmark", recovery: .refresh)
        }
    }
}

enum MenuBarActionState: Equatable, Sendable {
    case idle
    case moving(itemID: MenuBarItemID?)
    case result(MenuBarActionResult)
}
```

Render symbol, label, and the one relevant recovery button in both the status popover and main window. Disable only conflicting controls while an item is moving. Remove message-prefix success detection and the generic result exclamation mark.

- [ ] **Step 4: Run mapper, build, and UI tests**

```bash
xcrun swift test --filter MenuBarActionResult
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project prismBar.xcodeproj -scheme prismBar -configuration Debug build
./scripts/test-ui.sh --only prismBarUITests/LaunchTests/testMenuActionStates
```

Expected: every typed outcome renders a labelled, accessible state and applicable recovery control.

- [ ] **Step 5: Commit typed action feedback**

```bash
git add Sources/prismBarEngine/MenuBarActionResult.swift Tests/prismBarEngineTests/MenuBarActionResultTests.swift App Tests/prismBarUITests
git commit -S -m "ui: explain verified menu action results"
```

### Task 5: Finalize application and status-item prism assets

**Files:**
- Modify: `Resources/prismBar.icon/icon.json`
- Modify: `Resources/prismBar.icon/Assets/Prism.png` only if visual inspection finds inherited imagery or poor native adaptation
- Modify: `App/MenuBarSectionStatusController.swift`
- Delete: `Resources/Assets.xcassets/PrismMark.imageset/Contents.json`
- Delete: `Resources/Assets.xcassets/PrismMark.imageset/PrismMark.png`
- Delete: `Resources/Assets.xcassets/PrismMark.imageset/PrismMark@2x.png`
- Modify: `scripts/audit-release-bundle.sh`
- Modify: `Tests/prismBarUITests/LaunchTests.swift`

**Interfaces:**
- Consumes: final prism artwork and `MenuBarControllerIdentity.primaryControlLabel`
- Produces: one Icon Composer application icon and one monochrome template status icon

- [ ] **Step 1: Inspect source assets and write failing artifact audits**

Render the current Icon Composer source and status item at actual size. Add release audit checks:

```bash
if find Resources -type f | rg -i 'thaw|ice|cube|melt|droplet'; then
  echo "inherited icon artifact remains" >&2
  exit 1
fi
if rg -n 'Image\("PrismMark"\)|PrismMark' App; then
  echo "obsolete raster page mark remains" >&2
  exit 1
fi
```

- [ ] **Step 2: Run icon and bundle audits and confirm any current failure**

```bash
./scripts/audit-release-bundle.sh --source-only
```

Expected: failure while obsolete `PrismMark` assets or references remain.

- [ ] **Step 3: Finalize both rendering contexts**

Keep the app icon as a layered Icon Composer prism with adaptive black, deep-water blue, glacier blue, and restrained spectral light. Ensure `icon.json` has no inherited layer or asset reference. Remove the obsolete page-mark imageset after the source reference audit is clean.

Keep `makePrimaryControlImage()` purpose-drawn at 18 points, template-rendered, and accessible. Verify it contains prism geometry only and set:

```swift
image.isTemplate = true
image.accessibilityDescription = MenuBarControllerIdentity.primaryControlLabel
```

- [ ] **Step 4: Build, inspect, and run icon assertions**

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project prismBar.xcodeproj -scheme prismBar -configuration Release build
./scripts/audit-release-bundle.sh --source-only
./scripts/test-ui.sh --only prismBarUITests/LaunchTests/testStatusItemOpensCommandCenter
```

Expected: the source audit is clean, the app icon is present in the Release product, and the template status icon opens the command center with a normal click.

- [ ] **Step 5: Commit final prism iconography**

```bash
git add App Resources Tests scripts/audit-release-bundle.sh
git commit -S -m "brand: finalize prismBar iconography"
```
