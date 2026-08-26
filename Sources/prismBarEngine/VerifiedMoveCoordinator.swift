// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore

public protocol MenuBarSnapshotReading: Sendable {
    func snapshot() async throws -> MenuBarSnapshot
}

public enum VerifiedMoveError: Error, Equatable, Sendable {
    case observationFailed
    case inputFailed
}

public enum MoveExecutionOutcome: Equatable, Sendable {
    case success
    case partial(observedIndex: Int)
    case topologyChanged
    case itemUnavailable
    case observationFailed
    case inputFailed
}

public actor VerifiedMoveCoordinator<
    Reader: MenuBarSnapshotReading,
    Performer: MenuBarMovePerforming
> {
    private let reader: Reader
    private let performer: Performer

    public init(reader: Reader, performer: Performer) {
        self.reader = reader
        self.performer = performer
    }

    public func execute(_ plan: MovePlan) async -> MoveExecutionOutcome {
        let current: MenuBarSnapshot
        do {
            current = try await reader.snapshot()
        } catch {
            return .observationFailed
        }

        guard current.items.map(\.id) == plan.sourceOrder else {
            return .topologyChanged
        }
        guard let sourceItem = current.items.first(where: { $0.id == plan.item }),
              current.items.indices.contains(plan.destinationIndex),
              let sourceFrame = sourceItem.frame,
              let destinationFrame = current.items[plan.destinationIndex].frame
        else {
            return .itemUnavailable
        }

        if plan.sourceIndex != plan.destinationIndex {
            do {
                let insertionEdge: MenuBarInsertionEdge =
                    plan.sourceIndex < plan.destinationIndex ? .after : .before
                try await performer.move(
                    source: sourceFrame,
                    destination: destinationFrame,
                    insertionEdge: insertionEdge
                )
            } catch {
                return .inputFailed
            }
        }

        let observed: MenuBarSnapshot
        do {
            observed = try await reader.snapshot()
        } catch {
            return .observationFailed
        }

        if observed.items.map(\.id) == plan.expectedOrder {
            return .success
        }
        if let observedIndex = observed.items.firstIndex(where: { $0.id == plan.item }) {
            return .partial(observedIndex: observedIndex)
        }
        return .itemUnavailable
    }
}
