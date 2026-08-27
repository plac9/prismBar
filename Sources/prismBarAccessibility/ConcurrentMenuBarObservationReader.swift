// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore

protocol MenuBarApplicationObservationReading: Sendable {
    func observations(
        for application: RunningApplicationDescriptor,
        deadline: OperationDeadline
    ) async throws -> [MenuBarObservation]
}

struct ConcurrentMenuBarObservationReader<SourceReader: MenuBarApplicationObservationReading>:
    MenuBarObservationReading,
    Sendable {
    private static var defaultMaximumConcurrentSources: Int { 8 }
    private static var defaultMaximumTotalObservations: Int { 2_048 }

    private let sourceReader: SourceReader
    private let maximumConcurrentSources: Int
    private let maximumTotalObservations: Int

    init(
        sourceReader: SourceReader,
        maximumConcurrentSources: Int = Self.defaultMaximumConcurrentSources,
        maximumTotalObservations: Int = Self.defaultMaximumTotalObservations
    ) {
        self.sourceReader = sourceReader
        self.maximumConcurrentSources = max(1, maximumConcurrentSources)
        self.maximumTotalObservations = max(1, maximumTotalObservations)
    }

    func observations(
        for applications: [RunningApplicationDescriptor],
        deadline: OperationDeadline
    ) async throws -> MenuBarObservationBatch {
        try deadline.check()
        guard !applications.isEmpty else {
            return MenuBarObservationBatch(observations: [])
        }

        let sourceResults = try await readSources(
            applications,
            deadline: deadline
        )
        try deadline.check()

        var observations: [MenuBarObservation] = []
        var unavailableSourceCount = 0
        observations.reserveCapacity(min(applications.count, maximumTotalObservations))

        for result in sourceResults.sorted(by: { $0.index < $1.index }) {
            switch result.outcome {
            case let .available(sourceObservations):
                let remainingCapacity = maximumTotalObservations - observations.count
                guard remainingCapacity > 0 else {
                    if !sourceObservations.isEmpty {
                        unavailableSourceCount += 1
                    }
                    continue
                }
                observations.append(contentsOf: sourceObservations.prefix(remainingCapacity))
                if sourceObservations.count > remainingCapacity {
                    unavailableSourceCount += 1
                }
            case .unavailable:
                unavailableSourceCount += 1
            }
        }

        return MenuBarObservationBatch(
            observations: observations,
            unavailableSourceCount: unavailableSourceCount
        )
    }

    private func readSources(
        _ applications: [RunningApplicationDescriptor],
        deadline: OperationDeadline
    ) async throws -> [IndexedSourceResult] {
        let sourceReader = sourceReader
        let initialTaskCount = min(maximumConcurrentSources, applications.count)

        return try await withThrowingTaskGroup(
            of: IndexedSourceResult.self,
            returning: [IndexedSourceResult].self
        ) { group in
            var nextIndex = 0
            var results: [IndexedSourceResult] = []
            results.reserveCapacity(applications.count)

            func addTask(at index: Int) {
                let application = applications[index]
                group.addTask {
                    try deadline.check()
                    do {
                        let observations = try await sourceReader.observations(
                            for: application,
                            deadline: deadline
                        )
                        return IndexedSourceResult(
                            index: index,
                            outcome: .available(observations)
                        )
                    } catch MenuBarAuthorizationError.permissionRevoked {
                        throw MenuBarAuthorizationError.permissionRevoked
                    } catch is OperationDeadlineError {
                        throw OperationDeadlineError.expired
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        return IndexedSourceResult(index: index, outcome: .unavailable)
                    }
                }
            }

            while nextIndex < initialTaskCount {
                addTask(at: nextIndex)
                nextIndex += 1
            }

            while let result = try await group.next() {
                results.append(result)
                if nextIndex < applications.count {
                    addTask(at: nextIndex)
                    nextIndex += 1
                }
            }

            return results
        }
    }
}

private struct IndexedSourceResult: Sendable {
    enum Outcome: Sendable {
        case available([MenuBarObservation])
        case unavailable
    }

    let index: Int
    let outcome: Outcome
}
