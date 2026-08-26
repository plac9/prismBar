// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct PluginHandshake: Equatable, Codable, Sendable {
    public let hostProtocol: PluginProtocolVersion
    public let requestedCapabilities: [PluginCapability]

    public init(
        hostProtocol: PluginProtocolVersion,
        requestedCapabilities: [PluginCapability]
    ) {
        self.hostProtocol = hostProtocol
        self.requestedCapabilities = requestedCapabilities
    }
}

public enum PluginRequest: Equatable, Codable, Sendable {
    case handshake(PluginHandshake)
    case panel
    case invoke(PluginCommandInvocation)
}

public enum PluginResponse: Equatable, Codable, Sendable {
    case manifest(PluginManifest)
    case panel(PluginPanelUpdate)
}

public enum PluginWireError: Error, Equatable, Sendable {
    case messageTooLarge(Int)
}

public struct PluginWireCodec: Sendable {
    public static let maximumMessageBytes = 64 * 1024

    public init() {}

    public func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        guard data.count <= Self.maximumMessageBytes else {
            throw PluginWireError.messageTooLarge(data.count)
        }
        return data
    }

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard data.count <= Self.maximumMessageBytes else {
            throw PluginWireError.messageTooLarge(data.count)
        }
        return try JSONDecoder().decode(type, from: data)
    }
}

@objc public protocol PluginXPCServiceProtocol: NSObjectProtocol {
    func process(
        _ request: Data,
        withReply reply: @escaping (Data?, NSError?) -> Void
    )
}
