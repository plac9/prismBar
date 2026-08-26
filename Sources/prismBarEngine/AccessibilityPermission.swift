// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct CodeIdentity: Equatable, Sendable {
    public let bundleIdentifier: String
    public let teamIdentifier: String

    public init(bundleIdentifier: String, teamIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
        self.teamIdentifier = teamIdentifier
    }
}

public enum AccessibilityPermissionState: Equatable, Sendable {
    case requiresStableInstall
    case identityMismatch
    case notRequested
    case denied
    case granted
}

public struct AccessibilityPermissionSnapshot: Equatable, Sendable {
    public let isStableInstall: Bool
    public let identity: CodeIdentity?
    public let isTrusted: Bool
    public let hasRequestedAccess: Bool

    public init(
        isStableInstall: Bool,
        identity: CodeIdentity?,
        isTrusted: Bool,
        hasRequestedAccess: Bool
    ) {
        self.isStableInstall = isStableInstall
        self.identity = identity
        self.isTrusted = isTrusted
        self.hasRequestedAccess = hasRequestedAccess
    }
}

public struct AccessibilityPermissionEvaluator: Sendable {
    private let expectedIdentity: CodeIdentity

    public init(expectedBundleIdentifier: String, expectedTeamIdentifier: String) {
        expectedIdentity = CodeIdentity(
            bundleIdentifier: expectedBundleIdentifier,
            teamIdentifier: expectedTeamIdentifier
        )
    }

    public func state(for snapshot: AccessibilityPermissionSnapshot) -> AccessibilityPermissionState {
        guard snapshot.isStableInstall else {
            return .requiresStableInstall
        }
        guard snapshot.identity == expectedIdentity else {
            return .identityMismatch
        }
        if snapshot.isTrusted {
            return .granted
        }
        return snapshot.hasRequestedAccess ? .denied : .notRequested
    }
}

public struct AccessibilityPermissionSession: Sendable {
    public private(set) var hasRequestedAccess: Bool

    private let evaluator: AccessibilityPermissionEvaluator

    public init(
        evaluator: AccessibilityPermissionEvaluator,
        hasRequestedAccess: Bool = false
    ) {
        self.evaluator = evaluator
        self.hasRequestedAccess = hasRequestedAccess
    }

    public func refresh(
        isStableInstall: Bool,
        identity: CodeIdentity?,
        isTrusted: Bool
    ) -> AccessibilityPermissionState {
        evaluator.state(for: AccessibilityPermissionSnapshot(
            isStableInstall: isStableInstall,
            identity: identity,
            isTrusted: isTrusted,
            hasRequestedAccess: hasRequestedAccess
        ))
    }

    public func refreshTrust(
        isStableInstall: Bool,
        isTrusted: Bool
    ) -> AccessibilityPermissionState {
        guard isStableInstall else {
            return .requiresStableInstall
        }
        if isTrusted {
            return .granted
        }
        return hasRequestedAccess ? .denied : .notRequested
    }

    public mutating func requestAccess(
        isStableInstall: Bool,
        identity: CodeIdentity?,
        trustRequest: () -> Bool
    ) -> AccessibilityPermissionState {
        let prerequisiteState = refresh(
            isStableInstall: isStableInstall,
            identity: identity,
            isTrusted: false
        )
        guard prerequisiteState != .requiresStableInstall,
              prerequisiteState != .identityMismatch
        else {
            return prerequisiteState
        }

        hasRequestedAccess = true
        return refresh(
            isStableInstall: isStableInstall,
            identity: identity,
            isTrusted: trustRequest()
        )
    }
}

public enum StableInstall {
    public static let canonicalURL = URL(fileURLWithPath: "/Applications/prismBar.app", isDirectory: true)

    public static func isCanonical(_ bundleURL: URL) -> Bool {
        bundleURL.standardizedFileURL.path == canonicalURL.standardizedFileURL.path
    }
}
