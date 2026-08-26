// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismPluginKit
import Testing

@Suite("Bundled plugin registry")
struct BundledPluginRegistryTests {
    @Test("registers prismCalc as a capability-bounded first plugin")
    func registersPrismCalc() throws {
        let registration = try makeRegistration()
        let registry = try BundledPluginRegistry(registrations: [registration])

        #expect(registry.registrations == [registration])
        #expect(registry.registration(identifier: registration.identifier) == registration)
        #expect(registration.preferenceKey ==
            "plugins.com.laclairtech.prismbar.plugin.prismcalc.enabled")

        let policy = try registration.makePolicy(teamIdentifier: "N8A5T2PZY9")
        #expect(policy.pluginIdentifier == registration.identifier)
        #expect(policy.expectedPluginVersion == registration.version)
        #expect(policy.allowedCapabilities == registration.capabilities)
        #expect(policy.allowedApplicationIdentifiers == registration.allowedApplicationIdentifiers)
    }

    @Test("rejects duplicate plugin identifiers")
    func rejectsDuplicateIdentifiers() throws {
        let registration = try makeRegistration()

        #expect(throws: BundledPluginRegistryError.duplicateIdentifier(registration.identifier)) {
            _ = try BundledPluginRegistry(registrations: [registration, registration])
        }
    }

    @Test("requires declarative panels and a bounded registry")
    func requiresPanelCapabilityAndBoundedCount() throws {
        #expect(throws: BundledPluginRegistrationError.missingPanelCapability) {
            _ = try makeRegistration(capabilities: [.commands])
        }

        let registrations = try (0 ... BundledPluginRegistry.maximumRegistrations).map { index in
            try makeRegistration(identifier: "com.laclairtech.prismbar.plugin.test\(index)")
        }
        #expect(throws: BundledPluginRegistryError.tooManyRegistrations) {
            _ = try BundledPluginRegistry(registrations: registrations)
        }
    }

    @Test("open application capability and allowlist must agree")
    func validatesOpenApplicationAllowlist() {
        #expect(throws: BundledPluginRegistrationError.missingApplicationAllowlist) {
            _ = try makeRegistration(
                capabilities: [.panel, .openApplication],
                allowedApplicationIdentifiers: []
            )
        }

        #expect(throws: BundledPluginRegistrationError.unexpectedApplicationAllowlist) {
            _ = try makeRegistration(
                capabilities: [.panel],
                allowedApplicationIdentifiers: ["com.laclairtech.prismcalc"]
            )
        }
    }

    @Test("rejects unsafe identity and display metadata")
    func rejectsUnsafeMetadata() {
        #expect(throws: BundledPluginRegistrationError.invalidIdentifier) {
            _ = try makeRegistration(identifier: "../plugin")
        }
        #expect(throws: BundledPluginRegistrationError.invalidDisplayName) {
            _ = try makeRegistration(displayName: "prismCalc\nspoofed")
        }
    }

    private func makeRegistration(
        identifier: String = "com.laclairtech.prismbar.plugin.prismcalc",
        displayName: String = "prismCalc",
        capabilities: Set<PluginCapability> = [.panel, .commands, .openApplication],
        allowedApplicationIdentifiers: Set<String> = ["com.laclairtech.prismcalc"]
    ) throws -> BundledPluginRegistration {
        try BundledPluginRegistration(
            identifier: identifier,
            displayName: displayName,
            version: .init(major: 0, minor: 1, patch: 0),
            capabilities: capabilities,
            allowedApplicationIdentifiers: allowedApplicationIdentifiers,
            isEnabledByDefault: true
        )
    }
}
