// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import prismBarCore
import prismBarEngine
import SwiftUI

struct PrismDeckView: View {
    @Bindable private var model: AppModel
    private let openWorkspace: () -> Void
    @State private var isResetConfirmationPresented = false
    @State private var isItemListExpanded = false

    init(
        model: AppModel,
        openWorkspace: @escaping () -> Void
    ) {
        self.model = model
        self.openWorkspace = openWorkspace
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            barMode
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()
            footer
        }
        .frame(width: 360, height: 520)
        .environment(model)
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
}

private extension PrismDeckView {
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(nsImage: PrismStatusIcon.image)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text("prismDeck")
                        .font(.headline)
                    Text("Fast menu bar control without leaving your work")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: accessibilitySymbol)
                    .foregroundStyle(accessibilityColor)
                    .help(accessibilityTitle)
                    .accessibilityLabel(accessibilityTitle)
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private var barMode: some View {
        if model.accessibilityState != .granted {
            ContentUnavailableView {
                Label("Accessibility needed", systemImage: "hand.raised")
            } description: {
                Text("Grant access to organize menu bar items. prismBar never reads screen pixels.")
            } actions: {
                Button("Review Access") {
                    model.requestAccessibility()
                }
                Button("Check Again") {
                    model.refreshAccessibility()
                }
            }
            .padding(18)
        } else if let snapshot = model.menuBarSnapshot {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(
                        "\(snapshot.items.filter { $0.role == .item }.count) items",
                        systemImage: "menubar.rectangle"
                    )
                    .font(.callout.weight(.medium))

                    Spacer()

                    Button("Refresh", systemImage: "arrow.clockwise") {
                        model.refreshMenuBar()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .help("Refresh Menu Items")
                }

                actionStatus

                PrismRailView(snapshot: snapshot)

                DisclosureGroup("Item details and keyboard controls", isExpanded: $isItemListExpanded) {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(snapshot.items.filter { $0.role == .item }) { item in
                                itemRow(item, snapshot: snapshot)
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
                .font(.caption)

                HStack(spacing: 8) {
                    Button(
                        model.isHiddenSectionCollapsed ? "Reveal Hidden" : "Fold Hidden",
                        systemImage: model.isHiddenSectionCollapsed ? "eye" : "eye.slash"
                    ) {
                        model.setHiddenSectionCollapsed(!model.isHiddenSectionCollapsed)
                    }
                    .disabled(snapshot.hiddenSectionDivider == nil)

                    Spacer()

                    Button("Show All") {
                        isResetConfirmationPresented = true
                    }
                    .disabled(model.isMenuBarActionInProgress)
                }
                .buttonStyle(.glass)
            }
            .padding(14)
        } else {
            ProgressView("Reading menu bar items")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Open Workspace", systemImage: "rectangle.on.rectangle") {
                openWorkspace()
            }

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .labelStyle(.iconOnly)
            }
            .help("Open prismBar Settings")
            .accessibilityLabel("Settings")

            Spacer()

            Button("Quit prismBar", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
            .labelStyle(.iconOnly)
            .keyboardShortcut("q")
        }
        .buttonStyle(.glass)
        .padding(12)
    }

    private func itemRow(_ item: MenuBarItem, snapshot: MenuBarSnapshot) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(snapshot.section(for: item.id) == .hidden ? Color.secondary : Color.accentColor)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)

            Text(item.displayName)
                .lineLimit(1)

            Spacer()

            Menu("Move \(item.displayName)", systemImage: "ellipsis") {
                if snapshot.section(for: item.id) == .hidden {
                    Button("Show") {
                        model.moveMenuBarItem(item.id, to: .visible)
                    }
                } else if snapshot.section(for: item.id) == .visible {
                    Button("Hide") {
                        model.moveMenuBarItem(item.id, to: .hidden)
                    }
                }

                let destinations = snapshot.movementDestinations(for: item.id)
                if destinations.count > 1 {
                    Divider()
                    ForEach(Array(destinations.enumerated()), id: \.element.id) { offset, destination in
                        Button("Position \(offset + 1)") {
                            model.moveMenuBarItem(item.id, to: destination.position)
                        }
                        .disabled(destination.id == item.id)
                    }
                }
            }
            .menuStyle(.button)
            .labelStyle(.iconOnly)
            .disabled(!item.isMovable || model.isMenuBarActionInProgress)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
    }

    @ViewBuilder
    private var actionStatus: some View {
        switch model.menuBarActionState {
        case .idle:
            EmptyView()
        case .moving:
            Label("Moving and verifying", systemImage: "progress.indicator")
                .font(.caption)
                .accessibilityIdentifier("statusMenu.actionProgress")
        case let .result(result):
            Label(result.message, systemImage: result.symbol)
                .font(.caption)
                .foregroundStyle(resultColor(for: result.kind))
                .accessibilityIdentifier("statusMenu.actionResult")
        }
    }

    private var accessibilityTitle: String {
        model.accessibilityState == .granted ? "Accessibility ready" : "Accessibility needs attention"
    }

    private var accessibilitySymbol: String {
        model.accessibilityState == .granted ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
    }

    private var accessibilityColor: Color {
        model.accessibilityState == .granted ? .green : .orange
    }

    private func resultColor(for kind: MenuBarActionResultKind) -> Color {
        switch kind {
        case .success: .green
        case .warning: .orange
        case .failure: .red
        }
    }
}
