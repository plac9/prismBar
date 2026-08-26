// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

final class LaunchTests: XCTestCase {
    func testMainWindowUsesExactProductName() {
        let application = XCUIApplication()
        application.launch()

        let mainWindow = application.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
        XCTAssertEqual(mainWindow.title, "prismBar")
    }

    func testPermissionRecoveryControlIsAccessible() {
        let application = XCUIApplication()
        application.launch()

        let refreshButton = application.buttons["accessibility.refresh"]
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 5))
        XCTAssertEqual(refreshButton.label, "Check Again")
    }

    func testMenuBarDestinationHasARecoveryStateWithoutPermission() {
        let application = XCUIApplication()
        application.launch()

        let menuBarDestination = application.staticTexts["Menu Bar"].firstMatch
        XCTAssertTrue(menuBarDestination.waitForExistence(timeout: 5))
        menuBarDestination.click()

        XCTAssertTrue(application.staticTexts["Accessibility required"].waitForExistence(timeout: 5))
    }
}
