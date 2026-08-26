// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Observation
import prismBarAccessibility
import prismBarCore
import prismBarEngine

enum MenuBarLoadingState: Equatable {
    case waitingForPermission
    case loading
    case ready
    case unavailable
}

enum MenuBarActionState: Equatable {
    case idle
    case moving(MenuBarItemID)
    case result(String)
}

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    private(set) var accessibilityState: AccessibilityPermissionState
    private(set) var menuBarState: MenuBarLoadingState = .waitingForPermission
    private(set) var menuBarSnapshot: MenuBarSnapshot?
    private(set) var menuBarActionState: MenuBarActionState = .idle

    private static let requestHistoryKey = "accessibility.hasRequested"
    private let defaults: UserDefaults
    private var permissionSession: AccessibilityPermissionSession
    private var permissionRevision = 0
    private var topologyRevision = 0
    private let menuBarController = LiveMenuBarController()

    var isMenuBarActionInProgress: Bool {
        if case .moving = menuBarActionState {
            return true
        }
        return false
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        permissionSession = AccessibilityPermissionSession(
            evaluator: AccessibilityPermissionEvaluator(
                expectedBundleIdentifier: "com.laclairtech.prismbar",
                expectedTeamIdentifier: "N8A5T2PZY9"
            ),
            hasRequestedAccess: defaults.bool(forKey: Self.requestHistoryKey)
        )
        accessibilityState = .requiresStableInstall
        refreshAccessibility()
    }

    func refreshAccessibility() {
        permissionRevision += 1
        let revision = permissionRevision
        let isStableInstall = StableInstall.isCanonical(Bundle.main.bundleURL)

        Task { [weak self] in
            let isTrusted = await Self.readAccessibilityTrust(prompt: false)

            guard let self, revision == permissionRevision else { return }
            accessibilityState = permissionSession.refreshTrust(
                isStableInstall: isStableInstall,
                isTrusted: isTrusted
            )
            if accessibilityState == .granted {
                refreshMenuBar()
            } else {
                invalidateMenuBar()
            }
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
                accessibilityState = prerequisiteState
                return
            }

            let isTrusted = await Self.readAccessibilityTrust(prompt: true)
            guard revision == permissionRevision else { return }

            accessibilityState = permissionSession.requestAccess(
                isStableInstall: isStableInstall,
                identity: identity
            ) { isTrusted }
            defaults.set(permissionSession.hasRequestedAccess, forKey: Self.requestHistoryKey)

            if accessibilityState == .granted {
                refreshMenuBar()
            } else {
                invalidateMenuBar()
            }
        }
    }

    func refreshMenuBar() {
        guard accessibilityState == .granted else {
            invalidateMenuBar()
            return
        }

        topologyRevision += 1
        let revision = topologyRevision
        menuBarState = .loading

        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await menuBarController.snapshot()
                guard revision == topologyRevision else { return }
                menuBarSnapshot = snapshot
                menuBarState = .ready
            } catch MenuBarDiscoveryError.notTrusted {
                guard revision == topologyRevision else { return }
                accessibilityState = .denied
                invalidateMenuBar()
            } catch {
                guard revision == topologyRevision else { return }
                menuBarSnapshot = nil
                menuBarState = .unavailable
            }
        }
    }

    func moveMenuBarItem(_ itemID: MenuBarItemID, to destinationIndex: Int) {
        guard let snapshot = menuBarSnapshot else { return }

        let plan: MovePlan
        do {
            plan = try MovePlanner().plan(item: itemID, to: destinationIndex, in: snapshot)
        } catch {
            menuBarActionState = .result("That item cannot be moved to the requested position.")
            return
        }

        menuBarActionState = .moving(itemID)
        Task { [weak self] in
            guard let self else { return }
            let outcome = await menuBarController.execute(plan)
            menuBarActionState = .result(Self.message(for: outcome))
            refreshMenuBar()
        }
    }

    private func invalidateMenuBar() {
        topologyRevision += 1
        menuBarSnapshot = nil
        menuBarState = .waitingForPermission
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
        case .observationFailed:
            "The result could not be verified. Refresh before trying again."
        case .inputFailed:
            "macOS rejected the move input."
        }
    }

    private nonisolated static func readCodeIdentity() async -> CodeIdentity? {
        await Task.detached(priority: .userInitiated) {
            CurrentCodeIdentity.read()
        }.value
    }

    private nonisolated static func readAccessibilityTrust(prompt: Bool) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            SystemAccessibilityTrust.isTrusted(prompt: prompt)
        }.value
    }
}
