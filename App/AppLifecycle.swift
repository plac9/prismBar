// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        AppModel.shared.refreshAccessibility()
    }

    func applicationDidBecomeActive(_: Notification) {
        AppModel.shared.refreshAccessibility()
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            SceneActionRouter.shared.openWorkspace()
        }
        return true
    }
}
