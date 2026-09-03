// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBar
import prismBarCore
import XCTest

@MainActor
final class PrismTypographyTests: XCTestCase {
    func testSemanticRolesMatchTheDesignContract() {
        XCTAssertEqual(PrismFontRole.caption2.baseSize, 11)
        XCTAssertEqual(PrismFontRole.caption.baseSize, 12)
        XCTAssertEqual(PrismFontRole.body.baseSize, 13)
        XCTAssertEqual(PrismFontRole.headline.baseSize, 13)
        XCTAssertEqual(PrismFontRole.title2.baseSize, 22)
        XCTAssertEqual(PrismFontRole.title.baseSize, 28)
    }

    func testVisualAuditWindowExpandsForAccessibilityReadingSize() {
        XCTAssertEqual(UIAuditWindowSizePolicy.size(for: .standard).width, 920)
        XCTAssertEqual(UIAuditWindowSizePolicy.size(for: .standard).height, 640)
        XCTAssertEqual(UIAuditWindowSizePolicy.size(for: .accessibility).width, 1_160)
        XCTAssertEqual(UIAuditWindowSizePolicy.size(for: .accessibility).height, 760)
    }
}
