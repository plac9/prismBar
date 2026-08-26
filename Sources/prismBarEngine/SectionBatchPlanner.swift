// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore

public struct SectionBatchPlanner: Sendable {
    public init() {}

    public func itemIDsToMove(
        _ selectedItemIDs: Set<MenuBarItemID>,
        to targetSection: MenuBarSection,
        in snapshot: MenuBarSnapshot
    ) -> [MenuBarItemID] {
        guard targetSection != .controller else { return [] }

        let eligibleItems = snapshot.items.filter { item in
            selectedItemIDs.contains(item.id) &&
                item.role == .item &&
                item.isMovable &&
                item.availability == .controllable &&
                snapshot.section(for: item.id) != targetSection
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
}
