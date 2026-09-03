// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

public enum PrismSceneID {
    public static let workspace = "prismbar.workspace"
}

public enum WorkspaceDestination: String, CaseIterable, Identifiable, Sendable {
    case home
    case menuBar
    case automation
    case privacy
    case about

    public var id: String {
        rawValue
    }

    public static let primary: [Self] = [.home, .menuBar, .automation]
    public static let information: [Self] = [.privacy, .about]

    public var title: String {
        switch self {
        case .home: "Home"
        case .menuBar: "Menu Bar"
        case .automation: "Automation"
        case .privacy: "Privacy"
        case .about: "About"
        }
    }

    public var symbol: String {
        switch self {
        case .home: "sparkles"
        case .menuBar: "menubar.rectangle"
        case .automation: "bolt.badge.clock"
        case .privacy: "hand.raised"
        case .about: "info.circle"
        }
    }
}

public enum PrismRailPresentation {
    public static let title = "Rail"

    public static func sectionVisibilityAction(isCollapsed: Bool) -> String {
        isCollapsed ? "Reveal" : "Tuck Away"
    }
}

public struct MenuBarObservationPresentation: Equatable, Sendable {
    public let itemCount: Int
    public let unavailableSourceCount: Int

    public init(itemCount: Int, unavailableSourceCount: Int) {
        self.itemCount = max(0, itemCount)
        self.unavailableSourceCount = max(0, unavailableSourceCount)
    }

    public var isComplete: Bool {
        unavailableSourceCount == 0
    }

    public var summary: String {
        let items = "\(itemCount) \(itemCount == 1 ? "item" : "items")"
        guard unavailableSourceCount > 0 else {
            return "\(items) ready"
        }
        return "\(items) ready · limited scan"
    }

    public var unavailableSourcesWarning: String? {
        guard unavailableSourceCount > 0 else { return nil }
        let application = unavailableSourceCount == 1 ? "application" : "applications"
        let shownItems = itemCount == 1 ? "item shown" : "items shown"
        return "\(unavailableSourceCount) running \(application) did not answer. " +
            "You can still manage the \(shownItems); prismBar verifies every change."
    }

    public var inlineNotice: String? {
        unavailableSourcesWarning
    }

    public func sourceAvailabilityNotice(hiddenSectionCollapsed: Bool) -> String? {
        guard unavailableSourceCount > 0 else { return nil }
        if hiddenSectionCollapsed {
            return "Hidden items are folded. Reveal them to refresh and manage the full menu bar."
        }
        return unavailableSourcesWarning
    }
}
