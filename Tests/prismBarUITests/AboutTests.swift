// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

@MainActor
final class AboutTests: XCTestCase {
    func testProvidesSourceAndBundledLicenseActions() {
        let application = XCUIApplication()
        application.launch()

        let aboutDestination = application.outlines["Sidebar"].cells
            .containing(.staticText, identifier: "About")
            .element
        XCTAssertTrue(aboutDestination.waitForExistence(timeout: 5))
        aboutDestination.click()

        XCTAssertTrue(application.buttons["about.source"].waitForExistence(timeout: 5))
        XCTAssertTrue(application.staticTexts["Source revision"].exists)
        let licenseButton = application.buttons["about.license"]
        XCTAssertTrue(licenseButton.exists)
        licenseButton.click()

        XCTAssertTrue(application.staticTexts["Mozilla Public License 2.0"].waitForExistence(timeout: 3))
        XCTAssertTrue(application.staticTexts["prismBar legal notices"].exists)
        XCTAssertTrue(application.buttons["legal.done"].exists)
    }
}
