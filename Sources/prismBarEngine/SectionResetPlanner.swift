// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore

public struct SectionResetPlanner: Sendable {
    public init() {}

    public func hiddenItemsToReveal(in snapshot: MenuBarSnapshot) -> [MenuBarItemID] {
        snapshot.items
            .filter { item in
                item.allowsVerifiedMovement && snapshot.section(for: item.id) == .hidden
            }
            .reversed()
            .map(\.id)
    }
}
