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
            PageHeader(
                eyebrow: "Organization",
                title: "Menu Bar",
                message: "Move directly to any position in a section. Every action is checked " +
                    "against a fresh macOS topology before it is reported as complete."
            )

            GlassCard {
                HStack(spacing: 10) {
                    Button(
                        model.isHiddenSectionCollapsed ? "Reveal Hidden Items" : "Fold Hidden Items",
                        systemImage: model.isHiddenSectionCollapsed ? "eye" : "eye.slash"
                    ) {
                        model.setHiddenSectionCollapsed(!model.isHiddenSectionCollapsed)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(
                        model.accessibilityState != .granted ||
                            model.menuBarState == .loading ||
                            model.menuBarSnapshot?.hiddenSectionDivider == nil
                    )

                    Button("Refresh", systemImage: "arrow.clockwise") {
                        model.refreshMenuBar()
                    }
                    .buttonStyle(.glass)
                    .disabled(model.accessibilityState != .granted || model.menuBarState == .loading)

                    Spacer()

                    Menu {
                        Button("Show Every Movable Item", systemImage: "arrow.uturn.backward") {
                            isResetConfirmationPresented = true
                        }
                        .disabled(model.isMenuBarActionInProgress)
                    } label: {
                        Label("Recovery", systemImage: "lifepreserver")
                    }
                    .menuStyle(.button)
                    .buttonStyle(.glass)
                    .disabled(model.accessibilityState != .granted || model.menuBarState != .ready)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                if let snapshot = model.menuBarSnapshot {
                    if snapshot.unavailableSourceCount > 0 {
                        Label(
                            "\(snapshot.unavailableSourceCount) menu bar source(s) did not respond. " +
                                "Visible items remain available and every move is still verified.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.orange)
                    }

                    List {
                        Section("Visible") {
                            ForEach(items(in: .visible, snapshot: snapshot)) { item in
                                MenuBarItemRow(
                                    item: item,
                                    destinations: items(in: .visible, snapshot: snapshot).filter {
                                        $0.surfaceID == item.surfaceID
                                    },
                                    surfaceLabel: surfaceLabel(for: item, snapshot: snapshot),
                                    section: .visible
                                )
                            }
                        }

                        Section("Hidden") {
                            let hiddenItems = items(in: .hidden, snapshot: snapshot)
                            if hiddenItems.isEmpty {
                                Label("No hidden items", systemImage: "checkmark.circle")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(hiddenItems) { item in
                                    MenuBarItemRow(
                                        item: item,
                                        destinations: hiddenItems.filter {
                                            $0.surfaceID == item.surfaceID
                                        },
                                        surfaceLabel: surfaceLabel(for: item, snapshot: snapshot),
                                        section: .hidden
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 220)

                    if case let .result(message) = model.menuBarActionState {
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("menuBar.actionResult")
                    }
                } else {
                    Spacer(minLength: 24)
                    ContentUnavailableView(
                        unavailableTitle,
                        systemImage: "menubar.rectangle",
                        description: Text(unavailableDescription)
                    )
                    .frame(maxWidth: .infinity)
                    Spacer(minLength: 24)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
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

    private func items(
        in section: MenuBarSection,
        snapshot: MenuBarSnapshot
    ) -> [MenuBarItem] {
        snapshot.items.filter { item in
            item.role == .item && snapshot.section(for: item.id) == section
        }
    }

    private func surfaceLabel(
        for item: MenuBarItem,
        snapshot: MenuBarSnapshot
    ) -> String {
        guard snapshot.surfaceIDs.count > 1,
              let index = snapshot.surfaceIDs.firstIndex(of: item.surfaceID)
        else {
            return "Menu bar"
        }
        return "Display \(index + 1)"
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
    let destinations: [MenuBarItem]
    let surfaceLabel: String
    let section: MenuBarSection?
    @State private var destinationIndex: Int

    init(
        item: MenuBarItem,
        destinations: [MenuBarItem],
        surfaceLabel: String,
        section: MenuBarSection?
    ) {
        self.item = item
        self.destinations = destinations
        self.surfaceLabel = surfaceLabel
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
                Text("\(ownershipLabel), \(surfaceLabel)")
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
                ForEach(Array(destinations.enumerated()), id: \.element.id) { offset, destination in
                    Text("\(offset + 1)").tag(destination.position)
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
