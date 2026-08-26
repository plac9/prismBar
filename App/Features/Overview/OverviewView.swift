// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import prismBarEngine
import SwiftUI

struct OverviewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    eyebrow: "Local control",
                    title: "Your menu bar, in focus.",
                    message: "Organize once, move directly, and recover confidently. " +
                        "Every change is checked against the menu bar macOS actually presents."
                )

                GlassEffectContainer(spacing: 14) {
                    HStack(spacing: 14) {
                        StatusTile(
                            title: "Accessibility",
                            value: accessibilityLabel,
                            symbol: accessibilitySymbol,
                            isReady: model.accessibilityState == .granted
                        )
                        StatusTile(
                            title: "Menu items",
                            value: menuBarLabel,
                            symbol: "menubar.rectangle",
                            isReady: model.menuBarState == .ready
                        )
                        StatusTile(
                            title: "Plugin",
                            value: pluginLabel,
                            symbol: "puzzlepiece.extension",
                            isReady: model.pluginState == .ready
                        )
                    }
                }

                permissionSurface

                GlassCard {
                    HStack(spacing: 24) {
                        LocalPromise(title: "No screen capture", symbol: "eye.slash")
                        Divider()
                        LocalPromise(title: "No telemetry", symbol: "waveform.path.ecg.rectangle")
                        Divider()
                        LocalPromise(title: "No uploads", symbol: "lock.shield")
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(32)
        }
        .task {
            model.loadPluginIfNeeded()
        }
    }

    private var permissionSurface: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeading(actionTitle, message: actionMessage, systemImage: actionSymbol)

                if model.accessibilityState == .denied {
                    Divider()
                    HStack(alignment: .top, spacing: 18) {
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
                        RecoveryStep(number: 3, title: "Reconnect", message: "Return here and choose Check Again.")
                    }
                }

                HStack(spacing: 10) {
                    if needsPermissionAction {
                        Button(permissionActionLabel) {
                            model.requestAccessibility()
                        }
                        .buttonStyle(.glassProminent)
                        .accessibilityLabel(permissionActionLabel)
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

                    Button("Check Again") {
                        model.refreshAccessibility()
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Check Again")
                    .accessibilityIdentifier("accessibility.refresh")

                    if model.accessibilityState == .granted {
                        Button("Refresh Menu Bar") {
                            model.refreshMenuBar()
                        }
                        .buttonStyle(.glassProminent)
                        .accessibilityIdentifier("menuBar.refresh")
                    }
                }
            }
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
        case .requiresStableInstall:
            "Move prismBar into Applications"
        case .identityMismatch:
            "Install the current signed build"
        case .notRequested:
            "Allow Accessibility"
        case .denied:
            "Reconnect Accessibility"
        case .granted:
            "Ready when you are"
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
            "Review prismBar in Privacy & Security > Device Control and Data Access. " +
                "If it is already enabled, " +
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
        case .granted: "arrow.right.circle"
        }
    }

    private var permissionActionLabel: String {
        model.accessibilityState == .denied
            ? "Review Accessibility Access"
            : "Allow Accessibility Access"
    }

    private var menuBarLabel: String {
        switch model.menuBarState {
        case .waitingForPermission:
            "Waiting for permission"
        case .loading:
            "Checking"
        case .ready:
            if let snapshot = model.menuBarSnapshot, snapshot.unavailableSourceCount > 0 {
                "\(snapshot.items.count) found, \(snapshot.unavailableSourceCount) unavailable"
            } else {
                "\(model.menuBarSnapshot?.items.count ?? 0) found"
            }
        case .unavailable:
            "Refresh needed"
        }
    }

    private var pluginLabel: String {
        switch model.pluginState {
        case .idle, .loading:
            "Checking"
        case .ready:
            "prismCalc ready"
        case .unavailable:
            "prismCalc unavailable"
        case .paused:
            "prismCalc paused for safety"
        case .disabled:
            "prismCalc disabled"
        }
    }
}

private struct RecoveryStep: View {
    let number: Int
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 24, height: 24)
                .glassEffect(.regular.tint(.cyan.opacity(0.12)), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct LocalPromise: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.callout.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }
}

private struct StatusTile: View {
    let title: String
    let value: String
    let symbol: String
    let isReady: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(isReady ? .green : .secondary)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 94, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
    }
}
