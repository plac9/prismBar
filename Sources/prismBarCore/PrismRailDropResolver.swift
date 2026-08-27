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
              source.isMovable,
              source.availability == .controllable
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
              target.availability == .controllable,
              target.surfaceID == source.surfaceID,
              snapshot.section(for: target.id) == request.destinationSection
        else {
            return nil
        }

        return .position(target.position)
    }
}
