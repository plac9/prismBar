// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarCore
import Foundation
import Testing

@Suite("Operation deadline")
struct OperationDeadlineTests {
    @Test("remaining budget clamps at zero")
    func remainingBudgetClampsAtZero() {
        let clock = ContinuousClock()
        let start = clock.now
        let deadline = OperationDeadline(
            expiresAt: start.advanced(by: .seconds(2))
        )

        #expect(deadline.remaining(at: start) == .seconds(2))
        #expect(
            deadline.remaining(at: start.advanced(by: .seconds(3))) == .zero
        )
    }

    @Test("expiry is determined by the supplied monotonic instant")
    func checksExpiryAtSuppliedInstant() throws {
        let clock = ContinuousClock()
        let start = clock.now
        let deadline = OperationDeadline(
            expiresAt: start.advanced(by: .milliseconds(80))
        )

        try deadline.check(at: start.advanced(by: .milliseconds(79)))
        #expect(throws: OperationDeadlineError.expired) {
            try deadline.check(at: start.advanced(by: .milliseconds(80)))
        }
    }

    @Test("Accessibility timeout never exceeds remaining budget or maximum slice")
    func boundsAccessibilityTimeout() throws {
        let clock = ContinuousClock()
        let start = clock.now
        let deadline = OperationDeadline(
            expiresAt: start.advanced(by: .milliseconds(80))
        )

        let remainingBound = try deadline.accessibilityTimeout(
            at: start,
            maximum: .milliseconds(250)
        )
        let sliceBound = try deadline.accessibilityTimeout(
            at: start,
            maximum: .milliseconds(25)
        )

        #expect(abs(remainingBound - 0.08) < 0.000_001)
        #expect(abs(sliceBound - 0.025) < 0.000_001)
        #expect(throws: OperationDeadlineError.expired) {
            try deadline.accessibilityTimeout(
                at: start.advanced(by: .milliseconds(80)),
                maximum: .milliseconds(250)
            )
        }
    }
}
