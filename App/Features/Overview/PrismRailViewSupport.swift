// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import prismBarCore

enum PrismRailViewSupport {
    static func sectionTitle(_ section: MenuBarSection) -> String {
        section == .hidden ? "Tucked Away" : "On Bar"
    }

    static func sectionHint(_ section: MenuBarSection) -> String {
        section == .hidden ? "Reveal when needed" : "Always visible"
    }

    static func sectionSymbol(_ section: MenuBarSection) -> String {
        section == .hidden ? "eye.slash" : "menubar.rectangle"
    }

    static func fixedItemDescription(_ item: MenuBarItem) -> String {
        item.ownership == .system ? "fixed by macOS" : "unavailable"
    }

    static func itemHelp(_ item: MenuBarItem, canMove: Bool) -> String {
        if item.ownership == .system {
            return "macOS keeps this item in place"
        }
        return canMove ? "Drag to reposition \(item.displayName)" : "This item cannot be moved"
    }

    static func itemSymbol(isMoving: Bool, canMove: Bool) -> String {
        if isMoving { return "arrow.left.arrow.right" }
        return canMove ? "line.3.horizontal" : "lock.fill"
    }

    static func makeDragTokens(for snapshot: MenuBarSnapshot) -> [MenuBarItemID: String] {
        Dictionary(
            uniqueKeysWithValues: snapshot.items
                .filter { $0.role == .item }
                .map { ($0.id, UUID().uuidString) }
        )
    }
}
