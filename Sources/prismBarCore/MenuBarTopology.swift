// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

public struct MenuBarItemID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct MenuBarItem: Equatable, Codable, Sendable {
    public let id: MenuBarItemID
    public let position: Int
    public let isMovable: Bool

    public init(id: MenuBarItemID, position: Int, isMovable: Bool) {
        self.id = id
        self.position = position
        self.isMovable = isMovable
    }
}

public struct MenuBarSnapshot: Equatable, Codable, Sendable {
    public let generation: UInt64
    public let items: [MenuBarItem]

    public init(generation: UInt64, items: [MenuBarItem]) {
        self.generation = generation
        self.items = items.sorted { lhs, rhs in
            if lhs.position == rhs.position {
                return lhs.id.rawValue < rhs.id.rawValue
            }
            return lhs.position < rhs.position
        }
    }
}
