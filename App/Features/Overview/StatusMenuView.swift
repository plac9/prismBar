// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import SwiftUI

struct StatusMenuView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "triangle")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("prismBar")
                        .font(.headline)
                    Text("Menu bar control, kept local")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Button("Open prismBar", systemImage: "rectangle.on.rectangle") {
                AppWindowController.shared.show()
            }

            Button("Settings", systemImage: "gearshape") {
                openSettings()
                NSApplication.shared.activate()
            }

            Divider()

            Button("Quit prismBar", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 280)
    }
}
