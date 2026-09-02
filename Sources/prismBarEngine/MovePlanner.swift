// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore

public struct MovePlan: Equatable, Sendable {
    public let item: MenuBarItemID
    public let destinationItem: MenuBarItemID
    public let sourceIndex: Int
    public let destinationIndex: Int
    public let snapshotGeneration: UInt64
    public let sourceOrder: [MenuBarItemID]
    public let expectedOrder: [MenuBarItemID]
    public let sourceScopeOrder: [MenuBarItemID]
    public let expectedScopeOrder: [MenuBarItemID]
    public let verificationSection: MenuBarSection?
    public let requiresSectionObservation: Bool

    public init(
        item: MenuBarItemID,
        destinationItem: MenuBarItemID,
        sourceIndex: Int,
        destinationIndex: Int,
        snapshotGeneration: UInt64,
        sourceOrder: [MenuBarItemID],
        expectedOrder: [MenuBarItemID],
        sourceScopeOrder: [MenuBarItemID],
        expectedScopeOrder: [MenuBarItemID],
        verificationSection: MenuBarSection? = nil,
        requiresSectionObservation: Bool = false
    ) {
        self.item = item
        self.destinationItem = destinationItem
        self.sourceIndex = sourceIndex
        self.destinationIndex = destinationIndex
        self.snapshotGeneration = snapshotGeneration
        self.sourceOrder = sourceOrder
        self.expectedOrder = expectedOrder
        self.sourceScopeOrder = sourceScopeOrder
        self.expectedScopeOrder = expectedScopeOrder
        self.verificationSection = verificationSection
        self.requiresSectionObservation = requiresSectionObservation
    }
}

func moveScopeOrder(
    item itemID: MenuBarItemID,
    destination destinationID: MenuBarItemID,
    in snapshot: MenuBarSnapshot
) -> [MenuBarItemID]? {
    guard let sourceItem = snapshot.items.first(where: { $0.id == itemID }),
          let destinationItem = snapshot.items.first(where: { $0.id == destinationID }),
          sourceItem.surfaceID == destinationItem.surfaceID
    else {
        return nil
    }

    if let sourceSection = snapshot.section(for: itemID),
       let destinationSection = snapshot.section(for: destinationID),
       sourceSection == destinationSection,
       sourceSection != .controller {
        return snapshot.movementDestinations(for: itemID).map(\.id)
    }

    return snapshot.items
        .filter { $0.surfaceID == sourceItem.surfaceID }
        .map(\.id)
}

public enum MovePlanningError: Error, Equatable, Sendable {
    case itemNotFound(MenuBarItemID)
    case itemIsNotMovable(MenuBarItemID)
    case invalidDestination(Int)
    case differentSurface
    case unreachableDestination(MenuBarItemID)
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

        guard snapshot.items[sourceIndex].allowsVerifiedMovement else {
            throw MovePlanningError.itemIsNotMovable(itemID)
        }

        guard snapshot.items.indices.contains(destinationIndex) else {
            throw MovePlanningError.invalidDestination(destinationIndex)
        }
        guard snapshot.items[sourceIndex].surfaceID == snapshot.items[destinationIndex].surfaceID else {
            throw MovePlanningError.differentSurface
        }

        let destination = snapshot.items[destinationIndex]
        let destinationItem = destination.id
        if destination.role == .item,
           destination.ownership != snapshot.items[sourceIndex].ownership {
            throw MovePlanningError.unreachableDestination(destinationItem)
        }
        let sourceOrder = snapshot.items.map(\.id)
        var expectedOrder = sourceOrder
        let movingItem = expectedOrder.remove(at: sourceIndex)
        expectedOrder.insert(movingItem, at: destinationIndex)

        guard let sourceScopeOrder = moveScopeOrder(
            item: itemID,
            destination: destinationItem,
            in: snapshot
        ),
        let sourceScopeIndex = sourceScopeOrder.firstIndex(of: itemID),
        let destinationScopeIndex = sourceScopeOrder.firstIndex(of: destinationItem)
        else {
            throw MovePlanningError.differentSurface
        }
        var expectedScopeOrder = sourceScopeOrder
        let scopedMovingItem = expectedScopeOrder.remove(at: sourceScopeIndex)
        expectedScopeOrder.insert(scopedMovingItem, at: destinationScopeIndex)

        return MovePlan(
            item: itemID,
            destinationItem: destinationItem,
            sourceIndex: sourceIndex,
            destinationIndex: destinationIndex,
            snapshotGeneration: snapshot.generation,
            sourceOrder: sourceOrder,
            expectedOrder: expectedOrder,
            sourceScopeOrder: sourceScopeOrder,
            expectedScopeOrder: expectedScopeOrder,
            verificationSection: nil,
            requiresSectionObservation: snapshot.section(for: itemID) != nil &&
                snapshot.section(for: itemID) == snapshot.section(for: destinationItem)
        )
    }
}
