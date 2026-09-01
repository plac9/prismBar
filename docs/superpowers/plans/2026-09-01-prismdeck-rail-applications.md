# prismDeck Rail and Applications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved prismDeck Rail plus Applications drawer as the fast, truthful daily menu-bar control surface on macOS 27.

**Architecture:** Lift selected-display and selected-item state into `PrismDeckView`, then render Rail and a new Applications drawer from one immutable `MenuBarSnapshot`. A pure `prismBarCore` presenter owns filtering, ordering, endpoint availability, and selection validity; SwiftUI components only render presentation values and dispatch existing verified `AppModel` actions.

**Tech Stack:** Swift 6.4 strict concurrency, SwiftUI, AppKit `NSPopover`, Swift Testing, XCTest/XCUITest, Xcode 27 beta, public Apple APIs only.

**Spec:** `docs/superpowers/specs/2026-09-01-prismdeck-rail-applications-design.md`

## Global Constraints

- Human-facing names are exactly `prismBar`, `prismDeck`, `Rail`, and `Prism Cards`.
- Target macOS 27 or later on Apple silicon only.
- Build with `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`.
- Preserve Swift 6.4 complete strict concurrency and the existing app bundle identifier `com.laclairtech.prismbar`.
- Use public Apple APIs and native SwiftUI controls; AppKit remains limited to the status item, popover, icon lookup, lifecycle, Accessibility, and existing platform bridges.
- Do not add persistence, network access, telemetry, screen capture, OCR, dependencies, entitlements, URL schemes, background services, update mechanisms, or dynamic plugin loading.
- Never log or commit observed application names, bundle identifiers, icons, order, search text, PIDs, paths, or Accessibility values.
- Tests and committed fixtures use synthetic identifiers and display names only.
- macOS-owned items remain fixed anchors and never enter the Applications drawer.
- Prism Cards remains absent because the shipping host links no validated bundled Card registry.
- Every product change follows red-green-refactor and ends in a small signed conventional commit.

---

### Task 1: Pure Applications presentation

**Files:**
- Create: `Sources/prismBarCore/PrismDeckApplicationsPresentation.swift`
- Create: `Tests/prismBarCoreTests/PrismDeckApplicationsPresentationTests.swift`

**Interfaces:**
- Consumes: `MenuBarSnapshot`, `MenuBarSurfaceID`, `MenuBarItemID`, `MenuBarSection`, and `PrismRailKeyboardMoveResolver` from `prismBarCore`.
- Produces: `PrismDeckApplicationRow`, `PrismDeckApplicationsPresentation`, and `PrismDeckApplicationsPresenter.make(snapshot:surfaceID:query:)` for Tasks 2–4.

- [ ] **Step 1: Write failing inclusion, ordering, and endpoint tests**

```swift
@testable import prismBarCore
import Testing

@Suite("prismDeck applications presentation")
struct PrismDeckApplicationsPresentationTests {
    @Test("includes only application-owned items on the selected display")
    func filtersOwnershipRoleAndSurface() {
        let presentation = PrismDeckApplicationsPresenter().make(
            snapshot: fixtureSnapshot(),
            surfaceID: .init(rawValue: "fixture.primary"),
            query: ""
        )

        #expect(presentation.visibleRows.map(\.name) == ["Synthetic Mail", "Synthetic Chat"])
        #expect(presentation.hiddenRows.map(\.name) == ["Synthetic Calendar"])
        #expect(presentation.totalApplicationCount == 3)
        #expect(presentation.visibleRows[0].sectionPosition == 1)
        #expect(presentation.visibleRows[1].sectionPosition == 2)
    }

    @Test("derives only valid endpoint commands")
    func derivesEndpoints() {
        let presentation = PrismDeckApplicationsPresenter().make(
            snapshot: fixtureSnapshot(),
            surfaceID: .init(rawValue: "fixture.primary"),
            query: ""
        )

        #expect(presentation.visibleRows[0].firstDestinationPosition == nil)
        #expect(presentation.visibleRows[0].lastDestinationPosition != nil)
        #expect(presentation.visibleRows[1].firstDestinationPosition != nil)
        #expect(presentation.visibleRows[1].lastDestinationPosition == nil)
    }
}
```

The shared synthetic fixture contains visible Synthetic Mail and Synthetic Chat, the divider, hidden Synthetic Calendar, a system Clock, a self-owned control, an unavailable application, and an application on `fixture.secondary`.

- [ ] **Step 2: Run the focused test and confirm the type-missing failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter PrismDeckApplicationsPresentationTests
```

Expected: compilation fails because `PrismDeckApplicationsPresenter` does not exist.

- [ ] **Step 3: Implement immutable presentation values and the presenter**

```swift
public struct PrismDeckApplicationRow: Identifiable, Equatable, Sendable {
    public let id: MenuBarItemID
    public let name: String
    public let ownerBundleIdentifier: String?
    public let section: MenuBarSection
    public let sectionPosition: Int
    public let sectionCount: Int
    public let availability: MenuBarItemAvailability
    public let allowsVerifiedMovement: Bool
    public let firstDestinationPosition: Int?
    public let lastDestinationPosition: Int?
}

public struct PrismDeckApplicationsPresentation: Equatable, Sendable {
    public let visibleRows: [PrismDeckApplicationRow]
    public let hiddenRows: [PrismDeckApplicationRow]
    public let totalApplicationCount: Int
    public let queryIsEmpty: Bool

    public var filteredRows: [PrismDeckApplicationRow] { visibleRows + hiddenRows }
    public func containsApplication(itemID: MenuBarItemID) -> Bool
}

public struct PrismDeckApplicationsPresenter: Sendable {
    public init() {}

    public func make(
        snapshot: MenuBarSnapshot,
        surfaceID: MenuBarSurfaceID,
        query: String
    ) -> PrismDeckApplicationsPresentation
}
```

Build rows from `PrismRailLayout` before filtering application ownership so `sectionPosition` and `sectionCount` match Rail. Include only `role == .item`, `ownership == .application`, and the selected surface. Copy `MenuBarItem.allowsVerifiedMovement` into each row. Use `localizedCaseInsensitiveContains` only against `displayName`. Derive endpoints through `PrismRailKeyboardMoveResolver`; rows that do not allow verified movement receive no endpoints.

- [ ] **Step 4: Add failing search, empty-state, unavailable, and selection-validity tests**

```swift
@Test("search is localized and case insensitive")
func searchesRenderedNameOnly() {
    let result = presenter.make(snapshot: fixtureSnapshot(), surfaceID: primary, query: "cHaT")
    #expect(result.filteredRows.map(\.name) == ["Synthetic Chat"])
    #expect(result.totalApplicationCount == 3)
    #expect(result.queryIsEmpty == false)
}

@Test("unavailable applications remain visible but fail closed")
func unavailableRowsHaveNoCommands() {
    let row = presenter.make(snapshot: unavailableFixture(), surfaceID: primary, query: "")
        .visibleRows[0]
    #expect(row.allowsVerifiedMovement == false)
    #expect(row.firstDestinationPosition == nil)
    #expect(row.lastDestinationPosition == nil)
}

@Test("selection validity follows the unfiltered selected display")
func validatesSelectionIndependentOfSearch() {
    let result = presenter.make(snapshot: fixtureSnapshot(), surfaceID: primary, query: "mail")
    #expect(result.containsApplication(itemID: id("chat")))
    #expect(!result.containsApplication(itemID: id("secondary")))
}
```

Expose `containsApplication(itemID:)` against the selected display's complete application ID set, not only filtered rows, so typing a search does not erase selection.

- [ ] **Step 5: Run pure tests and the full package suite**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter PrismDeckApplicationsPresentationTests
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
```

Expected: all presentation tests and the complete Swift package suite pass.

- [ ] **Step 6: Commit the pure presentation layer**

```bash
git add Sources/prismBarCore/PrismDeckApplicationsPresentation.swift Tests/prismBarCoreTests/PrismDeckApplicationsPresentationTests.swift
git commit -S -m "feat: model prismDeck applications"
```

---

### Task 2: Rail selection and shared display state

**Files:**
- Modify: `Sources/prismBarCore/PrismRailDropResolver.swift`
- Modify: `App/Features/Overview/PrismRailView.swift`
- Modify: `App/Features/MenuBar/MenuBarView.swift`
- Modify: `Tests/prismBarCoreTests/PrismRailDropResolverTests.swift`

**Interfaces:**
- Consumes: `PrismRailSurfaceResolver.resolve(in:current:)` and `MenuBarItemID`.
- Produces: `PrismRailView(snapshot:selectedSurfaceID:selectedItemID:)`, with both values passed as bindings by prismDeck and local bindings by the full workspace.

- [ ] **Step 1: Add a failing resolver test for invalid selected application state**

```swift
@Test("rejects selection that is absent or on another display")
func validatesSelectedItemForSurface() {
    let snapshot = railSnapshot(batterySurface: .init(rawValue: "secondary"))
    let resolver = PrismRailSelectionResolver()

    #expect(resolver.resolve(id("mail"), in: snapshot, surfaceID: .unknown) == id("mail"))
    #expect(resolver.resolve(id("battery"), in: snapshot, surfaceID: .unknown) == nil)
    #expect(resolver.resolve(id("missing"), in: snapshot, surfaceID: .unknown) == nil)
}
```

- [ ] **Step 2: Run the focused test and confirm the resolver-missing failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter PrismRailDropResolverTests
```

Expected: compilation fails because `PrismRailSelectionResolver` does not exist.

- [ ] **Step 3: Add the minimal pure resolver beside the Rail resolvers**

```swift
public struct PrismRailSelectionResolver: Sendable {
    public init() {}

    public func resolve(
        _ selectedItemID: MenuBarItemID?,
        in snapshot: MenuBarSnapshot,
        surfaceID: MenuBarSurfaceID
    ) -> MenuBarItemID? {
        guard let selectedItemID,
              snapshot.items.contains(where: {
                  $0.id == selectedItemID &&
                  $0.surfaceID == surfaceID &&
                  $0.role == .item &&
                  $0.ownership == .application
              })
        else { return nil }
        return selectedItemID
    }
}
```

- [ ] **Step 4: Lift Rail state into bindings and add highlight/focus/scroll linkage**

Change the Rail signature to:

```swift
struct PrismRailView: View {
    @Environment(AppModel.self) private var model
    let snapshot: MenuBarSnapshot
    @Binding var selectedSurfaceID: MenuBarSurfaceID
    @Binding var selectedItemID: MenuBarItemID?
    @AccessibilityFocusState private var focusedItemID: MenuBarItemID?
}
```

Give each chip `.id(item.id)`, set `selectedItemID` on tap, draw a two-point semantic accent stroke when selected, and apply `.accessibilityFocused($focusedItemID, equals: item.id)`. Wrap each lane's horizontal content in `ScrollViewReader`; when selection changes to an item in that lane, scroll it to center and set accessibility focus. On snapshot or surface changes, resolve both bindings with `PrismRailSurfaceResolver` and `PrismRailSelectionResolver`.

In `MenuBarView`, add local `@State` values initialized from the first populated surface and pass bindings so the full workspace retains current behavior without sharing prismDeck state.

- [ ] **Step 5: Run Rail tests and unsigned app tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter PrismRailDropResolverTests
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodegen generate
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project prismBar.xcodeproj -scheme prismBar -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
```

Expected: resolver tests pass and both Rail call sites compile.

- [ ] **Step 6: Commit shared Rail selection**

```bash
git add Sources/prismBarCore/PrismRailDropResolver.swift Tests/prismBarCoreTests/PrismRailDropResolverTests.swift App/Features/Overview/PrismRailView.swift App/Features/MenuBar/MenuBarView.swift prismBar.xcodeproj/project.pbxproj
git commit -S -m "feat: link Rail selection"
```

---

### Task 3: Native Applications drawer

**Files:**
- Create: `App/Features/Overview/MenuBarApplicationIcon.swift`
- Create: `App/Features/Overview/PrismDeckApplicationsView.swift`
- Modify: `App/Features/Overview/PrismRailView.swift`
- Create: `Tests/prismBarAppTests/PrismDeckApplicationsCommandTests.swift`

**Interfaces:**
- Consumes: `PrismDeckApplicationsPresentation`, `PrismDeckApplicationRow`, `AppModel.moveMenuBarItem(_:to:)`, and the selected-item binding.
- Produces: `PrismDeckApplicationsView(presentation:snapshot:selectedItemID:searchText:)` and shared `MenuBarApplicationIcon` rendering.

- [ ] **Step 1: Write failing command-routing tests**

```swift
@testable import prismBar
import prismBarCore
import XCTest

@MainActor
final class PrismDeckApplicationsCommandTests: XCTestCase {
    func testShowAndHideUseSectionMoves() {
        XCTAssertEqual(PrismDeckApplicationCommand.toggleDestination(from: .visible), .hidden)
        XCTAssertEqual(PrismDeckApplicationCommand.toggleDestination(from: .hidden), .visible)
    }

    func testEndpointCommandsPreserveResolvedAbsolutePositions() {
        XCTAssertEqual(PrismDeckApplicationCommand.first(4).destinationPosition, 4)
        XCTAssertEqual(PrismDeckApplicationCommand.last(11).destinationPosition, 11)
    }
}
```

- [ ] **Step 2: Run the focused app test and confirm the command-type failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodegen generate
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild test -project prismBar.xcodeproj -scheme prismBar -destination 'platform=macOS,arch=arm64' -only-testing:prismBarAppTests/PrismDeckApplicationsCommandTests CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because `PrismDeckApplicationCommand` does not exist.

- [ ] **Step 3: Implement typed row commands and the shared icon view**

```swift
enum PrismDeckApplicationCommand: Equatable {
    case toggle(MenuBarSection)
    case first(Int)
    case last(Int)

    static func toggleDestination(from section: MenuBarSection) -> MenuBarSection {
        section == .hidden ? .visible : .hidden
    }

    var destinationPosition: Int? {
        switch self {
        case let .first(position), let .last(position): position
        case .toggle: nil
        }
    }
}
```

`MenuBarApplicationIcon` accepts `ownerBundleIdentifier`, a fallback system symbol, and a fixed size. It uses only `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` and `icon(forFile:)`, never logs or stores lookup inputs. Replace Rail's private duplicated icon lookup with this component.

- [ ] **Step 4: Build the native drawer and row action dispatch**

```swift
struct PrismDeckApplicationsView: View {
    @Environment(AppModel.self) private var model
    let presentation: PrismDeckApplicationsPresentation
    let snapshot: MenuBarSnapshot
    @Binding var selectedItemID: MenuBarItemID?
    @Binding var searchText: String
}
```

Use a `DisclosureGroup` titled `Applications` with the total count, a native searchable text field, `On Bar` and `Tucked Away` sections, and native rows. A row click only assigns `selectedItemID`. The primary button dispatches the opposite `MenuBarSection`; the compact menu dispatches only non-nil First/Last absolute positions. Disable all row actions while `model.isMenuBarActionInProgress` or when the row is unavailable. Use these identifiers:

```text
prismDeck.applications
prismDeck.applications.search
prismDeck.applications.visible
prismDeck.applications.hidden
prismDeck.application.<section>.<one-based-position>
prismDeck.application.<section>.<one-based-position>.toggle
prismDeck.application.<section>.<one-based-position>.more
```

Render exactly `No manageable applications are visible on this display.` when the total is zero, and `No applications match this search.` when a non-empty query yields no rows.

- [ ] **Step 5: Run app tests and strict build**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild test -project prismBar.xcodeproj -scheme prismBar -destination 'platform=macOS,arch=arm64' -only-testing:prismBarAppTests/PrismDeckApplicationsCommandTests CODE_SIGNING_ALLOWED=NO
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swiftlint lint --strict
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project prismBar.xcodeproj -scheme prismBar -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
```

Expected: focused tests, lint, and unsigned build pass with warnings treated as errors.

- [ ] **Step 6: Commit the drawer component**

```bash
git add App/Features/Overview/MenuBarApplicationIcon.swift App/Features/Overview/PrismDeckApplicationsView.swift App/Features/Overview/PrismRailView.swift Tests/prismBarAppTests/PrismDeckApplicationsCommandTests.swift prismBar.xcodeproj/project.pbxproj
git commit -S -m "feat: add prismDeck applications drawer"
```

---

### Task 4: Recompose prismDeck and popover lifecycle

**Files:**
- Modify: `App/Features/Overview/PrismDeckView.swift`
- Modify: `App/MenuBarSectionStatusController.swift`
- Modify: `Tests/prismBarUITests/PrismDeckTests.swift`

**Interfaces:**
- Consumes: Tasks 1–3 presentation, Rail bindings, drawer, and the existing action receipt/recovery coordinator.
- Produces: the shipping 440-point-wide, at-most-620-point-tall prismDeck hierarchy and dismissal cleanup.

- [ ] **Step 1: Add failing UI contract assertions**

Extend `testStatusItemOpensPrismDeckWithWorkspaceClosed`:

```swift
XCTAssertTrue(application.descendants(matching: .any)["prismRail"].exists)
XCTAssertTrue(application.disclosureTriangles["Applications"].exists || application.staticTexts["Applications"].exists)
XCTAssertFalse(application.staticTexts["Prism Cards"].exists)
XCTAssertFalse(application.buttons["Show Every Movable Item"].exists)
```

Add a test that enters synthetic text in `prismDeck.applications.search`, dismisses with Escape, reopens, and verifies the field value is empty. If Accessibility is unavailable, assert the focused recovery surface instead and skip only the inventory-specific branch using `XCTSkip` with the observed permission state.

- [ ] **Step 2: Run the focused UI test and confirm the hierarchy failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-ui.sh prismBarUITests/PrismDeckTests
```

Expected: the new Applications hierarchy assertion fails against the old deck.

- [ ] **Step 3: Lift prismDeck state and compose the approved order**

Add:

```swift
@State private var selectedSurfaceID: MenuBarSurfaceID = .unknown
@State private var selectedItemID: MenuBarItemID?
@State private var applicationSearchText = ""
@State private var applicationsExpanded = true
```

For each snapshot, resolve the selected surface, build one `PrismDeckApplicationsPresentation`, and render: topology truth, Rail, Applications, receipt/Undo, then the minimal footer. Remove the reset confirmation and `Show Every Movable Item` from prismDeck. Keep reset only in the full workspace. Put Tuck Away/Reveal in the footer and Settings/Quit in one `More` menu.

On snapshot generation, display, or trust changes, clear invalid selection with `PrismRailSelectionResolver`. On disappear, clear only `applicationSearchText` and `selectedItemID`; leave the per-process disclosure choice intact. Permission loss continues to replace privileged content immediately.

- [ ] **Step 4: Set the bounded popover geometry**

Set `NSPopover.contentSize` to `NSSize(width: 440, height: 620)`. Set the SwiftUI root to width 440 and maximum height 620, with a vertical `ScrollView` around management content so smaller screen geometry clips neither header nor footer. Do not add decorative material backgrounds; keep system popover material and native glass button treatments.

- [ ] **Step 5: Run focused UI, app, and package tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-ui.sh prismBarUITests/PrismDeckTests
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild test -project prismBar.xcodeproj -scheme prismBar -destination 'platform=macOS,arch=arm64' -only-testing:prismBarAppTests CODE_SIGNING_ALLOWED=NO
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
```

Expected: prismDeck UI contracts, app tests, and package tests pass.

- [ ] **Step 6: Commit the shipping prismDeck composition**

```bash
git add App/Features/Overview/PrismDeckView.swift App/MenuBarSectionStatusController.swift Tests/prismBarUITests/PrismDeckTests.swift
git commit -S -m "feat: rebuild prismDeck control surface"
```

---

### Task 5: Accessibility, visual, privacy, and release verification

**Files:**
- Modify: `Tests/prismBarUITests/AccessibilityAuditTests.swift`
- Modify: `Tests/prismBarUITests/VisualAuditTests.swift`
- Modify: `docs/IMPLEMENTATION-PLAN.md`
- Generated and ignored: `build/ui-audit-report.html`

**Interfaces:**
- Consumes: the complete shipping prismDeck from Task 4.
- Produces: automated evidence and exact-revision physical acceptance checklist; no product API.

- [ ] **Step 1: Strengthen accessibility and visual test assertions**

In the prismDeck accessibility audit, assert the Rail and Applications identifiers before running the existing macOS audit. In the visual audit, assert popover width is approximately 440 and height does not exceed 620 before capturing `08-prismDeck`. Never attach a textual accessibility hierarchy or commit a screenshot containing live observed application names.

- [ ] **Step 2: Run focused UI audits**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-ui.sh prismBarUITests/AccessibilityAuditTests/testPrismDeckPassesMacOSAccessibilityAudit
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/test-ui.sh prismBarUITests/VisualAuditTests/testCapturesPrivacySafeShippingSurfaces
```

Expected: the native accessibility audit passes and private screenshots are produced only in ignored build/test output.

- [ ] **Step 3: Run static security, privacy, licensing, and glass audits**

Run:

```bash
./scripts/audit-public-safety.sh
./scripts/audit-licensing.sh
./scripts/audit-macos-27-compatibility.sh
./scripts/audit-liquid-glass.sh
git diff --check
```

Expected: every audit passes and no tracked file contains private runtime inventory or malformed whitespace.

- [ ] **Step 4: Run the complete clean-revision CI gate**

Commit the test and documentation changes first, then run:

```bash
git add Tests/prismBarUITests/AccessibilityAuditTests.swift Tests/prismBarUITests/VisualAuditTests.swift docs/IMPLEMENTATION-PLAN.md
git commit -S -m "test: verify prismDeck applications experience"
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/ci-verify.sh
```

Expected: debug/release Swift tests, sanitizers, Xcode builds, analysis, signing-boundary checks, secret scan, static analysis, and policy gates pass from the clean committed revision.

- [ ] **Step 5: Generate the ignored HTML UI audit report**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/capture-ui-audit.sh
./scripts/generate-ui-audit-report.sh
test -f build/ui-audit-report.html
git status --short
```

Expected: `build/ui-audit-report.html` exists, generated evidence remains ignored, and the tracked tree stays clean.

---

### Task 6: Exact signed installation and physical macOS 27 acceptance

**Files:**
- Modify only after direct evidence: `docs/IMPLEMENTATION-PLAN.md`
- Generated and ignored: `build/physical-acceptance/`

**Interfaces:**
- Consumes: the clean exact revision that passed Task 5.
- Produces: signed installed build provenance and bounded physical acceptance evidence; no source API.

- [ ] **Step 1: Build and install the exact signed Development revision**

Use the repository's existing signed-install workflow with `PRISM_SOURCE_REVISION=$(git rev-parse HEAD)`. Verify `/Applications/prismBar.app` with `codesign --verify --deep --strict`, confirm bundle identifier `com.laclairtech.prismbar`, and read the embedded `PrismSourceRevision`. Do not replace a running installation until the new bundle has passed build and signing verification.

- [ ] **Step 2: Verify live trust and the status-item launch path**

Launch `/Applications/prismBar.app`, close the workspace, click the physical prismBar status item, and confirm prismDeck opens without a workspace window. Verify live Accessibility trust for that exact installed signature. A unit-test permission result is not acceptance.

- [ ] **Step 3: Exercise the core application workflow**

Using non-system application items only:

1. Confirm the same applications and sections appear in Rail and Applications.
2. Select a drawer row and confirm the corresponding Rail chip highlights and scrolls into view without moving.
3. Perform a multi-position Rail drag in one gesture and verify the exact observed order.
4. Perform First or Last from Applications and verify the exact observed order.
5. Hide and Show an application and verify section membership.
6. Use Undo and verify the prior topology is restored.
7. Confirm Clock, Siri, Control Center, dividers, and prismBar-owned controls expose no movement actions.

- [ ] **Step 4: Exercise lifecycle and accessibility variants**

Verify reopen, relaunch, signed upgrade, multiple displays, Spaces, full-screen, automatic menu-bar hiding, sleep, wake, logout, and reboot as distinct gates. Verify keyboard-only navigation, VoiceOver labels/actions, Increase Contrast, Reduce Transparency, Differentiate Without Color, Reduce Motion, and large text without clipped commands.

- [ ] **Step 5: Inspect evidence for information escape**

Confirm tracked files, Git history for this feature, production logs, defaults, diagnostics, and public audit metadata contain no observed application names, bundle identifiers, icons, order, search text, Accessibility values, PIDs, or paths. Store any private screenshots only under ignored `build/physical-acceptance/`.

- [ ] **Step 6: Record only directly evidenced gates and commit**

Update `docs/IMPLEMENTATION-PLAN.md` with the exact revision and bounded pass/fail status. Leave any unexecuted lifecycle gate unchecked. Then run the static audits again and commit:

```bash
git add docs/IMPLEMENTATION-PLAN.md
git commit -S -m "docs: record prismDeck physical acceptance"
git log -1 --show-signature
git status --short
```

Expected: a valid owner signature and a clean tracked tree. Do not claim release readiness unless every required physical gate has direct evidence.
