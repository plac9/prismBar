// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    static func shouldOpenWorkspaceOnLaunch(arguments: [String]) -> Bool {
        arguments.contains("--prismbar-ui-testing")
            && arguments.contains("--prismbar-ui-testing-open-workspace")
    }

    static func shouldOpenWorkspaceOnReopen(
        hasVisibleWindows: Bool,
        arguments: [String]
    ) -> Bool {
        guard !hasVisibleWindows else { return false }
        guard arguments.contains("--prismbar-ui-testing") else { return true }
        return arguments.contains("--prismbar-ui-testing-open-workspace")
    }

    func applicationDidFinishLaunching(_: Notification) {
        AppModel.shared.refreshAccessibility()
        guard Self.shouldOpenWorkspaceOnLaunch(
            arguments: ProcessInfo.processInfo.arguments
        ) else { return }

        DispatchQueue.main.async {
            self.openRequestedWorkspace(attemptsRemaining: 20)
        }
    }

    func applicationDidBecomeActive(_: Notification) {
        AppModel.shared.refreshAccessibility()
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if Self.shouldOpenWorkspaceOnReopen(
            hasVisibleWindows: flag,
            arguments: ProcessInfo.processInfo.arguments
        ) {
            SceneActionRouter.shared.openWorkspace()
        }
        return true
    }

    private func openRequestedWorkspace(attemptsRemaining: Int) {
        guard !SceneActionRouter.shared.openWorkspace(), attemptsRemaining > 0 else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.openRequestedWorkspace(attemptsRemaining: attemptsRemaining - 1)
        }
    }
}
