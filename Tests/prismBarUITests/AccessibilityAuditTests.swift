// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

@MainActor
final class AccessibilityAuditTests: XCTestCase {
    func testAuditRetryPolicyOnlyRetriesOneAppleTimeout() {
        let timeout = NSError(
            domain: "com.apple.xcode.xctest.accessibilityAudit",
            code: -56
        )
        let unrelated = NSError(domain: "synthetic.audit", code: -56)

        XCTAssertTrue(Self.shouldRetryAudit(timeout, completedAttempts: 1))
        XCTAssertFalse(Self.shouldRetryAudit(timeout, completedAttempts: 2))
        XCTAssertFalse(Self.shouldRetryAudit(unrelated, completedAttempts: 1))
    }

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
        let general = settings.buttons["General"]
        XCTAssertTrue(general.waitForExistence(timeout: 3), application.debugDescription)
        general.click()
        XCTAssertTrue(
            application.descendants(matching: .any)["settings.textSize"]
                .waitForExistence(timeout: 3),
            application.debugDescription
        )
        let textSizePicker = application.popUpButtons["settings.textSize"]
        XCTAssertTrue(textSizePicker.isHittable, application.debugDescription)
        textSizePicker.click()
        XCTAssertTrue(
            application.menuItems["Standard · 100%"].waitForExistence(timeout: 3),
            application.debugDescription
        )
        application.typeKey(.escape, modifierFlags: [])
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

        let rail = application.descendants(matching: .any)["prismRail"]
        if rail.waitForExistence(timeout: 2) {
            XCTAssertTrue(
                application.descendants(matching: .any)["prismDeck.applications"]
                    .waitForExistence(timeout: 2),
                application.debugDescription
            )
        } else {
            XCTAssertTrue(
                application.staticTexts["Accessibility needed"].exists ||
                    application.staticTexts["Reading menu bar"].exists,
                application.debugDescription
            )
        }
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
        var completedAttempts = 0
        while true {
            completedAttempts += 1
            do {
                try application.performAccessibilityAudit(for: macOSAuditTypes) { issue in
                    if issue.auditType == .action,
                       issue.element?.elementType == .popUpButton,
                       issue.element?.identifier == "settings.textSize" {
                        // Xcode 27 beta reports that SwiftUI's native Picker lacks an
                        // action even after the direct open assertion above succeeds.
                        return true
                    }

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
                return
            } catch {
                guard Self.shouldRetryAudit(error, completedAttempts: completedAttempts) else {
                    throw error
                }
                XCTAssertTrue(application.wait(for: .runningForeground, timeout: 3))
            }
        }
    }

    private static func shouldRetryAudit(
        _ error: Error,
        completedAttempts: Int
    ) -> Bool {
        let error = error as NSError
        return completedAttempts == 1 &&
            error.domain == "com.apple.xcode.xctest.accessibilityAudit" &&
            error.code == -56
    }
}
