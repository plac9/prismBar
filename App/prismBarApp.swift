// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

@main
struct prismBarApp: App {
    init() {
        MenuBarSectionStatusController.shared.installIfNeeded()
        AppWindowController.shared.startObservingLaunch()
    }

    var body: some Scene {
        Settings {
            SettingsRootView()
                .environment(AppModel.shared)
                .frame(width: 560, height: 420)
        }
    }
}
