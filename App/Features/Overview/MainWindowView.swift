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
            }
            .navigationTitle("prismBar")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            switch selection ?? .overview {
            case .overview:
                OverviewView()
            case .menuBar:
                PlaceholderDestination(
                    title: "Menu Bar",
                    message: "Detected items and verified movement controls will appear here.",
                    symbol: "menubar.rectangle"
                )
            case .plugins:
                PlaceholderDestination(
                    title: "Plugins",
                    message: "Bundled plugins run outside prismBar and never receive Accessibility access.",
                    symbol: "puzzlepiece.extension"
                )
            case .shortcuts:
                PlaceholderDestination(
                    title: "Shortcuts",
                    message: "Keyboard controls and conflict checks will appear here.",
                    symbol: "keyboard"
                )
            case .privacy:
                PlaceholderDestination(
                    title: "Privacy",
                    message: "No screenshots, OCR, analytics, telemetry, or menu-content uploads.",
                    symbol: "hand.raised"
                )
            case .about:
                PlaceholderDestination(
                    title: "About",
                    message: "Independent, public-source software from LaClair Technologies.",
                    symbol: "info.circle"
                )
            }
        }
        .navigationTitle("prismBar")
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

private struct PlaceholderDestination: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(message))
            .padding(24)
    }
}
