// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore

public struct MenuBarRecoveryEntry: Equatable, Sendable {
    public let receipt: MenuBarActionReceipt
    public let before: MenuBarSnapshot
    public let after: MenuBarSnapshot

    public init(
        receipt: MenuBarActionReceipt,
        before: MenuBarSnapshot,
        after: MenuBarSnapshot
    ) {
        self.receipt = receipt
        self.before = before
        self.after = after
    }
}

public struct MenuBarRecoveryLedger: Sendable {
    public static let maximumEntries = 10

    private struct PendingAction: Sendable {
        let id: MenuBarActionID
        let kind: MenuBarActionKind
        let before: MenuBarSnapshot
    }

    private var nextIdentifier: UInt64 = 1
    private var pending: PendingAction?
    public private(set) var entries: [MenuBarRecoveryEntry] = []

    public init() {}

    public mutating func begin(
        kind: MenuBarActionKind,
        before: MenuBarSnapshot
    ) -> MenuBarActionReceipt {
        let id = MenuBarActionID(rawValue: nextIdentifier)
        nextIdentifier &+= 1
        pending = PendingAction(id: id, kind: kind, before: before)
        return .verifying(id: id, kind: kind)
    }

    public mutating func complete(
        id: MenuBarActionID,
        result: MenuBarActionResult,
        after: MenuBarSnapshot?
    ) -> MenuBarActionReceipt? {
        guard let pending, pending.id == id else {
            return nil
        }
        self.pending = nil

        let canRecover = result.kind != .failure && after.map {
            Self.snapshotsAreCompatible(pending.before, $0)
        } == true
        let receipt = MenuBarActionReceipt.completed(
            id: id,
            kind: pending.kind,
            result: result,
            canRecover: canRecover
        )

        if canRecover, let after {
            entries.append(
                MenuBarRecoveryEntry(
                    receipt: receipt,
                    before: pending.before,
                    after: after
                )
            )
            if entries.count > Self.maximumEntries {
                entries.removeFirst(entries.count - Self.maximumEntries)
            }
        }

        return receipt
    }

    public func latestCompatible(
        with current: MenuBarSnapshot
    ) -> MenuBarRecoveryEntry? {
        entries.last { entry in
            Self.snapshotsAreCompatible(entry.after, current)
        }
    }

    public mutating func clear() {
        pending = nil
        entries.removeAll(keepingCapacity: false)
    }

    private static func snapshotsAreCompatible(
        _ first: MenuBarSnapshot,
        _ second: MenuBarSnapshot
    ) -> Bool {
        Set(first.items.map(\.id)) == Set(second.items.map(\.id)) &&
            Set(first.items.map(\.surfaceID)) == Set(second.items.map(\.surfaceID))
    }
}
