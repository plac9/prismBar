// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarCore
import Testing

@Suite("Rail drops")
struct PrismRailDropResolverTests {
    @Test("builds one display layout with ordered visible and hidden lanes")
    func buildsSelectedSurfaceLayout() {
        let first = MenuBarSurfaceID(rawValue: "first")
        let second = MenuBarSurfaceID(rawValue: "second")
        let snapshot = MenuBarSnapshot(
            generation: 8,
            items: [
                item("private.one", position: 0, surface: first),
                item("divider.one", position: 1, movable: false, role: .hiddenSectionDivider, surface: first),
                item("public.one", position: 2, surface: first),
                item("private.two", position: 3, surface: second),
                item("divider.two", position: 4, movable: false, role: .hiddenSectionDivider, surface: second),
                item("public.two", position: 5, surface: second),
            ]
        )

        let layout = PrismRailLayout(snapshot: snapshot, surfaceID: second)

        #expect(layout.surfaceID == second)
        #expect(layout.hiddenItems.map(\.id) == [id("private.two")])
        #expect(layout.visibleItems.map(\.id) == [id("public.two")])
        #expect(layout.itemCount == 2)
        #expect(layout.surfaceCount == 2)
        #expect(layout.generation == 8)
    }

    @Test("resolves adjacent keyboard movement without crossing lanes")
    func resolvesAdjacentKeyboardMovement() {
        let snapshot = railSnapshot()
        let resolver = PrismRailKeyboardMoveResolver()

        #expect(resolver.resolve(.previous, itemID: id("chat"), in: snapshot) == 0)
        #expect(resolver.resolve(.next, itemID: id("mail"), in: snapshot) == 1)
        #expect(resolver.resolve(.previous, itemID: id("mail"), in: snapshot) == nil)
        #expect(resolver.resolve(.next, itemID: id("chat"), in: snapshot) == nil)
    }

    @Test("resolves first and last keyboard movement within the current lane")
    func resolvesKeyboardEndpoints() {
        let snapshot = railSnapshot()
        let resolver = PrismRailKeyboardMoveResolver()

        #expect(resolver.resolve(.first, itemID: id("chat"), in: snapshot) == 0)
        #expect(resolver.resolve(.last, itemID: id("mail"), in: snapshot) == 1)
        #expect(resolver.resolve(.first, itemID: id("mail"), in: snapshot) == nil)
        #expect(resolver.resolve(.last, itemID: id("chat"), in: snapshot) == nil)
    }

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
