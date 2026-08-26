// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore

public enum MenuBarDiscoveryError: Error, Equatable, Sendable {
    case notTrusted
    case communicationFailure
    case malformedAccessibilityValue
}

public protocol MenuBarObservationReading: Sendable {
    func observations(
        for applications: [RunningApplicationDescriptor]
    ) async throws -> MenuBarObservationBatch
}

public struct MenuBarObservationBatch: Equatable, Sendable {
    public let observations: [MenuBarObservation]
    public let unavailableSourceCount: Int

    public init(
        observations: [MenuBarObservation],
        unavailableSourceCount: Int = 0
    ) {
        self.observations = observations
        self.unavailableSourceCount = max(0, unavailableSourceCount)
    }
}

public actor MenuBarTopologyDiscovery<Reader: MenuBarObservationReading> {
    private let reader: Reader
    private let assembler: TopologyAssembler
    private var generation: UInt64 = 0

    public init(reader: Reader, assembler: TopologyAssembler = TopologyAssembler()) {
        self.reader = reader
        self.assembler = assembler
    }

    public func snapshot(
        applications: [RunningApplicationDescriptor]
    ) async throws -> MenuBarSnapshot {
        let batch = try await reader.observations(for: applications)
        generation &+= 1
        return assembler.assemble(
            generation: generation,
            observations: batch.observations,
            unavailableSourceCount: batch.unavailableSourceCount
        )
    }
}
