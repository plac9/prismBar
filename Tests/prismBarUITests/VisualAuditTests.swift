// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import XCTest

@MainActor
final class VisualAuditTests: XCTestCase {
    private var systemUIOcclusionDetected = false

    func testCapturesAccessibilityReadingSizeSurfaces() {
        let interruptionMonitor = installSystemUIOcclusionMonitor()
        defer { removeUIInterruptionMonitor(interruptionMonitor) }

        let application = prismBarApplication(
            additionalLaunchArguments: [
                "--prismbar-ui-audit",
                "-prismBar.textSize",
                "accessibility",
            ]
        )
        application.launch()
        application.activate()

        let workspace = openWorkspaceIfNeeded(in: application)
        XCTAssertTrue(workspace.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(workspace.frame.width, 995)
        XCTAssertGreaterThanOrEqual(workspace.frame.height, 615)
        assertShippingSurfaceIsUnobscured()
        attach(workspace.screenshot(), named: "10-home-accessibility-size")

        application.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(workspace.waitForNonExistence(timeout: 3))
        let statusItem = application.descendants(matching: .statusItem)
            .matching(identifier: "prismBar")
            .firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        let deck = application.popovers.firstMatch
        XCTAssertTrue(deck.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(deck.frame.width, 580)
        XCTAssertTrue(application.buttons["Open prismBar"].isHittable)
        let deckContent = deck.groups.firstMatch
        XCTAssertTrue(deckContent.waitForExistence(timeout: 3))
        assertShippingSurfaceIsUnobscured()
        attachOpaquePopoverInterior(
            deckContent.screenshot(),
            named: "11-prismDeck-accessibility-size"
        )
    }

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
            ("Automation", "automation.header.bolt.badge.clock", "03-automation"),
            ("Privacy", "privacy.header.hand.raised", "04-privacy"),
            ("About", "about.header.info.circle", "05-about"),
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
        attach(settings.screenshot(), named: "06-settings-general")

        let privacy = settings.buttons["Privacy"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 3))
        privacy.click()
        assertShippingSurfaceIsUnobscured()
        attach(settings.screenshot(), named: "07-settings-privacy")

        application.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(settings.waitForNonExistence(timeout: 3))
        application.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(workspace.waitForNonExistence(timeout: 3))

        let statusItem = application.descendants(matching: .statusItem)
            .matching(identifier: "prismBar")
            .firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()

        let deckTitle = application.staticTexts["prismDeck"]
        XCTAssertTrue(deckTitle.waitForExistence(timeout: 3))
        let deck = application.popovers.firstMatch
        XCTAssertTrue(deck.waitForExistence(timeout: 3))
        // XCUI reports the NSPopover's native 13-point chrome around its
        // SwiftUI content frame.
        XCTAssertEqual(deck.frame.width, 466, accuracy: 4)
        if application.staticTexts["Accessibility needed"].exists {
            XCTAssertEqual(deck.frame.height, 386, accuracy: 4)
        } else {
            XCTAssertLessThanOrEqual(deck.frame.height, 646)
        }
        let deckContent = deck.groups.firstMatch
        XCTAssertTrue(deckContent.waitForExistence(timeout: 3))
        assertShippingSurfaceIsUnobscured()
        attachOpaquePopoverInterior(deckContent.screenshot(), named: "08-prismDeck")

        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(deckTitle.waitForNonExistence(timeout: 3))
        attach(statusItem.screenshot(), named: "09-status-item")
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

    private func attachOpaquePopoverInterior(
        _ screenshot: XCUIScreenshot,
        named name: String
    ) {
        let image = screenshot.image
        guard let representation = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: representation),
              let source = bitmap.cgImage
        else {
            XCTFail("Popover screenshot could not be decoded for privacy-safe cropping")
            return
        }

        let inset = max(1, Int(round(16 * CGFloat(source.width) / image.size.width)))
        let cropRect = CGRect(
            x: inset,
            y: inset,
            width: source.width - inset * 2,
            height: source.height - inset * 2
        )
        guard let cropped = source.cropping(to: cropRect) else {
            XCTFail("Popover screenshot could not be cropped to its opaque interior")
            return
        }

        let croppedImage = NSImage(
            cgImage: cropped,
            size: NSSize(width: cropRect.width, height: cropRect.height)
        )
        let attachment = XCTAttachment(image: croppedImage)
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

        let openWorkspace = application.buttons["Open prismBar"]
        XCTAssertTrue(openWorkspace.waitForExistence(timeout: 3), application.debugDescription)
        openWorkspace.click()
        return workspace
    }
}
