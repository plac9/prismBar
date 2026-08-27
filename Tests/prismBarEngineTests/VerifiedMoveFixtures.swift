// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarCore
import Testing

func snapshot(names: [String], generation: UInt64) -> MenuBarSnapshot {
    MenuBarSnapshot(
        generation: generation,
        items: names.enumerated().map { index, name in
            MenuBarItem(
                id: id(name),
                position: index,
                isMovable: true,
                displayName: name,
                frame: MenuBarItemFrame(
                    minX: Double(index * 30),
                    minY: 0,
                    width: 24,
                    height: 24
                )
            )
        }
    )
}

func sectionedSnapshot(
    hiddenNames: [String],
    visibleNames: [String],
    generation: UInt64
) -> MenuBarSnapshot {
    let surfaceID = MenuBarSurfaceID(rawValue: "main")
    let orderedNames = hiddenNames + ["divider"] + visibleNames
    return MenuBarSnapshot(
        generation: generation,
        items: orderedNames.enumerated().map { index, name in
            MenuBarItem(
                id: id(name),
                position: index,
                isMovable: name != "divider",
                displayName: name,
                role: name == "divider" ? .hiddenSectionDivider : .item,
                frame: MenuBarItemFrame(
                    minX: Double(index * 30),
                    minY: 0,
                    width: 24,
                    height: 24
                ),
                surfaceID: surfaceID
            )
        }
    )
}

func id(_ value: String) -> MenuBarItemID {
    MenuBarItemID(rawValue: value)
}

actor StalledMovePerformer: MenuBarMovePerforming {
    private(set) var executionCount = 0

    func move(
        source _: MenuBarItemFrame,
        destination _: MenuBarItemFrame,
        insertionEdge _: MenuBarInsertionEdge,
        deadline: OperationDeadline
    ) async throws {
        executionCount += 1
        try await Task.sleep(for: deadline.remaining())
        throw OperationDeadlineError.expired
    }
}
