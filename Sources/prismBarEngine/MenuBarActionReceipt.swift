// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

public struct MenuBarActionID: RawRepresentable, Hashable, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

public enum MenuBarActionKind: Equatable, Sendable {
    case directMove
    case sectionMove
    case batchMove
    case reset
    case recovery
}

public enum MenuBarActionPhase: Equatable, Sendable {
    case verifying
    case applied
    case partial
    case blocked
    case recovered
}

public struct MenuBarActionReceipt: Equatable, Sendable {
    public let id: MenuBarActionID
    public let kind: MenuBarActionKind
    public let phase: MenuBarActionPhase
    public let result: MenuBarActionResult?
    public let canRecover: Bool

    private init(
        id: MenuBarActionID,
        kind: MenuBarActionKind,
        phase: MenuBarActionPhase,
        result: MenuBarActionResult?,
        canRecover: Bool
    ) {
        self.id = id
        self.kind = kind
        self.phase = phase
        self.result = result
        self.canRecover = canRecover
    }

    public static func verifying(
        id: MenuBarActionID,
        kind: MenuBarActionKind
    ) -> MenuBarActionReceipt {
        MenuBarActionReceipt(
            id: id,
            kind: kind,
            phase: .verifying,
            result: nil,
            canRecover: false
        )
    }

    public static func completed(
        id: MenuBarActionID,
        kind: MenuBarActionKind,
        result: MenuBarActionResult,
        canRecover: Bool
    ) -> MenuBarActionReceipt {
        let phase: MenuBarActionPhase = switch result.kind {
        case .success: .applied
        case .warning: .partial
        case .failure: .blocked
        }

        return MenuBarActionReceipt(
            id: id,
            kind: kind,
            phase: phase,
            result: result,
            canRecover: canRecover
        )
    }

    public static func recovered(
        id: MenuBarActionID,
        result: MenuBarActionResult
    ) -> MenuBarActionReceipt {
        MenuBarActionReceipt(
            id: id,
            kind: .recovery,
            phase: .recovered,
            result: result,
            canRecover: false
        )
    }
}
