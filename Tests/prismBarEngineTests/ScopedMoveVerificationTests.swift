// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarCore
@testable import prismBarEngine
import Testing

@Suite("Scoped menu item move verification")
struct ScopedMoveVerificationTests {
    @Test("ignores unrelated section churn while preserving direct move anchors")
    func ignoresUnrelatedSectionChurn() async throws {
        let planned = sectionedSnapshot(
            hiddenNames: ["transient"],
            visibleNames: ["one", "two", "three"],
            generation: 1
        )
        let current = sectionedSnapshot(
            hiddenNames: [],
            visibleNames: ["one", "two", "three"],
            generation: 2
        )
        let verified = sectionedSnapshot(
            hiddenNames: ["returned"],
            visibleNames: ["three", "one", "two"],
            generation: 3
        )
        let destinationIndex = try #require(
            planned.items.firstIndex(where: { $0.id == id("one") })
        )
        let plan = try MovePlanner().plan(
            item: id("three"),
            to: destinationIndex,
            in: planned
        )
        let performer = ScopedRecordingMovePerformer()
        let coordinator = VerifiedMoveCoordinator(
            reader: ScopedSnapshotSequenceReader(snapshots: [current, verified]),
            performer: performer
        )

        let outcome = await coordinator.execute(plan)

        #expect(outcome == .success)
        #expect(await performer.executionCount == 1)
        #expect(await performer.destinationFrame?.minX == 30)
        #expect(await performer.insertionEdge == .before)
    }

    @Test("rejects churn inside the moved section before producing input")
    func rejectsMovedSectionChurn() async throws {
        let planned = sectionedSnapshot(
            hiddenNames: ["hidden"],
            visibleNames: ["one", "two", "three"],
            generation: 1
        )
        let changed = sectionedSnapshot(
            hiddenNames: [],
            visibleNames: ["one", "new", "two", "three"],
            generation: 2
        )
        let destinationIndex = try #require(
            planned.items.firstIndex(where: { $0.id == id("one") })
        )
        let plan = try MovePlanner().plan(
            item: id("three"),
            to: destinationIndex,
            in: planned
        )
        let performer = ScopedRecordingMovePerformer()
        let coordinator = VerifiedMoveCoordinator(
            reader: ScopedSnapshotSequenceReader(snapshots: [changed]),
            performer: performer
        )

        let outcome = await coordinator.execute(plan)

        #expect(outcome == .topologyChanged)
        #expect(await performer.executionCount == 0)
    }

    @Test("reports partial movement using the item section position")
    func reportsSectionLocalPartialMovement() async throws {
        let initial = sectionedSnapshot(
            hiddenNames: ["hidden"],
            visibleNames: ["one", "two", "three", "four"],
            generation: 1
        )
        let partial = sectionedSnapshot(
            hiddenNames: ["hidden", "new-hidden"],
            visibleNames: ["one", "four", "two", "three"],
            generation: 2
        )
        let destinationIndex = try #require(
            initial.items.firstIndex(where: { $0.id == id("one") })
        )
        let plan = try MovePlanner().plan(
            item: id("four"),
            to: destinationIndex,
            in: initial
        )
        let coordinator = VerifiedMoveCoordinator(
            reader: ScopedSnapshotSequenceReader(snapshots: [initial, partial]),
            performer: ScopedRecordingMovePerformer()
        )

        let outcome = await coordinator.execute(plan)

        #expect(outcome == .partial(observedIndex: 1))
    }

    @Test("accepts exact target placement while an unrelated post-input identity changes")
    func acceptsAnchoredPlacementAfterUnrelatedIdentityChurn() async throws {
        let initial = sectionedSnapshot(
            hiddenNames: [],
            visibleNames: ["one", "two", "three", "four"],
            generation: 1
        )
        let observed = sectionedSnapshot(
            hiddenNames: [],
            visibleNames: ["four", "one", "replacement", "three"],
            generation: 2
        )
        let destinationIndex = try #require(
            initial.items.firstIndex(where: { $0.id == id("one") })
        )
        let plan = try MovePlanner().plan(
            item: id("four"),
            to: destinationIndex,
            in: initial
        )
        let coordinator = VerifiedMoveCoordinator(
            reader: ScopedSnapshotSequenceReader(snapshots: [initial, observed]),
            performer: ScopedRecordingMovePerformer()
        )

        let result = await coordinator.executeWithObservation(plan)

        #expect(result.outcome == .success)
        #expect(result.verifiedSnapshot == observed)
    }

    @Test("retries an anchored placement until the menu bar section is observable")
    func retriesAnchoredPlacementWithoutDivider() async throws {
        let initial = sectionedSnapshot(
            hiddenNames: [],
            visibleNames: ["one", "two", "three", "four"],
            generation: 1
        )
        let stable = sectionedSnapshot(
            hiddenNames: [],
            visibleNames: ["four", "one", "two", "three"],
            generation: 3
        )
        let missingDivider = MenuBarSnapshot(
            generation: 2,
            items: stable.items.filter { $0.role != .hiddenSectionDivider },
            unavailableSourceCount: 1
        )
        let destinationIndex = try #require(
            initial.items.firstIndex(where: { $0.id == id("one") })
        )
        let plan = try MovePlanner().plan(
            item: id("four"),
            to: destinationIndex,
            in: initial
        )
        let coordinator = VerifiedMoveCoordinator(
            reader: ScopedSnapshotSequenceReader(snapshots: [initial, missingDivider, stable]),
            performer: ScopedRecordingMovePerformer()
        )

        let result = await coordinator.executeWithObservation(plan)

        #expect(result.outcome == .success)
        #expect(result.verifiedSnapshot == stable)
    }

    @Test("rejects target placement when surviving anchors are scrambled")
    func rejectsScrambledSurvivingAnchors() async throws {
        let initial = sectionedSnapshot(
            hiddenNames: [],
            visibleNames: ["one", "two", "three", "four"],
            generation: 1
        )
        let scrambled = sectionedSnapshot(
            hiddenNames: [],
            visibleNames: ["four", "one", "three", "two"],
            generation: 2
        )
        let destinationIndex = try #require(
            initial.items.firstIndex(where: { $0.id == id("one") })
        )
        let plan = try MovePlanner().plan(
            item: id("four"),
            to: destinationIndex,
            in: initial
        )
        let coordinator = VerifiedMoveCoordinator(
            reader: ScopedSnapshotSequenceReader(snapshots: [initial, scrambled]),
            performer: ScopedRecordingMovePerformer()
        )

        let result = await coordinator.executeWithObservation(plan)

        #expect(result.outcome == .partial(observedIndex: 0))
        #expect(result.verifiedSnapshot == scrambled)
    }
}

private actor ScopedSnapshotSequenceReader: MenuBarSnapshotReading {
    private var snapshots: [MenuBarSnapshot]

    init(snapshots: [MenuBarSnapshot]) {
        self.snapshots = snapshots
    }

    func snapshot(deadline _: OperationDeadline) throws -> MenuBarSnapshot {
        guard !snapshots.isEmpty else {
            throw VerifiedMoveError.observationFailed
        }
        return snapshots.removeFirst()
    }
}

private actor ScopedRecordingMovePerformer: MenuBarMovePerforming {
    private(set) var executionCount = 0
    private(set) var destinationFrame: MenuBarItemFrame?
    private(set) var insertionEdge: MenuBarInsertionEdge?

    func move(
        source _: MenuBarItemFrame,
        destination: MenuBarItemFrame,
        insertionEdge: MenuBarInsertionEdge,
        deadline _: OperationDeadline
    ) {
        executionCount += 1
        destinationFrame = destination
        self.insertionEdge = insertionEdge
    }
}
