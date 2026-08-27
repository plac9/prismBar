// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import SwiftUI

struct SettingsRootView: View {
    var body: some View {
        ZStack {
            PrismCanvasBackground()

            TabView {
                Tab("General", systemImage: "gearshape") {
                    GeneralSettingsView()
                }

                Tab("Privacy", systemImage: "hand.raised") {
                    PrivacySettingsView()
                }
            }
            .padding(.top, 8)
        }
    }
}

private struct GeneralSettingsView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Label(accessibilityTitle, systemImage: accessibilitySymbol)
                        .foregroundStyle(accessibilityColor)
                } label: {
                    Text("Accessibility")
                }

                Text(accessibilitySummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    if needsPermissionRequest {
                        Button(permissionActionLabel) {
                            model.requestAccessibility()
                        }
                        .buttonStyle(.glassProminent)
                    }

                    Button("Check Again", systemImage: "arrow.clockwise") {
                        model.refreshAccessibility()
                    }
                    .buttonStyle(.glass)

                    Spacer()

                    Button("Open Workspace", systemImage: "rectangle.on.rectangle") {
                        openWindow(id: PrismSceneID.workspace)
                    }
                    .buttonStyle(.glass)
                }
            } header: {
                Text("System access")
            } footer: {
                Text("prismBar checks the current signed app each time. Permission state is never cached as truth.")
            }

            Section("Not requested") {
                LabeledContent("Screen Recording", value: "Never")
                LabeledContent("Input Monitoring", value: "Never")
                LabeledContent("Files and Folders", value: "Never")
                LabeledContent("Network Access", value: "Never")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    private var needsPermissionRequest: Bool {
        model.accessibilityState == .notRequested || model.accessibilityState == .denied
    }

    private var accessibilityTitle: String {
        switch model.accessibilityState {
        case .granted: "Ready"
        case .requiresStableInstall: "Install required"
        case .identityMismatch: "Identity mismatch"
        case .notRequested: "Not requested"
        case .denied: "Access required"
        }
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
        model.accessibilityState == .granted ? .primary : .orange
    }

    private var accessibilitySummary: String {
        switch model.accessibilityState {
        case .granted:
            "prismBar can observe and move menu bar items only when you ask."
        case .requiresStableInstall:
            "Install this signed build in Applications before granting access."
        case .identityMismatch:
            "The running build does not match prismBar's signed identity."
        case .notRequested:
            "macOS will show its standard consent prompt when you allow access."
        case .denied:
            "If prismBar is already enabled, remove it, add /Applications/prismBar.app again, then check again."
        }
    }

    private var permissionActionLabel: String {
        model.accessibilityState == .denied ? "Review Access" : "Allow Access"
    }
}

private struct PrivacySettingsView: View {
    var body: some View {
        Form {
            Section {
                Text(PrivacyCopy.observation)
                    .fixedSize(horizontal: false, vertical: true)
                Text(PrivacyCopy.boundary)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Private by construction")
            }

            Section("Data boundary") {
                PrivacySetting(label: "Screen capture and OCR", value: "Never", symbol: "eye.slash")
                PrivacySetting(label: "Analytics and telemetry", value: "None", symbol: "waveform.path")
                PrivacySetting(label: "Network requests", value: "None", symbol: "network.slash")
                PrivacySetting(label: "Tool permissions", value: "Sandboxed", symbol: "shippingbox")
                PrivacySetting(label: "Observed menu labels", value: "Memory only", symbol: "memorychip")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
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
