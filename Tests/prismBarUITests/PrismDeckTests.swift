// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

@MainActor
final class PrismDeckTests: XCTestCase {
    func testStatusItemOpensPrismDeckWithWorkspaceClosed() {
        let application = prismBarApplication(opensWorkspace: false)
        application.launch()

        let workspace = closeWorkspaceIfNeeded(in: application)
        let statusItem = prismBarStatusItem(in: application)
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), application.debugDescription)
        statusItem.click()

        let deckTitle = application.staticTexts["prismDeck"]
        XCTAssertTrue(deckTitle.waitForExistence(timeout: 3))
        XCTAssertTrue(application.buttons["Open Workspace"].exists)
        XCTAssertFalse(application.buttons["Open prismCalc"].exists)
        XCTAssertFalse(application.radioButtons["Tools"].exists)

        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(deckTitle.waitForNonExistence(timeout: 3))

        statusItem.click()
        XCTAssertTrue(deckTitle.waitForExistence(timeout: 3))

        application.buttons["Open Workspace"].click()
        XCTAssertTrue(workspace.waitForExistence(timeout: 3))
        XCTAssertEqual(workspace.title, "prismBar")
    }

    func testPrismDeckOpensSettingsWithoutWorkspace() {
        let application = prismBarApplication(opensWorkspace: false)
        application.launch()

        let workspace = closeWorkspaceIfNeeded(in: application)
        let statusItem = prismBarStatusItem(in: application)
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), application.debugDescription)
        statusItem.click()

        let settings = application.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        settings.click()

        let settingsWindow = application.windows
            .matching(identifier: "com_apple_SwiftUI_Settings_window")
            .firstMatch
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5), application.debugDescription)
        XCTAssertGreaterThanOrEqual(settingsWindow.frame.width, 640)
        XCTAssertGreaterThanOrEqual(settingsWindow.frame.height, 500)
        XCTAssertTrue(settingsWindow.buttons["General"].exists)
        XCTAssertTrue(settingsWindow.buttons["Privacy"].exists)
        XCTAssertFalse(workspace.exists)

        application.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(settingsWindow.waitForNonExistence(timeout: 3))

        statusItem.click()
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        settings.click()
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))
        XCTAssertFalse(workspace.exists)
    }

    private func closeWorkspaceIfNeeded(in application: XCUIApplication) -> XCUIElement {
        let workspace = application.windows["prismBar"]
        if workspace.waitForExistence(timeout: 1) {
            application.typeKey("w", modifierFlags: .command)
            XCTAssertTrue(workspace.waitForNonExistence(timeout: 3))
        }
        return workspace
    }

    private func prismBarStatusItem(in application: XCUIApplication) -> XCUIElement {
        application.descendants(matching: .statusItem)
            .matching(identifier: "prismBar")
            .firstMatch
    }
}
