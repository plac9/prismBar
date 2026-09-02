// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@testable import prismBarEngine
import Testing

@Suite("Accessibility permission state")
struct AccessibilityPermissionTests {
    private let evaluator = AccessibilityPermissionEvaluator(
        expectedBundleIdentifier: "com.laclairtech.prismbar",
        expectedTeamIdentifier: "N8A5T2PZY9"
    )

    @Test("requires a stable Applications install before prompting")
    func requiresStableInstall() {
        let snapshot = permissionSnapshot(isStableInstall: false)

        #expect(evaluator.state(for: snapshot) == .requiresStableInstall)
    }

    @Test("rejects a build whose signing identity does not match")
    func rejectsIdentityMismatch() {
        let snapshot = permissionSnapshot(
            identity: CodeIdentity(
                bundleIdentifier: "com.example.copy",
                teamIdentifier: "OTHERTEAM"
            )
        )

        #expect(evaluator.state(for: snapshot) == .identityMismatch)
    }

    @Test("trust is always authoritative")
    func trustsLiveGrantedState() {
        let snapshot = permissionSnapshot(isTrusted: true, hasRequestedAccess: false)

        #expect(evaluator.state(for: snapshot) == .granted)
    }

    @Test("menu bar control requires Accessibility and event posting")
    func requiresBothControlAuthorities() {
        #expect(MenuBarControlTrust.isGranted(accessibility: true, eventPosting: true))
        #expect(!MenuBarControlTrust.isGranted(accessibility: false, eventPosting: true))
        #expect(!MenuBarControlTrust.isGranted(accessibility: true, eventPosting: false))
        #expect(!MenuBarControlTrust.isGranted(accessibility: false, eventPosting: false))
    }

    @Test("distinguishes first request from a denied request")
    func distinguishesRequestHistory() {
        let firstRequest = permissionSnapshot(hasRequestedAccess: false)
        let denied = permissionSnapshot(hasRequestedAccess: true)

        #expect(evaluator.state(for: firstRequest) == .notRequested)
        #expect(evaluator.state(for: denied) == .denied)
    }

    @Test("accepts only the canonical stable install path")
    func validatesStableInstallPath() {
        #expect(StableInstall.isCanonical(URL(fileURLWithPath: "/Applications/prismBar.app")))
        #expect(!StableInstall.isCanonical(URL(fileURLWithPath: "/tmp/prismBar.app")))
        #expect(!StableInstall.isCanonical(URL(fileURLWithPath: "/Applications/Other.app")))
    }

    @Test("does not prompt before install and identity gates pass")
    func gatesPrompt() {
        var session = AccessibilityPermissionSession(evaluator: evaluator)
        var promptCount = 0

        let state = session.requestAccess(
            isStableInstall: false,
            identity: nil
        ) {
            promptCount += 1
            return false
        }

        #expect(state == .requiresStableInstall)
        #expect(promptCount == 0)
        #expect(!session.hasRequestedAccess)
    }

    @Test("records a request while keeping live trust authoritative")
    func refreshesLiveTrust() {
        var session = AccessibilityPermissionSession(evaluator: evaluator)
        let identity = CodeIdentity(
            bundleIdentifier: "com.laclairtech.prismbar",
            teamIdentifier: "N8A5T2PZY9"
        )

        let denied = session.requestAccess(
            isStableInstall: true,
            identity: identity
        ) { false }
        let granted = session.refresh(
            isStableInstall: true,
            identity: identity,
            isTrusted: true
        )

        #expect(denied == .denied)
        #expect(session.hasRequestedAccess)
        #expect(granted == .granted)
    }

    @Test("refreshes live trust without revalidating the unchanged running code")
    func refreshesTrustWithoutIdentityWork() {
        let session = AccessibilityPermissionSession(
            evaluator: evaluator,
            hasRequestedAccess: true
        )

        #expect(session.refreshTrust(isStableInstall: true, isTrusted: false) == .denied)
        #expect(session.refreshTrust(isStableInstall: true, isTrusted: true) == .granted)
        #expect(session.refreshTrust(isStableInstall: false, isTrusted: true) == .requiresStableInstall)
    }

    @Test("builds only exact safe requirements for external applications")
    func boundsExternalApplicationRequirements() {
        #expect(
            SignedApplicationCode.requirement(
                bundleIdentifier: "com.laclairtech.prismcalc",
                teamIdentifier: "N8A5T2PZY9"
            ) == "identifier \"com.laclairtech.prismcalc\" and anchor apple generic " +
                "and certificate leaf[subject.OU] = \"N8A5T2PZY9\""
        )
        #expect(SignedApplicationCode.requirement(
            bundleIdentifier: "com.example.unsafe\" or true",
            teamIdentifier: "N8A5T2PZY9"
        ) == nil)
        #expect(SignedApplicationCode.requirement(
            bundleIdentifier: "com.laclairtech.prismcalc",
            teamIdentifier: "bad-team"
        ) == nil)
    }

    private func permissionSnapshot(
        isStableInstall: Bool = true,
        identity: CodeIdentity = CodeIdentity(
            bundleIdentifier: "com.laclairtech.prismbar",
            teamIdentifier: "N8A5T2PZY9"
        ),
        isTrusted: Bool = false,
        hasRequestedAccess: Bool = false
    ) -> AccessibilityPermissionSnapshot {
        AccessibilityPermissionSnapshot(
            isStableInstall: isStableInstall,
            identity: identity,
            isTrusted: isTrusted,
            hasRequestedAccess: hasRequestedAccess
        )
    }
}
