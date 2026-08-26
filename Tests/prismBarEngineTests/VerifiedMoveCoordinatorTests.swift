// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarCore
@testable import prismBarEngine
import Testing

@Suite("Verified menu item moves")
struct VerifiedMoveCoordinatorTests {
    @Test("executes one direct drag and verifies the resulting order")
    func verifiesDirectMove() async throws {
        let initial = snapshot(names: ["one", "two", "three", "four"], generation: 1)
        let expected = snapshot(names: ["four", "one", "two", "three"], generation: 2)
        let plan = try MovePlanner().plan(item: id("four"), to: 0, in: initial)
        let reader = SnapshotSequenceReader(snapshots: [initial, expected])
        let performer = RecordingMovePerformer()
        let coordinator = VerifiedMoveCoordinator(reader: reader, performer: performer)

        let outcome = await coordinator.execute(plan)

        #expect(outcome == .success)
        #expect(await performer.executionCount == 1)
    }

    @Test("rejects a stale plan before producing input")
    func rejectsStalePlan() async throws {
        let planned = snapshot(names: ["one", "two", "three"], generation: 1)
        let changed = snapshot(names: ["one", "new", "two", "three"], generation: 2)
        let plan = try MovePlanner().plan(item: id("three"), to: 0, in: planned)
        let reader = SnapshotSequenceReader(snapshots: [changed])
        let performer = RecordingMovePerformer()
        let coordinator = VerifiedMoveCoordinator(reader: reader, performer: performer)

        let outcome = await coordinator.execute(plan)

        #expect(outcome == .topologyChanged)
        #expect(await performer.executionCount == 0)
    }

    @Test("reports the observed index when movement is only partial")
    func reportsPartialMovement() async throws {
        let initial = snapshot(names: ["one", "two", "three", "four"], generation: 1)
        let partial = snapshot(names: ["one", "four", "two", "three"], generation: 2)
        let plan = try MovePlanner().plan(item: id("four"), to: 0, in: initial)
        let coordinator = VerifiedMoveCoordinator(
            reader: SnapshotSequenceReader(snapshots: [initial, partial]),
            performer: RecordingMovePerformer()
        )

        let outcome = await coordinator.execute(plan)

        #expect(outcome == .partial(observedIndex: 1))
    }

    @Test("moves between visible targets while preserving partial topology status")
    func movesWithinPartialTopology() async throws {
        let complete = snapshot(names: ["one", "two"], generation: 1)
        let incompleteInitial = MenuBarSnapshot(
            generation: 2,
            items: complete.items,
            unavailableSourceCount: 1
        )
        let movedItems = snapshot(names: ["two", "one"], generation: 3).items
        let incompleteResult = MenuBarSnapshot(
            generation: 3,
            items: movedItems,
            unavailableSourceCount: 1
        )
        let plan = try MovePlanner().plan(item: id("two"), to: 0, in: complete)
        let performer = RecordingMovePerformer()
        let coordinator = VerifiedMoveCoordinator(
            reader: SnapshotSequenceReader(snapshots: [incompleteInitial, incompleteResult]),
            performer: performer
        )

        let outcome = await coordinator.execute(plan)

        #expect(outcome == .success)
        #expect(await performer.executionCount == 1)
    }

    @Test("reports permission revocation before producing input")
    func reportsRevocationBeforeInput() async throws {
        let initial = snapshot(names: ["one", "two"], generation: 1)
        let plan = try MovePlanner().plan(item: id("two"), to: 0, in: initial)
        let performer = RecordingMovePerformer()
        let coordinator = VerifiedMoveCoordinator(
            reader: FailingSnapshotReader(error: MenuBarAuthorizationError.permissionRevoked),
            performer: performer
        )

        let outcome = await coordinator.execute(plan)

        #expect(outcome == .permissionRevoked)
        #expect(await performer.executionCount == 0)
    }

    @Test("reports permission revocation while producing input")
    func reportsRevocationDuringInput() async throws {
        let initial = snapshot(names: ["one", "two"], generation: 1)
        let plan = try MovePlanner().plan(item: id("two"), to: 0, in: initial)
        let coordinator = VerifiedMoveCoordinator(
            reader: SnapshotSequenceReader(snapshots: [initial]),
            performer: FailingMovePerformer(error: MenuBarAuthorizationError.permissionRevoked)
        )

        #expect(await coordinator.execute(plan) == .permissionRevoked)
    }

    @Test("reports permission revocation during verification")
    func reportsRevocationDuringVerification() async throws {
        let initial = snapshot(names: ["one", "two"], generation: 1)
        let plan = try MovePlanner().plan(item: id("two"), to: 0, in: initial)
        let reader = SnapshotThenFailureReader(
            snapshot: initial,
            error: MenuBarAuthorizationError.permissionRevoked
        )
        let coordinator = VerifiedMoveCoordinator(
            reader: reader,
            performer: RecordingMovePerformer()
        )

        #expect(await coordinator.execute(plan) == .permissionRevoked)
    }

    @Test("reports bounded failures without retrying input")
    func reportsBoundedFailuresWithoutRetries() async throws {
        let initial = snapshot(names: ["one", "two"], generation: 1)
        let plan = try MovePlanner().plan(item: id("two"), to: 0, in: initial)

        let observationPerformer = RecordingMovePerformer()
        let observationCoordinator = VerifiedMoveCoordinator(
            reader: FailingSnapshotReader(error: VerifiedMoveError.observationFailed),
            performer: observationPerformer
        )
        #expect(await observationCoordinator.execute(plan) == .observationFailed)
        #expect(await observationPerformer.executionCount == 0)

        let inputPerformer = CountingFailingMovePerformer(error: VerifiedMoveError.inputFailed)
        let inputCoordinator = VerifiedMoveCoordinator(
            reader: SnapshotSequenceReader(snapshots: [initial]),
            performer: inputPerformer
        )
        #expect(await inputCoordinator.execute(plan) == .inputFailed)
        #expect(await inputPerformer.executionCount == 1)
    }

    @Test("reports an unavailable menu bar without retrying input")
    func reportsUnavailableMenuBar() async throws {
        let initial = snapshot(names: ["one", "two"], generation: 1)
        let plan = try MovePlanner().plan(item: id("two"), to: 0, in: initial)
        let performer = CountingFailingMovePerformer(error: MenuBarInputError.menuBarUnavailable)
        let coordinator = VerifiedMoveCoordinator(
            reader: SnapshotSequenceReader(snapshots: [initial]),
            performer: performer
        )

        #expect(await coordinator.execute(plan) == .menuBarUnavailable)
        #expect(await performer.executionCount == 1)
    }

    @Test("times out a stalled observation without producing input")
    func timesOutStalledObservation() async throws {
        let initial = snapshot(names: ["one", "two"], generation: 1)
        let plan = try MovePlanner().plan(item: id("two"), to: 0, in: initial)
        let performer = RecordingMovePerformer()
        let coordinator = VerifiedMoveCoordinator(
            reader: StalledSnapshotReader(),
            performer: performer,
            operationTimeout: .milliseconds(20)
        )

        #expect(await coordinator.execute(plan) == .timedOut)
        #expect(await performer.executionCount == 0)
    }

    @Test("times out stalled input without retrying or verifying")
    func timesOutStalledInput() async throws {
        let initial = snapshot(names: ["one", "two"], generation: 1)
        let plan = try MovePlanner().plan(item: id("two"), to: 0, in: initial)
        let reader = SnapshotSequenceReader(snapshots: [initial])
        let performer = StalledMovePerformer()
        let coordinator = VerifiedMoveCoordinator(
            reader: reader,
            performer: performer,
            operationTimeout: .milliseconds(20)
        )

        #expect(await coordinator.execute(plan) == .timedOut)
        #expect(await performer.executionCount == 1)
        #expect(await reader.remainingCount == 0)
    }

    @Test("a no-op plan verifies fresh topology without producing input")
    func verifiesNoOpWithoutInput() async throws {
        let initial = snapshot(names: ["one", "two"], generation: 1)
        let verified = snapshot(names: ["one", "two"], generation: 2)
        let plan = try MovePlanner().plan(item: id("one"), to: 0, in: initial)
        let performer = RecordingMovePerformer()
        let coordinator = VerifiedMoveCoordinator(
            reader: SnapshotSequenceReader(snapshots: [initial, verified]),
            performer: performer
        )

        #expect(await coordinator.execute(plan) == .success)
        #expect(await performer.executionCount == 0)
    }

    @Test("missing geometry never produces input")
    func rejectsMissingGeometry() async throws {
        let planned = snapshot(names: ["one", "two"], generation: 1)
        let current = MenuBarSnapshot(
            generation: 2,
            items: planned.items.map { item in
                MenuBarItem(
                    id: item.id,
                    position: item.position,
                    isMovable: item.isMovable,
                    displayName: item.displayName,
                    frame: item.id == id("two") ? nil : item.frame
                )
            }
        )
        let plan = try MovePlanner().plan(item: id("two"), to: 0, in: planned)
        let performer = RecordingMovePerformer()
        let coordinator = VerifiedMoveCoordinator(
            reader: SnapshotSequenceReader(snapshots: [current]),
            performer: performer
        )

        #expect(await coordinator.execute(plan) == .itemUnavailable)
        #expect(await performer.executionCount == 0)
    }

    private func snapshot(names: [String], generation: UInt64) -> MenuBarSnapshot {
        MenuBarSnapshot(
            generation: generation,
            items: names.enumerated().map { index, name in
                MenuBarItem(
                    id: id(name),
                    position: index,
                    isMovable: true,
                    displayName: name,
                    frame: MenuBarItemFrame(
                        minX: Double(index * 30),
                        minY: 0,
                        width: 24,
                        height: 24
                    )
                )
            }
        )
    }

    private func id(_ value: String) -> MenuBarItemID {
        MenuBarItemID(rawValue: value)
    }
}

private actor SnapshotSequenceReader: MenuBarSnapshotReading {
    private var snapshots: [MenuBarSnapshot]

    init(snapshots: [MenuBarSnapshot]) {
        self.snapshots = snapshots
    }

    func snapshot() throws -> MenuBarSnapshot {
        guard !snapshots.isEmpty else {
            throw VerifiedMoveError.observationFailed
        }
        return snapshots.removeFirst()
    }

    var remainingCount: Int {
        snapshots.count
    }
}

private struct StalledSnapshotReader: MenuBarSnapshotReading {
    func snapshot() async throws -> MenuBarSnapshot {
        try await Task.sleep(for: .seconds(30))
        throw VerifiedMoveError.observationFailed
    }
}

private actor RecordingMovePerformer: MenuBarMovePerforming {
    private(set) var executionCount = 0

    func move(
        source _: MenuBarItemFrame,
        destination _: MenuBarItemFrame,
        insertionEdge _: MenuBarInsertionEdge
    ) {
        executionCount += 1
    }
}

private struct FailingSnapshotReader: MenuBarSnapshotReading {
    let error: any Error & Sendable

    func snapshot() throws -> MenuBarSnapshot {
        throw error
    }
}

private actor SnapshotThenFailureReader: MenuBarSnapshotReading {
    private var snapshotValue: MenuBarSnapshot?
    private let error: any Error & Sendable

    init(snapshot: MenuBarSnapshot, error: any Error & Sendable) {
        snapshotValue = snapshot
        self.error = error
    }

    func snapshot() throws -> MenuBarSnapshot {
        guard let snapshotValue else { throw error }
        self.snapshotValue = nil
        return snapshotValue
    }
}

private struct FailingMovePerformer: MenuBarMovePerforming {
    let error: any Error & Sendable

    func move(
        source _: MenuBarItemFrame,
        destination _: MenuBarItemFrame,
        insertionEdge _: MenuBarInsertionEdge
    ) throws {
        throw error
    }
}

private actor CountingFailingMovePerformer: MenuBarMovePerforming {
    private(set) var executionCount = 0
    let error: any Error & Sendable

    init(error: any Error & Sendable) {
        self.error = error
    }

    func move(
        source _: MenuBarItemFrame,
        destination _: MenuBarItemFrame,
        insertionEdge _: MenuBarInsertionEdge
    ) throws {
        executionCount += 1
        throw error
    }
}

private actor StalledMovePerformer: MenuBarMovePerforming {
    private(set) var executionCount = 0

    func move(
        source _: MenuBarItemFrame,
        destination _: MenuBarItemFrame,
        insertionEdge _: MenuBarInsertionEdge
    ) async throws {
        executionCount += 1
        try await Task.sleep(for: .seconds(30))
    }
}
