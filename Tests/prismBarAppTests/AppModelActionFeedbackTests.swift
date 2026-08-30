// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBar
import prismBarCore
import prismBarEngine
import XCTest

@MainActor
final class AppModelActionFeedbackTests: XCTestCase {
    func testManualMenuBarRefreshClearsVisibleReceiptButPreservesHistory() {
        let model = makeModel()
        let before = snapshot(generation: 1)
        let after = snapshot(generation: 2, reversed: true)
        let pending = model.beginMenuBarAction(
            kind: .directMove,
            before: before,
            itemID: MenuBarItemID(rawValue: "fixture.visible")
        )
        model.completeMenuBarAction(
            id: pending.id,
            result: .success("Completed action"),
            after: after
        )

        model.refreshMenuBar()

        XCTAssertNil(model.currentActionReceipt)
        XCTAssertEqual(model.menuBarActionState, .idle)
        XCTAssertEqual(model.recentActionReceipts.count, 1)
    }

    func testPermissionRevocationClearsVisibleReceiptAndRecoveryHistory() {
        let model = makeModel()
        let pending = model.beginMenuBarAction(
            kind: .directMove,
            before: snapshot(generation: 1),
            itemID: nil
        )
        model.completeMenuBarAction(
            id: pending.id,
            result: .success("Completed action"),
            after: snapshot(generation: 2, reversed: true)
        )

        model.handleAccessibilityRevocation()

        XCTAssertNil(model.currentActionReceipt)
        XCTAssertEqual(model.recentActionReceipts, [])
        XCTAssertEqual(model.menuBarActionState, .idle)
    }

    func testVerifyingReceiptProjectsToMovingState() {
        let model = makeModel()

        let receipt = model.beginMenuBarAction(
            kind: .sectionMove,
            before: snapshot(generation: 1),
            itemID: MenuBarItemID(rawValue: "fixture.visible")
        )

        XCTAssertEqual(model.currentActionReceipt, receipt)
        XCTAssertEqual(
            model.menuBarActionState,
            .moving(itemID: MenuBarItemID(rawValue: "fixture.visible"))
        )
    }

    func testCompletedReceiptProjectsToResultState() {
        let model = makeModel()
        let result = MenuBarActionResult.success("Completed action")
        let pending = model.beginMenuBarAction(
            kind: .directMove,
            before: snapshot(generation: 1),
            itemID: nil
        )

        model.completeMenuBarAction(
            id: pending.id,
            result: result,
            after: snapshot(generation: 2, reversed: true)
        )

        XCTAssertEqual(model.currentActionReceipt?.result, result)
        XCTAssertEqual(model.menuBarActionState, .result(result))
    }

    private func makeModel() -> AppModel {
        let suiteName = "com.laclairtech.prismbar.tests.action-feedback.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppModel(defaults: defaults, automaticallyRefresh: false)
    }

    private func snapshot(generation: UInt64, reversed: Bool = false) -> MenuBarSnapshot {
        let surface = MenuBarSurfaceID(rawValue: "fixture.display")
        let hidden = item("fixture.hidden", position: reversed ? 2 : 0, surface: surface)
        let divider = item(
            "fixture.divider",
            position: 1,
            surface: surface,
            role: .hiddenSectionDivider
        )
        let visible = item("fixture.visible", position: reversed ? 0 : 2, surface: surface)
        return MenuBarSnapshot(generation: generation, items: [hidden, divider, visible])
    }

    private func item(
        _ identifier: String,
        position: Int,
        surface: MenuBarSurfaceID,
        role: MenuBarItemRole = .item
    ) -> MenuBarItem {
        MenuBarItem(
            id: MenuBarItemID(rawValue: identifier),
            position: position,
            isMovable: role == .item,
            displayName: "Synthetic item",
            role: role,
            frame: MenuBarItemFrame(
                minX: Double(position * 24),
                minY: 0,
                width: 20,
                height: 20
            ),
            surfaceID: surface
        )
    }
}
