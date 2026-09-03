// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import SwiftUI

struct MainWindowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.prismTextSizePreference) private var textSize
    @State private var selection: WorkspaceDestination? = .home

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    ForEach(WorkspaceDestination.primary) { destination in
                        Label(destination.title, systemImage: destination.symbol)
                            .tag(destination)
                            .padding(.vertical, 4)
                    }
                }

                Section("Information") {
                    ForEach(WorkspaceDestination.information) { destination in
                        Label(destination.title, systemImage: destination.symbol)
                            .tag(destination)
                            .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("prismBar")
            .accessibilityIdentifier("workspace.sidebar")
            .navigationSplitViewColumnWidth(
                min: 190 + CGFloat(textSize.scale - 1) * 80,
                ideal: 220 + CGFloat(textSize.scale - 1) * 100,
                max: 260 + CGFloat(textSize.scale - 1) * 140
            )
        } detail: {
            ZStack {
                PrismCanvasBackground()
                detailView
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Workspace content")
            .accessibilityIdentifier("workspace.prismaticCanvas")
        }
        .navigationTitle("prismBar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Label(connectionLabel, systemImage: connectionSymbol)
                    .prismFont(.callout, weight: .medium)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("toolbar.connection")
            }

            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    model.refreshAccessibility()
                }
                .disabled(model.menuBarState == .loading)
                .help("Recheck Accessibility and refresh the local menu bar state")
                .accessibilityIdentifier("toolbar.refresh")
            }
        }
        .frame(
            minWidth: 760 + CGFloat(textSize.scale - 1) * 240,
            minHeight: 520 + CGFloat(textSize.scale - 1) * 100
        )
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .home {
        case .home:
            OverviewView()
        case .menuBar:
            MenuBarView()
        case .automation:
            ShortcutsView()
        case .privacy:
            PrivacyView()
        case .about:
            AboutView()
        }
    }

    private var connectionLabel: String {
        switch model.accessibilityState {
        case .granted: "Connected"
        case .requiresStableInstall: "Install required"
        case .identityMismatch: "Identity mismatch"
        case .notRequested, .denied: "Access required"
        }
    }

    private var connectionSymbol: String {
        model.accessibilityState == .granted ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
    }

}
