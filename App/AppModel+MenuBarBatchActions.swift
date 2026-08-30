// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import prismBarEngine

private struct BatchMoveExecution {
    let movedCount: Int
    let failure: MoveExecutionOutcome?
    let verifiedSnapshot: MenuBarSnapshot?
}

extension AppModel {
    func performBatchMove(
        _ itemIDs: Set<MenuBarItemID>,
        to section: MenuBarSection,
        displayedSnapshot: MenuBarSnapshot,
        receiptID: MenuBarActionID
    ) async {
        let wasCollapsed = isHiddenSectionCollapsed
        await revealHiddenSectionForAction()

        do {
            let initialSnapshot = try await menuBarController.snapshot(
                deadline: OperationDeadline(timeout: .seconds(8))
            )
            guard initialSnapshot.items.map(\.id) == displayedSnapshot.items.map(\.id) else {
                await finishRejectedBatchMove(
                    "The menu bar changed before the batch move. Refresh and try again.",
                    receiptID: receiptID,
                    snapshot: nil,
                    wasCollapsed: wasCollapsed
                )
                return
            }
            let orderedItemIDs = SectionBatchPlanner().itemIDsToMove(
                itemIDs,
                to: section,
                in: initialSnapshot
            )
            guard !orderedItemIDs.isEmpty else {
                await finishRejectedBatchMove(
                    "No selected items can move to that section.",
                    receiptID: receiptID,
                    snapshot: initialSnapshot,
                    wasCollapsed: wasCollapsed
                )
                return
            }

            let execution = try await executeBatchMoves(orderedItemIDs, to: section)
            await finishBatchExecution(
                execution,
                section: section,
                receiptID: receiptID,
                wasCollapsed: wasCollapsed
            )
        } catch MenuBarAuthorizationError.permissionRevoked {
            handleAccessibilityRevocation()
        } catch {
            await finishRejectedBatchMove(
                "Batch move stopped safely because the menu bar changed. Refresh and try again.",
                receiptID: receiptID,
                snapshot: nil,
                wasCollapsed: wasCollapsed
            )
        }
    }
}

private extension AppModel {
    func executeBatchMoves(
        _ itemIDs: [MenuBarItemID],
        to section: MenuBarSection
    ) async throws -> BatchMoveExecution {
        var movedCount = 0
        var latestVerifiedSnapshot: MenuBarSnapshot?
        for itemID in itemIDs {
            let snapshot = try await menuBarController.snapshot(
                deadline: OperationDeadline(timeout: .seconds(8))
            )
            latestVerifiedSnapshot = snapshot
            switch SectionBatchPlanner().disposition(for: itemID, to: section, in: snapshot) {
            case .alreadyCompleted:
                movedCount += 1
                continue
            case .unavailable:
                return BatchMoveExecution(
                    movedCount: movedCount,
                    failure: .itemUnavailable,
                    verifiedSnapshot: latestVerifiedSnapshot
                )
            case .moveRequired:
                break
            }
            let plan = try SectionMovePlanner().plan(item: itemID, to: section, in: snapshot)
            let execution = await menuBarController.executeWithObservation(plan)
            if let verifiedSnapshot = execution.verifiedSnapshot {
                latestVerifiedSnapshot = verifiedSnapshot
            }
            guard execution.outcome == .success else {
                return BatchMoveExecution(
                    movedCount: movedCount,
                    failure: execution.outcome,
                    verifiedSnapshot: latestVerifiedSnapshot
                )
            }
            movedCount += 1
        }
        return BatchMoveExecution(
            movedCount: movedCount,
            failure: nil,
            verifiedSnapshot: latestVerifiedSnapshot
        )
    }

    func finishBatchExecution(
        _ execution: BatchMoveExecution,
        section: MenuBarSection,
        receiptID: MenuBarActionID,
        wasCollapsed: Bool
    ) async {
        if let failure = execution.failure {
            await finishFailedBatchMove(
                execution,
                failure: failure,
                receiptID: receiptID,
                wasCollapsed: wasCollapsed
            )
            return
        }
        if let verifiedSnapshot = execution.verifiedSnapshot {
            acceptVerifiedMenuBarSnapshot(verifiedSnapshot)
        }
        completeMenuBarAction(
            id: receiptID,
            result: .success("Batch move verified for \(execution.movedCount) item(s)."),
            after: execution.verifiedSnapshot
        )
        await collapseHiddenSectionIfNeeded(section == .hidden || wasCollapsed)
        refreshMenuBar(preservingActionResult: true)
    }

    func finishFailedBatchMove(
        _ execution: BatchMoveExecution,
        failure: MoveExecutionOutcome,
        receiptID: MenuBarActionID,
        wasCollapsed: Bool
    ) async {
        if failure == .permissionRevoked {
            handleAccessibilityRevocation()
            return
        }
        await restoreHiddenSectionIfNeeded(wasCollapsed)
        let detail = MenuBarActionResult.move(failure, itemName: "the selected item")
        if let verifiedSnapshot = execution.verifiedSnapshot {
            acceptVerifiedMenuBarSnapshot(verifiedSnapshot)
        }
        completeMenuBarAction(
            id: receiptID,
            result: MenuBarActionResult(
                kind: detail.kind,
                message: "Moved \(execution.movedCount) item(s), then stopped safely. \(detail.message)",
                symbol: detail.symbol,
                recovery: detail.recovery
            ),
            after: execution.verifiedSnapshot
        )
        refreshMenuBar(preservingActionResult: true)
    }

    func finishRejectedBatchMove(
        _ message: String,
        receiptID: MenuBarActionID,
        snapshot: MenuBarSnapshot?,
        wasCollapsed: Bool
    ) async {
        completeMenuBarAction(
            id: receiptID,
            result: .warning(message, recovery: snapshot == nil ? .refresh : .none),
            after: snapshot
        )
        await restoreHiddenSectionIfNeeded(wasCollapsed)
        refreshMenuBar(preservingActionResult: true)
    }
}
