// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismPluginKit
import Testing

@Suite("Plugin manifest validation")
struct PluginManifestTests {
    @Test("accepts a bundled plugin with bounded capabilities")
    func acceptsBoundedManifest() throws {
        let manifest = PluginManifest(
            identifier: "com.laclairtech.prismbar.plugin.prismcalc",
            displayName: "prismCalc",
            version: .init(major: 1, minor: 0, patch: 0),
            protocolVersion: .current,
            capabilities: [.panel, .commands, .openApplication]
        )

        let validated = try manifest.validated(
            supportedProtocol: .current,
            allowedIdentifier: "com.laclairtech.prismbar.plugin.prismcalc",
            allowedCapabilities: [.panel, .commands, .openApplication]
        )

        #expect(validated == manifest)
    }

    @Test("rejects a protocol version the host does not implement")
    func rejectsUnsupportedProtocol() {
        let manifest = PluginManifest(
            identifier: "com.laclairtech.prismbar.plugin.prismcalc",
            displayName: "prismCalc",
            version: .init(major: 1, minor: 0, patch: 0),
            protocolVersion: .init(major: 2, minor: 0),
            capabilities: [.panel]
        )

        #expect(throws: PluginValidationError.unsupportedProtocol(.init(major: 2, minor: 0))) {
            try manifest.validated(
                supportedProtocol: .current,
                allowedIdentifier: manifest.identifier,
                allowedCapabilities: [.panel]
            )
        }
    }

    @Test("rejects an undeclared host capability")
    func rejectsUnapprovedCapability() {
        let manifest = PluginManifest(
            identifier: "com.laclairtech.prismbar.plugin.prismcalc",
            displayName: "prismCalc",
            version: .init(major: 1, minor: 0, patch: 0),
            protocolVersion: .current,
            capabilities: [.panel, .openApplication]
        )

        #expect(throws: PluginValidationError.disallowedCapabilities([.openApplication])) {
            try manifest.validated(
                supportedProtocol: .current,
                allowedIdentifier: manifest.identifier,
                allowedCapabilities: [.panel]
            )
        }
    }
}
