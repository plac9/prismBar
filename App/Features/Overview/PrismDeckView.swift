// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import prismBarCore
import prismBarEngine
import SwiftUI

struct PrismDeckView: View {
    @Environment(\.openSettings) private var openSettings
    @Bindable private var model: AppModel
    private let layoutSize: CGSize
    private let openWorkspace: () -> Void
    private let dismissDeck: () -> Void
    @State private var selectedRailSurfaceID: MenuBarSurfaceID = .unknown
    @State private var selectedRailItemID: MenuBarItemID?
    @State private var applicationSearchText = ""
    @State private var applicationsExpanded = true

    init(
        model: AppModel,
        layoutSize: CGSize,
        openWorkspace: @escaping () -> Void,
        dismissDeck: @escaping () -> Void
    ) {
        self.model = model
        self.layoutSize = layoutSize
        self.openWorkspace = openWorkspace
        self.dismissDeck = dismissDeck
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: layoutSize.width, height: layoutSize.height)
        .environment(model)
        .onDisappear {
            clearEphemeralState()
        }
        .onChange(of: model.accessibilityState) {
            if model.accessibilityState != .granted {
                clearEphemeralState()
            }
        }
    }
}

private extension PrismDeckView {
    var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: PrismStatusIcon.image)
                .prismFont(.title2, weight: .semibold)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("prismDeck")
                    .prismFont(.headline)
                Text(accessibilityTitle)
                    .prismFont(.caption)
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
            managementContent(snapshot)
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

    func managementContent(_ snapshot: MenuBarSnapshot) -> some View {
        let surfaceID = PrismRailSurfaceResolver().resolve(
            in: snapshot,
            current: selectedRailSurfaceID
        )
        let applications = PrismDeckApplicationsPresenter().make(
            snapshot: snapshot,
            surfaceID: surfaceID,
            query: applicationSearchText
        )

        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                topologyTruth(snapshot)
                PrismRailView(
                    snapshot: snapshot,
                    selectedSurfaceID: $selectedRailSurfaceID,
                    selectedItemID: $selectedRailItemID
                )
                PrismDeckApplicationsView(
                    presentation: applications,
                    selectedItemID: $selectedRailItemID,
                    searchText: $applicationSearchText,
                    isExpanded: $applicationsExpanded
                )
                actionRecovery
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.automatic)
    }

    func topologyTruth(_ snapshot: MenuBarSnapshot) -> some View {
        let presentation = MenuBarObservationPresentation(
            itemCount: snapshot.items.filter { $0.role == .item }.count,
            unavailableSourceCount: snapshot.unavailableSourceCount
        )

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label(
                    presentation.summary,
                    systemImage: snapshot.isComplete ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .prismFont(.caption, weight: .medium)
                .foregroundStyle(.secondary)

                Spacer()

                if model.isHiddenSectionCollapsed {
                    Label("Tucked away", systemImage: "eye.slash")
                        .prismFont(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let notice = presentation.inlineNotice {
                Label(notice, systemImage: "info.circle")
                    .prismFont(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("prismDeck.limitedScanNotice")
            }
        }
    }

    @ViewBuilder
    var actionStatus: some View {
        switch model.menuBarActionState {
        case .idle:
            Label("Ready for direct changes", systemImage: "cursorarrow.motionlines")
                .prismFont(.caption)
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
                .prismFont(.caption, weight: .medium)
            }
            .accessibilityIdentifier("statusMenu.actionProgress")
        case let .result(result):
            HStack(spacing: 8) {
                Label(result.message, systemImage: result.symbol)
                    .prismFont(.caption, weight: .medium)
                    .foregroundStyle(resultColor(for: result.kind))
                    .lineLimit(2)

                Spacer()

                recoveryButton(for: result.recovery)
            }
            .accessibilityIdentifier("statusMenu.actionResult")
        }
    }

    var actionRecovery: some View {
        HStack(spacing: 10) {
            actionStatus
            Spacer()
            if model.canRecoverLastAction {
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    model.recoverLastMenuBarAction()
                }
                .disabled(model.isMenuBarActionInProgress)
                .buttonStyle(.glass)
                .accessibilityIdentifier("statusMenu.undoLastChange")
            }
        }
        .padding(12)
        .background(.background.secondary, in: .rect(cornerRadius: 14))
        .accessibilityIdentifier("prismDeck.actionStatus")
    }

    var footer: some View {
        HStack(spacing: 8) {
            if model.menuBarSnapshot?.hiddenSectionDivider != nil {
                Button(
                    model.isHiddenSectionCollapsed ? "Reveal" : "Tuck Away",
                    systemImage: model.isHiddenSectionCollapsed ? "eye" : "eye.slash"
                ) {
                    model.setHiddenSectionCollapsed(!model.isHiddenSectionCollapsed)
                }
                .disabled(model.isMenuBarActionInProgress)
            }

            Button("Open prismBar", systemImage: "rectangle.on.rectangle") {
                openWorkspace()
            }

            Spacer()

            Menu("More", systemImage: "ellipsis") {
                Button("Settings", systemImage: "gearshape") {
                    dismissDeck()
                    openSettings()
                }

                Divider()

                Button("Quit prismBar", systemImage: "power") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .labelStyle(.iconOnly)
            .menuStyle(.button)
            .help("More prismBar actions")
            .accessibilityIdentifier("prismDeck.more")
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
        guard model.accessibilityState == .granted else {
            return "Accessibility needs attention"
        }
        return model.menuBarSnapshot?.isComplete == false
            ? "Menu bar ready · limited scan"
            : "Menu bar ready"
    }

    var accessibilitySymbol: String {
        model.accessibilityState == .granted && model.menuBarSnapshot?.isComplete != false
            ? "checkmark.shield.fill"
            : "exclamationmark.shield.fill"
    }

    var accessibilityColor: Color {
        model.accessibilityState == .granted && model.menuBarSnapshot?.isComplete != false
            ? .green
            : .orange
    }

    func resultColor(for kind: MenuBarActionResultKind) -> Color {
        switch kind {
        case .success: .green
        case .warning: .orange
        case .failure: .red
        }
    }

    func clearEphemeralState() {
        selectedRailSurfaceID = .unknown
        selectedRailItemID = nil
        applicationSearchText = ""
    }
}
