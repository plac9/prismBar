// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public enum OperationDeadlineError: Error, Equatable, Sendable {
    case expired
}

public struct OperationDeadline: Sendable {
    public let expiresAt: ContinuousClock.Instant

    public init(expiresAt: ContinuousClock.Instant) {
        self.expiresAt = expiresAt
    }

    public init(
        timeout: Duration,
        now: ContinuousClock.Instant = ContinuousClock().now
    ) {
        expiresAt = now.advanced(by: max(.zero, timeout))
    }

    public func remaining(
        at now: ContinuousClock.Instant = ContinuousClock().now
    ) -> Duration {
        max(.zero, now.duration(to: expiresAt))
    }

    public func check(
        at now: ContinuousClock.Instant = ContinuousClock().now
    ) throws {
        guard now < expiresAt else {
            throw OperationDeadlineError.expired
        }
    }

    public func accessibilityTimeout(
        at now: ContinuousClock.Instant = ContinuousClock().now,
        maximum: Duration
    ) throws -> Float {
        try check(at: now)
        let bounded = min(remaining(at: now), max(.zero, maximum))
        let components = bounded.components
        let seconds = Double(components.seconds) +
            Double(components.attoseconds) / 1_000_000_000_000_000_000
        return Float(max(0.001, seconds))
    }
}
