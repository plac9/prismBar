// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

@MainActor
final class VisualAuditTests: XCTestCase {
    private var systemUIOcclusionDetected = false

    func testCapturesPrivacySafeShippingSurfaces() {
        let interruptionMonitor = installSystemUIOcclusionMonitor()
        defer { removeUIInterruptionMonitor(interruptionMonitor) }

        let application = prismBarApplication(
            additionalLaunchArguments: ["--prismbar-ui-audit"]
        )
        application.launch()
        application.activate()

        let workspace = openWorkspaceIfNeeded(in: application)
        XCTAssertTrue(workspace.waitForExistence(timeout: 5))
        XCTAssertEqual(workspace.frame.width, 920, accuracy: 24)
        XCTAssertEqual(workspace.frame.height, 640, accuracy: 24)

        let destinations = [
            ("Home", "home.header.sparkles", "01-home"),
            ("Menu Bar", "menuBar.header.menubar.rectangle", "02-menu-bar"),
            ("Tools", "tools.header.wrench.and.screwdriver", "03-tools"),
            ("Automation", "automation.header.bolt.badge.clock", "05-automation"),
            ("Privacy", "privacy.header.hand.raised", "06-privacy"),
            ("About", "about.header.info.circle", "07-about"),
        ]

        for (destination, headerIdentifier, attachmentName) in destinations {
            let cell = sidebarCell(named: destination, in: application)
            XCTAssertTrue(cell.waitForExistence(timeout: 5))
            cell.click()
            XCTAssertTrue(
                application.descendants(matching: .any)[headerIdentifier]
                    .waitForExistence(timeout: 5)
            )
            assertShippingSurfaceIsUnobscured()
            if destination == "About" {
                XCTAssertFalse(application.staticTexts["Local development"].exists)
            }
            attach(workspace.screenshot(), named: attachmentName)

            if destination == "Tools" {
                captureReadyPrismCalc(in: application)
            }
        }

        captureSettingsAndStatusItem(in: application, workspace: workspace)
    }

    private func captureSettingsAndStatusItem(
        in application: XCUIApplication,
        workspace: XCUIElement
    ) {
        application.typeKey(",", modifierFlags: .command)
        let settings = application.windows
            .matching(identifier: "com_apple_SwiftUI_Settings_window")
            .firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        assertShippingSurfaceIsUnobscured()
        attach(settings.screenshot(), named: "08-settings")

        application.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(settings.waitForNonExistence(timeout: 3))
        application.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(workspace.waitForNonExistence(timeout: 3))

        let statusItem = application.descendants(matching: .statusItem)
            .matching(identifier: "prismBar")
            .firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        assertShippingSurfaceIsUnobscured()
        attach(statusItem.screenshot(), named: "09-status-item")
    }

    private func captureReadyPrismCalc(in application: XCUIApplication) {
        let health = application.descendants(matching: .any)["plugin.health"]
        XCTAssertTrue(health.waitForExistence(timeout: 5))
        XCTAssertEqual(health.label, "Plugin health: Verified and ready")

        let openButton = application.buttons["Open prismCalc"]
        XCTAssertTrue(openButton.isEnabled)
        openButton.click()

        let utility = application.windows["prismCalc"]
        XCTAssertTrue(utility.waitForExistence(timeout: 5))
        XCTAssertTrue(application.descendants(matching: .any)["plugin.panel"].waitForExistence(timeout: 5))
        utility.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03)).click()
        assertShippingSurfaceIsUnobscured()
        attach(utility.screenshot(), named: "04-prism-calc")
        let closeButton = utility.buttons["_XCUI:CloseWindow"]
        XCTAssertTrue(closeButton.exists)
        closeButton.click()
        XCTAssertTrue(utility.waitForNonExistence(timeout: 3))
    }

    private func installSystemUIOcclusionMonitor() -> NSObjectProtocol {
        systemUIOcclusionDetected = false
        return addUIInterruptionMonitor(
            withDescription: "Reject system UI occlusion"
        ) { [weak self] _ in
            self?.systemUIOcclusionDetected = true
            return false
        }
    }

    private func assertShippingSurfaceIsUnobscured() {
        XCTAssertFalse(
            systemUIOcclusionDetected,
            "System UI is obscuring the shipping surface"
        )
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func sidebarCell(named name: String, in application: XCUIApplication) -> XCUIElement {
        application.descendants(matching: .any)["workspace.sidebar"].cells
            .containing(.staticText, identifier: name)
            .element
    }

    private func openWorkspaceIfNeeded(in application: XCUIApplication) -> XCUIElement {
        let workspace = application.windows["prismBar"]
        guard !workspace.waitForExistence(timeout: 1) else {
            return workspace
        }

        let statusItem = application.descendants(matching: .statusItem)
            .matching(identifier: "prismBar")
            .firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), application.debugDescription)
        statusItem.click()

        let openWorkspace = application.buttons["Open Workspace"]
        XCTAssertTrue(openWorkspace.waitForExistence(timeout: 3), application.debugDescription)
        openWorkspace.click()
        return workspace
    }
}
