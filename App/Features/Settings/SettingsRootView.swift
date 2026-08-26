// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct SettingsRootView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                Form {
                    Section("Startup") {
                        Text("Launch behavior will be enabled after permission recovery is physically verified.")
                            .foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
            }

            Tab("Privacy", systemImage: "hand.raised") {
                Form {
                    Section("Local by design") {
                        LabeledContent("Screen capture", value: "Never")
                        LabeledContent("Analytics", value: "None")
                        LabeledContent("Network access", value: "None")
                    }
                }
                .formStyle(.grouped)
            }
        }
        .padding(12)
    }
}
