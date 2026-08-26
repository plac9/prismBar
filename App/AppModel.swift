// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import Foundation
import Observation
import prismBarAccessibility
import prismBarCore
import prismBarEngine
import prismPluginKit

enum MenuBarLoadingState: Equatable {
    case waitingForPermission
    case loading
    case ready
    case unavailable
}

enum MenuBarActionState: Equatable {
    case idle
    case moving
    case result(String)
}

enum PluginLoadingState: Equatable {
    case idle
    case loading
    case ready
    case unavailable
    case paused
    case disabled
}

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    private(set) var accessibilityState: AccessibilityPermissionState
    private(set) var menuBarState: MenuBarLoadingState = .waitingForPermission
    private(set) var menuBarSnapshot: MenuBarSnapshot?
    var menuBarActionState: MenuBarActionState = .idle
    var isHiddenSectionCollapsed = false
    private(set) var pluginState: PluginLoadingState = .idle
    private(set) var pluginPanel: PluginPanelUpdate?
    private(set) var pluginMessage: String?
    private(set) var isPluginActionInProgress = false
    private(set) var isPluginEnabled = false

    private static let requestHistoryKey = "accessibility.hasRequested"
    private let defaults: UserDefaults
    private var permissionSession: AccessibilityPermissionSession
    private var permissionRevision = 0
    private var topologyRevision = 0
    let menuBarController = LiveMenuBarController()
    private let pluginRegistry: BundledPluginRegistry?
    private let pluginRegistration: BundledPluginRegistration?
    private let pluginClient: BundledPluginClient?
    private var pluginRevision = 0

    var isMenuBarActionInProgress: Bool {
        menuBarActionState == .moving
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let registry = try? PluginCatalog.makeRegistry()
        let registration = registry?.registration(identifier: PluginCatalog.prismCalcIdentifier)
        pluginRegistry = registry
        pluginRegistration = registration
        pluginClient = registration.flatMap { try? BundledPluginClient(registration: $0) }
        if let registration {
            isPluginEnabled = defaults.object(forKey: registration.preferenceKey) as? Bool
                ?? registration.isEnabledByDefault
        }
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

extension AppModel {
    var bundledPluginRegistrations: [BundledPluginRegistration] {
        pluginRegistry?.registrations ?? []
    }

    func refreshPlugin() {
        guard isPluginEnabled else {
            pluginState = .disabled
            pluginPanel = nil
            pluginMessage = "prismCalc is disabled."
            return
        }
        guard let pluginClient else {
            pluginState = .unavailable
            pluginMessage = "The bundled plugin could not be configured."
            return
        }

        pluginRevision += 1
        let revision = pluginRevision
        pluginState = .loading
        pluginMessage = nil

        Task { [weak self] in
            do {
                let update = try await pluginClient.loadPanel()
                guard let self, revision == pluginRevision else { return }
                pluginPanel = update
                pluginState = .ready
            } catch PluginClientError.disabledForSession {
                guard let self, revision == pluginRevision else { return }
                pluginState = .paused
                pluginMessage = "prismCalc paused after repeated failures. Retry when ready."
            } catch let error as PluginClientError {
                guard let self, revision == pluginRevision else { return }
                pluginState = .unavailable
                pluginMessage = Self.pluginFailureMessage(error)
            } catch {
                guard let self, revision == pluginRevision else { return }
                pluginState = .unavailable
                pluginMessage = "prismCalc is temporarily unavailable."
            }
        }
    }

    func loadPluginIfNeeded() {
        guard pluginState == .idle else { return }
        refreshPlugin()
    }

    func setPluginEnabled(_ enabled: Bool) {
        guard let pluginRegistration else { return }
        isPluginEnabled = enabled
        defaults.set(enabled, forKey: pluginRegistration.preferenceKey)
        pluginRevision += 1
        pluginClient?.stop()
        pluginPanel = nil
        isPluginActionInProgress = false

        if enabled {
            pluginClient?.retryAfterFailure()
            pluginState = .idle
            pluginMessage = nil
            refreshPlugin()
        } else {
            pluginState = .disabled
            pluginMessage = "\(pluginRegistration.displayName) is disabled."
        }
    }

    func retryPlugin() {
        guard isPluginEnabled else { return }
        pluginClient?.retryAfterFailure()
        refreshPlugin()
    }

    func invokePluginCommand(_ commandIdentifier: String) {
        guard isPluginEnabled, let pluginClient, !isPluginActionInProgress else { return }

        pluginRevision += 1
        let revision = pluginRevision
        isPluginActionInProgress = true
        pluginMessage = nil

        Task { [weak self] in
            defer {
                if let self, revision == pluginRevision {
                    isPluginActionInProgress = false
                }
            }
            do {
                let update = try await pluginClient.invoke(commandIdentifier)
                guard let self, revision == pluginRevision else { return }
                pluginPanel = update
                pluginState = .ready
                applyPluginMutations(update.mutations)
            } catch PluginClientError.disabledForSession {
                guard let self, revision == pluginRevision else { return }
                pluginState = .paused
                pluginMessage = "prismCalc paused after repeated failures. Retry when ready."
            } catch let error as PluginClientError {
                guard let self, revision == pluginRevision else { return }
                pluginState = .unavailable
                pluginMessage = Self.pluginFailureMessage(error)
            } catch {
                guard let self, revision == pluginRevision else { return }
                pluginState = .unavailable
                pluginMessage = "The command could not be completed."
            }
        }
    }

    private func applyPluginMutations(_ mutations: [PluginMutation]) {
        for mutation in mutations {
            switch mutation {
            case let .copyText(value):
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                if pasteboard.setString(value, forType: .string) {
                    pluginMessage = "Result copied."
                } else {
                    pluginMessage = "The result could not be copied."
                }
            case let .openApplication(bundleIdentifier):
                guard pluginRegistration?.allowedApplicationIdentifiers.contains(bundleIdentifier) == true,
                      let applicationURL = NSWorkspace.shared.urlForApplication(
                          withBundleIdentifier: bundleIdentifier
                      ),
                      SignedApplicationCode.isValid(
                          at: applicationURL,
                          bundleIdentifier: bundleIdentifier,
                          teamIdentifier: "N8A5T2PZY9"
                      )
                else {
                    pluginMessage = "A verified LaClair Technologies copy of prismCalc is not installed."
                    continue
                }
                NSWorkspace.shared.openApplication(
                    at: applicationURL,
                    configuration: NSWorkspace.OpenConfiguration()
                ) { [weak self] _, error in
                    guard error != nil else { return }
                    Task { @MainActor in
                        self?.pluginMessage = "prismCalc could not be opened."
                    }
                }
            }
        }
    }

    private static func pluginFailureMessage(_ error: PluginClientError) -> String {
        switch error {
        case .busy:
            "prismCalc is already completing another request."
        case .cancelled:
            "The prismCalc request was cancelled."
        case .disabledForSession:
            "prismCalc is paused for this session."
        default:
            pluginTransportFailureMessage(error)
        }
    }

    private static func pluginTransportFailureMessage(_ error: PluginClientError) -> String {
        switch error {
        case .connectionInterrupted:
            "The isolated prismCalc connection was interrupted."
        case .invalidConnection:
            "prismCalc could not open its bundled service connection."
        case .invalidReply:
            "prismCalc returned an invalid service reply."
        case .invalidResponse:
            "prismCalc returned a response that failed validation."
        case .rejected:
            "The isolated prismCalc service rejected the request."
        case .timedOut:
            "The isolated prismCalc service did not respond in time."
        case .trustRejected:
            "prismCalc could not verify the bundled service signature."
        case .unavailable:
            "prismCalc is temporarily unavailable."
        case .busy, .cancelled, .disabledForSession:
            "prismCalc is temporarily unavailable."
        case .serviceInvalidRequest, .serviceInvalidResponse, .serviceRejectedRequest:
            pluginServiceFailureMessage(error)
        }
    }

    private static func pluginServiceFailureMessage(_ error: PluginClientError) -> String {
        switch error {
        case .serviceInvalidRequest:
            "prismCalc could not decode the host request."
        case .serviceInvalidResponse:
            "prismCalc could not encode its response."
        case .serviceRejectedRequest:
            "prismCalc rejected the decoded request."
        default:
            "prismCalc is temporarily unavailable."
        }
    }
}
