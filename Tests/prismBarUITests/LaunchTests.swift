// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

@MainActor
final class LaunchTests: XCTestCase {
    func testMainWindowUsesExactProductName() {
        let application = prismBarApplication()
        application.launch()

        let mainWindow = application.windows["prismBar"]
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
        XCTAssertEqual(mainWindow.title, "prismBar")
    }

    func testPermissionRecoveryControlIsAccessible() {
        let application = prismBarApplication()
        application.launch()

        let refreshButton = application.buttons["accessibility.refresh"]
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 5))
        XCTAssertEqual(refreshButton.label, "Check Again")
    }

    func testMenuBarDestinationHasARecoveryStateWithoutPermission() {
        let application = prismBarApplication()
        application.launch()

        let menuBarDestination = sidebarCell(named: "Menu Bar", in: application)
        XCTAssertTrue(menuBarDestination.waitForExistence(timeout: 5))
        menuBarDestination.click()

        XCTAssertTrue(application.staticTexts["Accessibility required"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            application.buttons["menuBar.primaryRecovery"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            application.buttons["menuBar.checkAccess"]
                .waitForExistence(timeout: 3)
        )
    }

    func testChangingDestinationsDoesNotResizeOrDisplaceTheWindow() {
        let application = prismBarApplication()
        application.launch()

        let mainWindow = application.windows["prismBar"]
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

    func testAutomationDestinationExposesPrivacyPreservingCommands() {
        let application = prismBarApplication()
        application.launch()

        let automationDestination = sidebarCell(named: "Automation", in: application)
        XCTAssertTrue(automationDestination.waitForExistence(timeout: 5))
        automationDestination.click()

        XCTAssertTrue(application.staticTexts["prismBar commands"].waitForExistence(timeout: 5))
        XCTAssertTrue(application.staticTexts["No global keyboard monitoring"].exists)
    }

    func testPrivacyTruthNamesLocalObservationAndDataBoundary() {
        let application = prismBarApplication()
        application.launch()

        let privacyDestination = sidebarCell(named: "Privacy", in: application)
        XCTAssertTrue(privacyDestination.waitForExistence(timeout: 5))
        privacyDestination.click()

        XCTAssertTrue(
            application.staticTexts
                .matching(NSPredicate(format: "value CONTAINS %@", PrivacyCopyFixture.observation))
                .firstMatch
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            application.staticTexts
                .matching(NSPredicate(format: "value CONTAINS %@", PrivacyCopyFixture.boundary))
                .firstMatch
                .exists
        )
    }

    func testEveryDestinationExposesItsShippingSurface() {
        let application = prismBarApplication()
        application.launch()

        let destinations = [
            ("Home", "Your menu bar, in focus."),
            ("Menu Bar", "Accessibility required"),
            ("Automation", "prismBar commands"),
            ("Privacy", "Your menu bar stays on your Mac."),
            ("About", "Mozilla Public License 2.0"),
        ]

        for (destination, expectedText) in destinations {
            let cell = sidebarCell(named: destination, in: application)
            XCTAssertTrue(cell.waitForExistence(timeout: 5))
            cell.click()
            XCTAssertTrue(
                application.staticTexts[expectedText].waitForExistence(timeout: 5),
                "Missing \(expectedText) in \(destination)"
            )
        }

        XCTAssertTrue(
            application.descendants(matching: .any)
                .matching(identifier: "toolbar.connection")
                .firstMatch.exists
        )
        XCTAssertTrue(application.buttons["toolbar.refresh"].exists)
    }

    func testEveryDestinationHasAContextualHeader() {
        let application = prismBarApplication()
        application.launch()

        let destinations = [
            ("Home", "home.header.sparkles"),
            ("Menu Bar", "menuBar.header.menubar.rectangle"),
            ("Automation", "automation.header.bolt.badge.clock"),
            ("Privacy", "privacy.header.hand.raised"),
            ("About", "about.header.info.circle"),
        ]

        for (destination, headerIdentifier) in destinations {
            let cell = sidebarCell(named: destination, in: application)
            XCTAssertTrue(cell.waitForExistence(timeout: 5))
            cell.click()
            XCTAssertTrue(
                application.descendants(matching: .any)[headerIdentifier]
                    .waitForExistence(timeout: 5),
                "Missing contextual header for \(destination)"
            )
        }
    }

    func testShippingSurfacesRemainUsableAcrossSystemAppearanceVariants() {
        let variants: [[String]] = [
            ["-AppleInterfaceStyle", "Dark"],
            ["-NSAccessibilityDisplayShouldIncreaseContrast", "YES"],
            ["-NSAccessibilityReduceTransparencyEnabled", "YES"],
            ["-NSAccessibilityReduceMotionEnabled", "YES"],
        ]

        for launchArguments in variants {
            let application = prismBarApplication(
                additionalLaunchArguments: launchArguments
            )
            application.launch()

            let mainWindow = application.windows["prismBar"]
            XCTAssertTrue(
                mainWindow.waitForExistence(timeout: 5),
                "Main window unavailable for \(launchArguments)"
            )
            XCTAssertEqual(mainWindow.title, "prismBar")

            for destination in ["Home", "Menu Bar", "Automation", "Privacy", "About"] {
                application.activate()
                XCTAssertEqual(
                    application.state,
                    .runningForeground,
                    "prismBar did not recover foreground focus for \(launchArguments)"
                )
                let cell = sidebarCell(named: destination, in: application)
                XCTAssertTrue(
                    cell.waitForExistence(timeout: 5),
                    "Missing \(destination) for \(launchArguments)"
                )
                cell.click()
                XCTAssertEqual(application.state, .runningForeground)
            }

            application.terminate()
        }
    }

    func testNativeSettingsCommandReusesOneAdaptiveWindow() {
        let application = prismBarApplication()
        application.launch()

        application.typeKey(",", modifierFlags: .command)
        let settingsWindows = application.windows.matching(
            identifier: "com_apple_SwiftUI_Settings_window"
        )
        let settings = settingsWindows.firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5), application.debugDescription)
        XCTAssertGreaterThanOrEqual(settings.frame.width, 640)
        XCTAssertGreaterThanOrEqual(settings.frame.height, 500)
        XCTAssertTrue(settings.buttons["General"].exists)
        let privacy = settings.buttons["Privacy"]
        XCTAssertTrue(privacy.exists)

        privacy.click()
        XCTAssertGreaterThanOrEqual(
            privacy.frame.minY - settings.frame.minY,
            20,
            "Switching Settings tabs must keep the native toolbar fully inside the window"
        )

        application.typeKey(",", modifierFlags: .command)
        XCTAssertEqual(settingsWindows.count, 1)
    }

    func testKeyboardCommandReopensTheMainWindow() {
        let application = prismBarApplication()
        application.launch()

        let mainWindow = application.windows["prismBar"]
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
        application.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(mainWindow.waitForNonExistence(timeout: 3))

        application.typeKey("o", modifierFlags: [.command, .shift])

        XCTAssertTrue(mainWindow.waitForExistence(timeout: 3))
        XCTAssertEqual(mainWindow.title, "prismBar")
    }

}

@MainActor
private func sidebarCell(named name: String, in application: XCUIApplication) -> XCUIElement {
    application.descendants(matching: .any)["workspace.sidebar"].cells
        .containing(.staticText, identifier: name)
        .element
}

private enum PrivacyCopyFixture {
    static let observation = "prismBar observes local menu bar structure on activation, when you refresh, " +
        "and during requested movement."
    static let boundary = "It does not capture the screen or upload menu titles, process identity, " +
        "coordinates, or topology."
}
