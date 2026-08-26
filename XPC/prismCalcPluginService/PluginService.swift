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
        _ requestData: Data,
        withReply reply: @escaping (Data?, NSError?) -> Void
    ) {
        let request: PluginRequest
        do {
            request = try codec.decode(PluginRequest.self, from: requestData)
        } catch {
            reply(nil, PluginServiceFailure.invalidRequest.error)
            return
        }

        let response: PluginResponse
        do {
            response = try sessionLock.withLock {
                try session.process(request)
            }
        } catch {
            reply(nil, PluginServiceFailure.requestRejected.error)
            return
        }

        do {
            reply(try codec.encode(response), nil)
        } catch {
            reply(nil, PluginServiceFailure.invalidResponse.error)
        }
    }
}
