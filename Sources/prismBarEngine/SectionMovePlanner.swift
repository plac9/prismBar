// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore

public enum SectionMovePlanningError: Error, Equatable, Sendable {
    case dividerUnavailable
    case itemUnavailable(MenuBarItemID)
    case alreadyInSection(MenuBarSection)
}

public struct SectionMovePlanner: Sendable {
    public init() {}

    public func plan(
        item itemID: MenuBarItemID,
        to section: MenuBarSection,
        in snapshot: MenuBarSnapshot
    ) throws -> MovePlan {
        guard section != .controller else {
            throw SectionMovePlanningError.itemUnavailable(itemID)
        }
        guard let item = snapshot.items.first(where: { $0.id == itemID }) else {
            throw SectionMovePlanningError.itemUnavailable(itemID)
        }
        guard let dividerIndex = snapshot.items.firstIndex(where: {
            $0.role == .hiddenSectionDivider && $0.surfaceID == item.surfaceID
        }) else {
            throw SectionMovePlanningError.dividerUnavailable
        }
        guard let currentSection = snapshot.section(for: itemID) else {
            throw SectionMovePlanningError.itemUnavailable(itemID)
        }
        guard currentSection != .controller else {
            throw SectionMovePlanningError.itemUnavailable(itemID)
        }
        guard currentSection != section else {
            throw SectionMovePlanningError.alreadyInSection(section)
        }
        let directPlan = try MovePlanner().plan(item: itemID, to: dividerIndex, in: snapshot)
        return MovePlan(
            item: directPlan.item,
            destinationItem: directPlan.destinationItem,
            sourceIndex: directPlan.sourceIndex,
            destinationIndex: directPlan.destinationIndex,
            snapshotGeneration: directPlan.snapshotGeneration,
            sourceOrder: directPlan.sourceOrder,
            expectedOrder: directPlan.expectedOrder,
            sourceScopeOrder: directPlan.sourceScopeOrder,
            expectedScopeOrder: directPlan.expectedScopeOrder,
            verificationSection: section
        )
    }
}
