// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

public struct MenuBarItemID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
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

public enum MenuBarInsertionEdge: String, Equatable, Codable, Sendable {
    case before
    case after
}

public protocol MenuBarMovePerforming: Sendable {
    func move(
        source: MenuBarItemFrame,
        destination: MenuBarItemFrame,
        insertionEdge: MenuBarInsertionEdge
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
    public let frame: MenuBarItemFrame?

    public init(
        id: MenuBarItemID,
        position: Int,
        isMovable: Bool,
        displayName: String = "Menu bar item",
        ownerBundleIdentifier: String? = nil,
        ownership: MenuBarItemOwnership = .application,
        availability: MenuBarItemAvailability = .controllable,
        frame: MenuBarItemFrame? = nil
    ) {
        self.id = id
        self.position = position
        self.isMovable = isMovable
        self.displayName = displayName
        self.ownerBundleIdentifier = ownerBundleIdentifier
        self.ownership = ownership
        self.availability = availability
        self.frame = frame
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
}
