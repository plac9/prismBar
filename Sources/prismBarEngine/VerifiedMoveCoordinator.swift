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
    private static var verificationAttemptLimit: Int { 8 }
    private static var verificationRetryDelay: Duration { .milliseconds(120) }

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
        let preflightDeadline = OperationDeadline(timeout: operationTimeout)
        let current: MenuBarSnapshot
        switch await readSnapshot(deadline: preflightDeadline) {
        case let .success(snapshot):
            current = snapshot
        case let .failure(outcome):
            return VerifiedMoveResult(outcome: outcome)
        }

        if let verificationSection = plan.verificationSection,
           current.section(for: plan.item) == verificationSection {
            return VerifiedMoveResult(outcome: .success, verifiedSnapshot: current)
        }

        guard preflightMatches(plan, current: current) else {
            return VerifiedMoveResult(outcome: .topologyChanged)
        }
        guard let sourceItem = current.items.first(where: { $0.id == plan.item }),
              let sourceIndex = current.items.firstIndex(where: { $0.id == plan.item }),
              let destinationIndex = current.items.firstIndex(where: {
                  $0.id == plan.destinationItem
              }),
              let sourceFrame = sourceItem.frame,
              let destinationFrame = current.items[destinationIndex].frame
        else {
            return VerifiedMoveResult(outcome: .itemUnavailable)
        }

        if plan.item != plan.destinationItem {
            let inputDeadline = OperationDeadline(timeout: operationTimeout)
            if let failure = await performMove(
                sourceIndex: sourceIndex,
                destinationIndex: destinationIndex,
                sourceFrame: sourceFrame,
                destinationFrame: destinationFrame,
                deadline: inputDeadline
            ) {
                return VerifiedMoveResult(outcome: failure)
            }
        }

        return await verifyMove(
            plan,
            deadline: OperationDeadline(timeout: operationTimeout)
        )
    }

    private func preflightMatches(
        _ plan: MovePlan,
        current: MenuBarSnapshot
    ) -> Bool {
        guard plan.verificationSection != nil else {
            return moveScopeOrder(
                item: plan.item,
                destination: plan.destinationItem,
                in: current
            ) == plan.sourceScopeOrder
        }

        guard let source = current.items.first(where: { $0.id == plan.item }),
              let destination = current.items.first(where: {
                  $0.id == plan.destinationItem
              }),
              source.surfaceID == destination.surfaceID,
              destination.role == .hiddenSectionDivider,
              let currentSection = current.section(for: plan.item),
              currentSection != .controller
        else {
            return false
        }
        return true
    }

    private func verifyMove(
        _ plan: MovePlan,
        deadline: OperationDeadline
    ) async -> VerifiedMoveResult {
        var latestPartialResult: VerifiedMoveResult?
        let attemptLimit = Self.verificationAttemptLimit

        for attempt in 0 ..< attemptLimit {
            switch await readSnapshot(deadline: deadline) {
            case let .success(observed):
                let result = VerifiedMoveResult(
                    outcome: verificationOutcome(for: plan, observed: observed),
                    verifiedSnapshot: observed
                )
                guard case .partial = result.outcome,
                      attempt + 1 < attemptLimit
                else {
                    return result
                }
                latestPartialResult = result
            case let .failure(outcome):
                return latestPartialResult ?? VerifiedMoveResult(outcome: outcome)
            }

            do {
                try await Task.sleep(for: Self.verificationRetryDelay)
                try deadline.check()
            } catch {
                return latestPartialResult ?? VerifiedMoveResult(outcome: .timedOut)
            }
        }

        return latestPartialResult ?? VerifiedMoveResult(outcome: .observationFailed)
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
        sourceIndex: Int,
        destinationIndex: Int,
        sourceFrame: MenuBarItemFrame,
        destinationFrame: MenuBarItemFrame,
        deadline: OperationDeadline
    ) async -> MoveExecutionOutcome? {
        let insertionEdge: MenuBarInsertionEdge =
            sourceIndex < destinationIndex ? .after : .before
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
        if let verificationSection = plan.verificationSection,
           observed.section(for: plan.item) == verificationSection {
            return .success
        }
        if moveScopeOrder(
            item: plan.item,
            destination: plan.destinationItem,
            in: observed
        ) == plan.expectedScopeOrder {
            return .success
        }
        if plan.verificationSection == nil,
           directPlacementMatches(plan, observed: observed) {
            return .success
        }
        if let section = observed.section(for: plan.item),
           section != .controller,
           let observedIndex = observed.movementDestinations(for: plan.item)
               .firstIndex(where: { $0.id == plan.item }) {
            return .partial(observedIndex: observedIndex)
        }
        if let observedIndex = observed.items.firstIndex(where: { $0.id == plan.item }) {
            return .partial(observedIndex: observedIndex)
        }
        return .itemUnavailable
    }

    private func directPlacementMatches(
        _ plan: MovePlan,
        observed: MenuBarSnapshot
    ) -> Bool {
        guard let observedScope = moveScopeOrder(
            item: plan.item,
            destination: plan.destinationItem,
            in: observed
        ),
        let plannedSourceIndex = plan.sourceScopeOrder.firstIndex(of: plan.item),
        let plannedDestinationIndex = plan.sourceScopeOrder.firstIndex(of: plan.destinationItem),
        let observedSourceIndex = observedScope.firstIndex(of: plan.item),
        let observedDestinationIndex = observedScope.firstIndex(of: plan.destinationItem)
        else {
            return false
        }

        let isAtRequestedAnchor = if plannedSourceIndex < plannedDestinationIndex {
            observedSourceIndex == observedDestinationIndex + 1
        } else {
            observedSourceIndex + 1 == observedDestinationIndex
        }
        guard isAtRequestedAnchor else { return false }

        let plannedAnchors = plan.sourceScopeOrder.filter { $0 != plan.item }
        let observedAnchors = observedScope.filter { $0 != plan.item }
        let survivingAnchors = Set(plannedAnchors).intersection(observedAnchors)
        return plannedAnchors.filter(survivingAnchors.contains) ==
            observedAnchors.filter(survivingAnchors.contains)
    }
}
