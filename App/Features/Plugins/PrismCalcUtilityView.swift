// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct PrismCalcUtilityView: View {
    @Bindable private var model: AppModel

    init(model: AppModel) {
        self.model = model
    }

    var body: some View {
        Group {
            if !model.isPluginEnabled {
                ContentUnavailableView {
                    Label("prismCalc is off", systemImage: "plus.forwardslash.minus")
                } description: {
                    Text("Enable the tool to use the private calculator.")
                } actions: {
                    Button("Enable prismCalc") {
                        model.setPluginEnabled(true)
                    }
                    .buttonStyle(.glassProminent)
                }
            } else {
                switch model.pluginState {
                case .idle, .loading:
                    ProgressView("Opening prismCalc")
                case .ready:
                    if let update = model.pluginPanel {
                        PluginPanelView(update: update, compact: false)
                    }
                case .unavailable, .paused, .disabled:
                    ContentUnavailableView {
                        Label("prismCalc unavailable", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(model.pluginMessage ?? "The isolated tool service did not respond.")
                    } actions: {
                        Button("Retry") {
                            model.retryPlugin()
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(minWidth: 320, minHeight: 440)
        .environment(model)
        .task {
            model.loadPluginIfNeeded()
        }
    }
}
