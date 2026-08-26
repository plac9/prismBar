import Foundation
@testable import prismPluginKit
import Testing

@Suite("Plugin wire codec")
struct PluginWireCodecTests {
    @Test("round trips a bounded handshake")
    func handshakeRoundTrip() throws {
        let request = PluginRequest.handshake(
            .init(hostProtocol: .current, requestedCapabilities: [.panel, .commands])
        )

        let data = try PluginWireCodec().encode(request)
        let decoded = try PluginWireCodec().decode(PluginRequest.self, from: data)

        #expect(decoded == request)
        #expect(data.count <= PluginWireCodec.maximumMessageBytes)
    }

    @Test("rejects a message over the wire limit before decoding")
    func rejectsOversizedMessage() {
        let oversized = Data(repeating: 0x41, count: PluginWireCodec.maximumMessageBytes + 1)

        #expect(throws: PluginWireError.messageTooLarge(oversized.count)) {
            try PluginWireCodec().decode(PluginRequest.self, from: oversized)
        }
    }
}
