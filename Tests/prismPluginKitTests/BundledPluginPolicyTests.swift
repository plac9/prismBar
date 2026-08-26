// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@testable import prismPluginKit
import Testing

@Suite("Bundled plugin host policy")
struct BundledPluginPolicyTests {
    @Test("constructs an exact requirement for the bundled prismCalc service")
    func exactCodeRequirement() throws {
        let policy = try BundledPluginPolicy(
            pluginIdentifier: "com.laclairtech.prismbar.plugin.prismcalc",
            teamIdentifier: "N8A5T2PZY9",
            allowedCapabilities: [.panel, .commands, .openApplication],
            allowedApplicationIdentifiers: ["com.laclairtech.prismcalc"]
        )

        let expectedRequirement =
            #"identifier "com.laclairtech.prismbar.plugin.prismcalc" and "# +
            #"anchor apple generic and certificate leaf[subject.OU] = "N8A5T2PZY9""#
        #expect(policy.codeSigningRequirement == expectedRequirement)
    }

    @Test("rejects executable syntax in security identifiers")
    func rejectsUnsafeIdentifiers() {
        #expect(throws: BundledPluginPolicyError.invalidIdentifier) {
            try BundledPluginPolicy(
                pluginIdentifier: "com.laclairtech.plugin\" or true",
                teamIdentifier: "N8A5T2PZY9",
                allowedCapabilities: [.panel],
                allowedApplicationIdentifiers: []
            )
        }
    }

    @Test("accepts only the expected manifest and validated panel schema")
    func validatesResponses() throws {
        let policy = try makePolicy()
        let manifest = PluginManifest(
            identifier: "com.laclairtech.prismbar.plugin.prismcalc",
            displayName: "prismCalc",
            version: .init(major: 0, minor: 1, patch: 0),
            protocolVersion: .current,
            capabilities: [.panel, .commands, .openApplication]
        )

        #expect(try policy.validateManifest(manifest) == manifest)
        #expect(throws: BundledPluginPolicyError.unexpectedResponse) {
            try policy.validatePanelResponse(.manifest(manifest))
        }
    }

    private func makePolicy() throws -> BundledPluginPolicy {
        try BundledPluginPolicy(
            pluginIdentifier: "com.laclairtech.prismbar.plugin.prismcalc",
            teamIdentifier: "N8A5T2PZY9",
            allowedCapabilities: [.panel, .commands, .openApplication],
            allowedApplicationIdentifiers: ["com.laclairtech.prismcalc"]
        )
    }
}
