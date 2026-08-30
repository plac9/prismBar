// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarCore
@testable import prismBarEngine
import Testing

@Suite("Menu item move planning")
struct MovePlannerTests {
    @Test("moves directly across multiple positions")
    func directMultiPositionMove() throws {
        let snapshot = MenuBarSnapshot(
            generation: 7,
            items: ["mail", "chat", "calendar", "audio", "battery"].enumerated().map {
                MenuBarItem(id: .init(rawValue: $0.element), position: $0.offset, isMovable: true)
            }
        )

        let plan = try MovePlanner().plan(
            item: .init(rawValue: "battery"),
            to: 1,
            in: snapshot
        )

        #expect(plan.sourceIndex == 4)
        #expect(plan.destinationIndex == 1)
        #expect(plan.expectedOrder.map(\.rawValue) == ["mail", "battery", "chat", "calendar", "audio"])
        #expect(plan.snapshotGeneration == 7)
    }

    @Test("rejects an item that macOS cannot move")
    func rejectsImmovableItem() {
        let item = MenuBarItem(id: .init(rawValue: "system"), position: 0, isMovable: false)
        let snapshot = MenuBarSnapshot(generation: 2, items: [item])

        #expect(throws: MovePlanningError.itemIsNotMovable(item.id)) {
            try MovePlanner().plan(item: item.id, to: 0, in: snapshot)
        }
    }

    @Test("rejects an out of range destination")
    func rejectsInvalidDestination() {
        let item = MenuBarItem(id: .init(rawValue: "calendar"), position: 0, isMovable: true)
        let snapshot = MenuBarSnapshot(generation: 3, items: [item])

        #expect(throws: MovePlanningError.invalidDestination(4)) {
            try MovePlanner().plan(item: item.id, to: 4, in: snapshot)
        }
    }

    @Test("rejects a destination on another display")
    func rejectsCrossDisplayMove() {
        let firstSurface = MenuBarSurfaceID(rawValue: "first")
        let secondSurface = MenuBarSurfaceID(rawValue: "second")
        let first = MenuBarItem(
            id: .init(rawValue: "one"),
            position: 0,
            isMovable: true,
            surfaceID: firstSurface
        )
        let second = MenuBarItem(
            id: .init(rawValue: "two"),
            position: 1,
            isMovable: true,
            surfaceID: secondSurface
        )
        let snapshot = MenuBarSnapshot(generation: 1, items: [first, second])

        #expect(throws: MovePlanningError.differentSurface) {
            try MovePlanner().plan(item: first.id, to: 1, in: snapshot)
        }
    }

    @Test("rejects a destination beyond the protected system cluster boundary")
    func rejectsProtectedSystemDestination() {
        let application = MenuBarItem(
            id: .init(rawValue: "calendar"),
            position: 0,
            isMovable: true,
            ownership: .application
        )
        let system = MenuBarItem(
            id: .init(rawValue: "clock"),
            position: 1,
            isMovable: true,
            ownership: .system
        )
        let snapshot = MenuBarSnapshot(generation: 1, items: [application, system])

        #expect(throws: MovePlanningError.unreachableDestination(system.id)) {
            try MovePlanner().plan(item: application.id, to: 1, in: snapshot)
        }
    }

    @Test("preserves every item exactly once for all direct moves")
    func exhaustiveDirectMoveInvariants() throws {
        for itemCount in 1 ... 12 {
            let items = (0 ..< itemCount).map { index in
                MenuBarItem(
                    id: .init(rawValue: "item-\(index)"),
                    position: index,
                    isMovable: true
                )
            }
            let snapshot = MenuBarSnapshot(generation: 42, items: items)
            let sourceOrder = items.map(\.id)

            for sourceIndex in items.indices {
                for destinationIndex in items.indices {
                    let movingID = sourceOrder[sourceIndex]
                    let plan = try MovePlanner().plan(
                        item: movingID,
                        to: destinationIndex,
                        in: snapshot
                    )

                    #expect(plan.sourceOrder == sourceOrder)
                    #expect(plan.expectedOrder.count == sourceOrder.count)
                    #expect(Set(plan.expectedOrder) == Set(sourceOrder))
                    #expect(plan.expectedOrder[destinationIndex] == movingID)
                    #expect(plan.expectedOrder.filter { $0 == movingID }.count == 1)
                }
            }
        }
    }
}
