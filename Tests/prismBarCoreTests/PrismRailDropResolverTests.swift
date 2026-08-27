// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarCore
import Testing

@Suite("Prism Rail drops")
struct PrismRailDropResolverTests {
    @Test("selects the first surface that actually presents menu items")
    func selectsPopulatedSurface() {
        let emptySurface = MenuBarSurfaceID(rawValue: "controller-only")
        let populatedSurface = MenuBarSurfaceID(rawValue: "menu-items")
        let snapshot = MenuBarSnapshot(
            generation: 1,
            items: [
                item(
                    "controller",
                    position: 0,
                    movable: false,
                    role: .primaryControl,
                    surface: emptySurface
                ),
                item("mail", position: 1, surface: populatedSurface),
                item(
                    "divider",
                    position: 2,
                    movable: false,
                    role: .hiddenSectionDivider,
                    surface: populatedSurface
                ),
            ]
        )

        #expect(
            PrismRailSurfaceResolver().resolve(in: snapshot, current: nil)
                == populatedSurface
        )
    }

    @Test("keeps the current populated surface across refreshes")
    func retainsCurrentPopulatedSurface() {
        let first = MenuBarSurfaceID(rawValue: "first")
        let current = MenuBarSurfaceID(rawValue: "current")
        let snapshot = MenuBarSnapshot(
            generation: 2,
            items: [
                item("mail", position: 0, surface: first),
                item("calendar", position: 1, surface: current),
            ]
        )

        #expect(
            PrismRailSurfaceResolver().resolve(in: snapshot, current: current)
                == current
        )
    }

    @Test("resolves a direct drop to the target item position")
    func resolvesDirectPosition() {
        let snapshot = railSnapshot()
        let request = PrismRailDropRequest(
            itemID: id("calendar"),
            snapshotGeneration: 7,
            targetItemID: id("mail"),
            destinationSection: .hidden
        )

        #expect(
            PrismRailDropResolver().resolve(request, in: snapshot)
                == .position(0)
        )
    }

    @Test("resolves a drop across lanes in one direct move")
    func resolvesCrossLanePosition() {
        let snapshot = railSnapshot()
        let request = PrismRailDropRequest(
            itemID: id("mail"),
            snapshotGeneration: 7,
            targetItemID: id("battery"),
            destinationSection: .visible
        )

        #expect(
            PrismRailDropResolver().resolve(request, in: snapshot)
                == .position(4)
        )
    }

    @Test("resolves a drop into an empty opposite lane as a section move")
    func resolvesEmptyLaneDrop() {
        let snapshot = MenuBarSnapshot(
            generation: 3,
            items: [
                item("divider", position: 0, movable: false, role: .hiddenSectionDivider),
                item("calendar", position: 1),
                item("battery", position: 2),
            ]
        )
        let request = PrismRailDropRequest(
            itemID: id("calendar"),
            snapshotGeneration: 3,
            targetItemID: nil,
            destinationSection: .hidden
        )

        #expect(
            PrismRailDropResolver().resolve(request, in: snapshot)
                == .section(.hidden)
        )
    }

    @Test("rejects stale drag data")
    func rejectsStaleGeneration() {
        let snapshot = railSnapshot()
        let request = PrismRailDropRequest(
            itemID: id("calendar"),
            snapshotGeneration: 6,
            targetItemID: id("mail"),
            destinationSection: .hidden
        )

        #expect(PrismRailDropResolver().resolve(request, in: snapshot) == nil)
    }

    @Test("rejects a target presented in the wrong lane")
    func rejectsMismatchedLane() {
        let snapshot = railSnapshot()
        let request = PrismRailDropRequest(
            itemID: id("calendar"),
            snapshotGeneration: 7,
            targetItemID: id("mail"),
            destinationSection: .visible
        )

        #expect(PrismRailDropResolver().resolve(request, in: snapshot) == nil)
    }

    @Test("rejects a move across displays")
    func rejectsCrossSurfaceMove() {
        let snapshot = railSnapshot(
            batterySurface: MenuBarSurfaceID(rawValue: "secondary")
        )
        let request = PrismRailDropRequest(
            itemID: id("mail"),
            snapshotGeneration: 7,
            targetItemID: id("battery"),
            destinationSection: .visible
        )

        #expect(PrismRailDropResolver().resolve(request, in: snapshot) == nil)
    }

    @Test("rejects an immovable source item")
    func rejectsImmovableSource() {
        let snapshot = railSnapshot(calendarMovable: false)
        let request = PrismRailDropRequest(
            itemID: id("calendar"),
            snapshotGeneration: 7,
            targetItemID: id("mail"),
            destinationSection: .hidden
        )

        #expect(PrismRailDropResolver().resolve(request, in: snapshot) == nil)
    }

    @Test("rejects dropping an item onto itself")
    func rejectsIdentityDrop() {
        let snapshot = railSnapshot()
        let request = PrismRailDropRequest(
            itemID: id("calendar"),
            snapshotGeneration: 7,
            targetItemID: id("calendar"),
            destinationSection: .visible
        )

        #expect(PrismRailDropResolver().resolve(request, in: snapshot) == nil)
    }
}

private extension PrismRailDropResolverTests {
    func railSnapshot(
        calendarMovable: Bool = true,
        batterySurface: MenuBarSurfaceID = .unknown
    ) -> MenuBarSnapshot {
        MenuBarSnapshot(
            generation: 7,
            items: [
                item("mail", position: 0),
                item("chat", position: 1),
                item("divider", position: 2, movable: false, role: .hiddenSectionDivider),
                item("calendar", position: 3, movable: calendarMovable),
                item("battery", position: 4, surface: batterySurface),
            ]
        )
    }

    func item(
        _ value: String,
        position: Int,
        movable: Bool = true,
        role: MenuBarItemRole = .item,
        surface: MenuBarSurfaceID = .unknown
    ) -> MenuBarItem {
        MenuBarItem(
            id: id(value),
            position: position,
            isMovable: movable,
            role: role,
            surfaceID: surface
        )
    }

    func id(_ value: String) -> MenuBarItemID {
        MenuBarItemID(rawValue: value)
    }
}
