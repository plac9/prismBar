// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

@main
struct prismBarApp: App {
    init() {
        AppWindowController.shared.startObservingLaunch()
    }

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView()
                .environment(AppModel.shared)
        } label: {
            Image(systemName: "triangle")
                .accessibilityLabel("prismBar")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsRootView()
                .environment(AppModel.shared)
                .frame(width: 560, height: 420)
        }
    }
}
