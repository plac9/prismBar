// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public enum BundledPluginPolicyError: Error, Equatable, Sendable {
    case invalidIdentifier
    case invalidTeamIdentifier
    case capabilityMismatch
    case versionMismatch
    case unexpectedResponse
}

public struct BundledPluginPolicy: Equatable, Sendable {
    public let pluginIdentifier: String
    public let teamIdentifier: String
    public let expectedPluginVersion: SemanticVersion
    public let allowedCapabilities: Set<PluginCapability>
    public let allowedApplicationIdentifiers: Set<String>

    public init(
        pluginIdentifier: String,
        teamIdentifier: String,
        expectedPluginVersion: SemanticVersion,
        allowedCapabilities: Set<PluginCapability>,
        allowedApplicationIdentifiers: Set<String>
    ) throws {
        guard Self.isSafeBundleIdentifier(pluginIdentifier),
              allowedApplicationIdentifiers.allSatisfy(Self.isSafeBundleIdentifier)
        else {
            throw BundledPluginPolicyError.invalidIdentifier
        }
        guard teamIdentifier.utf8.count == 10,
              teamIdentifier.utf8.allSatisfy(Self.isASCIITeamIdentifierByte)
        else {
            throw BundledPluginPolicyError.invalidTeamIdentifier
        }

        self.pluginIdentifier = pluginIdentifier
        self.teamIdentifier = teamIdentifier
        self.expectedPluginVersion = expectedPluginVersion
        self.allowedCapabilities = allowedCapabilities
        self.allowedApplicationIdentifiers = allowedApplicationIdentifiers
    }

    public var codeSigningRequirement: String {
        #"identifier "\#(pluginIdentifier)" and anchor apple generic and "# +
            #"certificate leaf[subject.OU] = "\#(teamIdentifier)""#
    }

    public func validateManifest(_ manifest: PluginManifest) throws -> PluginManifest {
        _ = try manifest.validated(
            supportedProtocol: .current,
            allowedIdentifier: pluginIdentifier,
            allowedCapabilities: allowedCapabilities
        )
        guard Set(manifest.capabilities) == allowedCapabilities else {
            throw BundledPluginPolicyError.capabilityMismatch
        }
        guard manifest.version == expectedPluginVersion else {
            throw BundledPluginPolicyError.versionMismatch
        }
        return manifest
    }

    public func validatePanelResponse(_ response: PluginResponse) throws -> PluginPanelUpdate {
        guard case let .panel(update) = response else {
            throw BundledPluginPolicyError.unexpectedResponse
        }
        return try update.validated(
            allowedApplicationIdentifiers: allowedApplicationIdentifiers
        )
    }

    static func isSafeBundleIdentifier(_ identifier: String) -> Bool {
        guard !identifier.isEmpty,
              identifier.utf8.count <= PluginPanelLimits.maximumIdentifierCharacters
        else {
            return false
        }

        let segments = identifier.utf8.split(separator: 0x2E, omittingEmptySubsequences: false)
        return segments.count >= 2 && segments.allSatisfy { segment in
            guard let first = segment.first,
                  let last = segment.last,
                  isASCIIAlphanumeric(first),
                  isASCIIAlphanumeric(last)
            else {
                return false
            }
            return segment.allSatisfy { isASCIIAlphanumeric($0) || $0 == 0x2D }
        }
    }

    private static func isASCIITeamIdentifierByte(_ byte: UInt8) -> Bool {
        (0x30 ... 0x39).contains(byte) || (0x41 ... 0x5A).contains(byte)
    }

    private static func isASCIIAlphanumeric(_ byte: UInt8) -> Bool {
        (0x30 ... 0x39).contains(byte) ||
            (0x41 ... 0x5A).contains(byte) ||
            (0x61 ... 0x7A).contains(byte)
    }
}
