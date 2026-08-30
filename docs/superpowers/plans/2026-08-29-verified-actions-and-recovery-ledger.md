# Verified Actions and Recovery Ledger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every prismBar menu-bar operation a typed, privacy-safe receipt and retain at most ten process-local recovery candidates.

**Architecture:** Add immutable receipt and ledger values to `prismBarEngine`. The ledger stores before and verified-after snapshots only in memory, rejects incompatible recovery targets, and never conforms to `Codable`. App integration follows only after the domain behavior passes focused tests.

**Tech Stack:** Swift 6.4, Swift Testing, Observation, strict concurrency, macOS 27

**Spec:** `docs/superpowers/specs/2026-08-29-verified-prismbar-rebuild-design.md`

## Global Constraints

- Human-facing product name is exactly `prismBar`.
- Compact surface name is exactly `prismDeck`.
- Direct manipulation surface name is exactly `Rail`.
- macOS 27 or later and Apple silicon only.
- Swift 6.4 with complete strict concurrency.
- No production log may contain an observed menu title, process name, path, frame, AX value, plugin payload, environment value, or user content.
- Recovery history is process-local memory only and has a hard maximum of ten entries.
- Write and run a failing test before every production change.

---

### Task 1: Define typed action receipts

**Files:**
- Create: `Sources/prismBarEngine/MenuBarActionReceipt.swift`
- Create: `Tests/prismBarEngineTests/MenuBarActionReceiptTests.swift`

**Interfaces:**
- Produces: `MenuBarActionID`, `MenuBarActionKind`, `MenuBarActionPhase`, and `MenuBarActionReceipt`.
- `MenuBarActionReceipt` accepts an existing `MenuBarActionResult` and does not synthesize observed content.

- [x] **Step 1: Write the failing receipt tests**

```swift
@testable import prismBarEngine
import Testing

@Suite("Menu bar action receipts")
struct MenuBarActionReceiptTests {
    @Test("starts in verifying state without a result")
    func startsVerifying() {
        let receipt = MenuBarActionReceipt.verifying(
            id: MenuBarActionID(rawValue: 7),
            kind: .directMove
        )

        #expect(receipt.phase == .verifying)
        #expect(receipt.result == nil)
        #expect(!receipt.canRecover)
    }

    @Test("maps results to an explicit terminal phase")
    func mapsTerminalPhases() {
        let id = MenuBarActionID(rawValue: 1)

        #expect(MenuBarActionReceipt.completed(id: id, kind: .directMove, result: .success("Verified"), canRecover: true).phase == .applied)
        #expect(MenuBarActionReceipt.completed(id: id, kind: .directMove, result: .warning("Partial"), canRecover: true).phase == .partial)
        #expect(MenuBarActionReceipt.completed(id: id, kind: .directMove, result: .failure("Blocked"), canRecover: false).phase == .blocked)
    }

    @Test("recovery has its own terminal phase")
    func recordsRecovery() {
        let receipt = MenuBarActionReceipt.recovered(
            id: MenuBarActionID(rawValue: 9),
            result: .success("Previous layout restored")
        )

        #expect(receipt.kind == .recovery)
        #expect(receipt.phase == .recovered)
        #expect(!receipt.canRecover)
    }
}
```

- [x] **Step 2: Run the receipt tests and verify the missing-type failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter MenuBarActionReceiptTests
```

Expected: compilation fails because `MenuBarActionReceipt` and its supporting types do not exist.

- [x] **Step 3: Implement the minimal receipt domain**

```swift
public struct MenuBarActionID: RawRepresentable, Hashable, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

public enum MenuBarActionKind: Equatable, Sendable {
    case directMove
    case sectionMove
    case batchMove
    case reset
    case recovery
}

public enum MenuBarActionPhase: Equatable, Sendable {
    case verifying
    case applied
    case partial
    case blocked
    case recovered
}

public struct MenuBarActionReceipt: Equatable, Sendable {
    public let id: MenuBarActionID
    public let kind: MenuBarActionKind
    public let phase: MenuBarActionPhase
    public let result: MenuBarActionResult?
    public let canRecover: Bool
}
```

Add the three static factories exercised by the tests. Map success to `applied`, warning to `partial`, and failure to `blocked`.

- [x] **Step 4: Run focused and complete package tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter MenuBarActionReceiptTests
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
```

Expected: focused receipt tests pass and all package tests pass.

- [x] **Step 5: Commit the receipt domain**

```bash
git add Sources/prismBarEngine/MenuBarActionReceipt.swift Tests/prismBarEngineTests/MenuBarActionReceiptTests.swift
git commit -S -m "feat: add verified action receipts"
```

### Task 2: Add the bounded in-memory recovery ledger

**Files:**
- Create: `Sources/prismBarEngine/MenuBarRecoveryLedger.swift`
- Create: `Tests/prismBarEngineTests/MenuBarRecoveryLedgerTests.swift`

**Interfaces:**
- Consumes: `MenuBarActionID`, `MenuBarActionKind`, `MenuBarActionReceipt`, and `MenuBarSnapshot`.
- Produces: `MenuBarRecoveryEntry` and `MenuBarRecoveryLedger`.
- `MenuBarRecoveryLedger.begin(kind:before:)` returns a verifying receipt.
- `MenuBarRecoveryLedger.complete(id:result:after:)` returns the terminal receipt.
- `MenuBarRecoveryLedger.latestCompatible(with:)` returns only an entry whose item and surface sets match the current snapshot.

- [x] **Step 1: Write failing bounded-ledger tests**

Tests must prove:

- identifiers increase monotonically inside one ledger
- incomplete operations are not recoverable
- only successful or partial operations with a verified after-snapshot become recovery candidates
- the ledger retains the newest ten completed entries
- compatibility requires equal item-ID sets and equal surface-ID sets
- `clear()` removes pending and completed data

Use synthetic snapshots containing `fixture.visible`, `fixture.hidden`, and `fixture.divider` only.

- [x] **Step 2: Run the ledger tests and verify the missing-type failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter MenuBarRecoveryLedgerTests
```

Expected: compilation fails because `MenuBarRecoveryLedger` does not exist.

- [x] **Step 3: Implement the minimal bounded ledger**

```swift
public struct MenuBarRecoveryEntry: Equatable, Sendable {
    public let receipt: MenuBarActionReceipt
    public let before: MenuBarSnapshot
    public let after: MenuBarSnapshot
}

public struct MenuBarRecoveryLedger: Sendable {
    public static let maximumEntries = 10

    private var nextIdentifier: UInt64 = 1
    private var pending: [MenuBarActionID: PendingAction] = [:]
    public private(set) var entries: [MenuBarRecoveryEntry] = []
}
```

The implementation must not conform to `Codable`, must not use `UserDefaults`, and must remove pending state after every completion attempt.

- [x] **Step 4: Run focused and complete package tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter MenuBarRecoveryLedgerTests
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
```

Expected: focused ledger tests pass and all package tests pass.

- [x] **Step 5: Commit the recovery ledger**

```bash
git add Sources/prismBarEngine/MenuBarRecoveryLedger.swift Tests/prismBarEngineTests/MenuBarRecoveryLedgerTests.swift
git commit -S -m "feat: add bounded recovery ledger"
```

### Task 3: Bind AppModel action state to receipts

**Files:**
- Modify: `App/AppState.swift`
- Modify: `App/AppModel.swift`
- Modify: `App/AppModel+MenuBarActions.swift`
- Modify: `Tests/prismBarAppTests/AppModelActionFeedbackTests.swift`

**Interfaces:**
- Consumes: `MenuBarRecoveryLedger` and `MenuBarActionReceipt`.
- Produces: `AppModel.currentActionReceipt` and `AppModel.canRecoverLastAction`.
- Existing `menuBarActionState` remains a compatibility projection until Rail and prismDeck migrate in the next plan.

- [x] **Step 1: Write failing AppModel receipt tests**

Add tests proving:

- manual refresh clears only the visible receipt, not ledger history
- permission revocation clears both the current receipt and ledger
- a successful action result projects to `MenuBarActionState.result`
- a verifying receipt projects to `MenuBarActionState.moving`

Use an internal test initializer for `AppModel` with injected defaults and a test ledger. Do not mutate `AppModel.shared` across tests.

- [x] **Step 2: Run the AppModel tests and verify the expected failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodegen generate
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild test -project prismBar.xcodeproj -scheme prismBar -destination 'platform=macOS,arch=arm64' -only-testing:prismBarAppTests/AppModelActionFeedbackTests CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because the receipt-backed AppModel interface does not exist.

- [x] **Step 3: Implement receipt-backed application state**

Keep the domain ledger private to `AppModel`. Expose only the current receipt and the boolean recovery capability. Clear the ledger synchronously when Accessibility trust is lost.

- [x] **Step 4: Route direct moves through the ledger**

Before revealing the hidden section, call `begin(kind: .directMove, before: displayedSnapshot)`. Complete the entry only with a verified snapshot. Failures without verified topology create a visible blocked receipt but no recovery entry.

- [x] **Step 5: Run focused AppModel tests and all package tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild test -project prismBar.xcodeproj -scheme prismBar -destination 'platform=macOS,arch=arm64' -only-testing:prismBarAppTests/AppModelActionFeedbackTests CODE_SIGNING_ALLOWED=NO
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
```

Expected: focused app tests and all package tests pass.

- [x] **Step 6: Commit the AppModel integration**

```bash
git add App/AppState.swift App/AppModel.swift App/AppModel+MenuBarActions.swift Tests/prismBarAppTests/AppModelActionFeedbackTests.swift
git commit -S -m "refactor: route menu actions through receipts"
```

### Task 4: Reconcile product, architecture, security, and implementation contracts

**Files:**
- Modify: `docs/PRODUCT-BRIEF.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/SECURITY-MODEL.md`
- Modify: `docs/IMPLEMENTATION-PLAN.md`
- Modify: `README.md`

**Interfaces:**
- Documents the implemented receipt and process-local recovery behavior.
- Records the direct-distribution decision and rejects the failed Mac App Store organizer as a shipping alternative.

- [x] **Step 1: Update the five contracts from current code truth**

Required statements:

- prismBar is the real menu-bar manager
- direct distribution is required for the full product
- receipts are typed and process-local
- recovery snapshots never persist or cross XPC
- Prism Cards follow core menu-bar completion
- persistent Scenes remain privacy-gated future work

- [x] **Step 2: Run documentation and public-safety audits**

Run:

```bash
./scripts/audit-public-safety.sh
./scripts/audit-licensing.sh
rg -n "Prism Rail|Prism Deck|prismbar|PrismBar|prism bar" README.md docs App Sources Tests
```

Expected: audits pass. Search results contain only approved infrastructure identifiers, historical evidence, or exact `prismBar`, `prismDeck`, and `Rail` copy.

- [x] **Step 3: Run the complete phase gate**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodegen generate
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project prismBar.xcodeproj -scheme prismBar -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
git diff --check
git status --short
```

Expected: all tests pass, unsigned app build exits zero, no diff errors, and only the intended documentation changes remain.

- [x] **Step 4: Commit the reconciled contracts**

```bash
git add README.md docs/PRODUCT-BRIEF.md docs/ARCHITECTURE.md docs/SECURITY-MODEL.md docs/IMPLEMENTATION-PLAN.md
git commit -S -m "docs: define verified prismBar rebuild"
```

## Self-review

- Spec coverage: action lifecycle, privacy boundary, ledger limit, trust-loss clearing, direct distribution, and plugin ordering are mapped to tasks.
- Placeholder scan: no `TBD`, `TODO`, generic error-handling instruction, or undefined follow-up remains.
- Type consistency: Tasks 1 through 3 use the same receipt, identifier, phase, ledger, and AppModel property names.
- Scope boundary: recovery planning, Rail UI, prismDeck UI, Scenes, and Prism Cards are deliberately separate implementation plans after this foundation passes.
