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

    @Test("uses the divider on the item's display")
    func targetsSameDisplayDivider() throws {
        let firstSurface = MenuBarSurfaceID(rawValue: "first")
        let secondSurface = MenuBarSurfaceID(rawValue: "second")
        let secondVisibleID = MenuBarItemID(rawValue: "second-visible")
        let snapshot = MenuBarSnapshot(
            generation: 1,
            items: [
                item(
                    "first-divider",
                    position: 0,
                    role: .hiddenSectionDivider,
                    surfaceID: firstSurface
                ),
                item("first-visible", position: 1, surfaceID: firstSurface),
                item(
                    "second-divider",
                    position: 2,
                    role: .hiddenSectionDivider,
                    surfaceID: secondSurface
                ),
                item("second-visible", position: 3, surfaceID: secondSurface),
            ]
        )

        let plan = try SectionMovePlanner().plan(
            item: secondVisibleID,
            to: .hidden,
            in: snapshot
        )

        #expect(plan.destinationIndex == 2)
    }

    @Test("classifies items on either side of the divider")
    func classifiesSections() {
        let snapshot = fixtureSnapshot()

        #expect(snapshot.section(for: MenuBarItemID(rawValue: "hidden-one")) == .hidden)
        #expect(snapshot.section(for: MenuBarItemID(rawValue: "visible-one")) == .visible)
        #expect(snapshot.section(for: MenuBarItemID(rawValue: "hidden-divider")) == .controller)
        #expect(snapshot.section(for: MenuBarItemID(rawValue: "primary-control")) == .controller)
    }

    @Test("classifies every item relative to its own display divider")
    func exhaustiveSectionGrouping() {
        let surfaces = [
            MenuBarSurfaceID(rawValue: "first"),
            MenuBarSurfaceID(rawValue: "second"),
        ]

        for dividerOffset in 0 ... 6 {
            var items: [MenuBarItem] = []
            for (surfaceIndex, surface) in surfaces.enumerated() {
                for offset in 0 ... 6 {
                    let position = offset * surfaces.count + surfaceIndex
                    let role: MenuBarItemRole = offset == dividerOffset
                        ? .hiddenSectionDivider
                        : .item
                    items.append(item(
                        "surface-\(surfaceIndex)-item-\(offset)",
                        position: position,
                        role: role,
                        surfaceID: surface
                    ))
                }
            }

            let snapshot = MenuBarSnapshot(generation: 1, items: items)
            for surfaceIndex in surfaces.indices {
                for offset in 0 ... 6 {
                    let identifier = MenuBarItemID(
                        rawValue: "surface-\(surfaceIndex)-item-\(offset)"
                    )
                    let expected: MenuBarSection = if offset < dividerOffset {
                        .hidden
                    } else if offset == dividerOffset {
                        .controller
                    } else {
                        .visible
                    }
                    #expect(snapshot.section(for: identifier) == expected)
                }
            }
        }
    }

    @Test("offers direct destinations only within the same section and display")
    func directPositionDestinations() {
        let firstSurface = MenuBarSurfaceID(rawValue: "first")
        let secondSurface = MenuBarSurfaceID(rawValue: "second")
        let snapshot = MenuBarSnapshot(
            generation: 1,
            items: [
                item("first-hidden", position: 0, surfaceID: firstSurface),
                item(
                    "first-divider",
                    position: 1,
                    role: .hiddenSectionDivider,
                    surfaceID: firstSurface
                ),
                item("first-visible-one", position: 2, surfaceID: firstSurface),
                item("second-hidden", position: 3, surfaceID: secondSurface),
                item(
                    "second-divider",
                    position: 4,
                    role: .hiddenSectionDivider,
                    surfaceID: secondSurface
                ),
                item("first-visible-two", position: 5, surfaceID: firstSurface),
                item("second-visible", position: 6, surfaceID: secondSurface),
            ]
        )

        #expect(
            snapshot.movementDestinations(
                for: MenuBarItemID(rawValue: "first-visible-one")
            ).map(\.id.rawValue) == ["first-visible-one", "first-visible-two"]
        )
        #expect(
            snapshot.movementDestinations(
                for: MenuBarItemID(rawValue: "second-visible")
            ).map(\.id.rawValue) == ["second-visible"]
        )
        #expect(
            snapshot.movementDestinations(
                for: MenuBarItemID(rawValue: "first-divider")
            ).isEmpty
        )
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
        role: MenuBarItemRole = .item,
        surfaceID: MenuBarSurfaceID = .unknown
    ) -> MenuBarItem {
        MenuBarItem(
            id: MenuBarItemID(rawValue: identifier),
            position: position,
            isMovable: role == .item,
            displayName: identifier,
            ownership: role == .item ? .application : .selfOwned,
            availability: .controllable,
            role: role,
            frame: MenuBarItemFrame(minX: Double(position * 30), minY: 0, width: 24, height: 24),
            surfaceID: surfaceID
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
