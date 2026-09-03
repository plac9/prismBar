# prismBar Production Usability Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the core prismBar menu-bar workflow clear, responsive, recoverable, and physically verifiable on macOS 27 without expanding the shipping trust boundary.

**Architecture:** Keep domain copy and interaction policy in `prismBarCore`, live Accessibility work in the existing serialized adapter/engine, and SwiftUI surfaces as projections of verified state. Improve the shared Rail and observation presentation once so the workspace and prismDeck stay consistent, then strengthen lifecycle, constrained-layout, and resource acceptance before producing one exact signed candidate.

**Tech Stack:** Swift 6.4, SwiftUI, AppKit, Swift Testing, XCTest/XCUITest, public macOS Accessibility and CoreGraphics APIs, Xcode 27, Developer ID, Bash 3.2 release contracts.

**Spec:** `docs/superpowers/specs/2026-09-02-production-usability-hardening-design.md`

## Global Constraints

- Human-facing product name is exactly `prismBar`; `prismDeck` is the compact status-item surface.
- macOS 27 or later and Apple silicon only.
- The core shipping target contains no Prism Card, prismCalc, XPC service, or plugin runtime.
- No screen capture, OCR, network access, telemetry, arbitrary file access, or dynamic code loading.
- Production logs omit observed titles, process identity, paths, coordinates, topology, environment values, and Accessibility values.
- User-visible topology remains observation-backed; no optimistic authoritative reorder.
- Every movement has a bounded deadline, input cleanup, fresh verification, and typed process-local receipt.
- Source changes use red-green-refactor and focused signed commits.
- Build scratch is pruned after durable evidence is generated because vizzini has limited free space.

---

### Task 1: Make observation state understandable

**Files:**
- Modify: `Sources/prismBarCore/PresentationCatalog.swift`
- Modify: `Tests/prismBarCoreTests/PresentationCatalogTests.swift`
- Modify: `App/Features/MenuBar/MenuBarView.swift`
- Modify: `App/Features/Overview/PrismDeckView.swift`
- Modify: `Tests/prismBarUITests/VisualAuditTests.swift`

**Interfaces:**
- Consumes: `MenuBarObservationPresentation(itemCount:unavailableSourceCount:)`
- Produces: `summary`, `inlineNotice`, and `accessibilityDescription` with consistent complete and limited-scan language.

- [x] **Step 1: Write failing presentation tests**

```swift
@Test("limited scans remain usable and explain the limitation")
func limitedScanPresentation() {
    let presentation = MenuBarObservationPresentation(itemCount: 11, unavailableSourceCount: 2)
    #expect(presentation.summary == "11 items ready · limited scan")
    #expect(presentation.inlineNotice == "2 running applications did not answer. You can still manage the items shown; prismBar verifies every change.")
}
```

- [x] **Step 2: Run the focused test and verify the old `partial scan` expectation fails**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter PresentationCatalogTests`

Expected: failure because the current summary says `items found, partial scan` and exposes no concise inline notice.

- [x] **Step 3: Implement the shared presentation contract**

Add a non-optional `inlineNotice` only for limited scans and compose the accessibility description from the summary plus notice. Keep counts normalized to zero or greater.

- [x] **Step 4: Render the notice consistently**

Display the limited-scan notice directly below topology truth in the workspace and prismDeck with `info.circle`, semantic secondary text, and an accessibility identifier. Do not use a warning-only glyph or force amber text for a usable state.

- [x] **Step 5: Run focused core and UI-source tests**

Run the focused Swift test plus the app test target's presentation/visual-structure checks.

- [x] **Step 6: Commit the independently reviewable state-language change**

Commit message: `fix(ux): explain limited menu bar scans`

---

### Task 2: Make Rail overflow and actions discoverable

**Files:**
- Modify: `App/Features/Overview/PrismRailView.swift`
- Modify: `App/Features/Overview/PrismRailViewSupport.swift`
- Modify: `App/Features/MenuBar/MenuBarView.swift`
- Modify: `Tests/prismBarCoreTests/PrismRailLayoutTests.swift`
- Modify: `Tests/prismBarUITests/AccessibilityAuditTests.swift`
- Modify: `Tests/prismBarUITests/PrismDeckTests.swift`

**Interfaces:**
- Consumes: `PrismRailLayout`, selected item binding, native horizontal `ScrollView`.
- Produces: lane edge affordances, consistent section-action labels, and accessibility scroll actions without changing movement semantics.

- [x] **Step 1: Add failing label and overflow-policy tests**

```swift
@Test("section actions use the product vocabulary")
func sectionActions() {
    #expect(PrismRailPresentation.collapseAction == "Tuck Away")
    #expect(PrismRailPresentation.revealAction == "Reveal")
}
```

Use the exact-revision UI audit to verify that an overflowing Rail exposes the native horizontal scroll indicator and that fixed items remain reachable by accessibility scrolling. The indicator is system-owned presentation and does not warrant a source-constant test.

- [x] **Step 2: Run focused tests and verify missing policy symbols fail**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter PrismRail` plus the focused Rail UI test.

- [x] **Step 3: Implement lane overflow cues with native behavior**

Keep the native horizontal scroll indicator visible so overflow has a standard macOS cue and scroll path without custom geometry tracking. Preserve native momentum, keyboard/accessibility scrolling, and drag destinations. Do not add custom event monitors or decorative edge overlays.

- [x] **Step 4: Normalize action copy**

Replace `Tuck Away Hidden` and `Reveal Tucked Away` with the shared `Tuck Away` and `Reveal` policy in the workspace, prismDeck, command menu, help, and UI assertions.

- [x] **Step 5: Verify direct multi-position action access**

Assert every movable chip exposes drag plus first/last/left/right and cross-section actions. Assert macOS-owned chips say `fixed by macOS` and expose no movement action.

- [x] **Step 6: Commit the independently reviewable Rail affordance change**

Commit message: `fix(ux): clarify Rail overflow and section actions`

---

### Task 3: Harden prismDeck as the daily control surface

**Files:**
- Modify: `App/Features/Overview/PrismDeckView.swift`
- Modify: `App/Features/Overview/PrismDeckLayoutPolicy.swift`
- Modify: `App/MenuBarSectionStatusController.swift`
- Modify: `Tests/prismBarCoreTests/PrismDeckApplicationsPresentationTests.swift`
- Modify: `Tests/prismBarUITests/LaunchTests.swift`
- Modify: `Tests/prismBarUITests/PrismDeckTests.swift`

**Interfaces:**
- Consumes: current verified snapshot, text-size preference, visible screen frame, action receipt.
- Produces: immediate cached-state open, bounded refresh, stable header/footer, and deterministic dismiss/reopen behavior.

- [x] **Step 1: Add failing lifecycle and constrained-size UI tests**

Cover normal click, Escape, reopen, workspace routing, Settings routing, 640-point visible height, 200% reading size, and action buttons remaining hittable.

- [x] **Step 2: Verify tests fail against any missing state**

Run the focused prismDeck UI suite with local ad-hoc signing and a disposable DerivedData directory.

- [x] **Step 3: Fix only reproduced lifecycle/layout defects**

Keep one scrolling content region between the stable header and footer. Clamp to `visibleFrame` on every open. Preserve last verified content during refresh and reject duplicate refresh requests while loading.

- [x] **Step 4: Verify user feedback states**

Exercise ready, checking, limited scan, moving, applied, partial, access lost, full-screen/auto-hide unavailable, and compatible Undo states. Every state needs text, not color or icon alone.

- [x] **Step 5: Commit the independently reviewable prismDeck change**

Commit message: `fix(ux): harden prismDeck daily workflow`

---

### Task 4: Prove permission and recovery behavior without stale truth

**Files:**
- Modify only if a reproduced defect exists: `App/AppLifecycle.swift`, `App/AppModel.swift`, `App/Features/Overview/OverviewView.swift`, `App/Features/Settings/SettingsRootView.swift`
- Test: `Tests/prismBarEngineTests/AccessibilityPermissionTests.swift`
- Test: `Tests/prismBarAppTests/AppLifecycleTests.swift`
- Test: `Tests/prismBarUITests/LaunchTests.swift`

**Interfaces:**
- Consumes: live `AXIsProcessTrusted`, `CGPreflightPostEventAccess`, stable-install identity.
- Produces: one non-cached readiness state shared by Home, Menu Bar, Settings, toolbar, and prismDeck.

- [ ] **Step 1: Add or confirm tests for foreground recheck, runtime revocation, signed upgrade, and identity mismatch**

The app must transition immediately to safe disabled controls when either authority is lost and recover without clearing unrelated preferences.

- [ ] **Step 2: Exercise the installed candidate through the real system transition**

Use the final exact signed candidate. Observe access before and after relaunch and signed replacement. Record fresh grant and runtime revoke only from the visible physical result; do not alter TCC databases directly.

- [ ] **Step 3: Fix any reproduced mismatch test-first**

No workaround may cache permission as granted, open undocumented System Settings URLs, or request broader authority.

- [ ] **Step 4: Commit only if source changed**

Commit message: `fix(access): reconcile live macOS permission state`

---

### Task 5: Enforce responsiveness and bounded resource use

**Files:**
- Modify: `Tests/prismBarAppTests/AppModelActionFeedbackTests.swift`
- Modify: `Tests/prismBarAccessibilityTests/ConcurrentObservationReaderTests.swift`
- Modify only for reproduced defects: `App/AppModel.swift`, `App/LiveMenuBarController.swift`, `Sources/prismBarAccessibility/ConcurrentObservationReader.swift`
- Create: `scripts/audit-runtime-budget.sh`
- Create: `Tests/ReleaseWorkflowTests/runtime_budget_contract.sh`
- Modify: `scripts/ci-verify.sh`

**Interfaces:**
- Consumes: running app PID and existing synthetic refresh/action fixtures.
- Produces: a privacy-safe pass/fail runtime-budget report containing only aggregate CPU, footprint, task, and window counts.

- [ ] **Step 1: Write a failing runtime-budget source contract**

Require explicit thresholds of less than 1% settled idle CPU and less than 100 MiB physical footprint, bounded sample count, no command-line/environment dump, no process inventory output, and nonzero failure status when a threshold is exceeded.

- [ ] **Step 2: Add refresh coalescing tests**

Start multiple refresh requests while one observation is pending and assert that only one live observation task owns publication while all callers settle without unbounded task creation.

- [ ] **Step 3: Implement the minimum aggregate audit and any reproduced coalescing fix**

The script reads only the exact prismBar PID, samples aggregate metrics, and emits generic values. It never captures menu-bar or environment content.

- [ ] **Step 4: Run a ten-minute refresh/open/dismiss soak**

Compare beginning and ending physical footprint, task count, and window count. Fail on monotonic growth beyond a documented tolerance; preserve only aggregate results.

- [ ] **Step 5: Commit the independently reviewable runtime gate**

Commit message: `test(runtime): enforce prismBar resource budgets`

---

### Task 6: Produce exact automated, visual, and signed evidence

**Files:**
- Modify: `docs/IMPLEMENTATION-PLAN.md`
- Modify: `docs/MACOS-27-COMPATIBILITY.md`
- Modify: `docs/SECURITY-MODEL.md`
- Modify: `prismBar-threat-model.md`
- Generated ignored evidence: `build/ci`, `build/ui-audit`, `build/assurance`, `build/Distribution`, `build/PhysicalAcceptance`

**Interfaces:**
- Consumes: clean signed source revision, dedicated release Keychain, named notary profile.
- Produces: revision-bound CI, UI, assurance, archive, notarization, installation, and physical-acceptance records.

- [ ] **Step 1: Run the complete clean-revision verification**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/ci-verify.sh`

Expected: every core, app, sanitizer, static-analysis, security, licensing, bundle, and release-contract gate passes with zero secret or privacy findings.

- [ ] **Step 2: Capture and inspect the exact eleven-surface UI audit**

Review Home, Menu Bar, Automation, Privacy, About, Settings General, Settings Privacy, prismDeck, status icon, Home at 200%, and prismDeck at 200%. Reject any capture with clipping, unexplained state, or pixels outside the app-owned opaque region.

- [ ] **Step 3: Archive, notarize, staple, and transactionally install the exact clean revision**

Use only `release-readiness.sh`, `archive-release-candidate.sh`, `notarize-release-candidate.sh`, and `install-release-candidate.sh` with the dedicated release Keychain/profile. Do not fall back to login-Keychain signing.

- [ ] **Step 4: Exercise the physical macOS 27 matrix**

Record the exact installed revision's access, direct multi-position move, hide/show, Undo, prismDeck, relaunch, signed upgrade, displays, Spaces, full screen, auto-hide, reading sizes, appearance/accessibility states, sleep/wake, logout, reboot, and clean-account Gatekeeper observations individually.

- [ ] **Step 5: Reconcile documentation and public provenance**

Mark only observed gates complete, update the exact public source revision, regenerate the assurance report, and verify the GitHub repository contains no secret, private path, environment, or real menu-bar evidence.

- [ ] **Step 6: Prune disposable build scratch and verify the final state**

Retain revision-bound reports, screenshots, release evidence, and rollback artifact. Remove only disposable DerivedData, `.xcresult`, and temporary archives after their durable evidence has been validated. Confirm Git clean, remote synchronized, installed provenance exact, app running, VoiceOver restored off, and vizzini free-space headroom.
