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
        openWindow(id: pendingWindowID)
    }

    func openWorkspace() {
        presentWindow(id: PrismSceneID.workspace)
    }

    func openPrismCalc() {
        AppModel.shared.loadPluginIfNeeded()
        presentWindow(id: PrismSceneID.prismCalc)
    }

    private func presentWindow(id: String) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
        if let openWindow {
            openWindow(id: id)
            return
        }

        pendingWindowID = id == PrismSceneID.workspace ? nil : id
        openInitialWorkspace()
    }

    private func openInitialWorkspace() {
        let newWorkspaceTitle = "New prismBar Window"
        guard let fileMenu = NSApplication.shared.mainMenu?.items
            .first(where: { $0.title == "File" })?
            .submenu,
            let newWorkspaceIndex = fileMenu.items.firstIndex(where: {
                $0.title == newWorkspaceTitle
            })
        else { return }

        fileMenu.performActionForItem(at: newWorkspaceIndex)
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
