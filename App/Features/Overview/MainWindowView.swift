// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct MainWindowView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: Destination? = .overview

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    ForEach(Destination.primary) { destination in
                        Label(destination.title, systemImage: destination.symbol)
                            .tag(destination)
                            .padding(.vertical, 4)
                    }
                }

                Section("prismBar") {
                    ForEach(Destination.information) { destination in
                        Label(destination.title, systemImage: destination.symbol)
                            .tag(destination)
                            .padding(.vertical, 4)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 10) {
                    Image(systemName: "triangle")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("prismBar")
                            .font(.headline)
                        Text("Local menu bar control")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            detailView
        }
        .containerBackground(for: .window) {
            Color(nsColor: .windowBackgroundColor)
        }
        .navigationTitle("prismBar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Label(connectionLabel, systemImage: connectionSymbol)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(connectionColor)
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
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .overview {
        case .overview:
            OverviewView()
        case .menuBar:
            MenuBarView()
        case .plugins:
            PluginsView()
        case .shortcuts:
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

    private var connectionColor: Color {
        model.accessibilityState == .granted ? .green : .orange
    }
}

private enum Destination: String, CaseIterable, Identifiable {
    case overview
    case menuBar
    case plugins
    case shortcuts
    case privacy
    case about

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .menuBar: "Menu Bar"
        case .plugins: "Plugins"
        case .shortcuts: "Shortcuts"
        case .privacy: "Privacy"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "sparkles"
        case .menuBar: "menubar.rectangle"
        case .plugins: "puzzlepiece.extension"
        case .shortcuts: "keyboard"
        case .privacy: "hand.raised"
        case .about: "info.circle"
        }
    }

    static let primary: [Destination] = [.overview, .menuBar, .plugins, .shortcuts]
    static let information: [Destination] = [.privacy, .about]
}
