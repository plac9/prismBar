// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import prismBarCore
import prismBarEngine
import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @State private var isResetConfirmationPresented = false
    @State private var selectedItemIDs: Set<MenuBarItemID> = []

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(
                    symbol: "menubar.rectangle",
                    eyebrow: "Organization",
                    title: "Menu Bar",
                    message: "Move directly to any position in a section. Every action is checked " +
                        "against a fresh macOS topology before it is reported as complete.",
                    identifier: "menuBar.header.menubar.rectangle"
                )

                if model.accessibilityState == .granted {
                    menuBarControls
                }

                actionStatus
                menuBarContent
            }
            .padding(28)
            .frame(
                width: geometry.size.width,
                height: geometry.size.height,
                alignment: .topLeading
            )
        }
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
        .onChange(of: model.menuBarSnapshot?.generation) {
            guard let snapshot = model.menuBarSnapshot else {
                selectedItemIDs.removeAll()
                return
            }
            selectedItemIDs.formIntersection(snapshot.items.map(\.id))
        }
    }
}

private extension MenuBarView {
    private var menuBarControls: some View {
        PrismContentSection {
            VStack(alignment: .leading, spacing: 12) {
                Label("Menu bar controls", systemImage: "slider.horizontal.3")
                    .font(.headline)

                Divider()

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
                    .disabled(
                        model.accessibilityState != .granted ||
                            model.menuBarState == .loading
                    )

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

                Divider()

                HStack(spacing: 10) {
                    Label(
                        "\(selectedItemIDs.count) selected",
                        systemImage: selectedItemIDs.isEmpty ? "checklist.unchecked" : "checklist.checked"
                    )
                    .font(.callout.weight(.medium))
                    .foregroundStyle(selectedItemIDs.isEmpty ? .secondary : .primary)

                    Spacer()

                    Button("Hide Selected", systemImage: "eye.slash") {
                        let selection = selectedItemIDs
                        selectedItemIDs.removeAll()
                        model.moveMenuBarItems(selection, to: .hidden)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!canMoveSelection(to: .hidden))

                    Button("Show Selected", systemImage: "eye") {
                        let selection = selectedItemIDs
                        selectedItemIDs.removeAll()
                        model.moveMenuBarItems(selection, to: .visible)
                    }
                    .buttonStyle(.glass)
                    .disabled(!canMoveSelection(to: .visible))

                    Button("Clear") {
                        selectedItemIDs.removeAll()
                    }
                    .buttonStyle(.glass)
                    .disabled(selectedItemIDs.isEmpty || model.isMenuBarActionInProgress)
                }
            }
        }
    }

    @ViewBuilder
    private var menuBarContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let snapshot = model.menuBarSnapshot {
                if let notice = MenuBarObservationPresentation(
                    itemCount: snapshot.items.count,
                    unavailableSourceCount: snapshot.unavailableSourceCount
                ).sourceAvailabilityNotice(
                    hiddenSectionCollapsed: model.isHiddenSectionCollapsed
                ) {
                    Label(
                        notice,
                        systemImage: model.isHiddenSectionCollapsed
                            ? "eye.slash"
                            : "exclamationmark.triangle"
                    )
                    .foregroundStyle(model.isHiddenSectionCollapsed ? Color.secondary : .orange)
                }

                PrismRailView(snapshot: snapshot)

                List {
                    Section("Visible") {
                        ForEach(items(in: .visible, snapshot: snapshot)) { item in
                            MenuBarItemRow(
                                item: item,
                                destinations: snapshot.movementDestinations(for: item.id),
                                surfaceLabel: surfaceLabel(for: item, snapshot: snapshot),
                                section: .visible,
                                isSelected: selectionBinding(for: item.id)
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
                                    destinations: snapshot.movementDestinations(for: item.id),
                                    surfaceLabel: surfaceLabel(for: item, snapshot: snapshot),
                                    section: .hidden,
                                    isSelected: selectionBinding(for: item.id)
                                )
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 220)
            } else {
                ContentUnavailableView {
                    Label(unavailableTitle, systemImage: "menubar.rectangle")
                } description: {
                    Text(unavailableDescription)
                } actions: {
                    if model.accessibilityState != .granted {
                        primaryPermissionRecoveryButton

                        Button("Check Again", systemImage: "arrow.clockwise") {
                            model.refreshAccessibility()
                        }
                        .accessibilityIdentifier("menuBar.checkAccess")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    @ViewBuilder
    private var actionStatus: some View {
        switch model.menuBarActionState {
        case .idle:
            EmptyView()
        case .moving:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Moving and verifying against macOS…")
                    .font(.callout.weight(.medium))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.background.secondary, in: .rect(cornerRadius: 14))
            .accessibilityIdentifier("menuBar.actionProgress")
        case let .result(result):
            HStack(spacing: 10) {
                Label(result.message, systemImage: result.symbol)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(resultColor(for: result.kind))
                    .frame(maxWidth: .infinity, alignment: .leading)

                recoveryButton(for: result.recovery)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.background.secondary, in: .rect(cornerRadius: 14))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("menuBar.actionResult")
        }
    }

    @ViewBuilder
    private func recoveryButton(for recovery: MenuBarRecoveryAction) -> some View {
        switch recovery {
        case .refresh:
            Button("Refresh", systemImage: "arrow.clockwise") {
                model.refreshMenuBar()
            }
            .accessibilityIdentifier("menuBar.actionRecovery.refresh")
        case .recheckPermission:
            Button("Check Access", systemImage: "hand.raised") {
                model.refreshAccessibility()
            }
            .accessibilityIdentifier("menuBar.actionRecovery.permission")
        case .none:
            EmptyView()
        }
    }

    private func resultColor(for kind: MenuBarActionResultKind) -> Color {
        switch kind {
        case .success: .green
        case .warning: .orange
        case .failure: .red
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

    private func selectionBinding(for itemID: MenuBarItemID) -> Binding<Bool> {
        Binding {
            selectedItemIDs.contains(itemID)
        } set: { isSelected in
            if isSelected {
                selectedItemIDs.insert(itemID)
            } else {
                selectedItemIDs.remove(itemID)
            }
        }
    }

    private func canMoveSelection(to section: MenuBarSection) -> Bool {
        guard !model.isMenuBarActionInProgress,
              let snapshot = model.menuBarSnapshot
        else { return false }

        return snapshot.items.contains { item in
            selectedItemIDs.contains(item.id) &&
                item.isMovable &&
                item.availability == .controllable &&
                snapshot.section(for: item.id) != section
        }
    }

    private var unavailableTitle: String {
        model.accessibilityState == .granted ? "Checking the menu bar" : "Accessibility required"
    }

    private var unavailableDescription: String {
        switch model.accessibilityState {
        case .granted:
            "prismBar is building a fresh local topology."
        case .requiresStableInstall:
            "Install the signed app in Applications, then check access again."
        case .identityMismatch:
            "Install the current signed prismBar build before granting access."
        case .notRequested:
            "Allow Accessibility to organize the menu bar without reading screen pixels."
        case .denied:
            "Review prismBar in Device Control and Data Access, then check again."
        }
    }

    @ViewBuilder
    private var primaryPermissionRecoveryButton: some View {
        switch model.accessibilityState {
        case .requiresStableInstall, .identityMismatch:
            Button("Show in Finder", systemImage: "finder") {
                NSWorkspace.shared.activateFileViewerSelecting([
                    URL(fileURLWithPath: "/Applications/prismBar.app"),
                ])
            }
            .accessibilityIdentifier("menuBar.primaryRecovery")
        case .notRequested:
            Button("Allow Access", systemImage: "hand.raised") {
                model.requestAccessibility()
            }
            .accessibilityIdentifier("menuBar.primaryRecovery")
        case .denied:
            Button("Review Access", systemImage: "hand.raised") {
                model.requestAccessibility()
            }
            .accessibilityIdentifier("menuBar.primaryRecovery")
        case .granted:
            EmptyView()
        }
    }
}
