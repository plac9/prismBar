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
}
