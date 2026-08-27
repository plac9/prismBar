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

        let mainWindow = application.windows["prismBar"]
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
        let application = XCUIApplication()
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
        let application = XCUIApplication()
        application.launch()

        let automationDestination = sidebarCell(named: "Automation", in: application)
        XCTAssertTrue(automationDestination.waitForExistence(timeout: 5))
        automationDestination.click()

        XCTAssertTrue(application.staticTexts["prismBar commands"].waitForExistence(timeout: 5))
        XCTAssertTrue(application.staticTexts["No global keyboard monitoring"].exists)
    }

    func testPrivacyTruthNamesLocalObservationAndDataBoundary() {
        let application = XCUIApplication()
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
        let application = XCUIApplication()
        application.launch()

        let destinations = [
            ("Home", "Your menu bar, in focus."),
            ("Menu Bar", "Accessibility required"),
            ("Tools", "prismCalc"),
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
        let application = XCUIApplication()
        application.launch()

        let destinations = [
            ("Home", "home.header.sparkles"),
            ("Menu Bar", "menuBar.header.menubar.rectangle"),
            ("Tools", "tools.header.wrench.and.screwdriver"),
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
            let application = XCUIApplication()
            application.launchArguments = launchArguments
            application.launch()

            let mainWindow = application.windows["prismBar"]
            XCTAssertTrue(
                mainWindow.waitForExistence(timeout: 5),
                "Main window unavailable for \(launchArguments)"
            )
            XCTAssertEqual(mainWindow.title, "prismBar")

            for destination in ["Home", "Menu Bar", "Tools", "Automation", "Privacy", "About"] {
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
        let application = XCUIApplication()
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
        XCTAssertTrue(settings.buttons["Privacy"].exists)

        application.typeKey(",", modifierFlags: .command)
        XCTAssertEqual(settingsWindows.count, 1)
    }

    func testKeyboardCommandReopensTheMainWindow() {
        let application = XCUIApplication()
        application.launch()

        let mainWindow = application.windows["prismBar"]
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
        application.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(mainWindow.waitForNonExistence(timeout: 3))

        application.typeKey("o", modifierFlags: [.command, .shift])

        XCTAssertTrue(mainWindow.waitForExistence(timeout: 3))
        XCTAssertEqual(mainWindow.title, "prismBar")
    }

    func testToolsWorkspaceLaunchesPrismCalcWithoutEmbeddingCalculator() {
        let application = XCUIApplication()
        application.launch()

        let toolsDestination = sidebarCell(named: "Tools", in: application)
        XCTAssertTrue(toolsDestination.waitForExistence(timeout: 5))
        toolsDestination.click()

        let panelTitle = application.staticTexts["prismCalc"]
        XCTAssertTrue(panelTitle.waitForExistence(timeout: 7), application.debugDescription)
        let health = application.descendants(matching: .any)["plugin.health"]
        XCTAssertTrue(health.waitForExistence(timeout: 3))
        XCTAssertEqual(health.label, "Plugin health: Verified and ready")

        XCTAssertFalse(application.staticTexts["Calculator result"].exists)

        let openTool = application.buttons["Open prismCalc"]
        XCTAssertTrue(openTool.waitForExistence(timeout: 3))
        openTool.click()

        let utility = application.windows["prismCalc"]
        XCTAssertTrue(utility.waitForExistence(timeout: 5), application.debugDescription)
        XCTAssertTrue(application.staticTexts["Calculator result"].waitForExistence(timeout: 5))
    }

    func testHungPluginTimesOutWithoutHangingHostAndRecovers() throws {
        let application = XCUIApplication()
        application.launch()
        try openReadyPlugin(in: application)

        let servicePID = try XCTUnwrap(pluginServicePID())
        XCTAssertEqual(kill(servicePID, SIGSTOP), 0)
        defer {
            _ = kill(servicePID, SIGCONT)
        }

        let utility = application.windows["prismCalc"]
        let workspace = application.windows["prismBar"]
        utility.buttons["Seven"].click()
        XCTAssertTrue(utility.staticTexts["prismCalc unavailable"].waitForExistence(timeout: 5))
        XCTAssertEqual(
            workspace.descendants(matching: .any)["plugin.health"].label,
            "Plugin health: Connection needs attention"
        )
        XCTAssertNotEqual(application.state, .notRunning)

        XCTAssertEqual(kill(servicePID, SIGCONT), 0)
        utility.buttons["Retry"].click()
        XCTAssertTrue(utility.buttons["Seven"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(application.state, .notRunning)
    }

    func testCrashedPluginDoesNotCrashHostAndRecovers() throws {
        let application = XCUIApplication()
        application.launch()
        try openReadyPlugin(in: application)

        let servicePID = try XCTUnwrap(pluginServicePID())
        XCTAssertEqual(kill(servicePID, SIGSTOP), 0)
        let utility = application.windows["prismCalc"]
        let workspace = application.windows["prismBar"]
        utility.buttons["Seven"].click()
        XCTAssertEqual(kill(servicePID, SIGKILL), 0)

        XCTAssertTrue(utility.staticTexts["prismCalc unavailable"].waitForExistence(timeout: 5))
        XCTAssertEqual(
            workspace.descendants(matching: .any)["plugin.health"].label,
            "Plugin health: Connection needs attention"
        )
        XCTAssertNotEqual(application.state, .notRunning)

        utility.buttons["Retry"].click()
        XCTAssertTrue(utility.buttons["Seven"].waitForExistence(timeout: 8))
        XCTAssertNotEqual(application.state, .notRunning)
    }

}

@MainActor
private func sidebarCell(named name: String, in application: XCUIApplication) -> XCUIElement {
    application.descendants(matching: .any)["workspace.sidebar"].cells
        .containing(.staticText, identifier: name)
        .element
}

@MainActor
private func openReadyPlugin(in application: XCUIApplication) throws {
    let toolsDestination = sidebarCell(named: "Tools", in: application)
    XCTAssertTrue(toolsDestination.waitForExistence(timeout: 5))
    toolsDestination.click()
    let openTool = application.buttons["Open prismCalc"]
    XCTAssertTrue(openTool.waitForExistence(timeout: 7))
    openTool.click()
    XCTAssertTrue(application.buttons["Seven"].waitForExistence(timeout: 7))
    _ = try XCTUnwrap(pluginServicePID())
}

private func pluginServicePID() -> pid_t? {
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
        let pathLength = proc_pidpath(processIdentifier, &pathBuffer, UInt32(pathBuffer.count))
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

private enum PrivacyCopyFixture {
    static let observation = "prismBar observes local menu bar structure on activation, when you refresh, " +
        "and during requested movement."
    static let boundary = "It does not capture the screen or upload menu titles, process identity, " +
        "coordinates, or topology."
}
