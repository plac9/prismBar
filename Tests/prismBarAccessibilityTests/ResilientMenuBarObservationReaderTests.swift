// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarAccessibility
import prismBarCore
import Testing

@Suite("Resilient menu bar observation")
struct ResilientMenuBarObservationReaderTests {
    @Test("keeps the highest-coverage fresh attempt when sources respond intermittently")
    func keepsHighestCoverageAttempt() async throws {
        let sparse = MenuBarObservationBatch(
            observations: [observation("one")],
            unavailableSourceCount: 5
        )
        let best = MenuBarObservationBatch(
            observations: [observation("one"), observation("two"), observation("three")],
            unavailableSourceCount: 3
        )
        let laterSparse = MenuBarObservationBatch(
            observations: [observation("one"), observation("two")],
            unavailableSourceCount: 4
        )
        let source = ObservationBatchSequenceReader(batches: [sparse, best, laterSparse])
        let reader = ResilientMenuBarObservationReader(source: source, attemptLimit: 3)

        let result = try await reader.observations(
            for: [application()],
            deadline: OperationDeadline(timeout: .seconds(1))
        )

        #expect(result == best)
        #expect(await source.readCount == 3)
    }

    @Test("returns immediately when every source responds")
    func returnsCompleteAttemptImmediately() async throws {
        let complete = MenuBarObservationBatch(observations: [observation("one")])
        let source = ObservationBatchSequenceReader(
            batches: [complete, MenuBarObservationBatch(observations: [])]
        )
        let reader = ResilientMenuBarObservationReader(source: source, attemptLimit: 3)

        let result = try await reader.observations(
            for: [application()],
            deadline: OperationDeadline(timeout: .seconds(1))
        )

        #expect(result == complete)
        #expect(await source.readCount == 1)
    }

    @Test("never hides live permission revocation behind an earlier partial attempt")
    func propagatesPermissionRevocation() async {
        let partial = MenuBarObservationBatch(
            observations: [observation("one")],
            unavailableSourceCount: 1
        )
        let source = ObservationBatchThenRevocationReader(batch: partial)
        let reader = ResilientMenuBarObservationReader(source: source, attemptLimit: 3)

        await #expect(throws: MenuBarAuthorizationError.permissionRevoked) {
            try await reader.observations(
                for: [application()],
                deadline: OperationDeadline(timeout: .seconds(1))
            )
        }
    }

    private func application() -> RunningApplicationDescriptor {
        RunningApplicationDescriptor(
            processIdentifier: 42,
            bundleIdentifier: "test.synthetic.application",
            displayName: "Synthetic",
            isSelf: false
        )
    }

    private func observation(_ token: String) -> MenuBarObservation {
        MenuBarObservation(
            owner: application(),
            stableToken: token,
            displayName: "Synthetic item",
            frame: MenuBarItemFrame(minX: 0, minY: 0, width: 24, height: 24),
            isEnabled: true
        )
    }
}

private actor ObservationBatchThenRevocationReader: MenuBarObservationReading {
    private let batch: MenuBarObservationBatch
    private var didRead = false

    init(batch: MenuBarObservationBatch) {
        self.batch = batch
    }

    func observations(
        for _: [RunningApplicationDescriptor],
        deadline _: OperationDeadline
    ) throws -> MenuBarObservationBatch {
        guard didRead else {
            didRead = true
            return batch
        }
        throw MenuBarAuthorizationError.permissionRevoked
    }
}

private actor ObservationBatchSequenceReader: MenuBarObservationReading {
    private var batches: [MenuBarObservationBatch]
    private(set) var readCount = 0

    init(batches: [MenuBarObservationBatch]) {
        self.batches = batches
    }

    func observations(
        for _: [RunningApplicationDescriptor],
        deadline _: OperationDeadline
    ) throws -> MenuBarObservationBatch {
        readCount += 1
        guard !batches.isEmpty else {
            throw MenuBarDiscoveryError.communicationFailure
        }
        return batches.removeFirst()
    }
}
