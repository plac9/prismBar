// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import SwiftUI

struct PrismBarCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @Bindable var model: AppModel

    var body: some Commands {
        CommandMenu("prismBar") {
            Button("Open prismBar") {
                openWindow(id: PrismSceneID.workspace)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Divider()

            Button(
                PrismRailPresentation.sectionVisibilityAction(
                    isCollapsed: model.isHiddenSectionCollapsed
                )
            ) {
                model.setHiddenSectionCollapsed(!model.isHiddenSectionCollapsed)
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])
            .disabled(!canControlMenuBar)

            Button("Refresh Menu Bar") {
                model.refreshMenuBar()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(model.accessibilityState != .granted)

            Button("Show Every Movable Item") {
                model.resetMenuBar()
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])
            .disabled(!canControlMenuBar)
        }
    }

    private var canControlMenuBar: Bool {
        model.accessibilityState == .granted &&
            model.menuBarSnapshot?.hiddenSectionDivider != nil &&
            !model.isMenuBarActionInProgress
    }
}
