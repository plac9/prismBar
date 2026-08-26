// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import prismPluginKit

@main
enum prismCalcPluginServiceMain {
    static func main() {
        let delegate = ServiceDelegate()
        let listener = NSXPCListener.service()
        listener.delegate = delegate
        listener.resume()
        RunLoop.current.run()
    }
}

private final class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    private let service = PluginService()

    func listener(
        _: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        let hostRequirement =
            #"identifier "com.laclairtech.prismbar" and anchor apple generic "# +
            #"and certificate leaf[subject.OU] = "N8A5T2PZY9""#
        connection.setCodeSigningRequirement(hostRequirement)
        connection.exportedInterface = NSXPCInterface(with: PluginXPCServiceProtocol.self)
        connection.exportedObject = service
        connection.activate()
        return true
    }
}
