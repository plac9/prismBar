// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore

public enum MenuBarRecoveryPlanningError: Error, Equatable, Sendable {
    case incompleteSnapshot
    case incompatibleItemSet
    case incompatibleRole(MenuBarItemID)
    case incompatibleSurface(MenuBarItemID)
    case incompatibleAvailability(MenuBarItemID)
    case incompatibleAnchorOrder(MenuBarSurfaceID)
    case noSafeMove
}

public struct MenuBarRecoveryPlanner: Sendable {
    public init() {}

    public func isRestored(
        _ current: MenuBarSnapshot,
        target: MenuBarSnapshot
    ) throws -> Bool {
        try validate(current: current, target: target)
        return surfaceIDs(in: target).allSatisfy { surfaceID in
            order(on: surfaceID, in: current) == order(on: surfaceID, in: target)
        }
    }

    public func nextPlan(
        current: MenuBarSnapshot,
        restoring target: MenuBarSnapshot
    ) throws -> MovePlan? {
        try validate(current: current, target: target)
        let currentItems = Dictionary(uniqueKeysWithValues: current.items.map { ($0.id, $0) })

        for surfaceID in surfaceIDs(in: target) {
            let currentOrder = order(on: surfaceID, in: current)
            let targetOrder = order(on: surfaceID, in: target)
            guard let mismatchIndex = currentOrder.indices.first(where: {
                currentOrder[$0] != targetOrder[$0]
            }) else {
                continue
            }

            let desiredID = targetOrder[mismatchIndex]
            let displacedID = currentOrder[mismatchIndex]
            var candidates: [MovePlan] = []

            if currentItems[desiredID]?.role == .item,
               let plan = plan(
                   moving: desiredID,
                   toLocalIndex: mismatchIndex,
                   currentOrder: currentOrder,
                   current: current
               ) {
                candidates.append(plan)
            }

            if currentItems[displacedID]?.role == .item,
               let displacedTargetIndex = targetOrder.firstIndex(of: displacedID),
               let plan = plan(
                   moving: displacedID,
                   toLocalIndex: displacedTargetIndex,
                   currentOrder: currentOrder,
                   current: current
               ) {
                candidates.append(plan)
            }

            guard let best = candidates.max(by: { lhs, rhs in
                recoveryScore(
                    for: lhs,
                    currentItems: currentItems,
                    target: target
                ) < recoveryScore(
                    for: rhs,
                    currentItems: currentItems,
                    target: target
                )
            }) else {
                throw MenuBarRecoveryPlanningError.noSafeMove
            }
            return best
        }

        return nil
    }

    private func validate(
        current: MenuBarSnapshot,
        target: MenuBarSnapshot
    ) throws {
        guard current.isComplete, target.isComplete else {
            throw MenuBarRecoveryPlanningError.incompleteSnapshot
        }
        let currentByID = Dictionary(uniqueKeysWithValues: current.items.map { ($0.id, $0) })
        let targetByID = Dictionary(uniqueKeysWithValues: target.items.map { ($0.id, $0) })
        guard Set(currentByID.keys) == Set(targetByID.keys) else {
            throw MenuBarRecoveryPlanningError.incompatibleItemSet
        }

        for targetItem in target.items {
            guard let currentItem = currentByID[targetItem.id] else {
                throw MenuBarRecoveryPlanningError.incompatibleItemSet
            }
            guard currentItem.role == targetItem.role,
                  currentItem.isMovable == targetItem.isMovable
            else {
                throw MenuBarRecoveryPlanningError.incompatibleRole(targetItem.id)
            }
            guard currentItem.surfaceID == targetItem.surfaceID else {
                throw MenuBarRecoveryPlanningError.incompatibleSurface(targetItem.id)
            }
            if targetItem.role == .item,
               currentItem.availability != .controllable ||
                   targetItem.availability != .controllable ||
                   !currentItem.isMovable ||
                   !targetItem.isMovable {
                throw MenuBarRecoveryPlanningError.incompatibleAvailability(targetItem.id)
            }
        }

        for surfaceID in surfaceIDs(in: target) {
            let currentAnchors = current.items.filter {
                $0.surfaceID == surfaceID && $0.role != .item
            }.map(\.id)
            let targetAnchors = target.items.filter {
                $0.surfaceID == surfaceID && $0.role != .item
            }.map(\.id)
            guard currentAnchors == targetAnchors else {
                throw MenuBarRecoveryPlanningError.incompatibleAnchorOrder(surfaceID)
            }
        }
    }

    private func plan(
        moving itemID: MenuBarItemID,
        toLocalIndex localIndex: Int,
        currentOrder: [MenuBarItemID],
        current: MenuBarSnapshot
    ) -> MovePlan? {
        guard currentOrder.indices.contains(localIndex),
              let destinationIndex = current.items.firstIndex(where: {
                  $0.id == currentOrder[localIndex]
              }),
              currentOrder[localIndex] != itemID
        else {
            return nil
        }
        return try? MovePlanner().plan(item: itemID, to: destinationIndex, in: current)
    }

    private func recoveryScore(
        for plan: MovePlan,
        currentItems: [MenuBarItemID: MenuBarItem],
        target: MenuBarSnapshot
    ) -> Int {
        surfaceIDs(in: target).reduce(into: 0) { score, surfaceID in
            let expected = plan.expectedOrder.filter {
                currentItems[$0]?.surfaceID == surfaceID
            }
            let desired = order(on: surfaceID, in: target)
            score += zip(expected, desired).prefix(while: ==).count
        }
    }

    private func surfaceIDs(in snapshot: MenuBarSnapshot) -> [MenuBarSurfaceID] {
        var seen: Set<MenuBarSurfaceID> = []
        return snapshot.items.compactMap { item in
            seen.insert(item.surfaceID).inserted ? item.surfaceID : nil
        }
    }

    private func order(
        on surfaceID: MenuBarSurfaceID,
        in snapshot: MenuBarSnapshot
    ) -> [MenuBarItemID] {
        snapshot.items.filter { $0.surfaceID == surfaceID }.map(\.id)
    }
}
