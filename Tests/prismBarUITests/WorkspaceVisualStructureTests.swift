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
}
