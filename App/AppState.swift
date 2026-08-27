// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import prismBarEngine

enum MenuBarLoadingState: Equatable {
    case waitingForPermission
    case loading
    case ready
    case unavailable
}

enum MenuBarActionState: Equatable {
    case idle
    case moving(itemID: MenuBarItemID?)
    case result(MenuBarActionResult)
}

enum PluginLoadingState: Equatable {
    case idle
    case loading
    case ready
    case unavailable
    case paused
    case disabled
}
