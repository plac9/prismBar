// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import SwiftUI

struct ShortcutsView: View {
    @Environment(\.prismTextSizePreference) private var textSize
    private let shortcuts = ShortcutCatalog.defaults

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    symbol: "bolt.badge.clock",
                    eyebrow: "Automation",
                    title: "Fast paths, on your terms.",
                    message: "Use standard app commands while prismBar is frontmost. " +
                        "No background key monitoring is required.",
                    identifier: "automation.header.bolt.badge.clock"
                )

                PrismContentSection {
                    VStack(alignment: .leading, spacing: 0) {
                        Label("prismBar commands", systemImage: "command")
                            .prismFont(.headline)
                            .padding(.bottom, 8)

                        Divider()

                        ForEach(shortcuts, id: \.action) { shortcut in
                            HStack(spacing: 16) {
                                Image(systemName: shortcut.symbol)
                                    .prismFont(.title3)
                                    .foregroundStyle(.tint)
                                    .frame(width: 28 * CGFloat(textSize.scale))

                                Text(shortcut.title)
                                    .prismFont(.headline)

                                Spacer()

                                Text(shortcut.gesture.displayValue)
                                    .prismFont(.body, weight: .semibold, design: .rounded)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(.background.secondary, in: .capsule)
                                    .accessibilityLabel(shortcut.gesture.accessibilityValue)
                            }
                            .padding(.vertical, 11)

                            if shortcut.action != shortcuts.last?.action {
                                Divider()
                            }
                        }
                    }
                }

                PrismContentSection(tint: .blue) {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No global keyboard monitoring")
                                .prismFont(.headline)
                            Text(
                                "These are standard app commands. prismBar does not install a global " +
                                    "keystroke monitor or request Input Monitoring access."
                            )
                            .prismFont(.callout)
                            .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "keyboard.badge.ellipsis")
                            .prismFont(.title2)
                            .foregroundStyle(.tint)
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(32)
        }
    }
}

private extension AppShortcut {
    var title: String {
        switch action {
        case .openApplication: "Open prismBar"
        case .toggleHiddenSection: "Fold or reveal hidden items"
        case .refreshMenuBar: "Refresh menu items"
        case .showEveryItem: "Show every movable item"
        }
    }

    var symbol: String {
        switch action {
        case .openApplication: "macwindow"
        case .toggleHiddenSection: "eye"
        case .refreshMenuBar: "arrow.clockwise"
        case .showEveryItem: "arrow.uturn.backward"
        }
    }
}

private extension ShortcutGesture {
    var displayValue: String {
        modifierSymbols + key.uppercased()
    }

    var accessibilityValue: String {
        let names = [
            modifiers.contains(.control) ? "Control" : nil,
            modifiers.contains(.option) ? "Option" : nil,
            modifiers.contains(.shift) ? "Shift" : nil,
            modifiers.contains(.command) ? "Command" : nil,
            key.uppercased(),
        ].compactMap { $0 }
        return names.joined(separator: " plus ")
    }

    private var modifierSymbols: String {
        (modifiers.contains(.control) ? "⌃" : "") +
            (modifiers.contains(.option) ? "⌥" : "") +
            (modifiers.contains(.shift) ? "⇧" : "") +
            (modifiers.contains(.command) ? "⌘" : "")
    }
}
