// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarEngine
import prismBarCore
import Testing

@Suite("Menu bar recovery planning")
struct MenuBarRecoveryPlannerTests {
    private let planner = MenuBarRecoveryPlanner()

    @Test("returns no move for an already restored topology")
    func alreadyRestored() throws {
        let target = snapshot(order: ["hidden", "divider", "visible", "control"])

        #expect(try planner.nextPlan(current: target, restoring: target) == nil)
        #expect(try planner.isRestored(target, target: target))
    }

    @Test("plans one direct multi-position correction")
    func directCorrection() throws {
        let target = snapshot(order: ["one", "two", "three", "divider", "control"])
        let current = snapshot(
            generation: 2,
            order: ["three", "one", "two", "divider", "control"]
        )

        let candidate = try planner.nextPlan(current: current, restoring: target)
        let plan = try #require(candidate)

        #expect(plan.item == id("three"))
        #expect(plan.sourceIndex == 0)
        #expect(plan.destinationIndex == 2)
        #expect(plan.expectedOrder == target.items.map(\.id))
    }

    @Test("plans one divider crossing correction")
    func dividerCrossing() throws {
        let target = snapshot(order: ["hidden", "divider", "visible", "control"])
        let current = snapshot(
            generation: 2,
            order: ["divider", "hidden", "visible", "control"]
        )

        let candidate = try planner.nextPlan(current: current, restoring: target)
        let plan = try #require(candidate)

        #expect(plan.item == id("hidden"))
        #expect(plan.destinationItem == id("divider"))
        #expect(plan.expectedOrder == target.items.map(\.id))
    }

    @Test("reconciles displays independently")
    func multipleDisplays() throws {
        let target = snapshot(
            order: ["a.one", "a.two", "a.divider", "b.one", "b.two", "b.divider"],
            surfaces: [
                "a.one": "display.a", "a.two": "display.a", "a.divider": "display.a",
                "b.one": "display.b", "b.two": "display.b", "b.divider": "display.b",
            ]
        )
        let current = snapshot(
            generation: 2,
            order: ["a.one", "a.two", "a.divider", "b.two", "b.one", "b.divider"],
            surfaces: [
                "a.one": "display.a", "a.two": "display.a", "a.divider": "display.a",
                "b.one": "display.b", "b.two": "display.b", "b.divider": "display.b",
            ]
        )

        let candidate = try planner.nextPlan(current: current, restoring: target)
        let plan = try #require(candidate)

        #expect(plan.item == id("b.one"))
        #expect(plan.sourceIndex == 4)
        #expect(plan.destinationIndex == 3)
    }

    @Test("never selects a divider or controller as the moving item")
    func anchorsNeverMove() throws {
        let target = snapshot(order: ["one", "divider", "two", "control"])
        let current = snapshot(
            generation: 2,
            order: ["one", "two", "divider", "control"]
        )

        let candidate = try planner.nextPlan(current: current, restoring: target)
        let plan = try #require(candidate)

        #expect(plan.item == id("two"))
        #expect(plan.destinationItem == id("divider"))
    }

    @Test("fails closed for incompatible or incomplete topology", arguments: [
        RecoveryMutation.missingItem,
        .changedRole,
        .changedSurface,
        .unavailableItem,
        .incompleteSnapshot,
    ])
    func incompatibleTopology(_ mutation: RecoveryMutation) {
        let target = snapshot(order: ["one", "divider", "two", "control"])
        let current = mutatedSnapshot(from: target, mutation: mutation)

        #expect(throws: MenuBarRecoveryPlanningError.self) {
            try planner.nextPlan(current: current, restoring: target)
        }
    }

    @Test("repeated next plans converge within the movable item count")
    func converges() throws {
        let target = snapshot(
            order: ["one", "two", "divider", "three", "four", "control"]
        )
        var current = snapshot(
            generation: 2,
            order: ["four", "three", "divider", "two", "one", "control"]
        )
        let maximumMoves = current.items.count(where: { $0.role == .item })
        var moveCount = 0

        while let plan = try planner.nextPlan(current: current, restoring: target) {
            moveCount += 1
            #expect(moveCount <= maximumMoves)
            current = applying(plan, to: current)
        }

        #expect(try planner.isRestored(current, target: target))
    }

    enum RecoveryMutation: Sendable {
        case missingItem
        case changedRole
        case changedSurface
        case unavailableItem
        case incompleteSnapshot
    }

    private func mutatedSnapshot(
        from target: MenuBarSnapshot,
        mutation: RecoveryMutation
    ) -> MenuBarSnapshot {
        var items = target.items
        var unavailableSourceCount = 0
        switch mutation {
        case .missingItem:
            items.removeAll { $0.id == id("two") }
        case .changedRole:
            items = items.map { item in
                item.id == id("two") ? copying(item, role: .primaryControl) : item
            }
        case .changedSurface:
            items = items.map { item in
                item.id == id("two")
                    ? copying(item, surfaceID: MenuBarSurfaceID(rawValue: "display.other"))
                    : item
            }
        case .unavailableItem:
            items = items.map { item in
                item.id == id("two") ? copying(item, availability: .unavailable) : item
            }
        case .incompleteSnapshot:
            unavailableSourceCount = 1
        }
        return MenuBarSnapshot(
            generation: 2,
            items: items,
            unavailableSourceCount: unavailableSourceCount
        )
    }

    private func snapshot(
        generation: UInt64 = 1,
        order: [String],
        surfaces: [String: String] = [:]
    ) -> MenuBarSnapshot {
        MenuBarSnapshot(
            generation: generation,
            items: order.enumerated().map { index, name in
                let role: MenuBarItemRole = if name.hasSuffix("divider") || name == "divider" {
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
                    availability: .controllable,
                    role: role,
                    frame: MenuBarItemFrame(
                        minX: Double(index * 24),
                        minY: 0,
                        width: 20,
                        height: 20
                    ),
                    surfaceID: MenuBarSurfaceID(
                        rawValue: surfaces[name, default: "display.main"]
                    )
                )
            }
        )
    }

    private func applying(
        _ plan: MovePlan,
        to snapshot: MenuBarSnapshot
    ) -> MenuBarSnapshot {
        let byIdentifier = Dictionary(uniqueKeysWithValues: snapshot.items.map { ($0.id, $0) })
        let items = plan.expectedOrder.enumerated().map { index, identifier in
            copying(byIdentifier[identifier]!, position: index)
        }
        return MenuBarSnapshot(generation: snapshot.generation + 1, items: items)
    }

    private func copying(
        _ item: MenuBarItem,
        position: Int? = nil,
        availability: MenuBarItemAvailability? = nil,
        role: MenuBarItemRole? = nil,
        surfaceID: MenuBarSurfaceID? = nil
    ) -> MenuBarItem {
        MenuBarItem(
            id: item.id,
            position: position ?? item.position,
            isMovable: (role ?? item.role) == .item,
            displayName: "Synthetic item",
            ownership: item.ownership,
            availability: availability ?? item.availability,
            role: role ?? item.role,
            frame: item.frame,
            surfaceID: surfaceID ?? item.surfaceID
        )
    }

    private func id(_ value: String) -> MenuBarItemID {
        MenuBarItemID(rawValue: "fixture.\(value)")
    }
}
