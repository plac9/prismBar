// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import prismBarEngine

extension AppModel {
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
            dividerFrame: displayedSnapshot.hiddenSectionDivider?.frame
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
            await self?.verifyHiddenSectionState(
                collapsed,
                receiptID: pendingReceipt.id
            )
        }
    }

    func revealHiddenSectionForAction() async {
        guard isHiddenSectionCollapsed else { return }
        isHiddenSectionCollapsed = MenuBarSectionStatusController.shared.setCollapsed(
            false,
            dividerFrame: menuBarSnapshot?.hiddenSectionDivider?.frame
        )
        try? await Task.sleep(for: .milliseconds(120))
    }

    func restoreHiddenSectionIfNeeded(_ shouldCollapse: Bool) async {
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

    func collapseHiddenSectionIfNeeded(_ shouldCollapse: Bool) async {
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

private extension AppModel {
    func verifyHiddenSectionState(
        _ collapsed: Bool,
        receiptID: MenuBarActionID
    ) async {
        try? await Task.sleep(for: .milliseconds(120))
        do {
            let observed = try await menuBarController.snapshot(
                deadline: OperationDeadline(timeout: .seconds(8))
            )
            acceptVerifiedMenuBarSnapshot(observed)
            completeMenuBarAction(
                id: receiptID,
                result: .success(collapsed ? "Hidden items folded." : "Hidden items revealed."),
                after: observed
            )
        } catch MenuBarAuthorizationError.permissionRevoked {
            handleAccessibilityRevocation()
            return
        } catch {
            completeMenuBarAction(
                id: receiptID,
                result: .failure("prismBar could not verify the hidden section state."),
                after: nil
            )
        }
        refreshMenuBar(preservingActionResult: true)
    }
}
