// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismPluginKit

public enum PrismCalcPluginSessionError: Error, Equatable, Sendable {
    case handshakeRequired
    case handshakeAlreadyCompleted
}

public struct PrismCalcPluginSession: Sendable {
    public static let manifest = PluginManifest(
        identifier: "com.laclairtech.prismbar.plugin.prismcalc",
        displayName: "prismCalc",
        version: .init(major: 0, minor: 1, patch: 0),
        protocolVersion: .current,
        capabilities: [.panel, .commands, .openApplication]
    )

    private var controller = PrismCalcPluginController()
    private var isAuthenticated = false

    public init() {}

    public mutating func process(_ request: PluginRequest) throws -> PluginResponse {
        switch request {
        case let .handshake(handshake):
            guard !isAuthenticated else {
                throw PrismCalcPluginSessionError.handshakeAlreadyCompleted
            }
            _ = try Self.manifest.validated(
                supportedProtocol: handshake.hostProtocol,
                allowedIdentifier: Self.manifest.identifier,
                allowedCapabilities: Set(handshake.requestedCapabilities)
            )
            isAuthenticated = true
            return .manifest(Self.manifest)
        case .panel:
            try requireAuthentication()
            return .panel(try controller.panel())
        case let .invoke(invocation):
            try requireAuthentication()
            return .panel(try controller.invoke(invocation.commandIdentifier))
        }
    }

    private func requireAuthentication() throws {
        guard isAuthenticated else {
            throw PrismCalcPluginSessionError.handshakeRequired
        }
    }
}
