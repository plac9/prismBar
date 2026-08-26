// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

@MainActor
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

        let menuBarDestination = sidebarCell(named: "Menu Bar", in: application)
        XCTAssertTrue(menuBarDestination.waitForExistence(timeout: 5))
        menuBarDestination.click()

        XCTAssertTrue(application.staticTexts["Accessibility required"].waitForExistence(timeout: 5))
    }

    func testChangingDestinationsDoesNotResizeOrDisplaceTheWindow() {
        let application = XCUIApplication()
        application.launch()

        let mainWindow = application.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
        let initialFrame = mainWindow.frame

        let menuBarDestination = sidebarCell(named: "Menu Bar", in: application)
        XCTAssertTrue(menuBarDestination.waitForExistence(timeout: 5))
        menuBarDestination.click()

        XCTAssertTrue(application.staticTexts["Accessibility required"].waitForExistence(timeout: 5))
        XCTAssertEqual(mainWindow.frame.origin.x, initialFrame.origin.x, accuracy: 1)
        XCTAssertEqual(mainWindow.frame.origin.y, initialFrame.origin.y, accuracy: 1)
        XCTAssertEqual(mainWindow.frame.width, initialFrame.width, accuracy: 1)
        XCTAssertEqual(mainWindow.frame.height, initialFrame.height, accuracy: 1)
    }

    func testShortcutsDestinationExposesPrivacyPreservingCommands() {
        let application = XCUIApplication()
        application.launch()

        let shortcutsDestination = sidebarCell(named: "Shortcuts", in: application)
        XCTAssertTrue(shortcutsDestination.waitForExistence(timeout: 5))
        shortcutsDestination.click()

        XCTAssertTrue(application.staticTexts["prismBar commands"].waitForExistence(timeout: 5))
        XCTAssertTrue(application.staticTexts["No global keyboard monitoring"].exists)
    }

    func testBundledPrismCalcPluginRunsAcrossTheSignedXPCBoundary() {
        let application = XCUIApplication()
        application.launch()

        let pluginsDestination = sidebarCell(named: "Plugins", in: application)
        XCTAssertTrue(pluginsDestination.waitForExistence(timeout: 5))
        pluginsDestination.click()

        let panelTitle = application.staticTexts["prismCalc"]
        XCTAssertTrue(panelTitle.waitForExistence(timeout: 7), application.debugDescription)

        application.buttons["Seven"].click()
        application.buttons["Add"].click()
        application.buttons["Five"].click()
        application.buttons["Equals"].click()

        let result = application.staticTexts["Calculator result"]
        XCTAssertTrue(result.waitForExistence(timeout: 3))
        XCTAssertEqual(result.value as? String, "12")
    }

    func testStatusItemOpensCommandCenterWithMainWindowClosed() {
        let application = XCUIApplication()
        application.launch()

        let mainWindow = application.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
        application.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(mainWindow.waitForNonExistence(timeout: 3))

        let statusItem = application.descendants(matching: .statusItem)
            .matching(identifier: "prismBar")
            .firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), application.debugDescription)
        statusItem.click()

        XCTAssertTrue(application.buttons["Open prismBar"].waitForExistence(timeout: 3))
        XCTAssertTrue(application.buttons["Quit prismBar"].exists)
    }

    private func sidebarCell(named name: String, in application: XCUIApplication) -> XCUIElement {
        application.outlines["Sidebar"].cells
            .containing(.staticText, identifier: name)
            .element
    }

}
