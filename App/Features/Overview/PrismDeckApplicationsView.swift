// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import SwiftUI

enum PrismDeckApplicationCommand: Equatable {
    case toggle(MenuBarSection)
    case first(Int)
    case last(Int)

    static func toggleDestination(from section: MenuBarSection) -> MenuBarSection {
        section == .hidden ? .visible : .hidden
    }

    var destinationPosition: Int? {
        switch self {
        case .toggle:
            nil
        case let .first(position), let .last(position):
            position
        }
    }
}

struct PrismDeckApplicationsView: View {
    @Environment(\.prismTextSizePreference) private var textSize
    @Environment(AppModel.self) private var model
    let presentation: PrismDeckApplicationsPresentation
    @Binding var selectedItemID: MenuBarItemID?
    @Binding var searchText: String
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                searchField
                applicationContent
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Label("Applications", systemImage: "app.dashed")
                    .prismFont(.headline)
                Spacer()
                Text("\(presentation.totalApplicationCount)")
                    .prismFont(.caption, weight: .semibold, monospacedDigits: true)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(
                        "\(presentation.totalApplicationCount) manageable applications"
                    )
            }
        }
        .accessibilityIdentifier("prismDeck.applications")
        .padding(14)
        .background(.background.secondary, in: .rect(cornerRadius: 18))
    }
}

private extension PrismDeckApplicationsView {
    var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search applications", text: $searchText)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("prismDeck.applications.search")
            if !searchText.isEmpty {
                Button("Clear Search", systemImage: "xmark.circle.fill") {
                    searchText = ""
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 30 * CGFloat(textSize.scale))
        .background(.quaternary, in: .rect(cornerRadius: 9))
    }

    @ViewBuilder
    var applicationContent: some View {
        if presentation.totalApplicationCount == 0 {
            emptyMessage("No manageable applications are visible on this display.")
        } else if presentation.filteredRows.isEmpty, !presentation.queryIsEmpty {
            emptyMessage("No applications match this search.")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if !presentation.visibleRows.isEmpty {
                    applicationGroup(
                        title: "On Bar",
                        symbol: "menubar.rectangle",
                        rows: presentation.visibleRows
                    )
                    .accessibilityIdentifier("prismDeck.applications.visible")
                }
                if !presentation.hiddenRows.isEmpty {
                    applicationGroup(
                        title: "Tucked Away",
                        symbol: "eye.slash",
                        rows: presentation.hiddenRows
                    )
                    .accessibilityIdentifier("prismDeck.applications.hidden")
                }
            }
        }
    }

    func applicationGroup(
        title: String,
        symbol: String,
        rows: [PrismDeckApplicationRow]
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol)
                .prismFont(.caption, weight: .semibold)
                .foregroundStyle(.secondary)

            ForEach(rows) { row in
                applicationRow(row)
            }
        }
    }

    func applicationRow(_ row: PrismDeckApplicationRow) -> some View {
        HStack(spacing: 8) {
            rowSelectionButton(row)
            rowToggleButton(row)
            rowMoveMenu(row)
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 38 * CGFloat(textSize.scale))
        .background(
            selectedItemID == row.id ? Color.accentColor.opacity(0.12) : .clear,
            in: .rect(cornerRadius: 10)
        )
        .accessibilityIdentifier(rowIdentifier(row))
    }

    func rowSelectionButton(_ row: PrismDeckApplicationRow) -> some View {
        Button {
            selectedItemID = row.id
        } label: {
            HStack(spacing: 8) {
                MenuBarApplicationIcon(
                    bundleIdentifier: row.ownerBundleIdentifier,
                    fallbackSymbol: "app",
                    size: 20
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.name)
                        .prismFont(.callout, weight: .medium)
                        .lineLimit(1)
                    Text(rowSubtitle(row))
                        .prismFont(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    func rowToggleButton(_ row: PrismDeckApplicationRow) -> some View {
        Button(
            row.section == .hidden ? "Show" : "Hide",
            systemImage: row.section == .hidden ? "eye" : "eye.slash"
        ) {
            perform(.toggle(row.section), row: row)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .help(row.section == .hidden ? "Show on menu bar" : "Tuck away")
        .disabled(!canAct(on: row))
        .accessibilityIdentifier(rowIdentifier(row) + ".toggle")
    }

    func rowMoveMenu(_ row: PrismDeckApplicationRow) -> some View {
        Menu("Move", systemImage: "ellipsis") {
            Button("Move to First Position", systemImage: "arrow.left.to.line") {
                if let position = row.firstDestinationPosition {
                    perform(.first(position), row: row)
                }
            }
            .disabled(row.firstDestinationPosition == nil)

            Button("Move to Last Position", systemImage: "arrow.right.to.line") {
                if let position = row.lastDestinationPosition {
                    perform(.last(position), row: row)
                }
            }
            .disabled(row.lastDestinationPosition == nil)
        }
        .menuStyle(.button)
        .labelStyle(.iconOnly)
        .disabled(!canAct(on: row))
        .accessibilityIdentifier(rowIdentifier(row) + ".more")
    }

    func emptyMessage(_ message: String) -> some View {
        Text(message)
            .prismFont(.callout)
            .foregroundStyle(.secondary)
            .frame(
                maxWidth: .infinity,
                minHeight: 48 * CGFloat(textSize.scale),
                alignment: .leading
            )
    }

    func canAct(on row: PrismDeckApplicationRow) -> Bool {
        row.allowsVerifiedMovement && !model.isMenuBarActionInProgress
    }

    func perform(_ command: PrismDeckApplicationCommand, row: PrismDeckApplicationRow) {
        guard canAct(on: row) else { return }
        switch command {
        case let .toggle(section):
            model.moveMenuBarItem(
                row.id,
                to: PrismDeckApplicationCommand.toggleDestination(from: section)
            )
        case let .first(position), let .last(position):
            model.moveMenuBarItem(row.id, to: position)
        }
    }

    func rowSubtitle(_ row: PrismDeckApplicationRow) -> String {
        if !row.allowsVerifiedMovement {
            return "Unavailable · position \(row.sectionPosition) of \(row.sectionCount)"
        }
        let section = row.section == .hidden ? "Tucked Away" : "On Bar"
        return "\(section) · position \(row.sectionPosition) of \(row.sectionCount)"
    }

    func rowIdentifier(_ row: PrismDeckApplicationRow) -> String {
        "prismDeck.application.\(row.section.rawValue).\(row.sectionPosition)"
    }
}
