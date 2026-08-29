// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore

public enum SectionBatchMoveDisposition: Equatable, Sendable {
    case moveRequired
    case alreadyCompleted
    case unavailable
}

public struct SectionBatchPlanner: Sendable {
    public init() {}

    public func itemIDsToMove(
        _ selectedItemIDs: Set<MenuBarItemID>,
        to targetSection: MenuBarSection,
        in snapshot: MenuBarSnapshot
    ) -> [MenuBarItemID] {
        guard targetSection != .controller else { return [] }

        let eligibleItems = snapshot.items.filter { item in
            selectedItemIDs.contains(item.id) && disposition(
                for: item.id,
                to: targetSection,
                in: snapshot
            ) == .moveRequired
        }

        switch targetSection {
        case .hidden:
            return eligibleItems.map(\.id)
        case .visible:
            return eligibleItems.reversed().map(\.id)
        case .controller:
            return []
        }
    }

    public func disposition(
        for itemID: MenuBarItemID,
        to targetSection: MenuBarSection,
        in snapshot: MenuBarSnapshot
    ) -> SectionBatchMoveDisposition {
        guard targetSection != .controller,
              let item = snapshot.items.first(where: { $0.id == itemID }),
              item.role == .item,
              item.isMovable,
              item.availability == .controllable,
              let currentSection = snapshot.section(for: itemID),
              currentSection != .controller
        else {
            return .unavailable
        }
        return currentSection == targetSection ? .alreadyCompleted : .moveRequired
    }
}
