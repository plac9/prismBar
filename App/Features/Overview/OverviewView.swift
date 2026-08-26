// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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

                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(actionTitle)
                                    .font(.title2.bold())
                                Text(actionMessage)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: actionSymbol)
                                .font(.system(size: 34, weight: .medium))
                                .foregroundStyle(.tint)
                                .accessibilityHidden(true)
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

                HStack(spacing: 18) {
                    Label("No screen capture", systemImage: "eye.slash")
                    Label("No telemetry", systemImage: "waveform.path.ecg.rectangle")
                    Label("No content uploads", systemImage: "lock.shield")
                }
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(32)
        }
        .task {
            model.loadPluginIfNeeded()
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
            "Review prismBar in Privacy & Security > Accessibility. If it is already enabled, " +
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
        case .disabled:
            model.isPluginEnabled ? "prismCalc paused" : "prismCalc disabled"
        }
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
