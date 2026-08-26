// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import prismCalcPlugin
import prismPluginKit

final class PluginService: NSObject, PluginXPCServiceProtocol {
    private let codec = PluginWireCodec()
    private let sessionLock = NSLock()
    private var session = PrismCalcPluginSession()

    func process(
        _ request: Data,
        withReply reply: @escaping (Data?, NSError?) -> Void
    ) {
        do {
            let request = try codec.decode(PluginRequest.self, from: request)
            let response = try sessionLock.withLock {
                try session.process(request)
            }
            reply(try codec.encode(response), nil)
        } catch {
            reply(nil, NSError(
                domain: "com.laclairtech.prismbar.plugin",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The plugin request was rejected."]
            ))
        }
    }
}
