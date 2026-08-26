// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public enum BundledPluginPolicyError: Error, Equatable, Sendable {
    case invalidIdentifier
    case invalidTeamIdentifier
    case capabilityMismatch
    case unexpectedResponse
}

public struct BundledPluginPolicy: Equatable, Sendable {
    public let pluginIdentifier: String
    public let teamIdentifier: String
    public let allowedCapabilities: Set<PluginCapability>
    public let allowedApplicationIdentifiers: Set<String>

    public init(
        pluginIdentifier: String,
        teamIdentifier: String,
        allowedCapabilities: Set<PluginCapability>,
        allowedApplicationIdentifiers: Set<String>
    ) throws {
        guard Self.isSafeBundleIdentifier(pluginIdentifier),
              allowedApplicationIdentifiers.allSatisfy(Self.isSafeBundleIdentifier)
        else {
            throw BundledPluginPolicyError.invalidIdentifier
        }
        guard teamIdentifier.count == 10,
              teamIdentifier.unicodeScalars.allSatisfy({
                  CharacterSet.uppercaseLetters.union(.decimalDigits).contains($0)
              })
        else {
            throw BundledPluginPolicyError.invalidTeamIdentifier
        }

        self.pluginIdentifier = pluginIdentifier
        self.teamIdentifier = teamIdentifier
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

    private static func isSafeBundleIdentifier(_ identifier: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        return !identifier.isEmpty &&
            identifier.count <= PluginPanelLimits.maximumIdentifierCharacters &&
            identifier.contains(".") &&
            identifier.unicodeScalars.allSatisfy(allowed.contains)
    }
}
