// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarCore
@testable import prismBarEngine
import Testing

@Suite("Verified menu item section moves")
struct SectionMoveVerificationTests {
    @Test("accepts a section move when macOS chooses another slot in the requested section")
    func acceptsVerifiedSectionMove() async throws {
        let initial = sectionSnapshot(
            names: ["hidden", "divider", "visible", "moving"],
            generation: 1
        )
        let observed = sectionSnapshot(
            names: ["moving", "hidden", "divider", "visible"],
            generation: 2
        )
        let plan = try SectionMovePlanner().plan(item: id("moving"), to: .hidden, in: initial)
        let coordinator = VerifiedMoveCoordinator(
            reader: SectionSnapshotSequenceReader(snapshots: [initial, observed]),
            performer: SectionRecordingMovePerformer()
        )

        let result = await coordinator.executeWithObservation(plan)

        #expect(result.outcome == .success)
        #expect(result.verifiedSnapshot == observed)
    }

    @Test("waits for macOS to settle a section move before reporting failure")
    func waitsForSettledSectionMove() async throws {
        let initial = sectionSnapshot(
            names: ["hidden", "divider", "visible", "moving"],
            generation: 1
        )
        let intermediate = sectionSnapshot(
            names: ["hidden", "divider", "moving", "visible"],
            generation: 2
        )
        let settled = sectionSnapshot(
            names: ["moving", "hidden", "divider", "visible"],
            generation: 3
        )
        let plan = try SectionMovePlanner().plan(item: id("moving"), to: .hidden, in: initial)
        let coordinator = VerifiedMoveCoordinator(
            reader: SectionSnapshotSequenceReader(snapshots: [initial, intermediate, settled]),
            performer: SectionRecordingMovePerformer()
        )

        let result = await coordinator.executeWithObservation(plan)

        #expect(result.outcome == .success)
        #expect(result.verifiedSnapshot == settled)
    }

    @Test("ignores unrelated source churn before a section move")
    func ignoresUnrelatedSourceChurnBeforeSectionMove() async throws {
        let planned = sectionSnapshot(
            names: ["moving", "transient", "divider", "visible"],
            generation: 1
        )
        let current = sectionSnapshot(
            names: ["moving", "divider", "visible"],
            generation: 2
        )
        let verified = sectionSnapshot(
            names: ["divider", "visible", "moving"],
            generation: 3
        )
        let plan = try SectionMovePlanner().plan(item: id("moving"), to: .visible, in: planned)
        let performer = SectionRecordingMovePerformer()
        let coordinator = VerifiedMoveCoordinator(
            reader: SectionSnapshotSequenceReader(snapshots: [current, verified]),
            performer: performer
        )

        let result = await coordinator.executeWithObservation(plan)

        #expect(result.outcome == .success)
        #expect(result.verifiedSnapshot == verified)
        #expect(await performer.executionCount == 1)
    }

    @Test("accepts a section move completed before preflight without producing input")
    func acceptsSectionMoveCompletedBeforePreflight() async throws {
        let planned = sectionSnapshot(
            names: ["moving", "divider", "visible"],
            generation: 1
        )
        let current = sectionSnapshot(
            names: ["divider", "visible", "moving"],
            generation: 2
        )
        let plan = try SectionMovePlanner().plan(item: id("moving"), to: .visible, in: planned)
        let performer = SectionRecordingMovePerformer()
        let coordinator = VerifiedMoveCoordinator(
            reader: SectionSnapshotSequenceReader(snapshots: [current]),
            performer: performer
        )

        let result = await coordinator.executeWithObservation(plan)

        #expect(result.outcome == .success)
        #expect(result.verifiedSnapshot == current)
        #expect(await performer.executionCount == 0)
    }

    private func sectionSnapshot(names: [String], generation: UInt64) -> MenuBarSnapshot {
        MenuBarSnapshot(
            generation: generation,
            items: names.enumerated().map { index, name in
                let role: MenuBarItemRole = name == "divider" ? .hiddenSectionDivider : .item
                return MenuBarItem(
                    id: id(name),
                    position: index,
                    isMovable: role == .item,
                    displayName: name,
                    ownership: role == .item ? .application : .selfOwned,
                    availability: .controllable,
                    role: role,
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
}

private actor SectionSnapshotSequenceReader: MenuBarSnapshotReading {
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

private actor SectionRecordingMovePerformer: MenuBarMovePerforming {
    private(set) var executionCount = 0

    func move(
        source _: MenuBarItemFrame,
        destination _: MenuBarItemFrame,
        insertionEdge _: MenuBarInsertionEdge,
        deadline _: OperationDeadline
    ) {
        executionCount += 1
    }
}
