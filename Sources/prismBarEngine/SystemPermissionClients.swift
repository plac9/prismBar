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
        guard SignedApplicationCode.isValid(
            at: Bundle.main.bundleURL,
            bundleIdentifier: expectedBundleIdentifier,
            teamIdentifier: expectedTeamIdentifier
        ) else {
            return nil
        }

        return CodeIdentity(
            bundleIdentifier: expectedBundleIdentifier,
            teamIdentifier: expectedTeamIdentifier
        )
    }
}

public enum SignedApplicationCode {
    public static func requirement(
        bundleIdentifier: String,
        teamIdentifier: String
    ) -> String? {
        guard isSafeBundleIdentifier(bundleIdentifier),
              teamIdentifier.utf8.count == 10,
              teamIdentifier.utf8.allSatisfy({ byte in
                  (0x30 ... 0x39).contains(byte) || (0x41 ... 0x5A).contains(byte)
              })
        else {
            return nil
        }

        return #"identifier "\#(bundleIdentifier)" and anchor apple generic "# +
            #"and certificate leaf[subject.OU] = "\#(teamIdentifier)""#
    }

    public static func isValid(
        at applicationURL: URL,
        bundleIdentifier: String,
        teamIdentifier: String
    ) -> Bool {
        guard let requirementText = requirement(
            bundleIdentifier: bundleIdentifier,
            teamIdentifier: teamIdentifier
        ) else {
            return false
        }

        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(applicationURL as CFURL, [], &code) == errSecSuccess,
              let code
        else {
            return false
        }

        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(
            requirementText as CFString,
            [],
            &requirement
        ) == errSecSuccess,
              let requirement
        else {
            return false
        }

        return SecStaticCodeCheckValidity(code, [], requirement) == errSecSuccess
    }

    private static func isSafeBundleIdentifier(_ identifier: String) -> Bool {
        guard !identifier.isEmpty, identifier.utf8.count <= 255 else { return false }
        let segments = identifier.utf8.split(separator: 0x2E, omittingEmptySubsequences: false)
        return segments.count >= 2 && segments.allSatisfy { segment in
            guard let first = segment.first,
                  let last = segment.last,
                  isASCIIAlphanumeric(first),
                  isASCIIAlphanumeric(last)
            else {
                return false
            }
            return segment.allSatisfy { isASCIIAlphanumeric($0) || $0 == 0x2D }
        }
    }

    private static func isASCIIAlphanumeric(_ byte: UInt8) -> Bool {
        (0x30 ... 0x39).contains(byte) ||
            (0x41 ... 0x5A).contains(byte) ||
            (0x61 ... 0x7A).contains(byte)
    }
}
