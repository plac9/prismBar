// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @State private var isResetConfirmationPresented = false

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
                Button(
                    model.isHiddenSectionCollapsed ? "Reveal Hidden Items" : "Fold Hidden Items",
                    systemImage: model.isHiddenSectionCollapsed ? "eye" : "eye.slash"
                ) {
                    model.setHiddenSectionCollapsed(!model.isHiddenSectionCollapsed)
                }
                .disabled(
                    model.accessibilityState != .granted ||
                        model.menuBarState == .loading ||
                        model.menuBarSnapshot?.hiddenSectionDivider == nil
                )
                Button("Refresh", systemImage: "arrow.clockwise") {
                    model.refreshMenuBar()
                }
                .disabled(model.accessibilityState != .granted || model.menuBarState == .loading)
                Menu {
                    Button("Show Every Movable Item", systemImage: "arrow.uturn.backward") {
                        isResetConfirmationPresented = true
                    }
                    .disabled(model.isMenuBarActionInProgress)
                } label: {
                    Label("Recovery", systemImage: "lifepreserver")
                }
                .disabled(model.accessibilityState != .granted || model.menuBarState != .ready)
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

                List(snapshot.items.filter { $0.role == .item }) { item in
                    MenuBarItemRow(
                        item: item,
                        itemCount: snapshot.items.count,
                        section: snapshot.section(for: item.id)
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
        .confirmationDialog(
            "Show every movable menu bar item?",
            isPresented: $isResetConfirmationPresented
        ) {
            Button("Show Every Item") {
                model.resetMenuBar()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This preserves item order and leaves the hidden section unfolded.")
        }
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
    let section: MenuBarSection?
    @State private var destinationIndex: Int

    init(item: MenuBarItem, itemCount: Int, section: MenuBarSection?) {
        self.item = item
        self.itemCount = itemCount
        self.section = section
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

            Text(sectionLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(section == .hidden ? .secondary : .primary)

            if section == .hidden {
                Button("Show", systemImage: "eye") {
                    model.moveMenuBarItem(item.id, to: .visible)
                }
                .disabled(!canMove)
            } else if section == .visible {
                Button("Hide", systemImage: "eye.slash") {
                    model.moveMenuBarItem(item.id, to: .hidden)
                }
                .disabled(!canMove)
            }

            Picker("Position", selection: $destinationIndex) {
                ForEach(0 ..< itemCount, id: \.self) { index in
                    Text("\(index + 1)").tag(index)
                }
            }
            .labelsHidden()
            .frame(width: 74)
            .disabled(!canMove)
            .onChange(of: item.position) { _, newPosition in
                destinationIndex = newPosition
            }

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

    private var sectionLabel: String {
        switch section {
        case .hidden: "Hidden"
        case .visible: "Visible"
        case .controller: "prismBar"
        case nil: "Unassigned"
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
