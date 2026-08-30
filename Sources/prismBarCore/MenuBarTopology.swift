// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

public struct MenuBarItemID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct MenuBarSurfaceID: RawRepresentable, Hashable, Codable, Sendable {
    public static let unknown = Self(rawValue: "unknown")

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public enum MenuBarControllerIdentity {
    public static let primaryControlLabel = "prismBar"
    public static let hiddenSectionDividerLabel = "prismBar Hidden Section"
}

public struct MenuBarItemFrame: Equatable, Codable, Sendable {
    public let minX: Double
    public let minY: Double
    public let width: Double
    public let height: Double

    public init(minX: Double, minY: Double, width: Double, height: Double) {
        self.minX = minX
        self.minY = minY
        self.width = width
        self.height = height
    }
}

public enum MenuBarItemOwnership: String, Equatable, Codable, Sendable {
    case application
    case system
    case selfOwned
}

public enum MenuBarItemAvailability: String, Equatable, Codable, Sendable {
    case controllable
    case unavailable
}

public enum MenuBarItemRole: String, Equatable, Codable, Sendable {
    case item
    case primaryControl
    case hiddenSectionDivider
}

public enum MenuBarSection: String, Equatable, Codable, Sendable {
    case hidden
    case visible
    case controller
}

public enum MenuBarInsertionEdge: String, Equatable, Codable, Sendable {
    case before
    case after
}

/// A live authorization failure reported by a protected menu bar operation.
///
/// This value contains no Accessibility-derived content and lets the host
/// immediately discard privileged state when macOS revokes consent.
public enum MenuBarAuthorizationError: Error, Equatable, Sendable {
    case permissionRevoked
}

public enum MenuBarInputError: Error, Equatable, Sendable {
    case menuBarUnavailable
}

public protocol MenuBarMovePerforming: Sendable {
    func move(
        source: MenuBarItemFrame,
        destination: MenuBarItemFrame,
        insertionEdge: MenuBarInsertionEdge,
        deadline: OperationDeadline
    ) async throws
}

public struct MenuBarItem: Identifiable, Equatable, Codable, Sendable {
    public let id: MenuBarItemID
    public let position: Int
    public let isMovable: Bool
    public let displayName: String
    public let ownerBundleIdentifier: String?
    public let ownership: MenuBarItemOwnership
    public let availability: MenuBarItemAvailability
    public let role: MenuBarItemRole
    public let frame: MenuBarItemFrame?
    public let surfaceID: MenuBarSurfaceID

    public init(
        id: MenuBarItemID,
        position: Int,
        isMovable: Bool,
        displayName: String = "Menu bar item",
        ownerBundleIdentifier: String? = nil,
        ownership: MenuBarItemOwnership = .application,
        availability: MenuBarItemAvailability = .controllable,
        role: MenuBarItemRole = .item,
        frame: MenuBarItemFrame? = nil,
        surfaceID: MenuBarSurfaceID = .unknown
    ) {
        self.id = id
        self.position = position
        self.isMovable = isMovable
        self.displayName = displayName
        self.ownerBundleIdentifier = ownerBundleIdentifier
        self.ownership = ownership
        self.availability = availability
        self.role = role
        self.frame = frame
        self.surfaceID = surfaceID
    }
}

public struct MenuBarSnapshot: Equatable, Codable, Sendable {
    public let generation: UInt64
    public let items: [MenuBarItem]
    public let unavailableSourceCount: Int

    public init(
        generation: UInt64,
        items: [MenuBarItem],
        unavailableSourceCount: Int = 0
    ) {
        self.generation = generation
        self.unavailableSourceCount = max(0, unavailableSourceCount)
        self.items = items.sorted { lhs, rhs in
            if lhs.position == rhs.position {
                return lhs.id.rawValue < rhs.id.rawValue
            }
            return lhs.position < rhs.position
        }
    }

    public var isComplete: Bool {
        unavailableSourceCount == 0
    }

    public var hiddenSectionDivider: MenuBarItem? {
        items.first { $0.role == .hiddenSectionDivider }
    }

    public var surfaceIDs: [MenuBarSurfaceID] {
        var seen: Set<MenuBarSurfaceID> = []
        let orderedSurfaceIDs: [MenuBarSurfaceID] = items.compactMap { item -> MenuBarSurfaceID? in
            guard item.surfaceID != .unknown,
                  seen.insert(item.surfaceID).inserted
            else {
                return nil
            }
            return item.surfaceID
        }
        return orderedSurfaceIDs.isEmpty ? [.unknown] : orderedSurfaceIDs
    }

    public func section(for itemID: MenuBarItemID) -> MenuBarSection? {
        guard let itemIndex = items.firstIndex(where: { $0.id == itemID }) else {
            return nil
        }
        let item = items[itemIndex]
        guard let dividerIndex = items.firstIndex(where: {
            $0.role == .hiddenSectionDivider && $0.surfaceID == item.surfaceID
        })
        else {
            return nil
        }
        guard item.role == .item else {
            return .controller
        }
        return itemIndex < dividerIndex ? .hidden : .visible
    }

    public func movementDestinations(for itemID: MenuBarItemID) -> [MenuBarItem] {
        guard let item = items.first(where: { $0.id == itemID }),
              item.role == .item,
              let itemSection = section(for: itemID),
              itemSection != .controller
        else {
            return []
        }

        return items.filter { candidate in
            candidate.role == .item &&
                candidate.ownership == item.ownership &&
                candidate.surfaceID == item.surfaceID &&
                section(for: candidate.id) == itemSection
        }
    }
}
