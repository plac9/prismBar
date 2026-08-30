// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import prismBarEngine

extension AppModel {
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

    func moveMenuBarItem(_ itemID: MenuBarItemID, to section: MenuBarSection) {
        guard accessibilityState == .granted,
              !isMenuBarActionInProgress
        else { return }

        menuBarActionState = .moving(itemID: itemID)
        Task { [weak self] in
            guard let self else { return }
            let wasCollapsed = isHiddenSectionCollapsed
            await revealHiddenSectionForAction()

            do {
                let snapshot = try await menuBarController.snapshot(
                    deadline: OperationDeadline(timeout: .seconds(8))
                )
                let plan = try SectionMovePlanner().plan(item: itemID, to: section, in: snapshot)
                let outcome = await menuBarController.execute(plan)
                let itemName = snapshot.items.first(where: { $0.id == itemID })?.displayName
                    ?? "the selected item"
                menuBarActionState = .result(.move(outcome, itemName: itemName))

                if outcome == .permissionRevoked {
                    handleAccessibilityRevocation()
                } else if outcome == .success, wasCollapsed || section == .hidden {
                    let observed = try? await menuBarController.snapshot(
                        deadline: OperationDeadline(timeout: .seconds(8))
                    )
                    isHiddenSectionCollapsed = MenuBarSectionStatusController.shared.setCollapsed(
                        true,
                        dividerFrame: observed?.hiddenSectionDivider?.frame
                    )
                    try? await Task.sleep(for: .milliseconds(120))
                } else if outcome != .success {
                    await restoreHiddenSectionIfNeeded(wasCollapsed)
                }
                refreshMenuBar(preservingActionResult: true)
            } catch MenuBarAuthorizationError.permissionRevoked {
                handleAccessibilityRevocation()
                menuBarActionState = .result(.move(.permissionRevoked, itemName: "the selected item"))
                refreshMenuBar(preservingActionResult: true)
            } catch {
                menuBarActionState = .result(
                    .warning("The section changed before the item could be moved. Refresh and try again.")
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
              !isMenuBarActionInProgress
        else { return }

        menuBarActionState = .moving(itemID: nil)
        Task { [weak self] in
            await self?.performBatchMove(itemIDs, to: section)
        }
    }

    func resetMenuBar() {
        guard accessibilityState == .granted,
              !isMenuBarActionInProgress
        else { return }

        menuBarActionState = .moving(itemID: nil)
        Task { [weak self] in
            guard let self else { return }
            await revealHiddenSectionForAction()

            do {
                let initial = try await menuBarController.snapshot(
                    deadline: OperationDeadline(timeout: .seconds(8))
                )
                let itemIDs = SectionResetPlanner().hiddenItemsToReveal(in: initial)
                guard !itemIDs.isEmpty else {
                    menuBarActionState = .result(.success("Every menu bar item is already visible."))
                    refreshMenuBar(preservingActionResult: true)
                    return
                }

                if let failure = try await executeResetMoves(itemIDs) {
                    if failure == .permissionRevoked {
                        handleAccessibilityRevocation()
                    }
                    let detail = MenuBarActionResult.move(failure, itemName: "the selected item")
                    menuBarActionState = .result(
                        MenuBarActionResult(
                            kind: detail.kind,
                            message: "Reset stopped safely. \(detail.message)",
                            symbol: detail.symbol,
                            recovery: detail.recovery
                        )
                    )
                    refreshMenuBar(preservingActionResult: true)
                    return
                }

                menuBarActionState = .result(.success("Reset verified. Every movable item is visible."))
                refreshMenuBar(preservingActionResult: true)
            } catch MenuBarAuthorizationError.permissionRevoked {
                handleAccessibilityRevocation()
                menuBarActionState = .result(
                    .move(.permissionRevoked, itemName: "the selected item")
                )
                refreshMenuBar(preservingActionResult: true)
            } catch {
                menuBarActionState = .result(
                    .warning("Reset stopped safely because the menu bar changed. Refresh and try again.")
                )
                refreshMenuBar(preservingActionResult: true)
            }
        }
    }

    private func executeResetMoves(
        _ itemIDs: [MenuBarItemID]
    ) async throws -> MoveExecutionOutcome? {
        for itemID in itemIDs {
            let snapshot = try await menuBarController.snapshot(
                deadline: OperationDeadline(timeout: .seconds(8))
            )
            let plan = try SectionMovePlanner().plan(item: itemID, to: .visible, in: snapshot)
            let outcome = await menuBarController.execute(plan)
            guard outcome == .success else {
                return outcome
            }
        }
        return nil
    }

    func setHiddenSectionCollapsed(_ collapsed: Bool) {
        guard accessibilityState == .granted,
              !isMenuBarActionInProgress
        else { return }

        let actualState = MenuBarSectionStatusController.shared.setCollapsed(
            collapsed,
            dividerFrame: menuBarSnapshot?.hiddenSectionDivider?.frame
        )
        guard actualState == collapsed else {
            menuBarActionState = .result(
                .failure("The hidden section divider is not ready yet.", symbol: "eye.slash")
            )
            refreshMenuBar(preservingActionResult: true)
            return
        }

        isHiddenSectionCollapsed = actualState
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            self?.refreshMenuBar(preservingActionResult: true)
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
        to section: MenuBarSection
    ) async {
        let wasCollapsed = isHiddenSectionCollapsed
        await revealHiddenSectionForAction()

        do {
            let initialSnapshot = try await menuBarController.snapshot(
                deadline: OperationDeadline(timeout: .seconds(8))
            )
            let orderedItemIDs = SectionBatchPlanner().itemIDsToMove(
                itemIDs,
                to: section,
                in: initialSnapshot
            )
            guard !orderedItemIDs.isEmpty else {
                menuBarActionState = .result(
                    .warning("No selected items can move to that section.", recovery: .none)
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
                    wasCollapsed: wasCollapsed
                )
                return
            }

            menuBarActionState = .result(
                .success("Batch move verified for \(execution.movedCount) item(s).")
            )
            await collapseHiddenSectionIfNeeded(section == .hidden || wasCollapsed)
            refreshMenuBar(preservingActionResult: true)
        } catch MenuBarAuthorizationError.permissionRevoked {
            handleAccessibilityRevocation()
            menuBarActionState = .result(
                .move(.permissionRevoked, itemName: "the selected item")
            )
            refreshMenuBar(preservingActionResult: true)
        } catch {
            menuBarActionState = .result(
                .warning("Batch move stopped safely because the menu bar changed. Refresh and try again.")
            )
            await restoreHiddenSectionIfNeeded(wasCollapsed)
            refreshMenuBar(preservingActionResult: true)
        }
    }

    private func executeBatchMoves(
        _ itemIDs: [MenuBarItemID],
        to section: MenuBarSection
    ) async throws -> (movedCount: Int, failure: MoveExecutionOutcome?) {
        var movedCount = 0
        for itemID in itemIDs {
            let snapshot = try await menuBarController.snapshot(
                deadline: OperationDeadline(timeout: .seconds(8))
            )
            switch SectionBatchPlanner().disposition(
                for: itemID,
                to: section,
                in: snapshot
            ) {
            case .alreadyCompleted:
                movedCount += 1
                continue
            case .unavailable:
                return (movedCount, .itemUnavailable)
            case .moveRequired:
                break
            }
            let plan = try SectionMovePlanner().plan(item: itemID, to: section, in: snapshot)
            let outcome = await menuBarController.execute(plan)
            guard outcome == .success else {
                return (movedCount, outcome)
            }
            movedCount += 1
        }
        return (movedCount, nil)
    }

    private func finishFailedBatchMove(
        movedCount: Int,
        failure: MoveExecutionOutcome,
        wasCollapsed: Bool
    ) async {
        if failure == .permissionRevoked {
            handleAccessibilityRevocation()
        } else {
            await restoreHiddenSectionIfNeeded(wasCollapsed)
        }
        let detail = MenuBarActionResult.move(failure, itemName: "the selected item")
        menuBarActionState = .result(
            MenuBarActionResult(
                kind: detail.kind,
                message: "Moved \(movedCount) item(s), then stopped safely. \(detail.message)",
                symbol: detail.symbol,
                recovery: detail.recovery
            )
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
