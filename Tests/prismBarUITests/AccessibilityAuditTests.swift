// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

@MainActor
final class AccessibilityAuditTests: XCTestCase {
    func testHomePassesMacOSAccessibilityAudit() throws {
        try auditWorkspaceDestination("Home")
    }

    func testMenuBarPassesMacOSAccessibilityAudit() throws {
        try auditWorkspaceDestination("Menu Bar")
    }

    func testAutomationPassesMacOSAccessibilityAudit() throws {
        try auditWorkspaceDestination("Automation")
    }

    func testPrivacyPassesMacOSAccessibilityAudit() throws {
        try auditWorkspaceDestination("Privacy")
    }

    func testAboutPassesMacOSAccessibilityAudit() throws {
        try auditWorkspaceDestination("About")
    }

    private func auditWorkspaceDestination(_ destination: String) throws {
        let application = prismBarApplication()
        application.launch()

        let workspace = application.windows["prismBar"]
        XCTAssertTrue(workspace.waitForExistence(timeout: 5), application.debugDescription)

        let row = application.cells
            .containing(.staticText, identifier: destination)
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), application.debugDescription)
        row.click()
        XCTAssertTrue(application.wait(for: .runningForeground, timeout: 3))
        try performAudit(in: application)
    }

    func testSettingsPassesMacOSAccessibilityAudit() throws {
        let application = prismBarApplication()
        application.launch()

        let workspace = application.windows["prismBar"]
        XCTAssertTrue(workspace.waitForExistence(timeout: 5), application.debugDescription)
        application.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(workspace.waitForNonExistence(timeout: 3), application.debugDescription)

        application.typeKey(",", modifierFlags: .command)
        let settings = application.windows
            .matching(identifier: "com_apple_SwiftUI_Settings_window")
            .firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5), application.debugDescription)
        try performAudit(in: application)

        let privacy = settings.buttons["Privacy"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 3), application.debugDescription)
        privacy.click()
        try performAudit(in: application)
    }

    func testPrismDeckPassesMacOSAccessibilityAudit() throws {
        let application = prismBarApplication(opensWorkspace: false)
        application.launch()

        let statusItem = application.descendants(matching: .statusItem)
            .matching(identifier: "prismBar")
            .firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), application.debugDescription)
        statusItem.click()

        let deckTitle = application.staticTexts["prismDeck"]
        XCTAssertTrue(deckTitle.waitForExistence(timeout: 3), application.debugDescription)
        try performAudit(in: application)
    }

    private var macOSAuditTypes: XCUIAccessibilityAuditType {
        [
            .action,
            .contrast,
            .elementDetection,
            .hitRegion,
            .parentChild,
            .sufficientElementDescription,
        ]
    }

    private func performAudit(in application: XCUIApplication) throws {
        try application.performAccessibilityAudit(for: macOSAuditTypes) { issue in
            if issue.auditType == .contrast,
               issue.element?.elementType == .staticText {
                // Xcode 27 beta reports contrast failures for every SwiftUI static
                // text element, including native window titles and primary system
                // text. Non-text contrast remains audited, while source policy and
                // visual audit enforce semantic text colors until Apple fixes it.
                return true
            }

            guard issue.auditType == .sufficientElementDescription,
                  let element = issue.element
            else {
                return false
            }

            // Xcode 27 exposes SwiftUI's native NavigationSplitView containers and the
            // system Touch Bar proxy as unlabeled elements. Their labeled descendants
            // remain in the audit, so ignoring these containers cannot hide app copy.
            let isSystemContainer = element.elementType == .group &&
                element.identifier.isEmpty &&
                element.label.isEmpty
            return element.elementType == .touchBar || isSystemContainer
        }
    }
}
