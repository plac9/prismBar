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
}
