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
        XCTAssertEqual(PrismDeckLayoutPolicy.width(for: .standard), 440)
        XCTAssertEqual(PrismDeckLayoutPolicy.compactHeight(for: .standard), 360)
        XCTAssertEqual(PrismDeckLayoutPolicy.maximumHeight(for: .standard), 620)
        XCTAssertEqual(
            PrismDeckLayoutPolicy.height(accessibilityGranted: false, textSize: .standard),
            PrismDeckLayoutPolicy.compactHeight(for: .standard)
        )
        XCTAssertEqual(
            PrismDeckLayoutPolicy.height(accessibilityGranted: true, textSize: .standard),
            PrismDeckLayoutPolicy.maximumHeight(for: .standard)
        )
        XCTAssertGreaterThan(
            PrismDeckLayoutPolicy.width(for: .accessibility),
            PrismDeckLayoutPolicy.width(for: .standard)
        )
        XCTAssertGreaterThan(
            PrismDeckLayoutPolicy.maximumHeight(for: .accessibility),
            PrismDeckLayoutPolicy.maximumHeight(for: .standard)
        )
        XCTAssertFalse(PrismDeckLayoutPolicy.showsPrismCards)
        XCTAssertFalse(PrismDeckLayoutPolicy.showsReset)
    }

    func testAccessibilityLayoutIsBoundedToTheVisibleDisplay() {
        let size = PrismDeckLayoutPolicy.contentSize(
            accessibilityGranted: true,
            textSize: .accessibility,
            visibleFrameSize: CGSize(width: 1_024, height: 640)
        )

        XCTAssertEqual(size.width, 560)
        XCTAssertEqual(size.height, 600)
        XCTAssertLessThan(size.height, 640)
    }

    func testDisplayConstraintNeverEnlargesThePreferredLayout() {
        let size = PrismDeckLayoutPolicy.contentSize(
            accessibilityGranted: false,
            textSize: .standard,
            visibleFrameSize: CGSize(width: 1_920, height: 1_080)
        )

        XCTAssertEqual(size.width, PrismDeckLayoutPolicy.width(for: .standard))
        XCTAssertEqual(size.height, PrismDeckLayoutPolicy.compactHeight(for: .standard))
    }
}
