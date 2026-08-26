// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Darwin
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

    func testEveryDestinationExposesItsShippingSurface() {
        let application = XCUIApplication()
        application.launch()

        let destinations = [
            ("Overview", "Your menu bar, in focus."),
            ("Menu Bar", "Accessibility required"),
            ("Plugins", "prismCalc"),
            ("Shortcuts", "prismBar commands"),
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
        let application = XCUIApplication()
        application.launch()

        let destinations = [
            ("Overview", "overview.header.sparkles"),
            ("Menu Bar", "menuBar.header.menubar.rectangle"),
            ("Plugins", "plugins.header.puzzlepiece.extension"),
            ("Shortcuts", "shortcuts.header.keyboard"),
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
            let application = XCUIApplication()
            application.launchArguments = launchArguments
            application.launch()

            let mainWindow = application.windows.firstMatch
            XCTAssertTrue(
                mainWindow.waitForExistence(timeout: 5),
                "Main window unavailable for \(launchArguments)"
            )
            XCTAssertEqual(mainWindow.title, "prismBar")

            for destination in ["Overview", "Menu Bar", "Plugins", "Shortcuts", "Privacy", "About"] {
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

    func testKeyboardCommandReopensTheMainWindow() {
        let application = XCUIApplication()
        application.launch()

        let mainWindow = application.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
        application.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(mainWindow.waitForNonExistence(timeout: 3))

        application.typeKey("o", modifierFlags: [.command, .shift])

        XCTAssertTrue(mainWindow.waitForExistence(timeout: 3))
        XCTAssertEqual(mainWindow.title, "prismBar")
    }

    func testBundledPrismCalcPluginRunsAcrossTheSignedXPCBoundary() {
        let application = XCUIApplication()
        application.launch()

        let pluginsDestination = sidebarCell(named: "Plugins", in: application)
        XCTAssertTrue(pluginsDestination.waitForExistence(timeout: 5))
        pluginsDestination.click()

        let panelTitle = application.staticTexts["prismCalc"]
        XCTAssertTrue(panelTitle.waitForExistence(timeout: 7), application.debugDescription)
        let health = application.descendants(matching: .any)["plugin.health"]
        XCTAssertTrue(health.waitForExistence(timeout: 3))
        XCTAssertEqual(health.label, "Plugin health: Verified and ready")

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

        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(application.buttons["Open prismBar"].waitForNonExistence(timeout: 3))

        statusItem.click()
        XCTAssertTrue(application.buttons["Open prismBar"].waitForExistence(timeout: 3))

        application.buttons["Open prismBar"].click()
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 3))
        XCTAssertEqual(mainWindow.title, "prismBar")
    }

    func testHungPluginTimesOutWithoutHangingHostAndRecovers() throws {
        let application = XCUIApplication()
        application.launch()
        try openReadyPlugin(in: application)

        let servicePID = try XCTUnwrap(Self.pluginServicePID())
        XCTAssertEqual(kill(servicePID, SIGSTOP), 0)
        defer {
            _ = kill(servicePID, SIGCONT)
        }

        application.buttons["Seven"].click()
        XCTAssertTrue(application.staticTexts["prismCalc unavailable"].waitForExistence(timeout: 5))
        XCTAssertEqual(
            application.descendants(matching: .any)["plugin.health"].label,
            "Plugin health: Connection needs attention"
        )
        XCTAssertNotEqual(application.state, .notRunning)

        XCTAssertEqual(kill(servicePID, SIGCONT), 0)
        application.buttons["Retry"].click()
        XCTAssertTrue(application.buttons["Seven"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(application.state, .notRunning)
    }

    func testCrashedPluginDoesNotCrashHostAndRecovers() throws {
        let application = XCUIApplication()
        application.launch()
        try openReadyPlugin(in: application)

        let servicePID = try XCTUnwrap(Self.pluginServicePID())
        XCTAssertEqual(kill(servicePID, SIGSTOP), 0)
        application.buttons["Seven"].click()
        XCTAssertEqual(kill(servicePID, SIGKILL), 0)

        XCTAssertTrue(application.staticTexts["prismCalc unavailable"].waitForExistence(timeout: 5))
        XCTAssertEqual(
            application.descendants(matching: .any)["plugin.health"].label,
            "Plugin health: Connection needs attention"
        )
        XCTAssertNotEqual(application.state, .notRunning)

        application.buttons["Retry"].click()
        XCTAssertTrue(application.buttons["Seven"].waitForExistence(timeout: 8))
        XCTAssertNotEqual(application.state, .notRunning)
    }

    private func sidebarCell(named name: String, in application: XCUIApplication) -> XCUIElement {
        application.outlines["Sidebar"].cells
            .containing(.staticText, identifier: name)
            .element
    }

    private func openReadyPlugin(in application: XCUIApplication) throws {
        let pluginsDestination = sidebarCell(named: "Plugins", in: application)
        XCTAssertTrue(pluginsDestination.waitForExistence(timeout: 5))
        pluginsDestination.click()
        XCTAssertTrue(application.buttons["Seven"].waitForExistence(timeout: 7))
        _ = try XCTUnwrap(Self.pluginServicePID())
    }

    private nonisolated static func pluginServicePID() -> pid_t? {
        var processIdentifiers = [pid_t](repeating: 0, count: 16_384)
        let byteCount = proc_listallpids(
            &processIdentifiers,
            Int32(processIdentifiers.count * MemoryLayout<pid_t>.stride)
        )
        guard byteCount > 0 else { return nil }

        let processCount = Int(byteCount) / MemoryLayout<pid_t>.stride
        let serviceSuffix = "/Build/Products/Debug/prismBar.app/Contents/XPCServices/" +
            "prismCalcPluginService.xpc/Contents/MacOS/prismCalcPluginService"

        for processIdentifier in processIdentifiers.prefix(processCount) where processIdentifier > 0 {
            var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
            let pathLength = proc_pidpath(
                processIdentifier,
                &pathBuffer,
                UInt32(pathBuffer.count)
            )
            guard pathLength > 0 else { continue }

            let pathBytes = pathBuffer.prefix(Int(pathLength))
                .prefix { $0 != 0 }
                .map { UInt8(bitPattern: $0) }
            guard let executablePath = String(bytes: pathBytes, encoding: .utf8) else {
                continue
            }
            if executablePath.contains("/Build/Products/Debug/prismBar.app/") &&
                executablePath.hasSuffix(serviceSuffix) {
                return processIdentifier
            }
        }
        return nil
    }

}
