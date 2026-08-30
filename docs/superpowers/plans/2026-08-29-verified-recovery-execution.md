# Verified Recovery Execution Plan

**Status:** Automated engine phase completed on 2026-08-29. Signed installed-app movement and recovery remain physical release gates.

**Goal:** Restore the latest compatible menu-bar layout through bounded, freshly planned, verified moves without persisting topology or weakening the Accessibility trust boundary.

**Architecture:** Recovery remains a host-only process-local operation. A pure engine planner compares the current snapshot with the retained before snapshot and emits at most one safe move at a time. The application observes again after every move, replans from current truth, and reports recovered only after the complete per-surface order matches.

**Tech stack:** Swift 6.4, strict concurrency, Swift Testing, Observation, macOS 27

## Constraints

- Product copy is exactly `prismBar`, `prismDeck`, and `Rail`.
- Recovery never moves a controller or divider.
- Recovery rejects missing items, changed roles, changed surfaces, unavailable items, and incomplete topology.
- Every input action uses the existing hard deadline and cleanup guarantees.
- Recovery stops on the first partial, blocked, revoked, unavailable, or timed-out result.
- Recovery snapshots and plans remain in host-process memory only.
- Tests use synthetic identifiers and content only.

## Task 1: Add the incremental recovery planner

**Files:**

- Create `Sources/prismBarEngine/MenuBarRecoveryPlanner.swift`.
- Create `Tests/prismBarEngineTests/MenuBarRecoveryPlannerTests.swift`.

**Tests must prove:**

- an already restored topology produces no move
- a multi-position reorder produces one direct move
- a hidden-to-visible mismatch plans one divider-crossing move
- multiple displays are reconciled independently
- controllers and dividers are never selected as the moving item
- changed item sets, roles, surfaces, incomplete snapshots, or unavailable targets fail closed
- repeatedly applying the next expected order converges to the retained before order within the movable-item count

Run the focused test first and observe the missing-type failure. Implement only the pure incremental planner, then run the focused and complete package suites.

Commit as `feat: plan verified menu bar recovery`.

## Task 2: Add one-shot ledger recovery ownership

**Files:**

- Modify `Sources/prismBarEngine/MenuBarRecoveryLedger.swift`.
- Modify `Tests/prismBarEngineTests/MenuBarRecoveryLedgerTests.swift`.

Add APIs that return the latest compatible entry and consume it only after a verified recovered receipt is recorded. A blocked recovery leaves the candidate available only when the current topology still matches its verified after snapshot. Trust loss clears all state.

Commit as `feat: add recovery ledger completion`.

## Task 3: Execute recovery through AppModel

**Files:**

- Modify `App/AppModel.swift`.
- Modify `App/AppModel+MenuBarActions.swift`.
- Modify `Tests/prismBarAppTests/AppModelActionFeedbackTests.swift`.

Add one public application action for recovering the latest compatible entry. It begins a `.recovery` receipt, observes current topology, asks the planner for one move, executes it with verification, and repeats from a fresh observation. A hard move-count bound prevents cycles. Only an exact restored snapshot produces `.recovered`.

Route section, batch, and reset operations through the same receipt projection without changing their existing verified movement semantics.

Commit as `feat: execute verified menu bar recovery`.

## Task 4: Verify the engine phase

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild test -project prismBar.xcodeproj -scheme prismBar -destination 'platform=macOS,arch=arm64' -only-testing:prismBarAppTests CODE_SIGNING_ALLOWED=NO
./scripts/audit-public-safety.sh
./scripts/audit-licensing.sh
git diff --check
```

Update `docs/IMPLEMENTATION-PLAN.md` only for directly proved recovery gates. Do not mark physical installed-app recovery complete from automated evidence.

Commit as `docs: record verified recovery engine`.
