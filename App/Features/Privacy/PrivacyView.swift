// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    eyebrow: "Private by construction",
                    title: "Your menu bar stays on your Mac.",
                    message: "prismBar observes only the accessibility structure needed to organize items. " +
                        "It never captures, recognizes, uploads, or profiles what is on screen."
                )

                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("One permission, one purpose", systemImage: "checkmark.shield")
                            .font(.title2.bold())
                        Text(
                            "Accessibility is used only when you request menu bar discovery or movement. " +
                                "Permission state is rechecked live and is never stored as trusted truth."
                        )
                        .foregroundStyle(.secondary)

                        Divider()

                        PrivacyCapability(
                            title: "Screen capture and OCR",
                            value: "Never",
                            symbol: "eye.slash"
                        )
                        PrivacyCapability(
                            title: "Analytics and telemetry",
                            value: "None",
                            symbol: "waveform.path.ecg.rectangle"
                        )
                        PrivacyCapability(
                            title: "Network requests",
                            value: "None",
                            symbol: "network.slash"
                        )
                        PrivacyCapability(
                            title: "Menu item labels",
                            value: "Memory only",
                            symbol: "memorychip"
                        )
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    PrivacyPrinciple(
                        title: "No data exhaust",
                        message: "Production logs contain outcomes, never observed menu labels or screen content.",
                        symbol: "text.badge.xmark"
                    )
                    PrivacyPrinciple(
                        title: "Isolated plugins",
                        message: "Plugins run in sandboxed services without Accessibility, files, or network access.",
                        symbol: "shippingbox.and.arrow.backward"
                    )
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(32)
        }
    }
}

private struct PrivacyCapability: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(.secondary)
        } label: {
            Label(title, systemImage: symbol)
        }
    }
}

private struct PrivacyPrinciple: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
