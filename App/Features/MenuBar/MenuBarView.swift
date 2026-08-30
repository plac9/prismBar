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
    @State private var isBulkOrganizationExpanded = false
    @State private var selectedItemIDs: Set<MenuBarItemID> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    symbol: "menubar.rectangle",
                    eyebrow: "Organization",
                    title: "Menu Bar",
                    message: "Place an item once. prismBar checks the menu bar macOS actually presents " +
                        "before it reports the change as complete.",
                    identifier: "menuBar.header.menubar.rectangle"
                )

                menuBarContent
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
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
            Text("This preserves item order and leaves the tucked-away section open.")
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
    @ViewBuilder
    var menuBarContent: some View {
        if let snapshot = model.menuBarSnapshot {
            VStack(alignment: .leading, spacing: 14) {
                topologyTruth(snapshot)
                actionStatus
                PrismRailView(snapshot: snapshot)
                immediateActions(snapshot)
                bulkOrganization(snapshot)
            }
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
            .frame(maxWidth: .infinity, minHeight: 360)
        }
    }

    func topologyTruth(_ snapshot: MenuBarSnapshot) -> some View {
        let itemCount = snapshot.items.filter { $0.role == .item }.count
        let presentation = MenuBarObservationPresentation(
            itemCount: itemCount,
            unavailableSourceCount: snapshot.unavailableSourceCount
        )

        return HStack(spacing: 10) {
            Label(
                presentation.summary,
                systemImage: snapshot.isComplete
                    ? "checkmark.circle.fill"
                    : "exclamationmark.triangle.fill"
            )
            .font(.callout.weight(.medium))
            .foregroundStyle(snapshot.isComplete ? Color.secondary : .orange)
            .help(presentation.unavailableSourcesWarning ?? presentation.summary)
            .accessibilityHint(presentation.unavailableSourcesWarning ?? presentation.summary)

            Spacer()

            Label(
                model.isHiddenSectionCollapsed ? "Tucked away" : "All sections open",
                systemImage: model.isHiddenSectionCollapsed ? "eye.slash" : "eye"
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    func immediateActions(_ snapshot: MenuBarSnapshot) -> some View {
        HStack(spacing: 10) {
            Button(
                model.isHiddenSectionCollapsed ? "Reveal Tucked Away" : "Tuck Away Hidden",
                systemImage: model.isHiddenSectionCollapsed ? "eye" : "eye.slash"
            ) {
                model.setHiddenSectionCollapsed(!model.isHiddenSectionCollapsed)
            }
            .buttonStyle(.glassProminent)
            .disabled(
                model.accessibilityState != .granted ||
                    model.menuBarState == .loading ||
                    snapshot.hiddenSectionDivider == nil
            )

            Button("Undo", systemImage: "arrow.uturn.backward") {
                model.recoverLastMenuBarAction()
            }
            .buttonStyle(.glass)
            .disabled(!model.canRecoverLastAction || model.isMenuBarActionInProgress)
            .accessibilityIdentifier("menuBar.undoLastChange")

            Spacer()

            Button("Refresh", systemImage: "arrow.clockwise") {
                model.refreshMenuBar()
            }
            .buttonStyle(.glass)
            .disabled(model.menuBarState == .loading)

            Menu("More", systemImage: "ellipsis") {
                Button("Show Every Movable Item", systemImage: "eye") {
                    isResetConfirmationPresented = true
                }
                .disabled(model.isMenuBarActionInProgress)
            }
            .menuStyle(.button)
            .buttonStyle(.glass)
        }
    }

    func bulkOrganization(_ snapshot: MenuBarSnapshot) -> some View {
        DisclosureGroup("Bulk organization", isExpanded: $isBulkOrganizationExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                bulkActions
                itemSection("On Bar", section: .visible, snapshot: snapshot)
                itemSection("Tucked Away", section: .hidden, snapshot: snapshot)
            }
            .padding(.top, 10)
        }
        .font(.callout.weight(.medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.background.secondary, in: .rect(cornerRadius: 14))
    }

    var bulkActions: some View {
        HStack(spacing: 10) {
            Label(
                "\(selectedItemIDs.count) selected",
                systemImage: selectedItemIDs.isEmpty ? "checklist.unchecked" : "checklist.checked"
            )
            .foregroundStyle(selectedItemIDs.isEmpty ? .secondary : .primary)

            Spacer()

            Button("Hide Selected", systemImage: "eye.slash") {
                let selection = selectedItemIDs
                selectedItemIDs.removeAll()
                model.moveMenuBarItems(selection, to: .hidden)
            }
            .disabled(!canMoveSelection(to: .hidden))

            Button("Show Selected", systemImage: "eye") {
                let selection = selectedItemIDs
                selectedItemIDs.removeAll()
                model.moveMenuBarItems(selection, to: .visible)
            }
            .disabled(!canMoveSelection(to: .visible))

            Button("Clear") {
                selectedItemIDs.removeAll()
            }
            .disabled(selectedItemIDs.isEmpty || model.isMenuBarActionInProgress)
        }
        .buttonStyle(.glass)
    }

    @ViewBuilder
    func itemSection(
        _ title: String,
        section: MenuBarSection,
        snapshot: MenuBarSnapshot
    ) -> some View {
        let sectionItems = items(in: section, snapshot: snapshot)
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if sectionItems.isEmpty {
                Label("No items", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(sectionItems) { item in
                    MenuBarItemRow(
                        item: item,
                        destinations: snapshot.movementDestinations(for: item.id),
                        surfaceLabel: surfaceLabel(for: item, snapshot: snapshot),
                        section: section,
                        isSelected: selectionBinding(for: item.id)
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.background, in: .rect(cornerRadius: 10))
                }
            }
        }
    }

    @ViewBuilder
    var actionStatus: some View {
        switch model.menuBarActionState {
        case .idle:
            EmptyView()
        case .moving:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(actionProgressMessage)
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

    var actionProgressMessage: String {
        model.currentActionReceipt?.kind == .recovery
            ? "Restoring and checking macOS"
            : "Moving and checking macOS"
    }

    @ViewBuilder
    func recoveryButton(for recovery: MenuBarRecoveryAction) -> some View {
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

    func resultColor(for kind: MenuBarActionResultKind) -> Color {
        switch kind {
        case .success: .green
        case .warning: .orange
        case .failure: .red
        }
    }

    func items(in section: MenuBarSection, snapshot: MenuBarSnapshot) -> [MenuBarItem] {
        snapshot.items.filter { item in
            item.role == .item && snapshot.section(for: item.id) == section
        }
    }

    func surfaceLabel(for item: MenuBarItem, snapshot: MenuBarSnapshot) -> String {
        guard snapshot.surfaceIDs.count > 1,
              let index = snapshot.surfaceIDs.firstIndex(of: item.surfaceID)
        else {
            return "Menu bar"
        }
        return "Display \(index + 1)"
    }

    func selectionBinding(for itemID: MenuBarItemID) -> Binding<Bool> {
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

    func canMoveSelection(to section: MenuBarSection) -> Bool {
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

    var unavailableTitle: String {
        model.accessibilityState == .granted ? "Checking the menu bar" : "Accessibility required"
    }

    var unavailableDescription: String {
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
    var primaryPermissionRecoveryButton: some View {
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
