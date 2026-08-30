// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import prismBarEngine

extension AppModel {
    func resetMenuBar() {
        guard accessibilityState == .granted,
              let displayedSnapshot = menuBarSnapshot,
              !isMenuBarActionInProgress
        else { return }

        let pendingReceipt = beginMenuBarAction(
            kind: .reset,
            before: displayedSnapshot,
            itemID: nil
        )
        Task { [weak self] in
            await self?.performMenuBarReset(
                displayedSnapshot: displayedSnapshot,
                receiptID: pendingReceipt.id
            )
        }
    }
}

private extension AppModel {
    func performMenuBarReset(
        displayedSnapshot: MenuBarSnapshot,
        receiptID: MenuBarActionID
    ) async {
        await revealHiddenSectionForAction()

        do {
            let initial = try await menuBarController.snapshot(
                deadline: OperationDeadline(timeout: .seconds(8))
            )
            guard initial.items.map(\.id) == displayedSnapshot.items.map(\.id) else {
                completeReset(
                    receiptID: receiptID,
                    result: .warning("The menu bar changed before reset. Refresh and try again."),
                    snapshot: nil
                )
                return
            }
            let itemIDs = SectionResetPlanner().hiddenItemsToReveal(in: initial)
            guard !itemIDs.isEmpty else {
                completeReset(
                    receiptID: receiptID,
                    result: .success("Every menu bar item is already visible."),
                    snapshot: initial
                )
                return
            }

            let execution = try await executeResetMoves(itemIDs)
            await finishResetExecution(execution, receiptID: receiptID)
        } catch MenuBarAuthorizationError.permissionRevoked {
            handleAccessibilityRevocation()
        } catch {
            completeReset(
                receiptID: receiptID,
                result: .warning(
                    "Reset stopped safely because the menu bar changed. Refresh and try again."
                ),
                snapshot: nil
            )
        }
    }

    func executeResetMoves(
        _ itemIDs: [MenuBarItemID]
    ) async throws -> (
        failure: MoveExecutionOutcome?,
        verifiedSnapshot: MenuBarSnapshot?
    ) {
        var latestVerifiedSnapshot: MenuBarSnapshot?
        for itemID in itemIDs {
            let snapshot = try await menuBarController.snapshot(
                deadline: OperationDeadline(timeout: .seconds(8))
            )
            latestVerifiedSnapshot = snapshot
            let plan = try SectionMovePlanner().plan(item: itemID, to: .visible, in: snapshot)
            let execution = await menuBarController.executeWithObservation(plan)
            if let verifiedSnapshot = execution.verifiedSnapshot {
                latestVerifiedSnapshot = verifiedSnapshot
            }
            guard execution.outcome == .success else {
                return (execution.outcome, latestVerifiedSnapshot)
            }
        }
        return (nil, latestVerifiedSnapshot)
    }

    func finishResetExecution(
        _ execution: (
            failure: MoveExecutionOutcome?,
            verifiedSnapshot: MenuBarSnapshot?
        ),
        receiptID: MenuBarActionID
    ) async {
        if execution.failure == .permissionRevoked {
            handleAccessibilityRevocation()
            return
        }
        if let verifiedSnapshot = execution.verifiedSnapshot {
            acceptVerifiedMenuBarSnapshot(verifiedSnapshot)
        }
        if let failure = execution.failure {
            let detail = MenuBarActionResult.move(failure, itemName: "the selected item")
            completeReset(
                receiptID: receiptID,
                result: MenuBarActionResult(
                    kind: detail.kind,
                    message: "Reset stopped safely. \(detail.message)",
                    symbol: detail.symbol,
                    recovery: detail.recovery
                ),
                snapshot: execution.verifiedSnapshot
            )
            return
        }
        completeReset(
            receiptID: receiptID,
            result: .success("Reset verified. Every movable item is visible."),
            snapshot: execution.verifiedSnapshot
        )
    }

    func completeReset(
        receiptID: MenuBarActionID,
        result: MenuBarActionResult,
        snapshot: MenuBarSnapshot?
    ) {
        completeMenuBarAction(id: receiptID, result: result, after: snapshot)
        refreshMenuBar(preservingActionResult: true)
    }
}
