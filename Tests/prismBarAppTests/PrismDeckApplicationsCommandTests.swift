// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBar
import prismBarCore
import XCTest

@MainActor
final class PrismDeckApplicationsCommandTests: XCTestCase {
    func testShowAndHideUseOppositeSections() {
        XCTAssertEqual(
            PrismDeckApplicationCommand.toggleDestination(from: .visible),
            .hidden
        )
        XCTAssertEqual(
            PrismDeckApplicationCommand.toggleDestination(from: .hidden),
            .visible
        )
    }

    func testEndpointCommandsPreserveResolvedAbsolutePositions() {
        XCTAssertEqual(PrismDeckApplicationCommand.first(4).destinationPosition, 4)
        XCTAssertEqual(PrismDeckApplicationCommand.last(11).destinationPosition, 11)
        XCTAssertNil(PrismDeckApplicationCommand.toggle(.visible).destinationPosition)
    }

    func testShippingLayoutKeepsMenuBarControlPrimary() {
        XCTAssertEqual(
            PrismDeckLayoutPolicy.managementSections,
            [.topology, .rail, .applications, .actionStatus]
        )
        XCTAssertEqual(PrismDeckLayoutPolicy.maximumHeight, 620)
        XCTAssertFalse(PrismDeckLayoutPolicy.showsPrismCards)
        XCTAssertFalse(PrismDeckLayoutPolicy.showsReset)
    }
}
