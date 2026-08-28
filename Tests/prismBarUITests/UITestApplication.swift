// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

@MainActor
func prismBarApplication(
    opensWorkspace: Bool = true,
    additionalLaunchArguments: [String] = []
) -> XCUIApplication {
    let application = XCUIApplication()
    var launchArguments = [
        "--prismbar-ui-testing",
        "-ApplePersistenceIgnoreState",
        "YES",
    ]
    if opensWorkspace {
        launchArguments.append("--prismbar-ui-testing-open-workspace")
    }
    application.launchArguments = launchArguments + additionalLaunchArguments
    return application
}
