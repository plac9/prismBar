// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarEngine
import prismBarCore
import Testing

@Suite("Menu bar section moves")
struct SectionMovePlannerTests {
    @Test("moves a visible item directly before the hidden divider")
    func plansHide() throws {
        let snapshot = fixtureSnapshot()

        let plan = try SectionMovePlanner().plan(
            item: MenuBarItemID(rawValue: "visible-two"),
            to: .hidden,
            in: snapshot
        )

        #expect(plan.destinationIndex == 1)
        #expect(plan.expectedOrder.map(\.rawValue) == [
            "hidden-one",
            "visible-two",
            "hidden-divider",
            "visible-one",
            "primary-control",
        ])
    }

    @Test("moves a hidden item directly after the hidden divider")
    func plansShow() throws {
        let snapshot = fixtureSnapshot()

        let plan = try SectionMovePlanner().plan(
            item: MenuBarItemID(rawValue: "hidden-one"),
            to: .visible,
            in: snapshot
        )

        #expect(plan.destinationIndex == 1)
        #expect(plan.expectedOrder.map(\.rawValue) == [
            "hidden-divider",
            "hidden-one",
            "visible-one",
            "visible-two",
            "primary-control",
        ])
    }

    @Test("rejects a section move when the divider is unavailable")
    func rejectsMissingDivider() {
        let snapshot = MenuBarSnapshot(
            generation: 1,
            items: [item("visible", position: 0)]
        )

        #expect(throws: SectionMovePlanningError.dividerUnavailable) {
            try SectionMovePlanner().plan(
                item: MenuBarItemID(rawValue: "visible"),
                to: .hidden,
                in: snapshot
            )
        }
    }

    @Test("rejects a no-op request instead of crossing the divider")
    func rejectsExistingSection() {
        let snapshot = fixtureSnapshot()

        #expect(throws: SectionMovePlanningError.alreadyInSection(.hidden)) {
            try SectionMovePlanner().plan(
                item: MenuBarItemID(rawValue: "hidden-one"),
                to: .hidden,
                in: snapshot
            )
        }
    }

    @Test("classifies items on either side of the divider")
    func classifiesSections() {
        let snapshot = fixtureSnapshot()

        #expect(snapshot.section(for: MenuBarItemID(rawValue: "hidden-one")) == .hidden)
        #expect(snapshot.section(for: MenuBarItemID(rawValue: "visible-one")) == .visible)
        #expect(snapshot.section(for: MenuBarItemID(rawValue: "hidden-divider")) == .controller)
        #expect(snapshot.section(for: MenuBarItemID(rawValue: "primary-control")) == .controller)
    }

    private func fixtureSnapshot() -> MenuBarSnapshot {
        MenuBarSnapshot(
            generation: 1,
            items: [
                item("hidden-one", position: 0),
                item("hidden-divider", position: 1, role: .hiddenSectionDivider),
                item("visible-one", position: 2),
                item("visible-two", position: 3),
                item("primary-control", position: 4, role: .primaryControl),
            ]
        )
    }

    private func item(
        _ identifier: String,
        position: Int,
        role: MenuBarItemRole = .item
    ) -> MenuBarItem {
        MenuBarItem(
            id: MenuBarItemID(rawValue: identifier),
            position: position,
            isMovable: role == .item,
            displayName: identifier,
            ownership: role == .item ? .application : .selfOwned,
            availability: .controllable,
            role: role,
            frame: MenuBarItemFrame(minX: Double(position * 30), minY: 0, width: 24, height: 24)
        )
    }
}

@Suite("Menu bar section reset")
struct SectionResetPlannerTests {
    @Test("reveals hidden items from right to left to preserve their order")
    func preservesHiddenItemOrder() {
        let snapshot = MenuBarSnapshot(
            generation: 20,
            items: [
                item("hidden-one", position: 0),
                item("hidden-two", position: 1),
                item("divider", position: 2, movable: false, role: .hiddenSectionDivider),
                item("visible-one", position: 3),
                item("primary", position: 4, movable: false, role: .primaryControl),
            ]
        )

        #expect(
            SectionResetPlanner().hiddenItemsToReveal(in: snapshot) == [
                MenuBarItemID(rawValue: "hidden-two"),
                MenuBarItemID(rawValue: "hidden-one"),
            ]
        )
    }

    @Test("ignores controller items and an already empty hidden section")
    func ignoresControllers() {
        let snapshot = MenuBarSnapshot(
            generation: 21,
            items: [
                item("divider", position: 0, movable: false, role: .hiddenSectionDivider),
                item("visible-one", position: 1),
                item("primary", position: 2, movable: false, role: .primaryControl),
            ]
        )

        #expect(SectionResetPlanner().hiddenItemsToReveal(in: snapshot).isEmpty)
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
            role: role,
            frame: MenuBarItemFrame(minX: Double(position * 30), minY: 0, width: 24, height: 24)
        )
    }
}
