// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
@testable import prismBarCore

@Suite("Application shortcut catalog")
struct ShortcutCatalogTests {
    @Test("ships only unique shortcuts that do not replace standard macOS commands")
    func validatesDefaultCatalog() {
        #expect(ShortcutCatalog.validate(ShortcutCatalog.defaults).isEmpty)
    }

    @Test("reports duplicate gestures without logging user input")
    func detectsDuplicateGestures() {
        let gesture = ShortcutGesture(key: "b", modifiers: [.command, .shift])
        let shortcuts = [
            AppShortcut(action: .openApplication, gesture: gesture),
            AppShortcut(action: .toggleHiddenSection, gesture: gesture),
        ]

        #expect(ShortcutCatalog.validate(shortcuts) == [.duplicateGesture])
    }

    @Test("rejects standard app commands and unmodified character keys")
    func protectsStandardCommands() {
        let shortcuts = [
            AppShortcut(
                action: .openApplication,
                gesture: ShortcutGesture(key: "q", modifiers: [.command])
            ),
            AppShortcut(
                action: .refreshMenuBar,
                gesture: ShortcutGesture(key: "r", modifiers: [])
            ),
        ]

        #expect(
            ShortcutCatalog.validate(shortcuts) == [
                .reservedBySystem,
                .requiresModifier,
            ]
        )
    }
}
