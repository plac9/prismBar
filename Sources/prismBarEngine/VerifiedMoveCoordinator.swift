// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore

public protocol MenuBarSnapshotReading: Sendable {
    func snapshot(deadline: OperationDeadline) async throws -> MenuBarSnapshot
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

public struct VerifiedMoveResult: Equatable, Sendable {
    public let outcome: MoveExecutionOutcome
    public let verifiedSnapshot: MenuBarSnapshot?

    public init(
        outcome: MoveExecutionOutcome,
        verifiedSnapshot: MenuBarSnapshot? = nil
    ) {
        self.outcome = outcome
        self.verifiedSnapshot = verifiedSnapshot
    }
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
        await executeWithObservation(plan).outcome
    }

    public func executeWithObservation(_ plan: MovePlan) async -> VerifiedMoveResult {
        let deadline = OperationDeadline(timeout: operationTimeout)
        let current: MenuBarSnapshot
        switch await readSnapshot(deadline: deadline) {
        case let .success(snapshot):
            current = snapshot
        case let .failure(outcome):
            return VerifiedMoveResult(outcome: outcome)
        }

        guard current.items.map(\.id) == plan.sourceOrder else {
            return VerifiedMoveResult(outcome: .topologyChanged)
        }
        guard let sourceItem = current.items.first(where: { $0.id == plan.item }),
              current.items.indices.contains(plan.destinationIndex),
              let sourceFrame = sourceItem.frame,
              let destinationFrame = current.items[plan.destinationIndex].frame
        else {
            return VerifiedMoveResult(outcome: .itemUnavailable)
        }

        if plan.sourceIndex != plan.destinationIndex {
            if let failure = await performMove(
                plan: plan,
                sourceFrame: sourceFrame,
                destinationFrame: destinationFrame,
                deadline: deadline
            ) {
                return VerifiedMoveResult(outcome: failure)
            }
        }

        switch await readSnapshot(deadline: deadline) {
        case let .success(observed):
            return VerifiedMoveResult(
                outcome: verificationOutcome(for: plan, observed: observed),
                verifiedSnapshot: observed
            )
        case let .failure(outcome):
            return VerifiedMoveResult(outcome: outcome)
        }
    }

    private func readSnapshot(deadline: OperationDeadline) async -> SnapshotReadResult {
        let reader = reader
        let remaining = deadline.remaining()
        let results = AsyncStream<SnapshotReadResult> { continuation in
            let observationTask = Task.detached(priority: .userInitiated) {
                let result = await Self.snapshotResult(reader: reader, deadline: deadline)
                continuation.yield(result)
                continuation.finish()
            }
            let deadlineTask = Task.detached(priority: .userInitiated) {
                do {
                    try await Task.sleep(for: remaining)
                    try Task.checkCancellation()
                    continuation.yield(.failure(.timedOut))
                    continuation.finish()
                } catch {
                    return
                }
            }
            continuation.onTermination = { @Sendable _ in
                observationTask.cancel()
                deadlineTask.cancel()
            }
        }

        for await result in results {
            return result
        }
        return .failure(.timedOut)
    }

    private nonisolated static func snapshotResult(
        reader: Reader,
        deadline: OperationDeadline
    ) async -> SnapshotReadResult {
        do {
            try deadline.check()
            let snapshot = try await reader.snapshot(deadline: deadline)
            try deadline.check()
            return .success(snapshot)
        } catch MenuBarAuthorizationError.permissionRevoked {
            return .failure(.permissionRevoked)
        } catch is OperationDeadlineError {
            return .failure(.timedOut)
        } catch is CancellationError {
            return .failure(.timedOut)
        } catch {
            return .failure(.observationFailed)
        }
    }

    private func performMove(
        plan: MovePlan,
        sourceFrame: MenuBarItemFrame,
        destinationFrame: MenuBarItemFrame,
        deadline: OperationDeadline
    ) async -> MoveExecutionOutcome? {
        let insertionEdge: MenuBarInsertionEdge =
            plan.sourceIndex < plan.destinationIndex ? .after : .before
        do {
            try deadline.check()
            try await performer.move(
                source: sourceFrame,
                destination: destinationFrame,
                insertionEdge: insertionEdge,
                deadline: deadline
            )
            try deadline.check()
            return nil
        } catch MenuBarAuthorizationError.permissionRevoked {
            return .permissionRevoked
        } catch MenuBarInputError.menuBarUnavailable {
            return .menuBarUnavailable
        } catch is OperationDeadlineError {
            return .timedOut
        } catch is CancellationError {
            return .timedOut
        } catch {
            return .inputFailed
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
