// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBar
import prismBarEngine
import XCTest

@MainActor
final class AppModelActionFeedbackTests: XCTestCase {
    func testManualMenuBarRefreshClearsCompletedActionFeedback() {
        let model = AppModel.shared
        model.menuBarActionState = .result(.success("Completed action"))

        model.refreshMenuBar()

        XCTAssertEqual(model.menuBarActionState, .idle)
    }

    func testPostActionRefreshPreservesCompletedActionFeedback() {
        let model = AppModel.shared
        let result = MenuBarActionResult.success("Completed action")
        model.menuBarActionState = .result(result)

        model.refreshMenuBar(preservingActionResult: true)

        XCTAssertEqual(model.menuBarActionState, .result(result))
    }
}
