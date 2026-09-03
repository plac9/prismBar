// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    symbol: "hand.raised",
                    eyebrow: "Private by construction",
                    title: "Your menu bar stays on your Mac.",
                    message: PrivacyCopy.observation + " " + PrivacyCopy.boundary,
                    identifier: "privacy.header.hand.raised"
                )

                PrismContentSection {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("One permission, one purpose", systemImage: "checkmark.shield")
                            .prismFont(.headline)

                        Divider()

                        Text(
                            "Permission state is rechecked live and is never stored as trusted truth. " +
                                PrivacyCopy.observation
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

                PrismContentSection(tint: .blue) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Enforced boundaries")
                            .prismFont(.headline)
                        PrivacyPrinciple(
                            title: "No data exhaust",
                            message: "Production logs contain outcomes, never observed menu labels or screen content.",
                            symbol: "text.badge.xmark"
                        )
                        Divider()
                        PrivacyPrinciple(
                            title: "Minimal runtime",
                            message: "The core app has no plugin runtime, file access, or network access.",
                            symbol: "lock.shield"
                        )
                    }
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
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .prismFont(.headline)
                Text(message)
                    .prismFont(.callout)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
                .prismFont(.title2)
                .foregroundStyle(.tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
