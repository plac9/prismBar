// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct MainWindowView: View {
    @State private var selection: Destination? = .overview

    var body: some View {
        NavigationSplitView {
            List(Destination.allCases, selection: $selection) { destination in
                Label(destination.title, systemImage: destination.symbol)
                    .tag(destination)
                    .padding(.vertical, 3)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("prismBar")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            detailView
                .backgroundExtensionEffect()
        }
        .background(.clear)
        .containerBackground(for: .window) {
            PrismBackdrop()
        }
        .navigationTitle("prismBar")
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
}
