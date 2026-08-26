// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

public enum MenuBarActionResultKind: Equatable, Sendable {
    case success
    case warning
    case failure
}

public enum MenuBarRecoveryAction: Equatable, Sendable {
    case refresh
    case recheckPermission
    case none
}

public struct MenuBarActionResult: Equatable, Sendable {
    public let kind: MenuBarActionResultKind
    public let message: String
    public let symbol: String
    public let recovery: MenuBarRecoveryAction

    public init(
        kind: MenuBarActionResultKind,
        message: String,
        symbol: String,
        recovery: MenuBarRecoveryAction
    ) {
        self.kind = kind
        self.message = message
        self.symbol = symbol
        self.recovery = recovery
    }

    public static func success(_ message: String) -> MenuBarActionResult {
        MenuBarActionResult(
            kind: .success,
            message: message,
            symbol: "checkmark.circle.fill",
            recovery: .none
        )
    }

    public static func warning(
        _ message: String,
        recovery: MenuBarRecoveryAction = .refresh
    ) -> MenuBarActionResult {
        MenuBarActionResult(
            kind: .warning,
            message: message,
            symbol: "exclamationmark.triangle.fill",
            recovery: recovery
        )
    }

    public static func failure(
        _ message: String,
        symbol: String = "xmark.circle.fill",
        recovery: MenuBarRecoveryAction = .refresh
    ) -> MenuBarActionResult {
        MenuBarActionResult(
            kind: .failure,
            message: message,
            symbol: symbol,
            recovery: recovery
        )
    }

    public static func move(
        _ outcome: MoveExecutionOutcome,
        itemName: String
    ) -> MenuBarActionResult {
        switch outcome {
        case .success:
            MenuBarActionResult(
                kind: .success,
                message: "Move verified for \(itemName).",
                symbol: "checkmark.circle.fill",
                recovery: .none
            )
        case let .partial(observedIndex):
            MenuBarActionResult(
                kind: .warning,
                message: "\(itemName) moved to position \(observedIndex + 1), but not the requested position.",
                symbol: "arrow.trianglehead.2.clockwise.rotate.90",
                recovery: .refresh
            )
        case .topologyChanged:
            MenuBarActionResult(
                kind: .warning,
                message: "The menu bar changed before \(itemName) could move.",
                symbol: "arrow.clockwise",
                recovery: .refresh
            )
        case .itemUnavailable:
            MenuBarActionResult(
                kind: .failure,
                message: "\(itemName) is no longer available.",
                symbol: "questionmark.app",
                recovery: .refresh
            )
        case .permissionRevoked:
            MenuBarActionResult(
                kind: .failure,
                message: "Accessibility access is not currently available.",
                symbol: "hand.raised.slash",
                recovery: .recheckPermission
            )
        case .menuBarUnavailable:
            MenuBarActionResult(
                kind: .failure,
                message: "The current menu bar surface is unavailable.",
                symbol: "menubar.dock.rectangle.badge.questionmark",
                recovery: .refresh
            )
        case .observationFailed:
            MenuBarActionResult(
                kind: .failure,
                message: "prismBar could not verify the current menu bar.",
                symbol: "eye.slash",
                recovery: .refresh
            )
        case .inputFailed:
            MenuBarActionResult(
                kind: .failure,
                message: "macOS did not accept the move for \(itemName).",
                symbol: "cursorarrow.slash",
                recovery: .refresh
            )
        case .timedOut:
            MenuBarActionResult(
                kind: .failure,
                message: "The move for \(itemName) timed out safely.",
                symbol: "clock.badge.exclamationmark",
                recovery: .refresh
            )
        }
    }
}
