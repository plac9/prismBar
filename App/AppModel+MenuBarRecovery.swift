// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import prismBarEngine

private struct RecoveryProgressError: Error {
    let latestVerifiedSnapshot: MenuBarSnapshot?
}

extension AppModel {
    func recoverLastMenuBarAction() {
        guard accessibilityState == .granted,
              !isMenuBarActionInProgress,
              let attempt = beginMenuBarRecovery()
        else { return }

        Task { [weak self] in
            await self?.performMenuBarRecovery(attempt)
        }
    }
}

private extension AppModel {
    func performMenuBarRecovery(_ attempt: MenuBarRecoveryAttempt) async {
        let wasCollapsed = isHiddenSectionCollapsed
        await revealHiddenSectionForAction()

        do {
            try await executeRecoveryMoves(attempt, wasCollapsed: wasCollapsed)
        } catch MenuBarAuthorizationError.permissionRevoked {
            handleAccessibilityRevocation()
        } catch let error as RecoveryProgressError {
            completeMenuBarRecovery(
                id: attempt.receipt.id,
                result: .warning(
                    "Recovery stopped safely because the menu bar changed. Refresh and try again."
                ),
                after: error.latestVerifiedSnapshot
            )
            await restoreHiddenSectionIfNeeded(wasCollapsed)
        } catch {
            completeMenuBarRecovery(
                id: attempt.receipt.id,
                result: .warning(
                    "Recovery stopped safely because the menu bar changed. Refresh and try again."
                ),
                after: nil
            )
            await restoreHiddenSectionIfNeeded(wasCollapsed)
        }
    }

    func executeRecoveryMoves(
        _ attempt: MenuBarRecoveryAttempt,
        wasCollapsed: Bool
    ) async throws {
        var latestVerifiedSnapshot: MenuBarSnapshot?
        do {
            try await executeRecoveryLoop(
                attempt,
                wasCollapsed: wasCollapsed,
                latestVerifiedSnapshot: &latestVerifiedSnapshot
            )
        } catch MenuBarAuthorizationError.permissionRevoked {
            throw MenuBarAuthorizationError.permissionRevoked
        } catch {
            throw RecoveryProgressError(latestVerifiedSnapshot: latestVerifiedSnapshot)
        }
    }

    func executeRecoveryLoop(
        _ attempt: MenuBarRecoveryAttempt,
        wasCollapsed: Bool,
        latestVerifiedSnapshot: inout MenuBarSnapshot?
    ) async throws {
        let planner = MenuBarRecoveryPlanner()
        let moveLimit = attempt.entry.before.items.count(where: { $0.role == .item })

        for moveIndex in 0 ... moveLimit {
            let current = try await recoverySnapshot(latestVerifiedSnapshot)
            if try planner.isRestored(current, target: attempt.entry.before) {
                await finishSuccessfulRecovery(attempt, snapshot: current, wasCollapsed: wasCollapsed)
                return
            }

            guard moveIndex < moveLimit,
                  let plan = try planner.nextPlan(
                      current: current,
                      restoring: attempt.entry.before
                  )
            else {
                await finishLimitedRecovery(attempt, snapshot: current, wasCollapsed: wasCollapsed)
                return
            }

            let execution = await menuBarController.executeWithObservation(plan)
            latestVerifiedSnapshot = execution.verifiedSnapshot
            if let verifiedSnapshot = execution.verifiedSnapshot {
                acceptVerifiedMenuBarSnapshot(verifiedSnapshot)
            }
            guard execution.outcome == .success else {
                await finishFailedRecovery(attempt, execution: execution, wasCollapsed: wasCollapsed)
                return
            }
        }
    }

    func recoverySnapshot(
        _ latestVerifiedSnapshot: MenuBarSnapshot?
    ) async throws -> MenuBarSnapshot {
        if let latestVerifiedSnapshot {
            return latestVerifiedSnapshot
        }
        return try await menuBarController.snapshot(
            deadline: OperationDeadline(timeout: .seconds(8))
        )
    }

    func finishSuccessfulRecovery(
        _ attempt: MenuBarRecoveryAttempt,
        snapshot: MenuBarSnapshot,
        wasCollapsed: Bool
    ) async {
        acceptVerifiedMenuBarSnapshot(snapshot)
        completeMenuBarRecovery(
            id: attempt.receipt.id,
            result: .success("Previous menu bar layout restored."),
            after: snapshot
        )
        await restoreHiddenSectionIfNeeded(wasCollapsed)
    }

    func finishLimitedRecovery(
        _ attempt: MenuBarRecoveryAttempt,
        snapshot: MenuBarSnapshot,
        wasCollapsed: Bool
    ) async {
        completeMenuBarRecovery(
            id: attempt.receipt.id,
            result: .failure("Recovery stopped at its safe move limit."),
            after: snapshot
        )
        await restoreHiddenSectionIfNeeded(wasCollapsed)
    }

    func finishFailedRecovery(
        _ attempt: MenuBarRecoveryAttempt,
        execution: VerifiedMoveResult,
        wasCollapsed: Bool
    ) async {
        if execution.outcome == .permissionRevoked {
            handleAccessibilityRevocation()
            return
        }
        completeMenuBarRecovery(
            id: attempt.receipt.id,
            result: recoveryResult(for: execution.outcome),
            after: execution.verifiedSnapshot
        )
        await restoreHiddenSectionIfNeeded(wasCollapsed)
    }

    func recoveryResult(for outcome: MoveExecutionOutcome) -> MenuBarActionResult {
        let detail = MenuBarActionResult.move(outcome, itemName: "the previous layout")
        return MenuBarActionResult(
            kind: detail.kind,
            message: "Recovery stopped safely. \(detail.message)",
            symbol: detail.symbol,
            recovery: detail.recovery
        )
    }
}
