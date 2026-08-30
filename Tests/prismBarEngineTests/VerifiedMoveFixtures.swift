// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarCore
@testable import prismBarEngine
import Dispatch
import Testing

func snapshot(names: [String], generation: UInt64) -> MenuBarSnapshot {
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

func sectionedSnapshot(
    hiddenNames: [String],
    visibleNames: [String],
    generation: UInt64
) -> MenuBarSnapshot {
    let surfaceID = MenuBarSurfaceID(rawValue: "main")
    let orderedNames = hiddenNames + ["divider"] + visibleNames
    return MenuBarSnapshot(
        generation: generation,
        items: orderedNames.enumerated().map { index, name in
            MenuBarItem(
                id: id(name),
                position: index,
                isMovable: name != "divider",
                displayName: name,
                role: name == "divider" ? .hiddenSectionDivider : .item,
                frame: MenuBarItemFrame(
                    minX: Double(index * 30),
                    minY: 0,
                    width: 24,
                    height: 24
                ),
                surfaceID: surfaceID
            )
        }
    )
}

func id(_ value: String) -> MenuBarItemID {
    MenuBarItemID(rawValue: value)
}

actor StalledMovePerformer: MenuBarMovePerforming {
    private(set) var executionCount = 0

    func move(
        source _: MenuBarItemFrame,
        destination _: MenuBarItemFrame,
        insertionEdge _: MenuBarInsertionEdge,
        deadline: OperationDeadline
    ) async throws {
        executionCount += 1
        try await Task.sleep(for: deadline.remaining())
        throw OperationDeadlineError.expired
    }
}

actor SnapshotSequenceReader: MenuBarSnapshotReading {
    private var snapshots: [MenuBarSnapshot]
    private(set) var deadlines: [ContinuousClock.Instant] = []

    init(snapshots: [MenuBarSnapshot]) {
        self.snapshots = snapshots
    }

    func snapshot(deadline: OperationDeadline) throws -> MenuBarSnapshot {
        deadlines.append(deadline.expiresAt)
        guard !snapshots.isEmpty else {
            throw VerifiedMoveError.observationFailed
        }
        return snapshots.removeFirst()
    }

    var remainingCount: Int {
        snapshots.count
    }
}

struct StalledSnapshotReader: MenuBarSnapshotReading {
    func snapshot(deadline: OperationDeadline) async throws -> MenuBarSnapshot {
        try await Task.sleep(for: deadline.remaining())
        throw OperationDeadlineError.expired
    }
}

struct NoncooperativeSnapshotReader: MenuBarSnapshotReading {
    let snapshotValue: MenuBarSnapshot
    let delay: DispatchTimeInterval

    init(snapshot: MenuBarSnapshot, delay: DispatchTimeInterval) {
        snapshotValue = snapshot
        self.delay = delay
    }

    func snapshot(deadline _: OperationDeadline) async -> MenuBarSnapshot {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                continuation.resume(returning: snapshotValue)
            }
        }
    }
}

actor RecordingMovePerformer: MenuBarMovePerforming {
    private(set) var executionCount = 0
    private(set) var deadline: ContinuousClock.Instant?

    func move(
        source _: MenuBarItemFrame,
        destination _: MenuBarItemFrame,
        insertionEdge _: MenuBarInsertionEdge,
        deadline: OperationDeadline
    ) {
        executionCount += 1
        self.deadline = deadline.expiresAt
    }
}

struct FailingSnapshotReader: MenuBarSnapshotReading {
    let error: any Error & Sendable

    func snapshot(deadline _: OperationDeadline) throws -> MenuBarSnapshot {
        throw error
    }
}

actor SnapshotThenFailureReader: MenuBarSnapshotReading {
    private var snapshotValue: MenuBarSnapshot?
    private let error: any Error & Sendable

    init(snapshot: MenuBarSnapshot, error: any Error & Sendable) {
        snapshotValue = snapshot
        self.error = error
    }

    func snapshot(deadline _: OperationDeadline) throws -> MenuBarSnapshot {
        guard let snapshotValue else { throw error }
        self.snapshotValue = nil
        return snapshotValue
    }
}

struct FailingMovePerformer: MenuBarMovePerforming {
    let error: any Error & Sendable

    func move(
        source _: MenuBarItemFrame,
        destination _: MenuBarItemFrame,
        insertionEdge _: MenuBarInsertionEdge,
        deadline _: OperationDeadline
    ) throws {
        throw error
    }
}

actor CountingFailingMovePerformer: MenuBarMovePerforming {
    private(set) var executionCount = 0
    let error: any Error & Sendable

    init(error: any Error & Sendable) {
        self.error = error
    }

    func move(
        source _: MenuBarItemFrame,
        destination _: MenuBarItemFrame,
        insertionEdge _: MenuBarInsertionEdge,
        deadline _: OperationDeadline
    ) throws {
        executionCount += 1
        throw error
    }
}
