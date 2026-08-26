// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import prismPluginKit

final class PluginService: NSObject, PluginXPCServiceProtocol {
    private let codec = PluginWireCodec()
    private let manifest = PluginManifest(
        identifier: "com.laclairtech.prismbar.plugin.prismcalc",
        displayName: "prismCalc",
        version: .init(major: 0, minor: 1, patch: 0),
        protocolVersion: .current,
        capabilities: [.panel, .commands, .openApplication]
    )

    func process(
        _ request: Data,
        withReply reply: @escaping (Data?, NSError?) -> Void
    ) {
        do {
            let request = try codec.decode(PluginRequest.self, from: request)
            switch request {
            case let .handshake(handshake):
                _ = try manifest.validated(
                    supportedProtocol: handshake.hostProtocol,
                    allowedIdentifier: manifest.identifier,
                    allowedCapabilities: Set(handshake.requestedCapabilities)
                )
                try reply(codec.encode(PluginResponse.manifest(manifest)), nil)
            }
        } catch {
            reply(nil, NSError(
                domain: "com.laclairtech.prismbar.plugin",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The plugin request was rejected."]
            ))
        }
    }
}
