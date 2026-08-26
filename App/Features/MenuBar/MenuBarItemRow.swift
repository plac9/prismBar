// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import SwiftUI

struct MenuBarItemRow: View {
    @Environment(AppModel.self) private var model
    let item: MenuBarItem
    let destinations: [MenuBarItem]
    let surfaceLabel: String
    let section: MenuBarSection?
    @Binding var isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Toggle("Select \(item.displayName)", isOn: $isSelected)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .disabled(!canMove)

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

            sectionButton
            positionMenu
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityActions {
            accessibilityActions
        }
    }

    @ViewBuilder
    private var sectionButton: some View {
        if section == .hidden {
            Button("Show", systemImage: "eye") {
                model.moveMenuBarItem(item.id, to: .visible)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .disabled(!canMove)
        } else if section == .visible {
            Button("Hide", systemImage: "eye.slash") {
                model.moveMenuBarItem(item.id, to: .hidden)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .disabled(!canMove)
        }
    }

    private var positionMenu: some View {
        Menu {
            ForEach(Array(destinations.enumerated()), id: \.element.id) { offset, destination in
                Button {
                    model.moveMenuBarItem(item.id, to: destination.position)
                } label: {
                    if destination.id == item.id {
                        Label("Position \(offset + 1)", systemImage: "checkmark")
                    } else {
                        Text("Position \(offset + 1)")
                    }
                }
                .disabled(destination.id == item.id)
            }
        } label: {
            Label("Position \(currentSectionPosition)", systemImage: "arrow.left.arrow.right")
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .controlSize(.small)
        .disabled(!canMove)
    }

    @ViewBuilder
    private var accessibilityActions: some View {
        if canMove, section == .hidden {
            Button("Show") {
                model.moveMenuBarItem(item.id, to: .visible)
            }
        } else if canMove, section == .visible {
            Button("Hide") {
                model.moveMenuBarItem(item.id, to: .hidden)
            }
        }

        if canMove, let firstDestination = destinations.first,
           firstDestination.id != item.id {
            Button("Move to First Position") {
                model.moveMenuBarItem(item.id, to: firstDestination.position)
            }
        }

        if canMove, let lastDestination = destinations.last,
           lastDestination.id != item.id {
            Button("Move to Last Position") {
                model.moveMenuBarItem(item.id, to: lastDestination.position)
            }
        }
    }

    private var canMove: Bool {
        item.isMovable && item.availability == .controllable && !model.isMenuBarActionInProgress
    }

    private var currentSectionPosition: Int {
        (destinations.firstIndex(where: { $0.id == item.id }) ?? 0) + 1
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
