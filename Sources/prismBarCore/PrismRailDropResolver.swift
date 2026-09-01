// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

public struct PrismRailDropRequest: Equatable, Sendable {
    public let itemID: MenuBarItemID
    public let snapshotGeneration: UInt64
    public let targetItemID: MenuBarItemID?
    public let destinationSection: MenuBarSection

    public init(
        itemID: MenuBarItemID,
        snapshotGeneration: UInt64,
        targetItemID: MenuBarItemID?,
        destinationSection: MenuBarSection
    ) {
        self.itemID = itemID
        self.snapshotGeneration = snapshotGeneration
        self.targetItemID = targetItemID
        self.destinationSection = destinationSection
    }
}

public struct PrismRailLayout: Equatable, Sendable {
    public let generation: UInt64
    public let surfaceID: MenuBarSurfaceID
    public let surfaceCount: Int
    public let visibleItems: [MenuBarItem]
    public let hiddenItems: [MenuBarItem]

    public init(snapshot: MenuBarSnapshot, surfaceID: MenuBarSurfaceID) {
        generation = snapshot.generation
        self.surfaceID = surfaceID
        surfaceCount = snapshot.surfaceIDs.count
        visibleItems = Self.items(in: .visible, snapshot: snapshot, surfaceID: surfaceID)
        hiddenItems = Self.items(in: .hidden, snapshot: snapshot, surfaceID: surfaceID)
    }

    public init(snapshot: MenuBarSnapshot, currentSurfaceID: MenuBarSurfaceID?) {
        self.init(
            snapshot: snapshot,
            surfaceID: PrismRailSurfaceResolver().resolve(
                in: snapshot,
                current: currentSurfaceID
            )
        )
    }

    public var itemCount: Int {
        visibleItems.count + hiddenItems.count
    }

    private static func items(
        in section: MenuBarSection,
        snapshot: MenuBarSnapshot,
        surfaceID: MenuBarSurfaceID
    ) -> [MenuBarItem] {
        snapshot.items.filter { item in
            item.role == .item &&
                item.surfaceID == surfaceID &&
                snapshot.section(for: item.id) == section
        }
    }
}

public enum PrismRailKeyboardMove: Equatable, Sendable {
    case previous
    case next
    case first
    case last
}

public struct PrismRailKeyboardMoveResolver: Sendable {
    public init() {}

    public func resolve(
        _ move: PrismRailKeyboardMove,
        itemID: MenuBarItemID,
        in snapshot: MenuBarSnapshot
    ) -> Int? {
        guard let item = snapshot.items.first(where: { $0.id == itemID }),
              item.role == .item,
              item.allowsVerifiedMovement
        else {
            return nil
        }

        let destinations = snapshot.movementDestinations(for: itemID)
        guard let index = destinations.firstIndex(where: { $0.id == itemID }) else {
            return nil
        }

        let destinationIndex: Int
        switch move {
        case .previous:
            destinationIndex = index - 1
        case .next:
            destinationIndex = index + 1
        case .first:
            destinationIndex = 0
        case .last:
            destinationIndex = destinations.index(before: destinations.endIndex)
        }

        guard destinations.indices.contains(destinationIndex), destinationIndex != index else {
            return nil
        }
        return destinations[destinationIndex].position
    }
}

public enum PrismRailDropAction: Equatable, Sendable {
    case position(Int)
    case section(MenuBarSection)
}

public struct PrismRailSurfaceResolver: Sendable {
    public init() {}

    public func resolve(
        in snapshot: MenuBarSnapshot,
        current: MenuBarSurfaceID?
    ) -> MenuBarSurfaceID {
        let populatedSurfaceIDs = snapshot.surfaceIDs.filter { surfaceID in
            snapshot.items.contains { item in
                item.role == .item && item.surfaceID == surfaceID
            }
        }
        if let current, populatedSurfaceIDs.contains(current) {
            return current
        }
        return populatedSurfaceIDs.first ?? snapshot.surfaceIDs.first ?? .unknown
    }
}

public struct PrismRailSelectionResolver: Sendable {
    public init() {}

    public func resolve(
        _ selectedItemID: MenuBarItemID?,
        in snapshot: MenuBarSnapshot,
        surfaceID: MenuBarSurfaceID
    ) -> MenuBarItemID? {
        guard let selectedItemID,
              snapshot.items.contains(where: { item in
                  item.id == selectedItemID &&
                      item.surfaceID == surfaceID &&
                      item.role == .item &&
                      item.ownership == .application
              })
        else {
            return nil
        }
        return selectedItemID
    }
}

public struct PrismRailDropResolver: Sendable {
    public init() {}

    public func resolve(
        _ request: PrismRailDropRequest,
        in snapshot: MenuBarSnapshot
    ) -> PrismRailDropAction? {
        guard request.snapshotGeneration == snapshot.generation,
              request.destinationSection != .controller,
              let source = snapshot.items.first(where: { $0.id == request.itemID }),
              source.role == .item,
              source.allowsVerifiedMovement
        else {
            return nil
        }

        guard let targetItemID = request.targetItemID else {
            guard snapshot.section(for: source.id) != request.destinationSection else {
                return nil
            }
            return .section(request.destinationSection)
        }

        guard targetItemID != source.id,
              let target = snapshot.items.first(where: { $0.id == targetItemID }),
              target.role == .item,
              target.allowsVerifiedMovement,
              target.ownership == source.ownership,
              target.surfaceID == source.surfaceID,
              snapshot.section(for: target.id) == request.destinationSection
        else {
            return nil
        }

        return .position(target.position)
    }
}
