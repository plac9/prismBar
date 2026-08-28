// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @State private var isShowingLegalDocuments = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    symbol: "info.circle",
                    eyebrow: "LaClair Technologies",
                    title: "prismBar",
                    message: "A clean-room, public-source menu bar organizer built exclusively for macOS 27.",
                    identifier: "about.header.info.circle"
                )

                PrismContentSection {
                    VStack(alignment: .leading, spacing: 18) {
                        Label("Build", systemImage: "hammer")
                            .font(.headline)

                        Divider()

                        LabeledContent("Version", value: versionLabel)
                        LabeledContent("License", value: "Mozilla Public License 2.0")
                        LabeledContent("Platform", value: "macOS 27 on Apple silicon")
                        LabeledContent("Architecture", value: "Native Swift 6.4 and SwiftUI")
                        LabeledContent("Distribution", value: "Developer ID")
                        LabeledContent("Source revision", value: sourceRevisionLabel)
                    }
                }

                PrismContentSection(tint: .blue) {
                    VStack(alignment: .leading, spacing: 16) {
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

                        HStack {
                            Button("View Source", systemImage: "safari") {
                                openURL(ProductIdentity.sourceURL(for: sourceRevision))
                            }
                            .accessibilityIdentifier("about.source")

                            Button("View License", systemImage: "doc.text") {
                                isShowingLegalDocuments = true
                            }
                            .accessibilityIdentifier("about.license")
                        }
                        .buttonStyle(.glass)

                        Divider()

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
        .sheet(isPresented: $isShowingLegalDocuments) {
            LegalDocumentsView()
        }
    }

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (\(build))"
    }

    private var sourceRevision: String {
        Bundle.main.object(forInfoDictionaryKey: "PrismSourceRevision")
            as? String ?? "local-development"
    }

    private var sourceRevisionLabel: String {
        guard sourceRevision.count == 40 else {
            return "Local development"
        }
        return String(sourceRevision.prefix(12))
    }
}

private struct LegalDocumentsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Legal")
                    .font(.title2.bold())
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("legal.done")
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    legalSection(
                        title: "Mozilla Public License 2.0",
                        resource: "LICENSE"
                    )
                    legalSection(
                        title: "prismBar legal notices",
                        resource: "NOTICE"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 600)
    }

    private func legalSection(title: String, resource: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(bundledText(named: resource))
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func bundledText(named resource: String) -> String {
        guard let url = Bundle.main.url(forResource: resource, withExtension: nil),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return "The bundled legal document could not be read."
        }
        return text
    }
}
