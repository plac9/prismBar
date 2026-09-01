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
    @State private var selectedRailSurfaceID: MenuBarSurfaceID = .unknown
    @State private var selectedRailItemID: MenuBarItemID?

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
            content
            Divider()
            footer
        }
        .frame(width: 440, height: 500)
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
            Text("This preserves item order and leaves the tucked-away section open.")
        }
    }
}

private extension PrismDeckView {
    var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: PrismStatusIcon.image)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("prismDeck")
                    .font(.headline)
                Text(accessibilityTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: accessibilitySymbol)
                .foregroundStyle(accessibilityColor)
                .help(accessibilityTitle)
                .accessibilityLabel(accessibilityTitle)

            Button("Refresh", systemImage: "arrow.clockwise") {
                model.refreshMenuBar()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .disabled(model.accessibilityState != .granted || model.menuBarState == .loading)
            .help("Refresh Menu Bar")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    var content: some View {
        if model.accessibilityState != .granted {
            permissionContent
        } else if let snapshot = model.menuBarSnapshot {
            VStack(alignment: .leading, spacing: 10) {
                topologyTruth(snapshot)
                PrismRailView(
                    snapshot: snapshot,
                    selectedSurfaceID: $selectedRailSurfaceID,
                    selectedItemID: $selectedRailItemID
                )
                actionStatus
                immediateActions(snapshot)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ProgressView("Reading menu bar")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    var permissionContent: some View {
        ContentUnavailableView {
            Label("Accessibility needed", systemImage: "hand.raised")
        } description: {
            Text("Grant access to arrange menu bar items. prismBar never captures your screen.")
        } actions: {
            Button("Review Access") {
                model.requestAccessibility()
            }
            .buttonStyle(.glassProminent)

            Button("Check Again") {
                model.refreshAccessibility()
            }
            .buttonStyle(.glass)
        }
        .padding(18)
    }

    func topologyTruth(_ snapshot: MenuBarSnapshot) -> some View {
        let presentation = MenuBarObservationPresentation(
            itemCount: snapshot.items.filter { $0.role == .item }.count,
            unavailableSourceCount: snapshot.unavailableSourceCount
        )

        return HStack(spacing: 8) {
            Label(
                presentation.summary,
                systemImage: snapshot.isComplete ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(snapshot.isComplete ? Color.secondary : .orange)
            .help(presentation.unavailableSourcesWarning ?? presentation.summary)
            .accessibilityHint(presentation.unavailableSourcesWarning ?? presentation.summary)

            Spacer()

            if model.isHiddenSectionCollapsed {
                Label("Tucked away", systemImage: "eye.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    var actionStatus: some View {
        switch model.menuBarActionState {
        case .idle:
            Label("Ready for direct changes", systemImage: "cursorarrow.motionlines")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("statusMenu.actionReady")
        case .moving:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(
                    model.currentActionReceipt?.kind == .recovery
                        ? "Restoring and checking macOS"
                        : "Moving and checking macOS"
                )
                .font(.caption.weight(.medium))
            }
            .accessibilityIdentifier("statusMenu.actionProgress")
        case let .result(result):
            HStack(spacing: 8) {
                Label(result.message, systemImage: result.symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(resultColor(for: result.kind))
                    .lineLimit(2)

                Spacer()

                recoveryButton(for: result.recovery)
            }
            .accessibilityIdentifier("statusMenu.actionResult")
        }
    }

    func immediateActions(_ snapshot: MenuBarSnapshot) -> some View {
        HStack(spacing: 8) {
            Button("Undo", systemImage: "arrow.uturn.backward") {
                model.recoverLastMenuBarAction()
            }
            .disabled(!model.canRecoverLastAction || model.isMenuBarActionInProgress)
            .accessibilityIdentifier("statusMenu.undoLastChange")

            Button(
                model.isHiddenSectionCollapsed ? "Reveal" : "Tuck Away",
                systemImage: model.isHiddenSectionCollapsed ? "eye" : "eye.slash"
            ) {
                model.setHiddenSectionCollapsed(!model.isHiddenSectionCollapsed)
            }
            .disabled(snapshot.hiddenSectionDivider == nil)

            Spacer()

            Menu("More", systemImage: "ellipsis") {
                Button("Show Every Movable Item", systemImage: "eye") {
                    isResetConfirmationPresented = true
                }
                .disabled(model.isMenuBarActionInProgress)
            }
            .menuStyle(.button)
        }
        .buttonStyle(.glass)
    }

    var footer: some View {
        HStack(spacing: 8) {
            Button("Open prismBar", systemImage: "rectangle.on.rectangle") {
                openWorkspace()
            }

            Spacer()

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .labelStyle(.iconOnly)
            }
            .help("Open prismBar Settings")
            .accessibilityLabel("Settings")

            Button("Quit prismBar", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
            .labelStyle(.iconOnly)
            .keyboardShortcut("q")
        }
        .buttonStyle(.glass)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    func recoveryButton(for recovery: MenuBarRecoveryAction) -> some View {
        switch recovery {
        case .refresh:
            Button("Refresh") {
                model.refreshMenuBar()
            }
            .buttonStyle(.glass)
        case .recheckPermission:
            Button("Check Access") {
                model.refreshAccessibility()
            }
            .buttonStyle(.glass)
        case .none:
            EmptyView()
        }
    }

    var accessibilityTitle: String {
        model.accessibilityState == .granted ? "Menu bar control ready" : "Accessibility needs attention"
    }

    var accessibilitySymbol: String {
        model.accessibilityState == .granted ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
    }

    var accessibilityColor: Color {
        model.accessibilityState == .granted ? .green : .orange
    }

    func resultColor(for kind: MenuBarActionResultKind) -> Color {
        switch kind {
        case .success: .green
        case .warning: .orange
        case .failure: .red
        }
    }
}
