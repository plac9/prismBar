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

public struct MenuBarRecoveryAttempt: Equatable, Sendable {
    public let receipt: MenuBarActionReceipt
    public let entry: MenuBarRecoveryEntry

    public init(receipt: MenuBarActionReceipt, entry: MenuBarRecoveryEntry) {
        self.receipt = receipt
        self.entry = entry
    }
}

public struct MenuBarRecoveryLedger: Sendable {
    public static let maximumEntries = 10

    private struct PendingAction: Sendable {
        let id: MenuBarActionID
        let kind: MenuBarActionKind
        let before: MenuBarSnapshot
        let recoverySourceID: MenuBarActionID?
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
        pending = PendingAction(
            id: id,
            kind: kind,
            before: before,
            recoverySourceID: nil
        )
        return .verifying(id: id, kind: kind)
    }

    public mutating func beginRecovery(
        with current: MenuBarSnapshot
    ) -> MenuBarRecoveryAttempt? {
        guard let entry = latestCompatible(with: current) else {
            return nil
        }
        let id = MenuBarActionID(rawValue: nextIdentifier)
        nextIdentifier &+= 1
        pending = PendingAction(
            id: id,
            kind: .recovery,
            before: current,
            recoverySourceID: entry.receipt.id
        )
        return MenuBarRecoveryAttempt(
            receipt: .verifying(id: id, kind: .recovery),
            entry: entry
        )
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
        guard pending.kind != .recovery else {
            return nil
        }

        let canRecover = result.kind != .failure && after.map {
            Self.snapshotsAreCompatible(pending.before, $0) &&
                !Self.snapshotsMatchForRecovery(pending.before, $0)
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

    public mutating func completeRecovery(
        id: MenuBarActionID,
        result: MenuBarActionResult,
        after: MenuBarSnapshot?
    ) -> MenuBarActionReceipt? {
        guard let pending,
              pending.id == id,
              pending.kind == .recovery,
              let recoverySourceID = pending.recoverySourceID,
              let sourceIndex = entries.firstIndex(where: {
                  $0.receipt.id == recoverySourceID
              })
        else {
            return nil
        }
        self.pending = nil
        let source = entries[sourceIndex]

        if result.kind == .success,
           let after,
           Self.snapshotsMatchForRecovery(source.before, after) {
            entries.removeSubrange(sourceIndex...)
            return .recovered(id: id, result: result)
        }

        let safeResult: MenuBarActionResult = if result.kind == .success {
            .failure("Recovery could not be verified against the current menu bar.")
        } else {
            result
        }
        let canRecover = after.map {
            Self.snapshotsMatchForRecovery(source.after, $0)
        } == true
        return .completed(
            id: id,
            kind: .recovery,
            result: safeResult,
            canRecover: canRecover
        )
    }

    public func latestCompatible(
        with current: MenuBarSnapshot
    ) -> MenuBarRecoveryEntry? {
        entries.last { entry in
            Self.snapshotsMatchForRecovery(entry.after, current)
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

    private static func snapshotsMatchForRecovery(
        _ first: MenuBarSnapshot,
        _ second: MenuBarSnapshot
    ) -> Bool {
        guard first.unavailableSourceCount == second.unavailableSourceCount,
              snapshotsAreCompatible(first, second)
        else {
            return false
        }
        let secondByID = Dictionary(uniqueKeysWithValues: second.items.map { ($0.id, $0) })
        guard first.items.allSatisfy({ firstItem in
            guard let secondItem = secondByID[firstItem.id] else { return false }
            return firstItem.role == secondItem.role &&
                firstItem.ownership == secondItem.ownership &&
                firstItem.surfaceID == secondItem.surfaceID &&
                firstItem.isMovable == secondItem.isMovable &&
                (secondItem.role != .item ||
                    (firstItem.availability == .controllable &&
                        secondItem.availability == .controllable))
        }) else {
            return false
        }

        for surfaceID in Set(first.items.map(\.surfaceID)) {
            let firstOrder = first.items.filter { $0.surfaceID == surfaceID }.map(\.id)
            let secondOrder = second.items.filter { $0.surfaceID == surfaceID }.map(\.id)
            guard firstOrder == secondOrder else { return false }
        }
        return true
    }
}
