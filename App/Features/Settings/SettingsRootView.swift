// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct SettingsRootView: View {
    var body: some View {
        ZStack {
            PrismBackdrop()

            TabView {
                Tab("General", systemImage: "gearshape") {
                    GeneralSettingsView()
                }

                Tab("Privacy", systemImage: "hand.raised") {
                    PrivacySettingsView()
                }
            }
            .padding(12)
        }
    }
}

private struct GeneralSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsHeader(
                title: "System access",
                message: "One permission, checked against the current signed app every time."
            )

            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: accessibilitySymbol)
                            .font(.title2)
                            .foregroundStyle(accessibilityColor)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Accessibility")
                                .font(.headline)
                            Text(accessibilitySummary)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    HStack(spacing: 10) {
                        if needsPermissionRequest {
                            Button("Allow Access") {
                                model.requestAccessibility()
                            }
                            .buttonStyle(.glassProminent)
                        }

                        Button("Check Again", systemImage: "arrow.clockwise") {
                            model.refreshAccessibility()
                        }
                        .buttonStyle(.glass)

                        Spacer()

                        Button("Open Command Center", systemImage: "rectangle.on.rectangle") {
                            AppWindowController.shared.show()
                        }
                        .buttonStyle(.glass)
                    }
                }
            }

            Text("prismBar does not request Screen Recording, Input Monitoring, Files and Folders, or network access.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(24)
    }

    private var needsPermissionRequest: Bool {
        model.accessibilityState == .notRequested || model.accessibilityState == .denied
    }

    private var accessibilitySymbol: String {
        switch model.accessibilityState {
        case .granted: "checkmark.shield.fill"
        case .requiresStableInstall: "arrow.down.app"
        case .identityMismatch: "signature"
        case .notRequested, .denied: "exclamationmark.shield"
        }
    }

    private var accessibilityColor: Color {
        model.accessibilityState == .granted ? .green : .orange
    }

    private var accessibilitySummary: String {
        switch model.accessibilityState {
        case .granted:
            "Ready. prismBar can observe and move menu bar items when you ask."
        case .requiresStableInstall:
            "Install this signed build in Applications before granting access."
        case .identityMismatch:
            "The running build does not match prismBar's signed identity."
        case .notRequested:
            "Not requested. macOS will show its standard consent prompt."
        case .denied:
            "Not granted. Allow prismBar in System Settings, then check again."
        }
    }
}

private struct PrivacySettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsHeader(
                title: "Private by construction",
                message: "No capture pipeline, analytics SDK, telemetry client, or remote service."
            )

            GlassCard {
                VStack(spacing: 12) {
                    PrivacySetting(label: "Screen capture and OCR", value: "Never", symbol: "eye.slash")
                    Divider()
                    PrivacySetting(label: "Analytics and telemetry", value: "None", symbol: "waveform.path")
                    Divider()
                    PrivacySetting(label: "Network requests", value: "None", symbol: "network.slash")
                    Divider()
                    PrivacySetting(label: "Plugin permissions", value: "Sandboxed", symbol: "shippingbox")
                }
            }

            Text("Observed menu item labels remain in memory only and are never written to production logs.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(24)
    }
}

private struct SettingsHeader: View {
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            PrismMark(size: 38)
                .fixedSize()
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.bold())
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct PrivacySetting: View {
    let label: String
    let value: String
    let symbol: String

    var body: some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(.secondary)
        } label: {
            Label(label, systemImage: symbol)
        }
    }
}
