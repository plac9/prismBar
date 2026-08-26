// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public enum BundledPluginRegistrationError: Error, Equatable, Sendable {
    case invalidIdentifier
    case invalidDisplayName
    case missingPanelCapability
    case missingApplicationAllowlist
    case unexpectedApplicationAllowlist
}

public struct BundledPluginRegistration: Equatable, Sendable {
    public let identifier: String
    public let displayName: String
    public let version: SemanticVersion
    public let capabilities: Set<PluginCapability>
    public let allowedApplicationIdentifiers: Set<String>
    public let isEnabledByDefault: Bool

    public init(
        identifier: String,
        displayName: String,
        version: SemanticVersion,
        capabilities: Set<PluginCapability>,
        allowedApplicationIdentifiers: Set<String>,
        isEnabledByDefault: Bool
    ) throws {
        guard BundledPluginPolicy.isSafeBundleIdentifier(identifier) else {
            throw BundledPluginRegistrationError.invalidIdentifier
        }
        guard Self.isSafeDisplayName(displayName) else {
            throw BundledPluginRegistrationError.invalidDisplayName
        }
        guard capabilities.contains(.panel) else {
            throw BundledPluginRegistrationError.missingPanelCapability
        }

        if capabilities.contains(.openApplication) {
            guard !allowedApplicationIdentifiers.isEmpty else {
                throw BundledPluginRegistrationError.missingApplicationAllowlist
            }
        } else if !allowedApplicationIdentifiers.isEmpty {
            throw BundledPluginRegistrationError.unexpectedApplicationAllowlist
        }

        guard allowedApplicationIdentifiers.allSatisfy(BundledPluginPolicy.isSafeBundleIdentifier)
        else {
            throw BundledPluginRegistrationError.invalidIdentifier
        }

        self.identifier = identifier
        self.displayName = displayName
        self.version = version
        self.capabilities = capabilities
        self.allowedApplicationIdentifiers = allowedApplicationIdentifiers
        self.isEnabledByDefault = isEnabledByDefault
    }

    public var preferenceKey: String {
        "plugins.\(identifier).enabled"
    }

    public func makePolicy(teamIdentifier: String) throws -> BundledPluginPolicy {
        try BundledPluginPolicy(
            pluginIdentifier: identifier,
            teamIdentifier: teamIdentifier,
            expectedPluginVersion: version,
            allowedCapabilities: capabilities,
            allowedApplicationIdentifiers: allowedApplicationIdentifiers
        )
    }

    private static func isSafeDisplayName(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed == value,
              value.count <= PluginPanelLimits.maximumLabelCharacters
        else {
            return false
        }
        return value.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar)
        }
    }
}

public enum BundledPluginRegistryError: Error, Equatable, Sendable {
    case duplicateIdentifier(String)
    case tooManyRegistrations
}

public struct BundledPluginRegistry: Equatable, Sendable {
    public static let maximumRegistrations = 16

    public let registrations: [BundledPluginRegistration]

    public init(registrations: [BundledPluginRegistration]) throws {
        guard registrations.count <= Self.maximumRegistrations else {
            throw BundledPluginRegistryError.tooManyRegistrations
        }

        var identifiers: Set<String> = []
        for registration in registrations {
            guard identifiers.insert(registration.identifier).inserted else {
                throw BundledPluginRegistryError.duplicateIdentifier(registration.identifier)
            }
        }
        self.registrations = registrations
    }

    public func registration(identifier: String) -> BundledPluginRegistration? {
        registrations.first { $0.identifier == identifier }
    }
}
