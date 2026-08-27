// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarAccessibility
import prismBarCore
import Testing

@Suite("Menu bar drag geometry")
struct MenuBarDragGeometryTests {
    private let source = MenuBarItemFrame(minX: 300, minY: 0, width: 24, height: 24)
    private let destination = MenuBarItemFrame(minX: 100, minY: 0, width: 30, height: 24)

    @Test("moving left drops just before the target")
    func dropsBeforeTarget() {
        let gesture = MenuBarDragGeometry().gesture(
            source: source,
            destination: destination,
            insertionEdge: .before
        )

        #expect(gesture.start.horizontal == 312)
        #expect(gesture.end.horizontal == 101)
        #expect(gesture.end.vertical == 12)
        #expect(gesture.path.last == gesture.end)
    }

    @Test("moving right drops just after the target")
    func dropsAfterTarget() {
        let gesture = MenuBarDragGeometry().gesture(
            source: source,
            destination: destination,
            insertionEdge: .after
        )

        #expect(gesture.end.horizontal == 129)
    }

    @Test("narrow divider targets remain strictly inside both insertion edges")
    func supportsNarrowDividerTargets() {
        let divider = MenuBarItemFrame(minX: 100, minY: 0, width: 1, height: 24)
        let geometry = MenuBarDragGeometry()

        let before = geometry.gesture(
            source: source,
            destination: divider,
            insertionEdge: .before
        )
        let after = geometry.gesture(
            source: source,
            destination: divider,
            insertionEdge: .after
        )

        #expect(before.end.horizontal > divider.minX)
        #expect(before.end.horizontal < divider.minX + divider.width)
        #expect(after.end.horizontal > divider.minX)
        #expect(after.end.horizontal < divider.minX + divider.width)
        #expect(before.end.horizontal < after.end.horizontal)
    }

    @Test("long moves use a dense path with an exact endpoint")
    func samplesLongMovesDensely() {
        let gesture = MenuBarDragGeometry().gesture(
            source: source,
            destination: destination,
            insertionEdge: .before
        )

        #expect(gesture.path.count > 2)
        #expect(gesture.path.last == gesture.end)
        for (previous, next) in zip([gesture.start] + gesture.path, gesture.path) {
            #expect(abs(next.horizontal - previous.horizontal) <= 16)
            #expect(abs(next.vertical - previous.vertical) <= 16)
        }
    }

    @Test("short moves still include their exact endpoint")
    func samplesShortMoves() {
        let nearbyDestination = MenuBarItemFrame(minX: 302, minY: 0, width: 24, height: 24)
        let gesture = MenuBarDragGeometry().gesture(
            source: source,
            destination: nearbyDestination,
            insertionEdge: .after
        )

        #expect(gesture.path == [gesture.end])
    }
}

@Suite("Menu bar input safety")
struct MenuBarInputSafetyTests {
    private let validator = MenuBarInputSafetyValidator()
    private let visibleSurface = MenuBarInputSurface(
        frame: MenuBarItemFrame(minX: 0, minY: 0, width: 1800, height: 1169),
        reservedMenuBarHeight: 39
    )

    @Test("allows input only inside one visible menu bar surface")
    func allowsVisibleSameSurfaceInput() {
        let source = MenuBarItemFrame(minX: 1500, minY: 8, width: 24, height: 24)
        let destination = MenuBarItemFrame(minX: 1200, minY: 8, width: 24, height: 24)

        #expect(validator.allows(source: source, destination: destination, surfaces: [visibleSurface]))
    }

    @Test("rejects auto-hidden or full-screen menu bar surfaces")
    func rejectsSurfacesWithoutReservedMenuBarSpace() {
        let unavailableSurface = MenuBarInputSurface(
            frame: visibleSurface.frame,
            reservedMenuBarHeight: 0
        )
        let source = MenuBarItemFrame(minX: 1500, minY: 8, width: 24, height: 24)
        let destination = MenuBarItemFrame(minX: 1200, minY: 8, width: 24, height: 24)

        #expect(!validator.allows(
            source: source,
            destination: destination,
            surfaces: [unavailableSurface]
        ))
    }

    @Test("rejects stale geometry outside the reserved menu bar area")
    func rejectsStaleGeometry() {
        let staleSource = MenuBarItemFrame(minX: 1500, minY: 90, width: 24, height: 24)
        let destination = MenuBarItemFrame(minX: 1200, minY: 8, width: 24, height: 24)

        #expect(!validator.allows(
            source: staleSource,
            destination: destination,
            surfaces: [visibleSurface]
        ))
    }

    @Test("rejects input that crosses displays")
    func rejectsCrossDisplayInput() {
        let secondSurface = MenuBarInputSurface(
            frame: MenuBarItemFrame(minX: 1800, minY: 0, width: 1440, height: 900),
            reservedMenuBarHeight: 30
        )
        let source = MenuBarItemFrame(minX: 1500, minY: 8, width: 24, height: 24)
        let destination = MenuBarItemFrame(minX: 2000, minY: 4, width: 24, height: 24)

        #expect(!validator.allows(
            source: source,
            destination: destination,
            surfaces: [visibleSurface, secondSurface]
        ))
    }
}
