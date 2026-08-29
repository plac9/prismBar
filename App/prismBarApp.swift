// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import SwiftUI

@main
struct prismBarApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appLifecycle

    init() {
        MenuBarSectionStatusController.shared.installIfNeeded()
    }

    var body: some Scene {
        WindowGroup("prismBar", id: PrismSceneID.workspace) {
            MainWindowView()
                .environment(AppModel.shared)
                .background {
                    SceneActionRegistrationView()
                    UIAuditWindowConfiguration()
                }
                .frame(minWidth: 760, minHeight: 520)
        }
        .defaultSize(width: 920, height: 640)
        .windowResizability(.contentMinSize)
        .commands {
            PrismBarCommands(model: AppModel.shared)
        }
        .defaultLaunchBehavior(.suppressed)

        Settings {
            SettingsRootView()
                .environment(AppModel.shared)
                .frame(
                    minWidth: 640,
                    idealWidth: 680,
                    minHeight: 500,
                    idealHeight: 540
                )
        }
    }
}
