// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

@MainActor
final class PrismDeckTests: XCTestCase {
    func testStatusItemOpensPrismDeckWithWorkspaceClosed() {
        let application = XCUIApplication()
        application.launch()

        let workspace = closeWorkspaceIfNeeded(in: application)
        let statusItem = prismBarStatusItem(in: application)
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), application.debugDescription)
        statusItem.click()

        let modePicker = application.descendants(matching: .any)["prismDeck.mode"]
        XCTAssertTrue(modePicker.waitForExistence(timeout: 3))
        XCTAssertTrue(application.buttons["Open Workspace"].exists)

        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(modePicker.waitForNonExistence(timeout: 3))

        statusItem.click()
        XCTAssertTrue(modePicker.waitForExistence(timeout: 3))

        application.buttons["Open Workspace"].click()
        XCTAssertTrue(workspace.waitForExistence(timeout: 3))
        XCTAssertEqual(workspace.title, "prismBar")
    }

    func testToolsModeOpensPrismCalcUtilityWithoutWorkspace() {
        let application = XCUIApplication()
        application.launch()

        let workspace = closeWorkspaceIfNeeded(in: application)
        let statusItem = prismBarStatusItem(in: application)
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), application.debugDescription)
        statusItem.click()

        let modePicker = application.descendants(matching: .any)["prismDeck.mode"]
        XCTAssertTrue(modePicker.waitForExistence(timeout: 3))
        modePicker.radioButtons["Tools"].click()

        let openPrismCalc = application.buttons["Open prismCalc"]
        XCTAssertTrue(openPrismCalc.waitForExistence(timeout: 3))
        openPrismCalc.click()

        let utility = application.windows["prismCalc"]
        XCTAssertTrue(utility.waitForExistence(timeout: 5), application.debugDescription)
        XCTAssertFalse(workspace.exists)

        clickWhenEnabled(application.buttons["Seven"])
        clickWhenEnabled(application.buttons["Add"])
        clickWhenEnabled(application.buttons["Five"])
        clickWhenEnabled(application.buttons["Equals"])

        let result = application.staticTexts["Calculator result"]
        XCTAssertTrue(result.waitForExistence(timeout: 3))
        XCTAssertEqual(result.value as? String, "12")
    }

    func testPrismDeckOpensSettingsWithoutWorkspace() {
        let application = XCUIApplication()
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

    private func clickWhenEnabled(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 3), .completed)
        element.click()
    }
}
