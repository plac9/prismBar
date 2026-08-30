// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import prismBarEngine

extension AppModel {
    func recoverLastMenuBarAction() {
        guard accessibilityState == .granted,
              !isMenuBarActionInProgress,
              let attempt = beginMenuBarRecovery()
        else { return }

        Task { [weak self] in
            guard let self else { return }
            let wasCollapsed = isHiddenSectionCollapsed
            await revealHiddenSectionForAction()
            let planner = MenuBarRecoveryPlanner()
            let moveLimit = attempt.entry.before.items.count(where: { $0.role == .item })
            var latestVerifiedSnapshot: MenuBarSnapshot?

            do {
                for moveIndex in 0 ... moveLimit {
                    let current: MenuBarSnapshot
                    if let latestVerifiedSnapshot {
                        current = latestVerifiedSnapshot
                    } else {
                        current = try await menuBarController.snapshot(
                            deadline: OperationDeadline(timeout: .seconds(8))
                        )
                    }

                    if try planner.isRestored(current, target: attempt.entry.before) {
                        acceptVerifiedMenuBarSnapshot(current)
                        completeMenuBarRecovery(
                            id: attempt.receipt.id,
                            result: .success("Previous menu bar layout restored."),
                            after: current
                        )
                        await restoreHiddenSectionIfNeeded(wasCollapsed)
                        return
                    }

                    guard moveIndex < moveLimit,
                          let plan = try planner.nextPlan(
                              current: current,
                              restoring: attempt.entry.before
                          )
                    else {
                        completeMenuBarRecovery(
                            id: attempt.receipt.id,
                            result: .failure("Recovery stopped at its safe move limit."),
                            after: current
                        )
                        await restoreHiddenSectionIfNeeded(wasCollapsed)
                        return
                    }

                    let execution = await menuBarController.executeWithObservation(plan)
                    if let verifiedSnapshot = execution.verifiedSnapshot {
                        acceptVerifiedMenuBarSnapshot(verifiedSnapshot)
                        latestVerifiedSnapshot = verifiedSnapshot
                    } else {
                        latestVerifiedSnapshot = nil
                    }
                    guard execution.outcome == .success else {
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
                        return
                    }
                }
            } catch MenuBarAuthorizationError.permissionRevoked {
                handleAccessibilityRevocation()
            } catch {
                completeMenuBarRecovery(
                    id: attempt.receipt.id,
                    result: .warning(
                        "Recovery stopped safely because the menu bar changed. Refresh and try again."
                    ),
                    after: latestVerifiedSnapshot
                )
                await restoreHiddenSectionIfNeeded(wasCollapsed)
            }
        }
    }

    func moveMenuBarItem(_ itemID: MenuBarItemID, to destinationIndex: Int) {
        guard accessibilityState == .granted,
              let displayedSnapshot = menuBarSnapshot,
              !isMenuBarActionInProgress
        else { return }

        let itemName = displayedSnapshot.items.first(where: { $0.id == itemID })?.displayName
            ?? "the selected item"
        let pendingReceipt = beginMenuBarAction(
            kind: .directMove,
            before: displayedSnapshot,
            itemID: itemID
        )
        Task { [weak self] in
            guard let self else { return }
            let wasCollapsed = isHiddenSectionCollapsed
            var didAcceptVerifiedSnapshot = false
            await revealHiddenSectionForAction()

            do {
                let snapshot = try await menuBarController.snapshot(
                    deadline: OperationDeadline(timeout: .seconds(8))
                )
                guard snapshot.items.map(\.id) == displayedSnapshot.items.map(\.id) else {
                    completeMenuBarAction(
                        id: pendingReceipt.id,
                        result: .warning(
                            "The menu bar changed before the move. Review the refreshed positions and try again."
                        ),
                        after: nil
                    )
                    await restoreHiddenSectionIfNeeded(wasCollapsed)
                    refreshMenuBar(preservingActionResult: true)
                    return
                }
                let plan = try MovePlanner().plan(item: itemID, to: destinationIndex, in: snapshot)
                let execution = await menuBarController.executeWithObservation(plan)
                let outcome = acceptVerifiedExecution(execution)
                didAcceptVerifiedSnapshot = execution.verifiedSnapshot != nil
                completeMenuBarAction(
                    id: pendingReceipt.id,
                    result: .move(outcome, itemName: itemName),
                    after: execution.verifiedSnapshot
                )
                if outcome == .permissionRevoked {
                    handleAccessibilityRevocation()
                } else {
                    await restoreHiddenSectionIfNeeded(wasCollapsed)
                }
            } catch MenuBarAuthorizationError.permissionRevoked {
                handleAccessibilityRevocation()
            } catch {
                completeMenuBarAction(
                    id: pendingReceipt.id,
                    result: .failure("That item cannot be moved to the requested position."),
                    after: nil
                )
                await restoreHiddenSectionIfNeeded(wasCollapsed)
            }
            if !didAcceptVerifiedSnapshot, accessibilityState == .granted {
                refreshMenuBar(preservingActionResult: true)
            }
        }
    }

    private func acceptVerifiedExecution(_ execution: VerifiedMoveResult) -> MoveExecutionOutcome {
        if let snapshot = execution.verifiedSnapshot {
            acceptVerifiedMenuBarSnapshot(snapshot)
        }
        return execution.outcome
    }

    private func recoveryResult(for outcome: MoveExecutionOutcome) -> MenuBarActionResult {
        let detail = MenuBarActionResult.move(outcome, itemName: "the previous layout")
        return MenuBarActionResult(
            kind: detail.kind,
            message: "Recovery stopped safely. \(detail.message)",
            symbol: detail.symbol,
            recovery: detail.recovery
        )
    }

    func moveMenuBarItem(_ itemID: MenuBarItemID, to section: MenuBarSection) {
        guard accessibilityState == .granted,
              let displayedSnapshot = menuBarSnapshot,
              !isMenuBarActionInProgress
        else { return }

        let pendingReceipt = beginMenuBarAction(
            kind: .sectionMove,
            before: displayedSnapshot,
            itemID: itemID
        )
        Task { [weak self] in
            guard let self else { return }
            let wasCollapsed = isHiddenSectionCollapsed
            await revealHiddenSectionForAction()

            do {
                let snapshot = try await menuBarController.snapshot(
                    deadline: OperationDeadline(timeout: .seconds(8))
                )
                guard snapshot.items.map(\.id) == displayedSnapshot.items.map(\.id) else {
                    completeMenuBarAction(
                        id: pendingReceipt.id,
                        result: .warning(
                            "The menu bar changed before the item could move. Refresh and try again."
                        ),
                        after: nil
                    )
                    await restoreHiddenSectionIfNeeded(wasCollapsed)
                    refreshMenuBar(preservingActionResult: true)
                    return
                }
                let plan = try SectionMovePlanner().plan(item: itemID, to: section, in: snapshot)
                let execution = await menuBarController.executeWithObservation(plan)
                let outcome = execution.outcome
                if let verifiedSnapshot = execution.verifiedSnapshot {
                    acceptVerifiedMenuBarSnapshot(verifiedSnapshot)
                }
                let itemName = snapshot.items.first(where: { $0.id == itemID })?.displayName
                    ?? "the selected item"
                completeMenuBarAction(
                    id: pendingReceipt.id,
                    result: .move(outcome, itemName: itemName),
                    after: execution.verifiedSnapshot
                )

                if outcome == .permissionRevoked {
                    handleAccessibilityRevocation()
                } else if outcome == .success, wasCollapsed || section == .hidden {
                    isHiddenSectionCollapsed = MenuBarSectionStatusController.shared.setCollapsed(
                        true,
                        dividerFrame: execution.verifiedSnapshot?.hiddenSectionDivider?.frame
                    )
                    try? await Task.sleep(for: .milliseconds(120))
                } else if outcome != .success {
                    await restoreHiddenSectionIfNeeded(wasCollapsed)
                }
                refreshMenuBar(preservingActionResult: true)
            } catch MenuBarAuthorizationError.permissionRevoked {
                handleAccessibilityRevocation()
            } catch {
                completeMenuBarAction(
                    id: pendingReceipt.id,
                    result: .warning(
                        "The section changed before the item could be moved. Refresh and try again."
                    ),
                    after: nil
                )
                await restoreHiddenSectionIfNeeded(wasCollapsed)
                refreshMenuBar(preservingActionResult: true)
            }
        }
    }

    func moveMenuBarItems(_ itemIDs: Set<MenuBarItemID>, to section: MenuBarSection) {
        guard accessibilityState == .granted,
              section != .controller,
              !itemIDs.isEmpty,
              let displayedSnapshot = menuBarSnapshot,
              !isMenuBarActionInProgress
        else { return }

        let pendingReceipt = beginMenuBarAction(
            kind: .batchMove,
            before: displayedSnapshot,
            itemID: nil
        )
        Task { [weak self] in
            await self?.performBatchMove(
                itemIDs,
                to: section,
                displayedSnapshot: displayedSnapshot,
                receiptID: pendingReceipt.id
            )
        }
    }

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
            guard let self else { return }
            await revealHiddenSectionForAction()

            do {
                let initial = try await menuBarController.snapshot(
                    deadline: OperationDeadline(timeout: .seconds(8))
                )
                guard initial.items.map(\.id) == displayedSnapshot.items.map(\.id) else {
                    completeMenuBarAction(
                        id: pendingReceipt.id,
                        result: .warning(
                            "The menu bar changed before reset. Refresh and try again."
                        ),
                        after: nil
                    )
                    refreshMenuBar(preservingActionResult: true)
                    return
                }
                let itemIDs = SectionResetPlanner().hiddenItemsToReveal(in: initial)
                guard !itemIDs.isEmpty else {
                    completeMenuBarAction(
                        id: pendingReceipt.id,
                        result: .success("Every menu bar item is already visible."),
                        after: initial
                    )
                    refreshMenuBar(preservingActionResult: true)
                    return
                }

                let execution = try await executeResetMoves(itemIDs)
                if let failure = execution.failure {
                    if failure == .permissionRevoked {
                        handleAccessibilityRevocation()
                        return
                    }
                    let detail = MenuBarActionResult.move(failure, itemName: "the selected item")
                    let result = MenuBarActionResult(
                        kind: detail.kind,
                        message: "Reset stopped safely. \(detail.message)",
                        symbol: detail.symbol,
                        recovery: detail.recovery
                    )
                    if let verifiedSnapshot = execution.verifiedSnapshot {
                        acceptVerifiedMenuBarSnapshot(verifiedSnapshot)
                    }
                    completeMenuBarAction(
                        id: pendingReceipt.id,
                        result: result,
                        after: execution.verifiedSnapshot
                    )
                    refreshMenuBar(preservingActionResult: true)
                    return
                }

                if let verifiedSnapshot = execution.verifiedSnapshot {
                    acceptVerifiedMenuBarSnapshot(verifiedSnapshot)
                }
                completeMenuBarAction(
                    id: pendingReceipt.id,
                    result: .success("Reset verified. Every movable item is visible."),
                    after: execution.verifiedSnapshot
                )
                refreshMenuBar(preservingActionResult: true)
            } catch MenuBarAuthorizationError.permissionRevoked {
                handleAccessibilityRevocation()
            } catch {
                completeMenuBarAction(
                    id: pendingReceipt.id,
                    result: .warning(
                        "Reset stopped safely because the menu bar changed. Refresh and try again."
                    ),
                    after: nil
                )
                refreshMenuBar(preservingActionResult: true)
            }
        }
    }

    private func executeResetMoves(
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

    func setHiddenSectionCollapsed(_ collapsed: Bool) {
        guard accessibilityState == .granted,
              let displayedSnapshot = menuBarSnapshot,
              !isMenuBarActionInProgress
        else { return }

        let pendingReceipt = beginMenuBarAction(
            kind: .sectionMove,
            before: displayedSnapshot,
            itemID: nil
        )
        let actualState = MenuBarSectionStatusController.shared.setCollapsed(
            collapsed,
            dividerFrame: menuBarSnapshot?.hiddenSectionDivider?.frame
        )
        guard actualState == collapsed else {
            completeMenuBarAction(
                id: pendingReceipt.id,
                result: .failure(
                    "The hidden section divider is not ready yet.",
                    symbol: "eye.slash"
                ),
                after: nil
            )
            refreshMenuBar(preservingActionResult: true)
            return
        }

        isHiddenSectionCollapsed = actualState
        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(120))
            do {
                let observed = try await menuBarController.snapshot(
                    deadline: OperationDeadline(timeout: .seconds(8))
                )
                acceptVerifiedMenuBarSnapshot(observed)
                completeMenuBarAction(
                    id: pendingReceipt.id,
                    result: .success(collapsed ? "Hidden items folded." : "Hidden items revealed."),
                    after: observed
                )
                refreshMenuBar(preservingActionResult: true)
            } catch MenuBarAuthorizationError.permissionRevoked {
                handleAccessibilityRevocation()
            } catch {
                completeMenuBarAction(
                    id: pendingReceipt.id,
                    result: .failure("prismBar could not verify the hidden section state."),
                    after: nil
                )
                refreshMenuBar(preservingActionResult: true)
            }
        }
    }

    private func revealHiddenSectionForAction() async {
        guard isHiddenSectionCollapsed else { return }
        isHiddenSectionCollapsed = MenuBarSectionStatusController.shared.setCollapsed(
            false,
            dividerFrame: menuBarSnapshot?.hiddenSectionDivider?.frame
        )
        try? await Task.sleep(for: .milliseconds(120))
    }

    private func restoreHiddenSectionIfNeeded(_ shouldCollapse: Bool) async {
        guard shouldCollapse else { return }
        let observed = try? await menuBarController.snapshot(
            deadline: OperationDeadline(timeout: .seconds(8))
        )
        isHiddenSectionCollapsed = MenuBarSectionStatusController.shared.setCollapsed(
            true,
            dividerFrame: observed?.hiddenSectionDivider?.frame
        )
        try? await Task.sleep(for: .milliseconds(120))
    }

    private func performBatchMove(
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
                completeMenuBarAction(
                    id: receiptID,
                    result: .warning(
                        "The menu bar changed before the batch move. Refresh and try again."
                    ),
                    after: nil
                )
                await restoreHiddenSectionIfNeeded(wasCollapsed)
                refreshMenuBar(preservingActionResult: true)
                return
            }
            let orderedItemIDs = SectionBatchPlanner().itemIDsToMove(
                itemIDs,
                to: section,
                in: initialSnapshot
            )
            guard !orderedItemIDs.isEmpty else {
                completeMenuBarAction(
                    id: receiptID,
                    result: .warning(
                        "No selected items can move to that section.",
                        recovery: .none
                    ),
                    after: initialSnapshot
                )
                await restoreHiddenSectionIfNeeded(wasCollapsed)
                refreshMenuBar(preservingActionResult: true)
                return
            }

            let execution = try await executeBatchMoves(orderedItemIDs, to: section)
            if let failure = execution.failure {
                await finishFailedBatchMove(
                    movedCount: execution.movedCount,
                    failure: failure,
                    wasCollapsed: wasCollapsed,
                    receiptID: receiptID,
                    verifiedSnapshot: execution.verifiedSnapshot
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
        } catch MenuBarAuthorizationError.permissionRevoked {
            handleAccessibilityRevocation()
        } catch {
            completeMenuBarAction(
                id: receiptID,
                result: .warning(
                    "Batch move stopped safely because the menu bar changed. Refresh and try again."
                ),
                after: nil
            )
            await restoreHiddenSectionIfNeeded(wasCollapsed)
            refreshMenuBar(preservingActionResult: true)
        }
    }

    private func executeBatchMoves(
        _ itemIDs: [MenuBarItemID],
        to section: MenuBarSection
    ) async throws -> (
        movedCount: Int,
        failure: MoveExecutionOutcome?,
        verifiedSnapshot: MenuBarSnapshot?
    ) {
        var movedCount = 0
        var latestVerifiedSnapshot: MenuBarSnapshot?
        for itemID in itemIDs {
            let snapshot = try await menuBarController.snapshot(
                deadline: OperationDeadline(timeout: .seconds(8))
            )
            latestVerifiedSnapshot = snapshot
            switch SectionBatchPlanner().disposition(
                for: itemID,
                to: section,
                in: snapshot
            ) {
            case .alreadyCompleted:
                movedCount += 1
                continue
            case .unavailable:
                return (movedCount, .itemUnavailable, latestVerifiedSnapshot)
            case .moveRequired:
                break
            }
            let plan = try SectionMovePlanner().plan(item: itemID, to: section, in: snapshot)
            let execution = await menuBarController.executeWithObservation(plan)
            if let verifiedSnapshot = execution.verifiedSnapshot {
                latestVerifiedSnapshot = verifiedSnapshot
            }
            guard execution.outcome == .success else {
                return (movedCount, execution.outcome, latestVerifiedSnapshot)
            }
            movedCount += 1
        }
        return (movedCount, nil, latestVerifiedSnapshot)
    }

    private func finishFailedBatchMove(
        movedCount: Int,
        failure: MoveExecutionOutcome,
        wasCollapsed: Bool,
        receiptID: MenuBarActionID,
        verifiedSnapshot: MenuBarSnapshot?
    ) async {
        if failure == .permissionRevoked {
            handleAccessibilityRevocation()
            return
        } else {
            await restoreHiddenSectionIfNeeded(wasCollapsed)
        }
        let detail = MenuBarActionResult.move(failure, itemName: "the selected item")
        let result =
            MenuBarActionResult(
                kind: detail.kind,
                message: "Moved \(movedCount) item(s), then stopped safely. \(detail.message)",
                symbol: detail.symbol,
                recovery: detail.recovery
            )
        if let verifiedSnapshot {
            acceptVerifiedMenuBarSnapshot(verifiedSnapshot)
        }
        completeMenuBarAction(
            id: receiptID,
            result: result,
            after: verifiedSnapshot
        )
        refreshMenuBar(preservingActionResult: true)
    }

    private func collapseHiddenSectionIfNeeded(_ shouldCollapse: Bool) async {
        guard shouldCollapse else { return }
        let observed = try? await menuBarController.snapshot(
            deadline: OperationDeadline(timeout: .seconds(8))
        )
        isHiddenSectionCollapsed = MenuBarSectionStatusController.shared.setCollapsed(
            true,
            dividerFrame: observed?.hiddenSectionDivider?.frame
        )
        try? await Task.sleep(for: .milliseconds(120))
    }

}
