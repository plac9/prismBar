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

        menuBarActionState = .moving
        Task { [weak self] in
            guard let self else { return }
            let wasCollapsed = isHiddenSectionCollapsed
            await revealHiddenSectionForAction()

            do {
                let snapshot = try await menuBarController.snapshot()
                guard snapshot.items.map(\.id) == displayedSnapshot.items.map(\.id) else {
                    menuBarActionState = .result(
                        "The menu bar changed before the move. Review the refreshed positions and try again."
                    )
                    await restoreHiddenSectionIfNeeded(wasCollapsed)
                    refreshMenuBar()
                    return
                }
                let plan = try MovePlanner().plan(item: itemID, to: destinationIndex, in: snapshot)
                let outcome = await menuBarController.execute(plan)
                menuBarActionState = .result(Self.message(for: outcome))
                if outcome == .permissionRevoked {
                    handleAccessibilityRevocation()
                } else {
                    await restoreHiddenSectionIfNeeded(wasCollapsed)
                }
            } catch MenuBarAuthorizationError.permissionRevoked {
                handleAccessibilityRevocation()
                menuBarActionState = .result(Self.message(for: .permissionRevoked))
            } catch {
                menuBarActionState = .result("That item cannot be moved to the requested position.")
                await restoreHiddenSectionIfNeeded(wasCollapsed)
            }
            refreshMenuBar()
        }
    }

    func moveMenuBarItem(_ itemID: MenuBarItemID, to section: MenuBarSection) {
        guard accessibilityState == .granted,
              !isMenuBarActionInProgress
        else { return }

        menuBarActionState = .moving
        Task { [weak self] in
            guard let self else { return }
            let wasCollapsed = isHiddenSectionCollapsed
            await revealHiddenSectionForAction()

            do {
                let snapshot = try await menuBarController.snapshot()
                let plan = try SectionMovePlanner().plan(item: itemID, to: section, in: snapshot)
                let outcome = await menuBarController.execute(plan)
                menuBarActionState = .result(Self.message(for: outcome))

                if outcome == .permissionRevoked {
                    handleAccessibilityRevocation()
                } else if outcome == .success, wasCollapsed || section == .hidden {
                    let observed = try? await menuBarController.snapshot()
                    isHiddenSectionCollapsed = MenuBarSectionStatusController.shared.setCollapsed(
                        true,
                        dividerFrame: observed?.hiddenSectionDivider?.frame
                    )
                    try? await Task.sleep(for: .milliseconds(120))
                } else if outcome != .success {
                    await restoreHiddenSectionIfNeeded(wasCollapsed)
                }
                refreshMenuBar()
            } catch MenuBarAuthorizationError.permissionRevoked {
                handleAccessibilityRevocation()
                menuBarActionState = .result(Self.message(for: .permissionRevoked))
                refreshMenuBar()
            } catch {
                menuBarActionState = .result(
                    "The section changed before the item could be moved. Refresh and try again."
                )
                await restoreHiddenSectionIfNeeded(wasCollapsed)
                refreshMenuBar()
            }
        }
    }

    func moveMenuBarItems(_ itemIDs: Set<MenuBarItemID>, to section: MenuBarSection) {
        guard accessibilityState == .granted,
              section != .controller,
              !itemIDs.isEmpty,
              !isMenuBarActionInProgress
        else { return }

        menuBarActionState = .moving
        Task { [weak self] in
            await self?.performBatchMove(itemIDs, to: section)
        }
    }

    func resetMenuBar() {
        guard accessibilityState == .granted,
              !isMenuBarActionInProgress
        else { return }

        menuBarActionState = .moving
        Task { [weak self] in
            guard let self else { return }
            await revealHiddenSectionForAction()

            do {
                let initial = try await menuBarController.snapshot()
                let itemIDs = SectionResetPlanner().hiddenItemsToReveal(in: initial)
                guard !itemIDs.isEmpty else {
                    menuBarActionState = .result("Every menu bar item is already visible.")
                    refreshMenuBar()
                    return
                }

                for itemID in itemIDs {
                    let snapshot = try await menuBarController.snapshot()
                    let plan = try SectionMovePlanner().plan(
                        item: itemID,
                        to: .visible,
                        in: snapshot
                    )
                    let outcome = await menuBarController.execute(plan)
                    if outcome == .permissionRevoked {
                        handleAccessibilityRevocation()
                    }
                    guard outcome == .success else {
                        menuBarActionState = .result(
                            "Reset stopped safely. \(Self.message(for: outcome))"
                        )
                        refreshMenuBar()
                        return
                    }
                }

                menuBarActionState = .result("Reset verified. Every movable item is visible.")
                refreshMenuBar()
            } catch MenuBarAuthorizationError.permissionRevoked {
                handleAccessibilityRevocation()
                menuBarActionState = .result(Self.message(for: .permissionRevoked))
                refreshMenuBar()
            } catch {
                menuBarActionState = .result(
                    "Reset stopped safely because the menu bar changed. Refresh and try again."
                )
                refreshMenuBar()
            }
        }
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
            menuBarActionState = .result("The hidden section divider is not ready yet.")
            refreshMenuBar()
            return
        }

        isHiddenSectionCollapsed = actualState
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            self?.refreshMenuBar()
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
        let observed = try? await menuBarController.snapshot()
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
            let initialSnapshot = try await menuBarController.snapshot()
            let orderedItemIDs = SectionBatchPlanner().itemIDsToMove(
                itemIDs,
                to: section,
                in: initialSnapshot
            )
            guard !orderedItemIDs.isEmpty else {
                menuBarActionState = .result("No selected items can move to that section.")
                await restoreHiddenSectionIfNeeded(wasCollapsed)
                refreshMenuBar()
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
                "Batch move verified for \(execution.movedCount) item(s)."
            )
            await collapseHiddenSectionIfNeeded(section == .hidden || wasCollapsed)
            refreshMenuBar()
        } catch MenuBarAuthorizationError.permissionRevoked {
            handleAccessibilityRevocation()
            menuBarActionState = .result(Self.message(for: .permissionRevoked))
            refreshMenuBar()
        } catch {
            menuBarActionState = .result(
                "Batch move stopped safely because the menu bar changed. Refresh and try again."
            )
            await restoreHiddenSectionIfNeeded(wasCollapsed)
            refreshMenuBar()
        }
    }

    private func executeBatchMoves(
        _ itemIDs: [MenuBarItemID],
        to section: MenuBarSection
    ) async throws -> (movedCount: Int, failure: MoveExecutionOutcome?) {
        var movedCount = 0
        for itemID in itemIDs {
            let snapshot = try await menuBarController.snapshot()
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
        menuBarActionState = .result(
            "Moved \(movedCount) item(s), then stopped safely. " + Self.message(for: failure)
        )
        refreshMenuBar()
    }

    private func collapseHiddenSectionIfNeeded(_ shouldCollapse: Bool) async {
        guard shouldCollapse else { return }
        let observed = try? await menuBarController.snapshot()
        isHiddenSectionCollapsed = MenuBarSectionStatusController.shared.setCollapsed(
            true,
            dividerFrame: observed?.hiddenSectionDivider?.frame
        )
        try? await Task.sleep(for: .milliseconds(120))
    }

    private static func message(for outcome: MoveExecutionOutcome) -> String {
        switch outcome {
        case .success:
            "Move verified."
        case let .partial(observedIndex):
            "The item stopped at position \(observedIndex + 1)."
        case .topologyChanged:
            "The menu bar changed before the move. Refresh and try again."
        case .itemUnavailable:
            "The selected item is no longer available."
        case .permissionRevoked:
            "Accessibility access was revoked. Re-enable prismBar before moving items."
        case .menuBarUnavailable:
            "The menu bar is hidden or unavailable on this display. Show it, then try again."
        case .observationFailed:
            "The result could not be verified. Refresh before trying again."
        case .inputFailed:
            "macOS rejected the move input."
        case .timedOut:
            "macOS did not finish the move in time. Nothing else was attempted. Refresh and try again."
        }
    }
}
