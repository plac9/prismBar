// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore

public struct MovePlan: Equatable, Sendable {
    public let item: MenuBarItemID
    public let sourceIndex: Int
    public let destinationIndex: Int
    public let snapshotGeneration: UInt64
    public let sourceOrder: [MenuBarItemID]
    public let expectedOrder: [MenuBarItemID]
    public let verificationSection: MenuBarSection?

    public init(
        item: MenuBarItemID,
        sourceIndex: Int,
        destinationIndex: Int,
        snapshotGeneration: UInt64,
        sourceOrder: [MenuBarItemID],
        expectedOrder: [MenuBarItemID],
        verificationSection: MenuBarSection? = nil
    ) {
        self.item = item
        self.sourceIndex = sourceIndex
        self.destinationIndex = destinationIndex
        self.snapshotGeneration = snapshotGeneration
        self.sourceOrder = sourceOrder
        self.expectedOrder = expectedOrder
        self.verificationSection = verificationSection
    }
}

public enum MovePlanningError: Error, Equatable, Sendable {
    case itemNotFound(MenuBarItemID)
    case itemIsNotMovable(MenuBarItemID)
    case invalidDestination(Int)
    case differentSurface
}

public struct MovePlanner: Sendable {
    public init() {}

    public func plan(
        item itemID: MenuBarItemID,
        to destinationIndex: Int,
        in snapshot: MenuBarSnapshot
    ) throws -> MovePlan {
        guard let sourceIndex = snapshot.items.firstIndex(where: { $0.id == itemID }) else {
            throw MovePlanningError.itemNotFound(itemID)
        }

        guard snapshot.items[sourceIndex].isMovable else {
            throw MovePlanningError.itemIsNotMovable(itemID)
        }

        guard snapshot.items.indices.contains(destinationIndex) else {
            throw MovePlanningError.invalidDestination(destinationIndex)
        }
        guard snapshot.items[sourceIndex].surfaceID == snapshot.items[destinationIndex].surfaceID else {
            throw MovePlanningError.differentSurface
        }

        var expectedOrder = snapshot.items.map(\.id)
        let movingItem = expectedOrder.remove(at: sourceIndex)
        expectedOrder.insert(movingItem, at: destinationIndex)

        return MovePlan(
            item: itemID,
            sourceIndex: sourceIndex,
            destinationIndex: destinationIndex,
            snapshotGeneration: snapshot.generation,
            sourceOrder: snapshot.items.map(\.id),
            expectedOrder: expectedOrder,
            verificationSection: nil
        )
    }
}
