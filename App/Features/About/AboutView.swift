// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    eyebrow: "LaClair Technologies",
                    title: "prismBar",
                    message: "A clean-room, public-source menu bar organizer built exclusively for macOS 27."
                )

                GlassCard {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Build")
                                .font(.title2.bold())
                            Spacer()
                            Text(versionLabel)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        LabeledContent("License", value: "Mozilla Public License 2.0")
                        LabeledContent("Platform", value: "macOS 27 on Apple silicon")
                        LabeledContent("Architecture", value: "Native Swift 6.4 and SwiftUI")
                        LabeledContent("Distribution", value: "Developer ID")
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    GlassCard {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Public source")
                                    .font(.headline)
                                Text("Every MPL-covered release maps to its public source revision.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.title2)
                                .foregroundStyle(.tint)
                        }
                    }

                    GlassCard {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Independent work")
                                    .font(.headline)
                                Text("Authored under a documented clean-room policy.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "checkmark.seal")
                                .font(.title2)
                                .foregroundStyle(.tint)
                        }
                    }
                }

                Text("Copyright 2026 Patrick LaClair and LaClair Technologies")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(32)
        }
    }

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (\(build))"
    }
}
