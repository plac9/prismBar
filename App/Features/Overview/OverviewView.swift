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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your menu bar, under control.")
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    Text(
                        "prismBar keeps menu bar organization local " +
                            "and makes every change verifiable and recoverable."
                    )
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                GroupBox("Current state") {
                    LabeledContent("Accessibility", value: accessibilityLabel)
                    LabeledContent("Menu items", value: "Waiting for permission")
                    LabeledContent("Plugins", value: "prismCalc available")

                    HStack {
                        if needsPermissionAction {
                            Button("Allow Accessibility Access") {
                                model.requestAccessibility()
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityLabel("Allow Accessibility Access")
                            .accessibilityIdentifier("accessibility.request")
                        }

                        Button("Check Again") {
                            model.refreshAccessibility()
                        }
                        .accessibilityLabel("Check Again")
                        .accessibilityIdentifier("accessibility.refresh")
                    }
                }

                GroupBox("Privacy") {
                    Label("No screen capture or OCR", systemImage: "eye.slash")
                    Label("No analytics or telemetry", systemImage: "chart.bar.xaxis")
                    Label("No menu content leaves this Mac", systemImage: "lock.shield")
                }
            }
            .frame(maxWidth: 700, alignment: .leading)
            .padding(32)
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
}
