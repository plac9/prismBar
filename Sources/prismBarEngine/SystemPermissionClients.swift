// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@preconcurrency import ApplicationServices
import Foundation
import Security

public enum SystemAccessibilityTrust {
    public static func isTrusted(prompt: Bool = false) -> Bool {
        guard prompt else {
            return AXIsProcessTrusted()
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

public enum CurrentCodeIdentity {
    private static let expectedBundleIdentifier = "com.laclairtech.prismbar"
    private static let expectedTeamIdentifier = "N8A5T2PZY9"

    public static func read() -> CodeIdentity? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(
            Bundle.main.bundleURL as CFURL,
            [],
            &code
        ) == errSecSuccess,
            let code
        else {
            return nil
        }

        let requirementText =
            #"identifier "com.laclairtech.prismbar" and anchor apple generic "# +
            #"and certificate leaf[subject.OU] = "N8A5T2PZY9""#
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(
            requirementText as CFString,
            [],
            &requirement
        ) == errSecSuccess,
            let requirement,
            SecStaticCodeCheckValidity(code, [], requirement) == errSecSuccess
        else {
            return nil
        }

        return CodeIdentity(
            bundleIdentifier: expectedBundleIdentifier,
            teamIdentifier: expectedTeamIdentifier
        )
    }
}
