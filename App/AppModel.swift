// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Observation
import prismBarAccessibility
import prismBarCore
import prismBarEngine

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    private(set) var accessibilityState: AccessibilityPermissionState
    private(set) var menuBarState: MenuBarLoadingState = .waitingForPermission
    private(set) var menuBarSnapshot: MenuBarSnapshot?
    private(set) var currentActionReceipt: MenuBarActionReceipt?
    var menuBarActionState: MenuBarActionState = .idle
    var isHiddenSectionCollapsed = false

    private static let requestHistoryKey = "accessibility.hasRequested"
    private let defaults: UserDefaults
    private var permissionSession: AccessibilityPermissionSession
    private var permissionRevision = 0
    private var topologyRevision = 0
    private var isRecoveryRefreshPending = false
    private var recoveryLedger = MenuBarRecoveryLedger()
    let menuBarController: LiveMenuBarController
    private let menuBarSnapshotReader: any MenuBarSnapshotReading

    var recentActionReceipts: [MenuBarActionReceipt] {
        recoveryLedger.entries.map(\.receipt)
    }

    var canRecoverLastAction: Bool {
        guard let menuBarSnapshot else { return false }
        return recoveryLedger.latestCompatible(with: menuBarSnapshot) != nil
    }

    var isMenuBarActionInProgress: Bool {
        if case .moving = menuBarActionState {
            return true
        }
        return false
    }

    init(
        defaults: UserDefaults = .standard,
        automaticallyRefresh: Bool = true,
        snapshotReader: (any MenuBarSnapshotReading)? = nil
    ) {
        let liveMenuBarController = LiveMenuBarController()
        self.defaults = defaults
        menuBarController = liveMenuBarController
        menuBarSnapshotReader = snapshotReader ?? liveMenuBarController
        permissionSession = AccessibilityPermissionSession(
            evaluator: AccessibilityPermissionEvaluator(
                expectedBundleIdentifier: "com.laclairtech.prismbar",
                expectedTeamIdentifier: "N8A5T2PZY9"
            ),
            hasRequestedAccess: defaults.bool(forKey: Self.requestHistoryKey)
        )
        accessibilityState = .requiresStableInstall
        if automaticallyRefresh {
            refreshAccessibility()
        }
    }

    func refreshAccessibility() {
        permissionRevision += 1
        let revision = permissionRevision
        let isStableInstall = StableInstall.isCanonical(Bundle.main.bundleURL)

        Task { [weak self] in
            let isTrusted = await Self.readMenuBarControlTrust(prompt: false)

            guard let self, revision == permissionRevision else { return }
            let refreshedState = permissionSession.refreshTrust(
                isStableInstall: isStableInstall,
                isTrusted: isTrusted
            )
            acceptAccessibilityState(refreshedState)
        }
    }

    func requestAccessibility() {
        permissionRevision += 1
        let revision = permissionRevision
        let isStableInstall = StableInstall.isCanonical(Bundle.main.bundleURL)

        Task { [weak self] in
            let identity = await Self.readCodeIdentity()
            guard let self, revision == permissionRevision else { return }

            let prerequisiteState = permissionSession.refresh(
                isStableInstall: isStableInstall,
                identity: identity,
                isTrusted: false
            )
            guard prerequisiteState != .requiresStableInstall,
                  prerequisiteState != .identityMismatch
            else {
                acceptAccessibilityState(prerequisiteState)
                return
            }

            let isTrusted = await Self.readMenuBarControlTrust(prompt: true)
            guard revision == permissionRevision else { return }

            let requestedState = permissionSession.requestAccess(
                isStableInstall: isStableInstall,
                identity: identity
            ) { isTrusted }
            defaults.set(permissionSession.hasRequestedAccess, forKey: Self.requestHistoryKey)
            acceptAccessibilityState(requestedState)
        }
    }

    func refreshMenuBar(preservingActionResult: Bool = false) {
        guard accessibilityState == .granted else {
            clearVisibleMenuBarAction(unlessPreserved: preservingActionResult)
            invalidateMenuBar()
            return
        }
        guard menuBarState != .loading else {
            if preservingActionResult {
                isRecoveryRefreshPending = true
            }
            return
        }
        clearVisibleMenuBarAction(unlessPreserved: preservingActionResult)

        topologyRevision += 1
        let revision = topologyRevision
        menuBarState = .loading

        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await menuBarSnapshotReader.snapshot(
                    deadline: OperationDeadline(timeout: .seconds(8))
                )
                guard revision == topologyRevision else { return }
                menuBarSnapshot = snapshot
                menuBarState = .ready
                runPendingRecoveryRefreshIfNeeded()
            } catch MenuBarAuthorizationError.permissionRevoked {
                guard revision == topologyRevision else { return }
                handleAccessibilityRevocation()
            } catch {
                guard revision == topologyRevision else { return }
                menuBarSnapshot = nil
                menuBarState = .unavailable
                runPendingRecoveryRefreshIfNeeded()
            }
        }
    }

    func acceptVerifiedMenuBarSnapshot(_ snapshot: MenuBarSnapshot) {
        topologyRevision += 1
        isRecoveryRefreshPending = false
        menuBarSnapshot = snapshot
        menuBarState = .ready
    }

    private func invalidateMenuBar() {
        topologyRevision += 1
        isRecoveryRefreshPending = false
        menuBarSnapshot = nil
        menuBarState = .waitingForPermission
    }

    private func runPendingRecoveryRefreshIfNeeded() {
        guard isRecoveryRefreshPending else { return }
        isRecoveryRefreshPending = false
        refreshMenuBar(preservingActionResult: true)
    }

    private func clearVisibleMenuBarAction(unlessPreserved isPreserved: Bool) {
        guard !isPreserved else { return }
        clearVisibleMenuBarAction()
    }

    func handleAccessibilityRevocation() {
        accessibilityState = .denied
        recoveryLedger.clear()
        clearVisibleMenuBarAction()
        invalidateMenuBar()
    }

    func acceptAccessibilityState(
        _ state: AccessibilityPermissionState,
        refreshMenuBarWhenGranted: Bool = true
    ) {
        let didLoseTrust = accessibilityState == .granted && state != .granted
        accessibilityState = state

        if state == .granted {
            if refreshMenuBarWhenGranted {
                refreshMenuBar()
            }
            return
        }

        if didLoseTrust {
            recoveryLedger.clear()
            clearVisibleMenuBarAction()
        }
        invalidateMenuBar()
    }

    @discardableResult
    func beginMenuBarAction(
        kind: MenuBarActionKind,
        before: MenuBarSnapshot,
        itemID: MenuBarItemID?
    ) -> MenuBarActionReceipt {
        let receipt = recoveryLedger.begin(kind: kind, before: before)
        currentActionReceipt = receipt
        menuBarActionState = .moving(itemID: itemID)
        return receipt
    }

    func completeMenuBarAction(
        id: MenuBarActionID,
        result: MenuBarActionResult,
        after: MenuBarSnapshot?
    ) {
        guard let receipt = recoveryLedger.complete(id: id, result: result, after: after) else {
            return
        }
        currentActionReceipt = receipt
        menuBarActionState = .result(result)
    }

    func beginMenuBarRecovery() -> MenuBarRecoveryAttempt? {
        guard let menuBarSnapshot,
              let attempt = recoveryLedger.beginRecovery(with: menuBarSnapshot)
        else {
            return nil
        }
        currentActionReceipt = attempt.receipt
        menuBarActionState = .moving(itemID: nil)
        return attempt
    }

    func completeMenuBarRecovery(
        id: MenuBarActionID,
        result: MenuBarActionResult,
        after: MenuBarSnapshot?
    ) {
        guard let receipt = recoveryLedger.completeRecovery(
            id: id,
            result: result,
            after: after
        ) else {
            return
        }
        currentActionReceipt = receipt
        menuBarActionState = .result(receipt.result ?? result)
    }

    private func clearVisibleMenuBarAction() {
        currentActionReceipt = nil
        menuBarActionState = .idle
    }

    private nonisolated static func readCodeIdentity() async -> CodeIdentity? {
        await Task.detached(priority: .userInitiated) {
            CurrentCodeIdentity.read()
        }.value
    }

    private nonisolated static func readMenuBarControlTrust(prompt: Bool) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            SystemMenuBarControlTrust.isTrusted(prompt: prompt)
        }.value
    }
}
