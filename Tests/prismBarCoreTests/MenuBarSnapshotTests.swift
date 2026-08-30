// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarCore
import Testing

@Suite("Menu bar snapshots")
struct MenuBarSnapshotTests {
    @Test("allows verified movement only for controllable application items")
    func verifiedMovementPolicy() {
        let application = MenuBarItem(
            id: .init(rawValue: "application"),
            position: 0,
            isMovable: true
        )
        let system = MenuBarItem(
            id: .init(rawValue: "clock"),
            position: 1,
            isMovable: true,
            ownership: .system
        )

        #expect(application.allowsVerifiedMovement)
        #expect(!system.allowsVerifiedMovement)
    }

    @Test("numbers displays by menu order instead of private identifier value")
    func ordersSurfacesByFirstMenuItem() {
        let leadingSurface = MenuBarSurfaceID(rawValue: "z-private-id")
        let trailingSurface = MenuBarSurfaceID(rawValue: "a-private-id")
        let snapshot = MenuBarSnapshot(
            generation: 1,
            items: [
                MenuBarItem(
                    id: .init(rawValue: "leading"),
                    position: 0,
                    isMovable: true,
                    surfaceID: leadingSurface
                ),
                MenuBarItem(
                    id: .init(rawValue: "trailing"),
                    position: 1,
                    isMovable: true,
                    surfaceID: trailingSurface
                ),
            ]
        )

        #expect(snapshot.surfaceIDs == [leadingSurface, trailingSurface])
    }
}
