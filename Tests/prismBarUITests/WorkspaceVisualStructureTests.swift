// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

@MainActor
final class WorkspaceVisualStructureTests: XCTestCase {
    func testWorkspaceUsesOneExtendedPrismaticContentCanvas() {
        let application = prismBarApplication()
        application.launch()

        let canvas = application.descendants(matching: .any)["workspace.prismaticCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        XCTAssertTrue(application.outlines["workspace.sidebar"].exists)
        XCTAssertTrue(
            application.descendants(matching: .any)["toolbar.connection"]
                .firstMatch.exists
        )
    }

    func testInformationalDestinationsExposeFocusedGroupedContent() {
        let application = prismBarApplication()
        application.launch()

        let canvas = application.descendants(matching: .any)["workspace.prismaticCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))

        for destination in ["Home", "Automation", "Privacy", "About"] {
            let cell = application.descendants(matching: .any)["workspace.sidebar"].cells
                .containing(.staticText, identifier: destination)
                .element
            XCTAssertTrue(cell.waitForExistence(timeout: 5))
            cell.click()

            let section = application.descendants(matching: .any)
                .matching(identifier: "workspace.contentSection")
                .firstMatch
            XCTAssertTrue(
                section.waitForExistence(timeout: 5),
                "Missing grouped content in \(destination)"
            )
            XCTAssertGreaterThan(
                section.frame.minX,
                canvas.frame.minX + 20,
                "\(destination) content touches the canvas edge"
            )
            XCTAssertLessThan(
                section.frame.maxX,
                canvas.frame.maxX - 20,
                "\(destination) content touches the canvas edge"
            )
        }
    }

    func testHomeKeepsReadinessRecoveryAndPrivacyInDistinctGroups() {
        let application = prismBarApplication()
        application.launch()

        let sections = application.descendants(matching: .any)
            .matching(identifier: "workspace.contentSection")

        XCTAssertEqual(
            sections.count,
            3,
            "Home should separate readiness, recovery, and the local privacy boundary"
        )
    }
}
