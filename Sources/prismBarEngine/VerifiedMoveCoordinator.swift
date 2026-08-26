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
        let deadline = OperationDeadline(timeout: operationTimeout)
        let current: MenuBarSnapshot
        switch await readSnapshot(deadline: deadline) {
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
                destinationFrame: destinationFrame,
                deadline: deadline
            ) {
                return failure
            }
        }

        switch await readSnapshot(deadline: deadline) {
        case let .success(observed):
            return verificationOutcome(for: plan, observed: observed)
        case let .failure(outcome):
            return outcome
        }
    }

    private func readSnapshot(deadline: OperationDeadline) async -> SnapshotReadResult {
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
