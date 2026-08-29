// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore

public struct ResilientMenuBarObservationReader<Source: MenuBarObservationReading>:
    MenuBarObservationReading,
    Sendable {
    private let source: Source
    private let attemptLimit: Int

    public init(source: Source, attemptLimit: Int = 3) {
        self.source = source
        self.attemptLimit = max(1, attemptLimit)
    }

    public func observations(
        for applications: [RunningApplicationDescriptor],
        deadline: OperationDeadline
    ) async throws -> MenuBarObservationBatch {
        var bestBatch: MenuBarObservationBatch?
        var latestError: (any Error)?

        for _ in 0 ..< attemptLimit {
            do {
                try deadline.check()
                let batch = try await source.observations(
                    for: applications,
                    deadline: deadline
                )
                if isBetter(batch, than: bestBatch) {
                    bestBatch = batch
                }
                if batch.unavailableSourceCount == 0 {
                    return batch
                }
            } catch MenuBarAuthorizationError.permissionRevoked {
                throw MenuBarAuthorizationError.permissionRevoked
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                latestError = error
                if error is OperationDeadlineError {
                    break
                }
            }
        }

        if let bestBatch {
            return bestBatch
        }
        throw latestError ?? MenuBarDiscoveryError.communicationFailure
    }

    private func isBetter(
        _ candidate: MenuBarObservationBatch,
        than current: MenuBarObservationBatch?
    ) -> Bool {
        guard let current else { return true }
        if candidate.observations.count != current.observations.count {
            return candidate.observations.count > current.observations.count
        }
        return candidate.unavailableSourceCount < current.unavailableSourceCount
    }
}
