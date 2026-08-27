// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import prismBarCore
import prismBarEngine
import SwiftUI

struct OverviewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PageHeader(
                    symbol: "sparkles",
                    eyebrow: "Home",
                    title: "Your menu bar, in focus.",
                    message: "Organize once, move directly, and recover confidently. " +
                        "Every change is checked against the menu bar macOS actually presents."
                )
                .accessibilityIdentifier("home.header.sparkles")

                GroupBox("Readiness") {
                    VStack(spacing: 0) {
                        ReadinessRow(
                            title: "Accessibility",
                            value: accessibilityLabel,
                            symbol: accessibilitySymbol,
                            isReady: model.accessibilityState == .granted
                        )
                        Divider()
                        ReadinessRow(
                            title: "Menu Bar",
                            value: menuBarLabel,
                            symbol: "menubar.rectangle",
                            isReady: menuBarPresentation?.isComplete == true
                        )
                        Divider()
                        ReadinessRow(
                            title: "Tools",
                            value: pluginLabel,
                            symbol: "wrench.and.screwdriver",
                            isReady: model.pluginState == .ready
                        )
                    }
                }

                permissionSurface

                VStack(alignment: .leading, spacing: 12) {
                    Text("Private by construction")
                        .font(.headline)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 24) {
                            LocalBoundary(title: "No screen capture", symbol: "eye.slash")
                            LocalBoundary(title: "No telemetry", symbol: "waveform.path.ecg.rectangle")
                            LocalBoundary(title: "No uploads", symbol: "lock.shield")
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            LocalBoundary(title: "No screen capture", symbol: "eye.slash")
                            LocalBoundary(title: "No telemetry", symbol: "waveform.path.ecg.rectangle")
                            LocalBoundary(title: "No uploads", symbol: "lock.shield")
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(36)
        }
        .task {
            model.loadPluginIfNeeded()
        }
    }

    private var permissionSurface: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Text(actionMessage)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(PrivacyCopy.observation + " " + PrivacyCopy.boundary)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if model.accessibilityState == .denied {
                    Divider()
                    Grid(alignment: .topLeading, horizontalSpacing: 20, verticalSpacing: 12) {
                        GridRow {
                            RecoveryStep(
                                number: 1,
                                title: "Remove old entry",
                                message: "In Device Control and Data Access, remove prismBar if listed."
                            )
                            RecoveryStep(
                                number: 2,
                                title: "Add this app",
                                message: "Add /Applications/prismBar.app and enable it."
                            )
                            RecoveryStep(
                                number: 3,
                                title: "Reconnect",
                                message: "Return here and choose Check Again."
                            )
                        }
                    }
                }

                HStack(spacing: 10) {
                    if needsPermissionAction {
                        Button(permissionActionLabel) {
                            model.requestAccessibility()
                        }
                        .buttonStyle(.glassProminent)
                        .accessibilityIdentifier("accessibility.request")
                    }

                    if model.accessibilityState == .denied || model.accessibilityState == .requiresStableInstall {
                        Button("Show in Finder", systemImage: "finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([
                                URL(fileURLWithPath: "/Applications/prismBar.app"),
                            ])
                        }
                        .buttonStyle(.glass)
                    }

                    Button("Check Again", systemImage: "arrow.clockwise") {
                        model.refreshAccessibility()
                    }
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("accessibility.refresh")

                    if model.accessibilityState == .granted {
                        Button("Refresh Menu Bar", systemImage: "menubar.rectangle") {
                            model.refreshMenuBar()
                        }
                        .buttonStyle(.glassProminent)
                        .accessibilityIdentifier("menuBar.refresh")
                    }
                }
            }
        } label: {
            Label(actionTitle, systemImage: actionSymbol)
                .font(.headline)
        }
    }

    private var accessibilityLabel: String {
        switch model.accessibilityState {
        case .requiresStableInstall: "Install in Applications first"
        case .identityMismatch: "Build identity does not match"
        case .notRequested: "Not requested"
        case .denied: "Access not granted"
        case .granted: "Ready"
        }
    }

    private var needsPermissionAction: Bool {
        model.accessibilityState == .notRequested || model.accessibilityState == .denied
    }

    private var accessibilitySymbol: String {
        model.accessibilityState == .granted ? "checkmark.shield" : "exclamationmark.shield"
    }

    private var actionTitle: String {
        switch model.accessibilityState {
        case .requiresStableInstall: "Move prismBar into Applications"
        case .identityMismatch: "Install the current signed build"
        case .notRequested: "Allow Accessibility"
        case .denied: "Reconnect Accessibility"
        case .granted: "Ready when you are"
        }
    }

    private var actionMessage: String {
        switch model.accessibilityState {
        case .requiresStableInstall:
            "Run the signed app from /Applications/prismBar.app before granting access."
        case .identityMismatch:
            "The running code does not match prismBar's expected signed identity. Reinstall the current build."
        case .notRequested:
            "prismBar needs Accessibility only to observe and move menu bar items you control."
        case .denied:
            "Review prismBar in Privacy & Security > Device Control and Data Access. If it is already enabled, " +
                "remove that entry, add /Applications/prismBar.app again, then choose Check Again."
        case .granted:
            "Open Menu Bar to move, hide, reveal, or recover items."
        }
    }

    private var actionSymbol: String {
        switch model.accessibilityState {
        case .requiresStableInstall: "arrow.down.app"
        case .identityMismatch: "signature"
        case .notRequested: "lock.open.display"
        case .denied: "arrow.clockwise.circle"
        case .granted: "checkmark.circle"
        }
    }

    private var permissionActionLabel: String {
        model.accessibilityState == .denied ? "Review Accessibility Access" : "Allow Accessibility Access"
    }

    private var menuBarLabel: String {
        switch model.menuBarState {
        case .waitingForPermission: "Waiting for permission"
        case .loading: "Checking"
        case .ready:
            menuBarPresentation?.summary ?? "No items observed"
        case .unavailable: "Refresh needed"
        }
    }

    private var menuBarPresentation: MenuBarObservationPresentation? {
        guard let snapshot = model.menuBarSnapshot else { return nil }
        return MenuBarObservationPresentation(
            itemCount: snapshot.items.count,
            unavailableSourceCount: snapshot.unavailableSourceCount
        )
    }

    private var pluginLabel: String {
        switch model.pluginState {
        case .idle, .loading: "Checking"
        case .ready: "prismCalc ready"
        case .unavailable: "prismCalc unavailable"
        case .paused: "prismCalc paused for safety"
        case .disabled: "prismCalc disabled"
        }
    }
}

private struct RecoveryStep: View {
    let number: Int
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(number). \(title)")
                .font(.callout.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct LocalBoundary: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ReadinessRow: View {
    let title: String
    let value: String
    let symbol: String
    let isReady: Bool

    var body: some View {
        LabeledContent {
            Label(value, systemImage: isReady ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(isReady ? .primary : .secondary)
        } label: {
            Label(title, systemImage: symbol)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
