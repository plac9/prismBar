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
    case permissionRevoked
    case menuBarUnavailable
    case observationFailed
    case inputFailed
    case timedOut
}

public actor VerifiedMoveCoordinator<
    Reader: MenuBarSnapshotReading,
    Performer: MenuBarMovePerforming
> {
    private enum SnapshotReadResult: Sendable {
        case success(MenuBarSnapshot)
        case failure(MoveExecutionOutcome)
    }

    private let reader: Reader
    private let performer: Performer
    private let operationTimeout: Duration

    public init(
        reader: Reader,
        performer: Performer,
        operationTimeout: Duration = .seconds(8)
    ) {
        self.reader = reader
        self.performer = performer
        self.operationTimeout = operationTimeout
    }

    public func execute(_ plan: MovePlan) async -> MoveExecutionOutcome {
        let current: MenuBarSnapshot
        switch await readSnapshot() {
        case let .success(snapshot):
            current = snapshot
        case let .failure(outcome):
            return outcome
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
            if let failure = await performMove(
                plan: plan,
                sourceFrame: sourceFrame,
                destinationFrame: destinationFrame
            ) {
                return failure
            }
        }

        switch await readSnapshot() {
        case let .success(observed):
            return verificationOutcome(for: plan, observed: observed)
        case let .failure(outcome):
            return outcome
        }
    }

    private func readSnapshot() async -> SnapshotReadResult {
        await withTaskGroup(of: SnapshotReadResult.self) { group in
            group.addTask { [reader] in
                do {
                    return .success(try await reader.snapshot())
                } catch MenuBarAuthorizationError.permissionRevoked {
                    return .failure(.permissionRevoked)
                } catch is CancellationError {
                    return .failure(.timedOut)
                } catch {
                    return .failure(.observationFailed)
                }
            }
            group.addTask { [operationTimeout] in
                do {
                    try await Task.sleep(for: operationTimeout)
                    return .failure(.timedOut)
                } catch {
                    return .failure(.timedOut)
                }
            }

            let result = await group.next() ?? .failure(.observationFailed)
            group.cancelAll()
            return result
        }
    }

    private func performMove(
        plan: MovePlan,
        sourceFrame: MenuBarItemFrame,
        destinationFrame: MenuBarItemFrame
    ) async -> MoveExecutionOutcome? {
        let insertionEdge: MenuBarInsertionEdge =
            plan.sourceIndex < plan.destinationIndex ? .after : .before
        return await withTaskGroup(of: MoveExecutionOutcome?.self) { group in
            group.addTask { [performer] in
                do {
                    try await performer.move(
                        source: sourceFrame,
                        destination: destinationFrame,
                        insertionEdge: insertionEdge
                    )
                    return nil
                } catch MenuBarAuthorizationError.permissionRevoked {
                    return .permissionRevoked
                } catch MenuBarInputError.menuBarUnavailable {
                    return .menuBarUnavailable
                } catch is CancellationError {
                    return .timedOut
                } catch {
                    return .inputFailed
                }
            }
            group.addTask { [operationTimeout] in
                do {
                    try await Task.sleep(for: operationTimeout)
                    return .timedOut
                } catch {
                    return .timedOut
                }
            }

            let result = await group.next() ?? .inputFailed
            group.cancelAll()
            return result
        }
    }

    private func verificationOutcome(
        for plan: MovePlan,
        observed: MenuBarSnapshot
    ) -> MoveExecutionOutcome {
        if observed.items.map(\.id) == plan.expectedOrder {
            return .success
        }
        if let observedIndex = observed.items.firstIndex(where: { $0.id == plan.item }) {
            return .partial(observedIndex: observedIndex)
        }
        return .itemUnavailable
    }
}
