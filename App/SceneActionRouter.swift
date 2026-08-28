// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import prismBarCore
import SwiftUI

@MainActor
final class SceneActionRouter {
    static let shared = SceneActionRouter()

    private var openWindow: OpenWindowAction?
    private var pendingWindowID: String?

    private init() {}

    func register(openWindow: OpenWindowAction) {
        self.openWindow = openWindow
        guard let pendingWindowID else { return }
        self.pendingWindowID = nil

        if pendingWindowID != PrismSceneID.workspace {
            closeBootstrapWorkspace()
        }
        openWindow(id: pendingWindowID)
    }

    @discardableResult
    func openWorkspace() -> Bool {
        presentWindow(id: PrismSceneID.workspace)
    }

    func openPrismCalc() {
        AppModel.shared.loadPluginIfNeeded()
        presentWindow(id: PrismSceneID.prismCalc)
    }

    @discardableResult
    private func presentWindow(id: String) -> Bool {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
        if let openWindow {
            openWindow(id: id)
            return true
        }

        pendingWindowID = id == PrismSceneID.workspace ? nil : id
        return openInitialWorkspace()
    }

    private func openInitialWorkspace() -> Bool {
        let newWorkspaceTitle = "New prismBar Window"
        guard let fileMenu = NSApplication.shared.mainMenu?.items
            .first(where: { $0.title == "File" })?
            .submenu,
            let newWorkspaceIndex = fileMenu.items.firstIndex(where: {
                $0.title == newWorkspaceTitle
            })
        else { return false }

        fileMenu.performActionForItem(at: newWorkspaceIndex)
        return true
    }

    private func closeBootstrapWorkspace() {
        NSApplication.shared.windows
            .filter { $0.isVisible && $0.title == "prismBar" }
            .forEach { $0.close() }
    }
}

struct SceneActionRegistrationView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                SceneActionRouter.shared.register(openWindow: openWindow)
            }
    }
}
