// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import prismBarCore
import SwiftUI

struct StatusMenuView: View {
    @Environment(\.openSettings) private var openSettings
    @Bindable private var model: AppModel
    @State private var isCalculatorExpanded = false
    @State private var isResetConfirmationPresented = false

    init(model: AppModel) {
        self.model = model
    }

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

            Label(accessibilityLabel, systemImage: accessibilitySymbol)
                .foregroundStyle(model.accessibilityState == .granted ? .green : .secondary)

            if let snapshot = model.menuBarSnapshot {
                Text("\(snapshot.items.count) menu items")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(snapshot.items.filter { $0.role == .item }.prefix(6))) { item in
                    Menu(item.displayName) {
                        if snapshot.section(for: item.id) == .hidden {
                            Button("Show") {
                                model.moveMenuBarItem(item.id, to: .visible)
                            }
                        } else if snapshot.section(for: item.id) == .visible {
                            Button("Hide") {
                                model.moveMenuBarItem(item.id, to: .hidden)
                            }
                        }

                        Divider()

                        Button("Move Left") {
                            model.moveMenuBarItem(item.id, to: max(0, item.position - 1))
                        }
                        .disabled(!canMove(item) || item.position == 0)

                        Button("Move Right") {
                            model.moveMenuBarItem(
                                item.id,
                                to: min(snapshot.items.count - 1, item.position + 1)
                            )
                        }
                        .disabled(!canMove(item) || item.position == snapshot.items.count - 1)
                    }
                }

                Button("Refresh Menu Items", systemImage: "arrow.clockwise") {
                    model.refreshMenuBar()
                }

                Button(
                    model.isHiddenSectionCollapsed ? "Reveal Hidden Items" : "Fold Hidden Items",
                    systemImage: model.isHiddenSectionCollapsed ? "eye" : "eye.slash"
                ) {
                    model.setHiddenSectionCollapsed(!model.isHiddenSectionCollapsed)
                }
                .disabled(snapshot.hiddenSectionDivider == nil)

                Button("Show Every Item", systemImage: "arrow.uturn.backward") {
                    isResetConfirmationPresented = true
                }
                .disabled(model.isMenuBarActionInProgress)
            }

            if let pluginPanel = model.pluginPanel, model.pluginState == .ready {
                DisclosureGroup("prismCalc", isExpanded: $isCalculatorExpanded) {
                    PluginPanelView(update: pluginPanel, compact: true)
                        .padding(.top, 6)
                }
            } else if model.pluginState == .unavailable || model.pluginState == .disabled {
                Button("Retry prismCalc", systemImage: "arrow.clockwise") {
                    model.retryPlugin()
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
        .environment(model)
        .task {
            model.loadPluginIfNeeded()
        }
        .confirmationDialog(
            "Show every movable menu bar item?",
            isPresented: $isResetConfirmationPresented
        ) {
            Button("Show Every Item") {
                model.resetMenuBar()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This preserves item order and leaves the hidden section unfolded.")
        }
    }

    private var accessibilityLabel: String {
        model.accessibilityState == .granted ? "Accessibility ready" : "Accessibility needs attention"
    }

    private var accessibilitySymbol: String {
        model.accessibilityState == .granted ? "checkmark.shield" : "exclamationmark.shield"
    }

    private func canMove(_ item: MenuBarItem) -> Bool {
        item.isMovable && !model.isMenuBarActionInProgress
    }
}
