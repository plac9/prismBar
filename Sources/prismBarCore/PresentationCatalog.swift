// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

public enum PrismSceneID {
    public static let workspace = "prismbar.workspace"
    public static let prismCalc = "prismbar.tool.prismcalc"
}

public enum WorkspaceDestination: String, CaseIterable, Identifiable, Sendable {
    case home
    case menuBar
    case tools
    case automation
    case privacy
    case about

    public var id: String {
        rawValue
    }

    public static let primary: [Self] = [.home, .menuBar, .tools, .automation]
    public static let information: [Self] = [.privacy, .about]

    public var title: String {
        switch self {
        case .home: "Home"
        case .menuBar: "Menu Bar"
        case .tools: "Tools"
        case .automation: "Automation"
        case .privacy: "Privacy"
        case .about: "About"
        }
    }

    public var symbol: String {
        switch self {
        case .home: "sparkles"
        case .menuBar: "menubar.rectangle"
        case .tools: "wrench.and.screwdriver"
        case .automation: "bolt.badge.clock"
        case .privacy: "hand.raised"
        case .about: "info.circle"
        }
    }
}

public enum PrismDeckMode: String, CaseIterable, Identifiable, Sendable {
    case bar
    case tools

    public var id: String {
        rawValue
    }

    public var title: String {
        rawValue.capitalized
    }
}

public enum PrismToolID: String, CaseIterable, Identifiable, Sendable {
    case prismCalc = "com.laclairtech.prismbar.plugin.prismcalc"

    public var id: String {
        rawValue
    }

    public var displayName: String {
        "prismCalc"
    }
}
