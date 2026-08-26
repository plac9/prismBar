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
            expectedPluginVersion: .init(major: 0, minor: 1, patch: 0),
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
                expectedPluginVersion: .init(major: 0, minor: 1, patch: 0),
                allowedCapabilities: [.panel],
                allowedApplicationIdentifiers: []
            )
        }
    }

    @Test("rejects malformed bundle and non-ASCII signing identifiers")
    func rejectsMalformedSigningIdentifiers() {
        for identifier in ["com..plugin", ".com.plugin", "com.plugin-", "com.plug_in"] {
            #expect(throws: BundledPluginPolicyError.invalidIdentifier) {
                try BundledPluginPolicy(
                    pluginIdentifier: identifier,
                    teamIdentifier: "N8A5T2PZY9",
                    expectedPluginVersion: .init(major: 0, minor: 1, patch: 0),
                    allowedCapabilities: [.panel],
                    allowedApplicationIdentifiers: []
                )
            }
        }

        #expect(throws: BundledPluginPolicyError.invalidTeamIdentifier) {
            try BundledPluginPolicy(
                pluginIdentifier: "com.laclairtech.plugin",
                teamIdentifier: "N8A5T2PZY９",
                expectedPluginVersion: .init(major: 0, minor: 1, patch: 0),
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

    @Test("rejects a signed bundled plugin with the wrong product version")
    func rejectsWrongPluginVersion() throws {
        let policy = try makePolicy()
        let manifest = PluginManifest(
            identifier: "com.laclairtech.prismbar.plugin.prismcalc",
            displayName: "prismCalc",
            version: .init(major: 0, minor: 2, patch: 0),
            protocolVersion: .current,
            capabilities: [.panel, .commands, .openApplication]
        )

        #expect(throws: BundledPluginPolicyError.versionMismatch) {
            try policy.validateManifest(manifest)
        }
    }

    private func makePolicy() throws -> BundledPluginPolicy {
        try BundledPluginPolicy(
            pluginIdentifier: "com.laclairtech.prismbar.plugin.prismcalc",
            teamIdentifier: "N8A5T2PZY9",
            expectedPluginVersion: .init(major: 0, minor: 1, patch: 0),
            allowedCapabilities: [.panel, .commands, .openApplication],
            allowedApplicationIdentifiers: ["com.laclairtech.prismcalc"]
        )
    }
}
