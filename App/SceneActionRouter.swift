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

    @discardableResult
    func openWorkspace() -> Bool {
        presentWindow(id: PrismSceneID.workspace)
    }

    @discardableResult
    private func presentWindow(id: String) -> Bool {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
        if id == PrismSceneID.workspace,
           let existingWorkspace = Self.existingWorkspace(
               in: NSApplication.shared.windows
           ) {
            if existingWorkspace.isMiniaturized {
                existingWorkspace.deminiaturize(nil)
            }
            existingWorkspace.makeKeyAndOrderFront(nil)
            return true
        }
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

    static func existingWorkspace(in windows: [NSWindow]) -> NSWindow? {
        windows.first {
            shouldReuseWorkspace(
                title: $0.title,
                isVisible: $0.isVisible,
                isMiniaturized: $0.isMiniaturized
            )
        }
    }

    static func shouldReuseWorkspace(
        title: String,
        isVisible: Bool,
        isMiniaturized: Bool
    ) -> Bool {
        title == "prismBar" && (isVisible || isMiniaturized)
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
