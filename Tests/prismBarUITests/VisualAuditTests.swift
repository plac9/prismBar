// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

@MainActor
final class VisualAuditTests: XCTestCase {
    func testCapturesPrivacySafeShippingSurfaces() {
        let application = XCUIApplication()
        application.launchArguments = ["--prismbar-ui-audit"]
        application.launch()

        let workspace = application.windows["prismBar"]
        XCTAssertTrue(workspace.waitForExistence(timeout: 5))
        XCTAssertEqual(workspace.frame.width, 920, accuracy: 1)
        XCTAssertEqual(workspace.frame.height, 640, accuracy: 1)

        let destinations = [
            ("Home", "home.header.sparkles", "01-home"),
            ("Menu Bar", "menuBar.header.menubar.rectangle", "02-menu-bar"),
            ("Tools", "tools.header.wrench.and.screwdriver", "03-tools"),
            ("Automation", "automation.header.bolt.badge.clock", "04-automation"),
            ("Privacy", "privacy.header.hand.raised", "05-privacy"),
            ("About", "about.header.info.circle", "06-about"),
        ]

        for (destination, headerIdentifier, attachmentName) in destinations {
            let cell = sidebarCell(named: destination, in: application)
            XCTAssertTrue(cell.waitForExistence(timeout: 5))
            cell.click()
            XCTAssertTrue(
                application.descendants(matching: .any)[headerIdentifier]
                    .waitForExistence(timeout: 5)
            )
            if destination == "About" {
                XCTAssertFalse(application.staticTexts["Local development"].exists)
            }
            attach(workspace.screenshot(), named: attachmentName)
        }

        application.typeKey(",", modifierFlags: .command)
        let settings = application.windows
            .matching(identifier: "com_apple_SwiftUI_Settings_window")
            .firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        attach(settings.screenshot(), named: "07-settings")

        application.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(settings.waitForNonExistence(timeout: 3))
        application.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(workspace.waitForNonExistence(timeout: 3))

        let statusItem = application.descendants(matching: .statusItem)
            .matching(identifier: "prismBar")
            .firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        attach(statusItem.screenshot(), named: "08-status-item")
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func sidebarCell(named name: String, in application: XCUIApplication) -> XCUIElement {
        application.cells
            .containing(.staticText, identifier: name)
            .firstMatch
    }
}
