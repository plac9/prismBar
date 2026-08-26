// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import prismBarCore
import SwiftUI

struct StatusMenuView: View {
    @Environment(\.openSettings) private var openSettings
    @Bindable private var model: AppModel
    let dismissCommandCenter: () -> Void
    @State private var isCalculatorExpanded = false
    @State private var isResetConfirmationPresented = false

    init(model: AppModel, dismissCommandCenter: @escaping () -> Void) {
        self.model = model
        self.dismissCommandCenter = dismissCommandCenter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                PrismMark(size: 32)

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
                Text("\(snapshot.items.filter { $0.role == .item }.count) menu items")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(snapshot.items.filter { $0.role == .item }) { item in
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

                                let destinations = snapshot.movementDestinations(for: item.id)
                                Menu("Move to Position") {
                                    ForEach(Array(destinations.enumerated()), id: \.element.id) { offset, destination in
                                        Button("Position \(offset + 1)") {
                                            model.moveMenuBarItem(item.id, to: destination.position)
                                        }
                                        .disabled(destination.id == item.id)
                                    }
                                }
                                .disabled(!canMove(item) || destinations.count < 2)

                                Divider()

                                Button("Move Left") {
                                    if let destination = neighborDestination(
                                        for: item,
                                        offset: -1,
                                        snapshot: snapshot
                                    ) {
                                        model.moveMenuBarItem(item.id, to: destination)
                                    }
                                }
                                .disabled(
                                    !canMove(item) ||
                                        neighborDestination(
                                            for: item,
                                            offset: -1,
                                            snapshot: snapshot
                                        ) == nil
                                )

                                Button("Move Right") {
                                    if let destination = neighborDestination(
                                        for: item,
                                        offset: 1,
                                        snapshot: snapshot
                                    ) {
                                        model.moveMenuBarItem(item.id, to: destination)
                                    }
                                }
                                .disabled(
                                    !canMove(item) ||
                                        neighborDestination(
                                            for: item,
                                            offset: 1,
                                            snapshot: snapshot
                                        ) == nil
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 210)

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
            } else if model.pluginState == .disabled, !model.isPluginEnabled {
                Button("Enable prismCalc", systemImage: "puzzlepiece.extension") {
                    model.setPluginEnabled(true)
                }
            } else if model.pluginState == .unavailable || model.pluginState == .paused {
                Button("Retry prismCalc", systemImage: "arrow.clockwise") {
                    model.retryPlugin()
                }
            }

            Divider()

            Button("Open prismBar", systemImage: "rectangle.on.rectangle") {
                dismissCommandCenter()
                AppWindowController.shared.show()
            }

            Button("Settings", systemImage: "gearshape") {
                dismissCommandCenter()
                openSettings()
                NSApplication.shared.activate()
            }

            Divider()

            Button("Quit prismBar", systemImage: "power") {
                dismissCommandCenter()
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

    private func neighborDestination(
        for item: MenuBarItem,
        offset: Int,
        snapshot: MenuBarSnapshot
    ) -> Int? {
        let sectionItems = snapshot.movementDestinations(for: item.id)
        guard let index = sectionItems.firstIndex(where: { $0.id == item.id }) else { return nil }
        let destination = index + offset
        guard sectionItems.indices.contains(destination) else { return nil }
        return sectionItems[destination].position
    }
}
