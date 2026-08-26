// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

public struct SemanticVersion: Equatable, Hashable, Codable, Sendable {
    public let major: UInt16
    public let minor: UInt16
    public let patch: UInt16

    public init(major: UInt16, minor: UInt16, patch: UInt16) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
}

public struct PluginProtocolVersion: Equatable, Hashable, Codable, Sendable {
    public static let current = Self(major: 1, minor: 0)

    public let major: UInt16
    public let minor: UInt16

    public init(major: UInt16, minor: UInt16) {
        self.major = major
        self.minor = minor
    }
}

public enum PluginCapability: String, CaseIterable, Codable, Sendable {
    case panel
    case commands
    case openApplication
}

public struct PluginManifest: Equatable, Codable, Sendable {
    public let identifier: String
    public let displayName: String
    public let version: SemanticVersion
    public let protocolVersion: PluginProtocolVersion
    public let capabilities: [PluginCapability]

    public init(
        identifier: String,
        displayName: String,
        version: SemanticVersion,
        protocolVersion: PluginProtocolVersion,
        capabilities: [PluginCapability]
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.version = version
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
    }

    public func validated(
        supportedProtocol: PluginProtocolVersion,
        allowedIdentifier: String,
        allowedCapabilities: Set<PluginCapability>
    ) throws -> Self {
        guard identifier == allowedIdentifier else {
            throw PluginValidationError.unexpectedIdentifier(identifier)
        }
        guard protocolVersion.major == supportedProtocol.major,
              protocolVersion.minor <= supportedProtocol.minor
        else {
            throw PluginValidationError.unsupportedProtocol(protocolVersion)
        }

        let disallowed = capabilities.filter { !allowedCapabilities.contains($0) }
        guard disallowed.isEmpty else {
            throw PluginValidationError.disallowedCapabilities(disallowed)
        }

        return self
    }
}

public enum PluginValidationError: Error, Equatable, Sendable {
    case unexpectedIdentifier(String)
    case unsupportedProtocol(PluginProtocolVersion)
    case disallowedCapabilities([PluginCapability])
}
