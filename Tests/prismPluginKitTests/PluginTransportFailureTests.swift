// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@testable import prismPluginKit
import Testing

@Suite("Plugin transport failure classification")
struct PluginTransportFailureTests {
    @Test("classifies the bounded Foundation XPC failures")
    func classifiesKnownFailures() {
        #expect(classify(code: 4_102) == .codeSigningRequirement)
        #expect(classify(code: 4_097) == .interrupted)
        #expect(classify(code: 4_099) == .invalidConnection)
        #expect(classify(code: 4_101) == .invalidReply)
    }

    @Test("does not preserve arbitrary error details")
    func sanitizesUnknownFailures() {
        let error = NSError(
            domain: "private.example",
            code: 27,
            userInfo: [NSLocalizedDescriptionKey: "sensitive value"]
        )

        #expect(PluginTransportFailure.classify(error) == .unknown)
        #expect(PluginServiceFailure.classify(error) == nil)
    }

    @Test("classifies only the bounded plugin service failures")
    func classifiesServiceFailures() {
        for failure in PluginServiceFailure.allCases {
            #expect(PluginServiceFailure.classify(failure.error) == failure)
        }

        #expect(PluginServiceFailure.classify(
            NSError(domain: PluginServiceFailure.errorDomain, code: 27)
        ) == nil)
    }

    private func classify(code: Int) -> PluginTransportFailure {
        PluginTransportFailure.classify(
            NSError(domain: NSCocoaErrorDomain, code: code)
        )
    }
}
