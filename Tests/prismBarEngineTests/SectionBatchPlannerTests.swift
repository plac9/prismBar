// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarEngine
import prismBarCore
import Testing

@Suite("Menu bar batch section moves")
struct SectionBatchPlannerTests {
    @Test("hides selected visible items from left to right to preserve order")
    func hideOrder() {
        let snapshot = fixtureSnapshot()
        let selected = ids("visible-one", "visible-three")

        #expect(
            SectionBatchPlanner().itemIDsToMove(
                selected,
                to: .hidden,
                in: snapshot
            ).map(\.rawValue) == ["visible-one", "visible-three"]
        )
    }

    @Test("shows selected hidden items from right to left to preserve order")
    func showOrder() {
        let snapshot = fixtureSnapshot()
        let selected = ids("hidden-one", "hidden-three")

        #expect(
            SectionBatchPlanner().itemIDsToMove(
                selected,
                to: .visible,
                in: snapshot
            ).map(\.rawValue) == ["hidden-three", "hidden-one"]
        )
    }

    @Test("ignores unavailable, controller, missing, and already-targeted items")
    func filtersUnsafeItems() {
        let snapshot = fixtureSnapshot()
        let selected = ids(
            "hidden-one",
            "visible-one",
            "unavailable-visible",
            "divider",
            "missing"
        )

        #expect(
            SectionBatchPlanner().itemIDsToMove(
                selected,
                to: .hidden,
                in: snapshot
            ).map(\.rawValue) == ["visible-one"]
        )
    }

    private func fixtureSnapshot() -> MenuBarSnapshot {
        MenuBarSnapshot(
            generation: 1,
            items: [
                item("hidden-one", position: 0),
                item("hidden-two", position: 1),
                item("hidden-three", position: 2),
                item("divider", position: 3, movable: false, role: .hiddenSectionDivider),
                item("visible-one", position: 4),
                item("visible-two", position: 5),
                item("unavailable-visible", position: 6, movable: false),
                item("visible-three", position: 7),
            ]
        )
    }

    private func item(
        _ identifier: String,
        position: Int,
        movable: Bool = true,
        role: MenuBarItemRole = .item
    ) -> MenuBarItem {
        MenuBarItem(
            id: MenuBarItemID(rawValue: identifier),
            position: position,
            isMovable: movable,
            displayName: identifier,
            ownership: role == .item ? .application : .selfOwned,
            availability: movable ? .controllable : .unavailable,
            role: role,
            frame: MenuBarItemFrame(
                minX: Double(position * 30),
                minY: 0,
                width: 24,
                height: 24
            )
        )
    }

    private func ids(_ values: String...) -> Set<MenuBarItemID> {
        Set(values.map { MenuBarItemID(rawValue: $0) })
    }
}
