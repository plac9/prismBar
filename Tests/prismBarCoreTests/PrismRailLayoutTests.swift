// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarCore
import Testing

@Suite("Rail layout")
struct PrismRailLayoutTests {
    @Test("builds a populated layout when the stored surface is stale")
    func resolvesStaleSurfaceBeforeBuildingLayout() {
        let stale = MenuBarSurfaceID(rawValue: "stale")
        let current = MenuBarSurfaceID(rawValue: "current")
        let snapshot = MenuBarSnapshot(
            generation: 3,
            items: [
                item("mail", position: 0, surface: current),
                item(
                    "divider",
                    position: 1,
                    movable: false,
                    role: .hiddenSectionDivider,
                    surface: current
                ),
                item("calendar", position: 2, surface: current),
            ]
        )

        let layout = PrismRailLayout(snapshot: snapshot, currentSurfaceID: stale)

        #expect(layout.surfaceID == current)
        #expect(layout.itemCount == 2)
    }
}

private extension PrismRailLayoutTests {
    func item(
        _ value: String,
        position: Int,
        movable: Bool = true,
        role: MenuBarItemRole = .item,
        surface: MenuBarSurfaceID
    ) -> MenuBarItem {
        MenuBarItem(
            id: MenuBarItemID(rawValue: value),
            position: position,
            isMovable: movable,
            ownership: .application,
            role: role,
            surfaceID: surface
        )
    }
}
