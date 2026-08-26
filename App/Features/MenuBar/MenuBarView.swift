// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Menu Bar")
                        .font(.largeTitle.weight(.semibold))
                    Text("Choose an exact destination. Every move is rechecked against macOS.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") {
                    model.refreshMenuBar()
                }
                .disabled(model.accessibilityState != .granted || model.menuBarState == .loading)
            }

            if let snapshot = model.menuBarSnapshot {
                if snapshot.unavailableSourceCount > 0 {
                    Label(
                        "\(snapshot.unavailableSourceCount) menu bar source(s) did not respond. " +
                            "Visible items remain available and every move is still verified.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.orange)
                }

                List(snapshot.items) { item in
                    MenuBarItemRow(
                        item: item,
                        itemCount: snapshot.items.count
                    )
                }
                .listStyle(.inset)

                if case let .result(message) = model.menuBarActionState {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("menuBar.actionResult")
                }
            } else {
                ContentUnavailableView(
                    unavailableTitle,
                    systemImage: "menubar.rectangle",
                    description: Text(unavailableDescription)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(28)
    }

    private var unavailableTitle: String {
        model.accessibilityState == .granted ? "Checking the menu bar" : "Accessibility required"
    }

    private var unavailableDescription: String {
        model.accessibilityState == .granted
            ? "prismBar is building a fresh local topology."
            : "Return to Overview to grant or refresh Accessibility access."
    }
}

private struct MenuBarItemRow: View {
    @Environment(AppModel.self) private var model
    let item: MenuBarItem
    let itemCount: Int
    @State private var destinationIndex: Int

    init(item: MenuBarItem, itemCount: Int) {
        self.item = item
        self.itemCount = itemCount
        _destinationIndex = State(initialValue: item.position)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: ownershipSymbol)
                .frame(width: 22)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .lineLimit(1)
                Text(ownershipLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Position", selection: $destinationIndex) {
                ForEach(0 ..< itemCount, id: \.self) { index in
                    Text("\(index + 1)").tag(index)
                }
            }
            .labelsHidden()
            .frame(width: 74)
            .disabled(!canMove)

            Button("Move") {
                model.moveMenuBarItem(item.id, to: destinationIndex)
            }
            .disabled(!canMove || destinationIndex == item.position)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private var canMove: Bool {
        item.isMovable && !model.isMenuBarActionInProgress
    }

    private var ownershipLabel: String {
        switch item.ownership {
        case .application: "Application item"
        case .system: "macOS item"
        case .selfOwned: "prismBar item"
        }
    }

    private var ownershipSymbol: String {
        switch item.ownership {
        case .application: "app"
        case .system: "apple.logo"
        case .selfOwned: "triangle"
        }
    }
}
