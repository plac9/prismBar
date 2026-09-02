// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarEngine
import prismBarCore
import Testing

@Suite("Menu bar recovery partial coverage")
struct MenuBarRecoveryPartialCoverageTests {
    @Test("restores stable observed topology across partial coverage variance")
    func restoresAcrossPartialCoverageVariance() throws {
        let target = snapshot(
            generation: 1,
            order: ["one", "two", "divider", "control"],
            unavailableSourceCount: 3
        )
        let current = snapshot(
            generation: 2,
            order: ["two", "one", "divider", "control"],
            unavailableSourceCount: 2
        )

        let candidate = try MenuBarRecoveryPlanner().nextPlan(
            current: current,
            restoring: target
        )
        let plan = try #require(candidate)

        #expect(plan.item == id("one"))
        #expect(plan.destinationIndex == 0)
    }

    private func snapshot(
        generation: UInt64,
        order: [String],
        unavailableSourceCount: Int
    ) -> MenuBarSnapshot {
        MenuBarSnapshot(
            generation: generation,
            items: order.enumerated().map { index, name in
                let role: MenuBarItemRole = if name == "divider" {
                    .hiddenSectionDivider
                } else if name == "control" {
                    .primaryControl
                } else {
                    .item
                }
                return MenuBarItem(
                    id: id(name),
                    position: index,
                    isMovable: role == .item,
                    displayName: "Synthetic item",
                    ownership: .application,
                    availability: .controllable,
                    role: role,
                    frame: MenuBarItemFrame(
                        minX: Double(index * 24),
                        minY: 0,
                        width: 20,
                        height: 20
                    ),
                    surfaceID: MenuBarSurfaceID(rawValue: "display.main")
                )
            },
            unavailableSourceCount: unavailableSourceCount
        )
    }

    private func id(_ value: String) -> MenuBarItemID {
        MenuBarItemID(rawValue: "fixture.\(value)")
    }
}
