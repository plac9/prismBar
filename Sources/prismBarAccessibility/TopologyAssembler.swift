// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CryptoKit
import Foundation
import prismBarCore

private enum AccessibilityMetadataLimits {
    static let bundleIdentifierCharacters = 255
    static let ownerDisplayNameCharacters = 120
    static let stableTokenCharacters = 512
    static let itemDisplayNameCharacters = 120
    static let surfaceTokenCharacters = 120

    static func bounded(_ value: String, characters: Int) -> String {
        String(value.unicodeScalars.prefix(characters))
    }
}

public struct RunningApplicationDescriptor: Equatable, Sendable {
    public let processIdentifier: Int32
    public let bundleIdentifier: String?
    public let displayName: String
    public let isSelf: Bool

    public init(
        processIdentifier: Int32,
        bundleIdentifier: String?,
        displayName: String,
        isSelf: Bool
    ) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier.map {
            AccessibilityMetadataLimits.bounded(
                $0,
                characters: AccessibilityMetadataLimits.bundleIdentifierCharacters
            )
        }
        self.displayName = AccessibilityMetadataLimits.bounded(
            displayName,
            characters: AccessibilityMetadataLimits.ownerDisplayNameCharacters
        )
        self.isSelf = isSelf
    }
}

public struct MenuBarObservation: Equatable, Sendable {
    public let owner: RunningApplicationDescriptor
    public let stableToken: String
    public let displayName: String?
    public let frame: MenuBarItemFrame?
    public let isEnabled: Bool
    public let surfaceToken: String?

    public init(
        owner: RunningApplicationDescriptor,
        stableToken: String,
        displayName: String?,
        frame: MenuBarItemFrame?,
        isEnabled: Bool,
        surfaceToken: String? = nil
    ) {
        self.owner = owner
        self.stableToken = AccessibilityMetadataLimits.bounded(
            stableToken,
            characters: AccessibilityMetadataLimits.stableTokenCharacters
        )
        self.displayName = displayName.map {
            AccessibilityMetadataLimits.bounded(
                $0,
                characters: AccessibilityMetadataLimits.itemDisplayNameCharacters
            )
        }
        self.frame = frame
        self.isEnabled = isEnabled
        self.surfaceToken = surfaceToken.map {
            AccessibilityMetadataLimits.bounded(
                $0,
                characters: AccessibilityMetadataLimits.surfaceTokenCharacters
            )
        }
    }
}

public struct TopologyAssembler: Sendable {
    private static let maximumDisplayNameLength = 120
    private static let maximumObservations = 2_048
    private static let systemBundleIdentifiers = [
        "com.apple.controlcenter",
        "com.apple.menubaragent",
        "com.apple.siri",
        "com.apple.systemuiserver",
    ]
    private let identifierKey: SymmetricKey

    public init() {
        identifierKey = SymmetricKey(size: .bits256)
    }

    public func assemble(
        generation: UInt64,
        observations: [MenuBarObservation],
        unavailableSourceCount: Int = 0
    ) -> MenuBarSnapshot {
        let wasTruncated = observations.count > Self.maximumObservations
        let ordered = observations.prefix(Self.maximumObservations).sorted(by: observationOrder)
        var occurrenceCounts: [String: Int] = [:]

        let items = ordered.enumerated().map { position, observation in
            let surfaceID = surfaceIdentifier(for: observation.surfaceToken)
            let identitySeed = [
                observation.owner.bundleIdentifier ?? "unknown-owner",
                observation.stableToken,
                observation.surfaceToken ?? "unknown-surface",
            ].joined(separator: "\u{0}")
            let occurrence = occurrenceCounts[identitySeed, default: 0]
            occurrenceCounts[identitySeed] = occurrence + 1

            let availability: MenuBarItemAvailability =
                observation.frame == nil || !observation.isEnabled ? .unavailable : .controllable
            let ownership = ownership(for: observation.owner)
            let role = role(for: observation, ownership: ownership)

            return MenuBarItem(
                id: MenuBarItemID(rawValue: stableIdentifier(seed: identitySeed, occurrence: occurrence)),
                position: position,
                isMovable: availability == .controllable &&
                    role == .item &&
                    ownership == .application,
                displayName: displayName(for: observation),
                ownerBundleIdentifier: observation.owner.bundleIdentifier,
                ownership: ownership,
                availability: availability,
                role: role,
                frame: observation.frame,
                surfaceID: surfaceID
            )
        }

        let boundedUnavailableSourceCount = max(0, unavailableSourceCount)
        let finalUnavailableSourceCount: Int = if wasTruncated,
                                                  boundedUnavailableSourceCount < .max {
            boundedUnavailableSourceCount + 1
        } else {
            boundedUnavailableSourceCount
        }

        return MenuBarSnapshot(
            generation: generation,
            items: items,
            unavailableSourceCount: finalUnavailableSourceCount
        )
    }

    private func observationOrder(_ lhs: MenuBarObservation, _ rhs: MenuBarObservation) -> Bool {
        let lhsSurface = lhs.surfaceToken ?? ""
        let rhsSurface = rhs.surfaceToken ?? ""
        if lhsSurface != rhsSurface {
            return lhsSurface < rhsSurface
        }
        switch (lhs.frame, rhs.frame) {
        case let (.some(lhsFrame), .some(rhsFrame)):
            if lhsFrame.minX == rhsFrame.minX {
                return lhsFrame.minY < rhsFrame.minY
            }
            return lhsFrame.minX < rhsFrame.minX
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return lhs.stableToken < rhs.stableToken
        }
    }

    private func ownership(for owner: RunningApplicationDescriptor) -> MenuBarItemOwnership {
        if owner.isSelf {
            return .selfOwned
        }
        let bundleIdentifier = owner.bundleIdentifier?.lowercased()
        if bundleIdentifier.map(Self.systemBundleIdentifiers.contains) == true {
            return .system
        }
        return .application
    }

    private func role(
        for observation: MenuBarObservation,
        ownership: MenuBarItemOwnership
    ) -> MenuBarItemRole {
        guard ownership == .selfOwned else {
            return .item
        }
        let candidates = [observation.stableToken, observation.displayName ?? ""]
        if candidates.contains(MenuBarControllerIdentity.hiddenSectionDividerLabel) {
            return .hiddenSectionDivider
        }
        return .primaryControl
    }

    private func displayName(for observation: MenuBarObservation) -> String {
        let source = observation.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = observation.owner.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate: String = if let source, !source.isEmpty {
            source
        } else {
            fallback
        }
        let sanitized = candidate.unicodeScalars
            .filter { !CharacterSet.controlCharacters.contains($0) }
            .map(String.init)
            .joined()

        guard !sanitized.isEmpty else {
            return "Menu bar item"
        }
        return String(sanitized.prefix(Self.maximumDisplayNameLength))
    }

    private func stableIdentifier(seed: String, occurrence: Int) -> String {
        let digest = HMAC<SHA256>.authenticationCode(
            for: Data("\(seed)\u{0}\(occurrence)".utf8),
            using: identifierKey
        )
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func surfaceIdentifier(for token: String?) -> MenuBarSurfaceID {
        guard let token else { return .unknown }
        let digest = HMAC<SHA256>.authenticationCode(
            for: Data("surface\u{0}\(token)".utf8),
            using: identifierKey
        )
        return MenuBarSurfaceID(rawValue: digest.map { String(format: "%02x", $0) }.joined())
    }
}
