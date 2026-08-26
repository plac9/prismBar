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
