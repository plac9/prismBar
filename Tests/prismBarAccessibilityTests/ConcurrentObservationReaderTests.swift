// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarAccessibility
import prismBarCore
import Testing

@Suite("Concurrent menu bar observation")
struct ConcurrentObservationReaderTests {
    @Test("limits concurrent source reads to the configured capacity")
    func limitsConcurrentSourceReads() async throws {
        let sourceReader = ConcurrencyProbeSourceReader(delay: .milliseconds(20))
        let reader = ConcurrentMenuBarObservationReader(
            sourceReader: sourceReader,
            maximumConcurrentSources: 3
        )

        let batch = try await reader.observations(
            for: applicationFixtures(count: 6),
            deadline: OperationDeadline(timeout: .seconds(1))
        )

        #expect(batch.observations.count == 6)
        #expect(batch.unavailableSourceCount == 0)
        #expect(await sourceReader.peakConcurrentReads == 3)
    }

    @Test("preserves catalog order when sources finish out of order")
    func preservesCatalogOrder() async throws {
        let reader = ConcurrentMenuBarObservationReader(
            sourceReader: ReorderedSourceReader(),
            maximumConcurrentSources: 6
        )

        let batch = try await reader.observations(
            for: applicationFixtures(count: 6),
            deadline: OperationDeadline(timeout: .seconds(1))
        )

        #expect(batch.observations.map(\.stableToken) == [
            "fixture-1",
            "fixture-2",
            "fixture-3",
            "fixture-4",
            "fixture-5",
            "fixture-6",
        ])
    }

    @Test("counts unavailable sources without discarding healthy observations")
    func countsUnavailableSources() async throws {
        let reader = ConcurrentMenuBarObservationReader(
            sourceReader: PartiallyUnavailableSourceReader(),
            maximumConcurrentSources: 3
        )

        let batch = try await reader.observations(
            for: applicationFixtures(count: 6),
            deadline: OperationDeadline(timeout: .seconds(1))
        )

        #expect(batch.observations.map(\.stableToken) == [
            "fixture-1",
            "fixture-3",
            "fixture-5",
        ])
        #expect(batch.unavailableSourceCount == 3)
    }

    @Test("propagates live authorization revocation")
    func propagatesAuthorizationRevocation() async {
        let reader = ConcurrentMenuBarObservationReader(
            sourceReader: AuthorizationRevokedSourceReader(),
            maximumConcurrentSources: 2
        )

        await #expect(throws: MenuBarAuthorizationError.permissionRevoked) {
            try await reader.observations(
                for: applicationFixtures(count: 2),
                deadline: OperationDeadline(timeout: .seconds(1))
            )
        }
    }

    @Test("propagates operation deadline expiration")
    func propagatesDeadlineExpiration() async {
        let reader = ConcurrentMenuBarObservationReader(
            sourceReader: DeadlineExpiredSourceReader(),
            maximumConcurrentSources: 2
        )

        await #expect(throws: OperationDeadlineError.expired) {
            try await reader.observations(
                for: applicationFixtures(count: 2),
                deadline: OperationDeadline(timeout: .seconds(1))
            )
        }
    }

    @Test("bounds observations and counts only sources whose output is truncated")
    func boundsTotalObservations() async throws {
        let reader = ConcurrentMenuBarObservationReader(
            sourceReader: ObservationLimitSourceReader(),
            maximumConcurrentSources: 3,
            maximumTotalObservations: 3
        )

        let batch = try await reader.observations(
            for: applicationFixtures(count: 3),
            deadline: OperationDeadline(timeout: .seconds(1))
        )

        #expect(batch.observations.map(\.stableToken) == [
            "fixture-1-a",
            "fixture-1-b",
            "fixture-2-a",
        ])
        #expect(batch.unavailableSourceCount == 1)
    }
}

private actor ConcurrencyProbeSourceReader: MenuBarApplicationObservationReading {
    private let delay: Duration
    private var activeReads = 0
    private(set) var peakConcurrentReads = 0

    init(delay: Duration) {
        self.delay = delay
    }

    func observations(
        for application: RunningApplicationDescriptor,
        deadline _: OperationDeadline
    ) async throws -> [MenuBarObservation] {
        activeReads += 1
        peakConcurrentReads = max(peakConcurrentReads, activeReads)
        defer { activeReads -= 1 }
        try await Task.sleep(for: delay)

        return [
            MenuBarObservation(
                owner: application,
                stableToken: "fixture-\(application.processIdentifier)",
                displayName: "Fixture",
                frame: MenuBarItemFrame(
                    minX: Double(application.processIdentifier),
                    minY: 0,
                    width: 20,
                    height: 20
                ),
                isEnabled: true
            ),
        ]
    }
}

private struct ReorderedSourceReader: MenuBarApplicationObservationReading {
    func observations(
        for application: RunningApplicationDescriptor,
        deadline _: OperationDeadline
    ) async throws -> [MenuBarObservation] {
        let delay = Duration.milliseconds(Int64(7 - application.processIdentifier) * 10)
        try await Task.sleep(for: delay)
        return [observation(for: application)]
    }
}

private struct PartiallyUnavailableSourceReader: MenuBarApplicationObservationReading {
    func observations(
        for application: RunningApplicationDescriptor,
        deadline _: OperationDeadline
    ) async throws -> [MenuBarObservation] {
        guard application.processIdentifier.isMultiple(of: 2) == false else {
            throw SourceFixtureError.unavailable
        }
        return [observation(for: application)]
    }
}

private struct AuthorizationRevokedSourceReader: MenuBarApplicationObservationReading {
    func observations(
        for _: RunningApplicationDescriptor,
        deadline _: OperationDeadline
    ) async throws -> [MenuBarObservation] {
        throw MenuBarAuthorizationError.permissionRevoked
    }
}

private struct DeadlineExpiredSourceReader: MenuBarApplicationObservationReading {
    func observations(
        for _: RunningApplicationDescriptor,
        deadline _: OperationDeadline
    ) async throws -> [MenuBarObservation] {
        throw OperationDeadlineError.expired
    }
}

private struct ObservationLimitSourceReader: MenuBarApplicationObservationReading {
    func observations(
        for application: RunningApplicationDescriptor,
        deadline _: OperationDeadline
    ) async throws -> [MenuBarObservation] {
        guard application.processIdentifier < 3 else {
            return []
        }
        return ["a", "b"].map { suffix in
            MenuBarObservation(
                owner: application,
                stableToken: "fixture-\(application.processIdentifier)-\(suffix)",
                displayName: "Fixture",
                frame: nil,
                isEnabled: true
            )
        }
    }
}

private enum SourceFixtureError: Error {
    case unavailable
}

private func observation(
    for application: RunningApplicationDescriptor
) -> MenuBarObservation {
    MenuBarObservation(
        owner: application,
        stableToken: "fixture-\(application.processIdentifier)",
        displayName: "Fixture",
        frame: MenuBarItemFrame(
            minX: Double(application.processIdentifier),
            minY: 0,
            width: 20,
            height: 20
        ),
        isEnabled: true
    )
}

private func applicationFixtures(count: Int) -> [RunningApplicationDescriptor] {
    (1...count).map { index in
        RunningApplicationDescriptor(
            processIdentifier: Int32(index),
            bundleIdentifier: "com.example.fixture\(index)",
            displayName: "Fixture \(index)",
            isSelf: false
        )
    }
}
