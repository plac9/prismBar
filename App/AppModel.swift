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
    var menuBarActionState: MenuBarActionState = .idle
    var isHiddenSectionCollapsed = false

    private static let requestHistoryKey = "accessibility.hasRequested"
    private let defaults: UserDefaults
    private var permissionSession: AccessibilityPermissionSession
    private var permissionRevision = 0
    private var topologyRevision = 0
    let menuBarController = LiveMenuBarController()

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

    func refreshMenuBar(preservingActionResult: Bool = false) {
        if !preservingActionResult {
            menuBarActionState = .idle
        }

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
                let snapshot = try await menuBarController.snapshot(
                    deadline: OperationDeadline(timeout: .seconds(8))
                )
                guard revision == topologyRevision else { return }
                menuBarSnapshot = snapshot
                menuBarState = .ready
            } catch MenuBarAuthorizationError.permissionRevoked {
                guard revision == topologyRevision else { return }
                handleAccessibilityRevocation()
            } catch {
                guard revision == topologyRevision else { return }
                menuBarSnapshot = nil
                menuBarState = .unavailable
            }
        }
    }

    func acceptVerifiedMenuBarSnapshot(_ snapshot: MenuBarSnapshot) {
        topologyRevision += 1
        menuBarSnapshot = snapshot
        menuBarState = .ready
    }

    private func invalidateMenuBar() {
        topologyRevision += 1
        menuBarSnapshot = nil
        menuBarState = .waitingForPermission
    }

    func handleAccessibilityRevocation() {
        accessibilityState = .denied
        invalidateMenuBar()
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
