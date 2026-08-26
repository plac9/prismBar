# Operation Deadline and Movement Safety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every prismBar observation and move obey one real monotonic deadline while guaranteeing input cleanup and direct multi-position movement.

**Architecture:** Create one `OperationDeadline` in the engine for each requested move and propagate it through discovery, native Accessibility calls, input preparation, input posting, and verification. Replace task-group timeout races and blocking sleeps with deadline-aware production dependencies, while keeping typed outcomes and deterministic test seams.

**Tech Stack:** Swift 6.2, Swift Testing, `ContinuousClock`, ApplicationServices Accessibility APIs, CoreGraphics input events, macOS 27 SDK

**Spec:** `docs/superpowers/specs/2026-08-26-production-remediation-design.md`

## Global Constraints

- The deployment target is exactly macOS 27.0.
- Human-facing product casing is exactly `prismBar`.
- No third-party runtime dependency may be added.
- No observed menu label, process identity, bundle identifier, coordinate, pointer position, path, environment value, or private identifier may be logged.
- A move uses one drag to the requested insertion edge, never repeated one-position moves.
- No ordinary input event may be posted after deadline expiry.
- Mouse-up and pointer restoration remain mandatory after a posted button-down.
- MPL 2.0 notices remain on every covered Swift source file.

---

### Task 1: Monotonic operation deadline

**Files:**
- Create: `Sources/prismBarCore/OperationDeadline.swift`
- Create: `Tests/prismBarCoreTests/OperationDeadlineTests.swift`

**Interfaces:**
- Consumes: Swift `ContinuousClock.Instant` and `Duration`
- Produces: `OperationDeadline`, `OperationDeadlineError.expired`, `remaining`, `check()`, and `accessibilityTimeout(maximum:)`

- [ ] **Step 1: Write failing deadline tests**

Add deterministic tests using explicit instants:

```swift
@Test("remaining budget clamps at zero")
func remainingBudgetClampsAtZero() {
    let clock = ContinuousClock()
    let start = clock.now
    let deadline = OperationDeadline(expiresAt: start.advanced(by: .seconds(2)))

    #expect(deadline.remaining(at: start) == .seconds(2))
    #expect(deadline.remaining(at: start.advanced(by: .seconds(3))) == .zero)
}

@Test("Accessibility timeout never exceeds remaining budget")
func boundsAccessibilityTimeout() throws {
    let clock = ContinuousClock()
    let start = clock.now
    let deadline = OperationDeadline(expiresAt: start.advanced(by: .milliseconds(80)))

    #expect(try deadline.accessibilityTimeout(at: start, maximum: .milliseconds(250)) == 0.08)
    #expect(throws: OperationDeadlineError.expired) {
        try deadline.accessibilityTimeout(at: start.advanced(by: .milliseconds(80)), maximum: .milliseconds(250))
    }
}
```

- [ ] **Step 2: Run the tests and verify the missing type failure**

Run:

```bash
xcrun swift test --filter OperationDeadlineTests
```

Expected: compilation fails because `OperationDeadline` is not defined.

- [ ] **Step 3: Implement the immutable deadline value**

Implement a sendable value using one absolute `ContinuousClock.Instant`:

```swift
public enum OperationDeadlineError: Error, Equatable, Sendable {
    case expired
}

public struct OperationDeadline: Sendable {
    public let expiresAt: ContinuousClock.Instant

    public init(expiresAt: ContinuousClock.Instant) {
        self.expiresAt = expiresAt
    }

    public init(timeout: Duration, now: ContinuousClock.Instant = .now) {
        expiresAt = now.advanced(by: max(.zero, timeout))
    }

    public func remaining(at now: ContinuousClock.Instant = .now) -> Duration {
        max(.zero, now.duration(to: expiresAt))
    }

    public func check(at now: ContinuousClock.Instant = .now) throws {
        guard now < expiresAt else { throw OperationDeadlineError.expired }
    }

    public func accessibilityTimeout(
        at now: ContinuousClock.Instant = .now,
        maximum: Duration
    ) throws -> Float {
        try check(at: now)
        let bounded = min(remaining(at: now), maximum)
        let seconds = Double(bounded.components.seconds) +
            Double(bounded.components.attoseconds) / 1_000_000_000_000_000_000
        return Float(max(0.001, seconds))
    }
}
```

- [ ] **Step 4: Run core tests**

Run:

```bash
xcrun swift test --filter OperationDeadlineTests
```

Expected: all deadline tests pass.

- [ ] **Step 5: Commit the deadline primitive**

```bash
git add Sources/prismBarCore/OperationDeadline.swift Tests/prismBarCoreTests/OperationDeadlineTests.swift
git commit -S -m "engine: add monotonic operation deadline"
```

### Task 2: Propagate one deadline through the coordinator

**Files:**
- Modify: `Sources/prismBarCore/MenuBarTopology.swift`
- Modify: `Sources/prismBarEngine/VerifiedMoveCoordinator.swift`
- Modify: `Tests/prismBarEngineTests/VerifiedMoveCoordinatorTests.swift`
- Modify: conformers found by `rg -n 'MenuBarSnapshotReading|MenuBarMovePerforming' App Sources Tests`

**Interfaces:**
- Consumes: `OperationDeadline`
- Produces: `MenuBarSnapshotReading.snapshot(deadline:)` and `MenuBarMovePerforming.move(source:destination:insertionEdge:deadline:)`

- [ ] **Step 1: Write failing shared-budget tests**

Replace test doubles with deadline-recording actors and add assertions that both reads and the move receive the same `expiresAt`:

```swift
private actor DeadlineRecordingReader: MenuBarSnapshotReading {
    private var values: [MenuBarSnapshot]
    private(set) var deadlines: [ContinuousClock.Instant] = []

    init(_ values: [MenuBarSnapshot]) { self.values = values }

    func snapshot(deadline: OperationDeadline) throws -> MenuBarSnapshot {
        deadlines.append(deadline.expiresAt)
        return values.removeFirst()
    }
}

@Test("shares one absolute deadline across read move and verification")
func sharesOneDeadline() async {
    let reader = DeadlineRecordingReader([sourceSnapshot, expectedSnapshot])
    let performer = DeadlineRecordingPerformer()
    let coordinator = VerifiedMoveCoordinator(reader: reader, performer: performer)

    #expect(await coordinator.execute(plan) == .success)
    let readDeadlines = await reader.deadlines
    #expect(readDeadlines.count == 2)
    #expect(readDeadlines[0] == readDeadlines[1])
    #expect(await performer.deadline == readDeadlines[0])
}
```

Add a regression fake that blocks past its deadline and prove the result is returned only after the fake completes, without leaving hidden work. This documents the coordinator boundary while production dependencies become bounded at their sources.

- [ ] **Step 2: Run the coordinator tests and verify protocol failures**

```bash
xcrun swift test --filter VerifiedMoveCoordinatorTests
```

Expected: compilation fails because the protocols do not accept a deadline.

- [ ] **Step 3: Change protocols and remove task-group timeout races**

Use these exact signatures:

```swift
public protocol MenuBarSnapshotReading: Sendable {
    func snapshot(deadline: OperationDeadline) async throws -> MenuBarSnapshot
}

public protocol MenuBarMovePerforming: Sendable {
    func move(
        source: MenuBarItemFrame,
        destination: MenuBarItemFrame,
        insertionEdge: MenuBarInsertionEdge,
        deadline: OperationDeadline
    ) async throws
}
```

In `execute`, create the deadline once:

```swift
let deadline = OperationDeadline(timeout: operationTimeout)
let current = try await reader.snapshot(deadline: deadline)
try deadline.check()
try await performer.move(
    source: sourceFrame,
    destination: destinationFrame,
    insertionEdge: insertionEdge,
    deadline: deadline
)
try deadline.check()
let observed = try await reader.snapshot(deadline: deadline)
```

Map `OperationDeadlineError.expired` and `CancellationError` to `.timedOut`. Preserve all existing permission, input, observation, topology, unavailable-item, partial, and success mappings. Delete both `withTaskGroup` timeout races.

- [ ] **Step 4: Run the coordinator and package tests**

```bash
xcrun swift test --filter VerifiedMoveCoordinatorTests
xcrun swift test
```

Expected: coordinator and full package tests pass with no orphan timeout tasks.

- [ ] **Step 5: Commit protocol propagation**

```bash
git add Sources App Tests
git commit -S -m "engine: propagate one move deadline"
```

### Task 3: Bound native Accessibility at each object

**Files:**
- Modify: `Sources/prismBarAccessibility/MenuBarTopologyDiscovery.swift`
- Modify: `Sources/prismBarAccessibility/NativeMenuBarObservationReader.swift`
- Create: `Tests/prismBarAccessibilityTests/AccessibilityDeadlineTests.swift`
- Modify: `Tests/prismBarAccessibilityTests/TopologyAssemblerTests.swift`

**Interfaces:**
- Consumes: `OperationDeadline`
- Produces: `MenuBarObservationReading.observations(for:deadline:)` and `MenuBarTopologyDiscovery.snapshot(applications:deadline:)`

- [ ] **Step 1: Write failing Accessibility boundary tests**

Extract an internal client seam and test call order without reading real menu content:

```swift
protocol AccessibilityElementClient: Sendable {
    func setTimeout(_ timeout: Float, on element: AXUIElement) throws
    func attribute(_ attribute: CFString, from element: AXUIElement) throws -> CFTypeRef?
}
```

Use a recording client with opaque synthetic AX application elements. Assert that every attribute read is immediately preceded by `setTimeout`, every timeout is positive and no greater than the remaining budget, and no attribute read starts after the controlled clock crosses expiry.

- [ ] **Step 2: Run Accessibility tests and verify the missing interface failure**

```bash
xcrun swift test --filter AccessibilityDeadlineTests
```

Expected: compilation fails because the reader lacks a deadline and client seam.

- [ ] **Step 3: Implement per-object deadline enforcement**

Change the observation protocol and discovery signatures:

```swift
func observations(
    for applications: [RunningApplicationDescriptor],
    deadline: OperationDeadline
) async throws -> MenuBarObservationBatch

func snapshot(
    applications: [RunningApplicationDescriptor],
    deadline: OperationDeadline
) async throws -> MenuBarSnapshot
```

Centralize protected reads:

```swift
private func attribute(
    _ name: CFString,
    from element: AXUIElement,
    deadline: OperationDeadline
) throws -> CFTypeRef? {
    let timeout = try deadline.accessibilityTimeout(maximum: Self.maximumAccessibilitySlice)
    try client.setTimeout(timeout, on: element)
    try deadline.check()
    return try client.attribute(name, from: element)
}
```

Pass the same deadline through application iteration, extras-menu retrieval, recursive child traversal, role, identifier, description, title, enabled, position, and size reads. Configure every child before querying its attributes. Stop traversal immediately on deadline expiry or permission revocation. Keep depth, per-application element, total observation, and application limits.

- [ ] **Step 4: Run Accessibility and package tests**

```bash
xcrun swift test --filter AccessibilityDeadlineTests
xcrun swift test --filter MenuBarTopologyDiscoveryTests
xcrun swift test
```

Expected: all tests pass, including expiry and partial-source behavior.

- [ ] **Step 5: Commit bounded observation**

```bash
git add Sources/prismBarAccessibility Tests/prismBarAccessibilityTests
git commit -S -m "accessibility: enforce deadline per AX object"
```

### Task 4: Make native drag execution deadline-safe

**Files:**
- Modify: `Sources/prismBarAccessibility/NativeMenuBarMovePerformer.swift`
- Modify: `Tests/prismBarAccessibilityTests/MenuBarDragGeometryTests.swift`
- Create: `Tests/prismBarAccessibilityTests/MenuBarInputDeadlineTests.swift`

**Interfaces:**
- Consumes: `OperationDeadline`
- Produces: internal `MenuBarInputEventPosting`, `MenuBarDragStage`, and deadline-aware drag lifecycle

- [ ] **Step 1: Write failing event-sequence tests**

Introduce an injected poster and sleeper so tests record events without controlling the Mac:

```swift
enum MenuBarDragStage: Equatable, Sendable {
    case position, press, midpoint, endpoint, release, restore
}

protocol MenuBarInputEventPosting: Sendable {
    func post(_ event: CGEvent, stage: MenuBarDragStage)
}
```

Add tests for success, expiry before press, expiry after press, cancellation after midpoint, and injected endpoint failure. Expected sequences include:

```swift
#expect(recorder.stages == [.position, .press, .midpoint, .endpoint, .release, .restore])
#expect(expiredAfterPress.stages == [.position, .press, .release, .restore])
#expect(expiredBeforePress.stages == [.position])
```

Also assert that a destination several positions away still generates one press, one endpoint, and one release.

- [ ] **Step 2: Run the input tests and verify failure**

```bash
xcrun swift test --filter MenuBarInputDeadlineTests
```

Expected: compilation fails because event posting and suspension are not injectable or deadline-aware.

- [ ] **Step 3: Implement the async drag state machine**

Replace `Thread.sleep` with a helper that checks the remaining deadline before and after suspension:

```swift
private func pause(_ duration: Duration, deadline: OperationDeadline) async throws {
    try deadline.check()
    guard deadline.remaining() >= duration else { throw OperationDeadlineError.expired }
    try await Task.sleep(for: duration)
    try deadline.check()
}
```

Before posting `.position`, `.press`, `.midpoint`, and `.endpoint`, call `deadline.check()`. Track `didPress` and `didCleanUp`. In a `defer`-backed or explicit catch path, post `.release` only when `didPress`, then always post `.restore` after any started sequence. Cleanup bypasses the ordinary deadline check and is idempotent. Remove all `Thread.sleep` calls.

- [ ] **Step 4: Run input, engine, and sanitizer-ready tests**

```bash
xcrun swift test --filter MenuBarInputDeadlineTests
xcrun swift test --filter MenuBarDrag
xcrun swift test
```

Expected: every event-sequence assertion passes and the complete package remains green.

- [ ] **Step 5: Commit deadline-safe input**

```bash
git add Sources/prismBarAccessibility Tests/prismBarAccessibilityTests
git commit -S -m "accessibility: make drag input deadline safe"
```

### Task 5: Integrate the live controller and prove movement regression

**Files:**
- Modify: `App/LiveMenuBarController.swift`
- Modify: `App/AppModel+MenuBarActions.swift`
- Modify: `Tests/prismBarEngineTests/VerifiedMoveCoordinatorTests.swift`
- Modify: `Tests/prismBarAccessibilityTests/TopologyAssemblerTests.swift`

**Interfaces:**
- Consumes: deadline-aware discovery, coordinator, and performer
- Produces: a live snapshot reader that forwards the same deadline and verified direct-move results

- [ ] **Step 1: Add failing integration assertions**

Add an engine test where an item moves from index 0 to index 4 and verification receives the expected full order. Add a live-reader unit seam that records the deadline passed into discovery.

```swift
#expect(await coordinator.execute(longDistancePlan) == .success)
#expect(await performer.executionCount == 1)
#expect(await reader.receivedDeadlines.allSatisfy { $0 == reader.receivedDeadlines.first })
```

- [ ] **Step 2: Run focused tests and verify integration failures**

```bash
xcrun swift test --filter VerifiedMoveCoordinatorTests
```

Expected: live adapter or test conformers fail until they forward the deadline.

- [ ] **Step 3: Wire the live adapter**

Update the live snapshot reader to use:

```swift
func snapshot(deadline: OperationDeadline) async throws -> MenuBarSnapshot {
    let applications = await RunningApplicationCatalog.current()
    return try await discovery.snapshot(applications: applications, deadline: deadline)
}
```

Keep the existing one-call `MovePlanner` path for any destination index. Do not add loops that decompose a move by distance.

- [ ] **Step 4: Run the full engine gate**

```bash
xcrun swift test
./scripts/audit-public-safety.sh
./scripts/audit-licensing.sh
```

Expected: all package tests and both audits pass.

- [ ] **Step 5: Commit engine integration**

```bash
git add App Sources Tests
git commit -S -m "engine: integrate verified deadline movement"
```

