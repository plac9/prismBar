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
                let plan = try Self.directMovePlan(
                    itemID: itemID,
                    destinationIndex: destinationIndex,
                    displayedSnapshot: displayedSnapshot
                )
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

    static func directMovePlan(
        itemID: MenuBarItemID,
        destinationIndex: Int,
        displayedSnapshot: MenuBarSnapshot
    ) throws -> MovePlan {
        try MovePlanner().plan(
            item: itemID,
            to: destinationIndex,
            in: displayedSnapshot
        )
    }

    static func sectionMovePlan(
        itemID: MenuBarItemID,
        section: MenuBarSection,
        displayedSnapshot: MenuBarSnapshot
    ) throws -> MovePlan {
        try SectionMovePlanner().plan(
            item: itemID,
            to: section,
            in: displayedSnapshot
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
            await self?.performSectionMove(
                itemID,
                to: section,
                displayedSnapshot: displayedSnapshot,
                receiptID: pendingReceipt.id
            )
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
}

private extension AppModel {
    func acceptVerifiedExecution(_ execution: VerifiedMoveResult) -> MoveExecutionOutcome {
        if let snapshot = execution.verifiedSnapshot {
            acceptVerifiedMenuBarSnapshot(snapshot)
        }
        return execution.outcome
    }

    func performSectionMove(
        _ itemID: MenuBarItemID,
        to section: MenuBarSection,
        displayedSnapshot: MenuBarSnapshot,
        receiptID: MenuBarActionID
    ) async {
        let wasCollapsed = isHiddenSectionCollapsed
        await revealHiddenSectionForAction()

        do {
            let plan = try Self.sectionMovePlan(
                itemID: itemID,
                section: section,
                displayedSnapshot: displayedSnapshot
            )
            let execution = await menuBarController.executeWithObservation(plan)
            if let verifiedSnapshot = execution.verifiedSnapshot {
                acceptVerifiedMenuBarSnapshot(verifiedSnapshot)
            }
            let itemName = displayedSnapshot.items.first(where: { $0.id == itemID })?.displayName
                ?? "the selected item"
            completeMenuBarAction(
                id: receiptID,
                result: .move(execution.outcome, itemName: itemName),
                after: execution.verifiedSnapshot
            )
            await finishSectionMove(
                execution.outcome,
                to: section,
                wasCollapsed: wasCollapsed,
                verifiedSnapshot: execution.verifiedSnapshot
            )
        } catch MenuBarAuthorizationError.permissionRevoked {
            handleAccessibilityRevocation()
        } catch {
            completeMenuBarAction(
                id: receiptID,
                result: .warning(
                    "The section changed before the item could be moved. Refresh and try again."
                ),
                after: nil
            )
            await restoreHiddenSectionIfNeeded(wasCollapsed)
            refreshMenuBar(preservingActionResult: true)
        }
    }

    func finishSectionMove(
        _ outcome: MoveExecutionOutcome,
        to section: MenuBarSection,
        wasCollapsed: Bool,
        verifiedSnapshot: MenuBarSnapshot?
    ) async {
        if outcome == .permissionRevoked {
            handleAccessibilityRevocation()
            return
        }
        if outcome == .success, wasCollapsed || section == .hidden {
            isHiddenSectionCollapsed = MenuBarSectionStatusController.shared.setCollapsed(
                true,
                dividerFrame: verifiedSnapshot?.hiddenSectionDivider?.frame
            )
            try? await Task.sleep(for: .milliseconds(120))
        } else if outcome != .success {
            await restoreHiddenSectionIfNeeded(wasCollapsed)
        }
        refreshMenuBar(preservingActionResult: true)
    }
}
