// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBar
import XCTest

@MainActor
final class AppLifecycleTests: XCTestCase {
    func testNormalReopenOpensWorkspaceOnlyWhenNoWindowIsVisible() {
        XCTAssertTrue(
            AppLifecycleDelegate.shouldOpenWorkspaceOnReopen(
                hasVisibleWindows: false,
                arguments: ["/Applications/prismBar.app/Contents/MacOS/prismBar"]
            )
        )
        XCTAssertFalse(
            AppLifecycleDelegate.shouldOpenWorkspaceOnReopen(
                hasVisibleWindows: true,
                arguments: ["/Applications/prismBar.app/Contents/MacOS/prismBar"]
            )
        )
    }

    func testUITestReactivationNeverSynthesizesAWorkspace() {
        XCTAssertFalse(
            AppLifecycleDelegate.shouldOpenWorkspaceOnReopen(
                hasVisibleWindows: false,
                arguments: ["prismBar", "--prismbar-ui-testing"]
            )
        )
    }

    func testUITestCanExplicitlyRequestTheWorkspace() {
        let arguments = [
            "prismBar",
            "--prismbar-ui-testing",
            "--prismbar-ui-testing-open-workspace",
        ]

        XCTAssertTrue(
            AppLifecycleDelegate.shouldOpenWorkspaceOnLaunch(arguments: arguments)
        )
        XCTAssertTrue(
            AppLifecycleDelegate.shouldOpenWorkspaceOnReopen(
                hasVisibleWindows: false,
                arguments: arguments
            )
        )
    }

    func testNormalLaunchAndMenuOnlyUITestDoNotOpenWorkspace() {
        XCTAssertFalse(
            AppLifecycleDelegate.shouldOpenWorkspaceOnLaunch(arguments: ["prismBar"])
        )
        XCTAssertFalse(
            AppLifecycleDelegate.shouldOpenWorkspaceOnLaunch(
                arguments: ["prismBar", "--prismbar-ui-testing"]
            )
        )
    }
}
