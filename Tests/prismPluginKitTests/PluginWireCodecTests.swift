// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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

    @Test("round trips a bounded panel request")
    func panelRequestRoundTrip() throws {
        let request = PluginRequest.invoke(.init(commandIdentifier: "calculator.digit.7"))

        let data = try PluginWireCodec().encode(request)
        let decoded = try PluginWireCodec().decode(PluginRequest.self, from: data)

        #expect(decoded == request)
    }

    @Test("rejects unknown wire cases")
    func rejectsUnknownWireCases() {
        let unknownRequest = Data(#"{"unknown":{"_0":{}}}"#.utf8)

        #expect(throws: (any Error).self) {
            try PluginWireCodec().decode(PluginRequest.self, from: unknownRequest)
        }
    }

    @Test("rejects an encoded message over the wire limit")
    func rejectsOversizedEncodedMessage() {
        let update = PluginPanelUpdate(
            panel: .init(
                identifier: "oversized.panel",
                title: "Oversized",
                elements: (0 ..< 300).map { index in
                    .result(.init(
                        identifier: "result.\(index)",
                        value: String(repeating: "9", count: 256),
                        accessibilityLabel: "Result"
                    ))
                }
            ),
            mutations: []
        )

        #expect(throws: (any Error).self) {
            try PluginWireCodec().encode(PluginResponse.panel(update))
        }
    }

    @Test("handles a deterministic hostile byte corpus without trapping")
    func hostileByteCorpus() throws {
        var generator = DeterministicByteGenerator(seed: 0x5052_4953_4D42_4152)
        let codec = PluginWireCodec()

        for sample in 0 ..< 2_048 {
            let length = Int(generator.next() % 2_049)
            let data = Data((0 ..< length).map { _ in generator.nextByte() })

            do {
                let request = try codec.decode(PluginRequest.self, from: data)
                #expect(try codec.encode(request).count <= PluginWireCodec.maximumMessageBytes)
            } catch {
                #expect(data.count <= PluginWireCodec.maximumMessageBytes)
            }

            if sample.isMultiple(of: 128) {
                let oversized = Data(
                    repeating: generator.nextByte(),
                    count: PluginWireCodec.maximumMessageBytes + 1
                )
                #expect(throws: PluginWireError.messageTooLarge(oversized.count)) {
                    try codec.decode(PluginRequest.self, from: oversized)
                }
            }
        }
    }
}

private struct DeterministicByteGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }

    mutating func nextByte() -> UInt8 {
        UInt8(truncatingIfNeeded: next() >> 24)
    }
}
