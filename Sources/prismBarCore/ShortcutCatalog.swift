// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

public struct ShortcutModifiers: OptionSet, Hashable, Codable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let command = ShortcutModifiers(rawValue: 1 << 0)
    public static let option = ShortcutModifiers(rawValue: 1 << 1)
    public static let shift = ShortcutModifiers(rawValue: 1 << 2)
    public static let control = ShortcutModifiers(rawValue: 1 << 3)
}

public struct ShortcutGesture: Hashable, Codable, Sendable {
    public let key: String
    public let modifiers: ShortcutModifiers

    public init(key: String, modifiers: ShortcutModifiers) {
        self.key = key.lowercased()
        self.modifiers = modifiers
    }
}

public enum AppShortcutAction: String, CaseIterable, Codable, Sendable {
    case openApplication
    case toggleHiddenSection
    case refreshMenuBar
    case showEveryItem
}

public struct AppShortcut: Equatable, Codable, Sendable {
    public let action: AppShortcutAction
    public let gesture: ShortcutGesture

    public init(action: AppShortcutAction, gesture: ShortcutGesture) {
        self.action = action
        self.gesture = gesture
    }
}

public enum ShortcutConflict: Equatable, Sendable {
    case duplicateGesture
    case reservedBySystem
    case requiresModifier
}

public enum ShortcutCatalog {
    public static let defaults = [
        AppShortcut(
            action: .openApplication,
            gesture: ShortcutGesture(key: "o", modifiers: [.command, .shift])
        ),
        AppShortcut(
            action: .toggleHiddenSection,
            gesture: ShortcutGesture(key: "b", modifiers: [.command, .shift])
        ),
        AppShortcut(
            action: .refreshMenuBar,
            gesture: ShortcutGesture(key: "r", modifiers: [.command, .shift])
        ),
        AppShortcut(
            action: .showEveryItem,
            gesture: ShortcutGesture(key: "u", modifiers: [.command, .shift])
        ),
    ]

    private static let reservedGestures: Set<ShortcutGesture> = [
        ShortcutGesture(key: "q", modifiers: [.command]),
        ShortcutGesture(key: "w", modifiers: [.command]),
        ShortcutGesture(key: "h", modifiers: [.command]),
        ShortcutGesture(key: "m", modifiers: [.command]),
        ShortcutGesture(key: ",", modifiers: [.command]),
    ]

    public static func validate(_ shortcuts: [AppShortcut]) -> [ShortcutConflict] {
        var conflicts: [ShortcutConflict] = []
        var gestures: Set<ShortcutGesture> = []

        for shortcut in shortcuts {
            if shortcut.gesture.modifiers.isEmpty {
                conflicts.append(.requiresModifier)
            }
            if reservedGestures.contains(shortcut.gesture) {
                conflicts.append(.reservedBySystem)
            }
            if !gestures.insert(shortcut.gesture).inserted {
                conflicts.append(.duplicateGesture)
            }
        }
        return conflicts.sorted(by: conflictOrder)
    }

    private static func conflictOrder(_ lhs: ShortcutConflict, _ rhs: ShortcutConflict) -> Bool {
        order(lhs) < order(rhs)
    }

    private static func order(_ conflict: ShortcutConflict) -> Int {
        switch conflict {
        case .reservedBySystem: 0
        case .requiresModifier: 1
        case .duplicateGesture: 2
        }
    }
}
