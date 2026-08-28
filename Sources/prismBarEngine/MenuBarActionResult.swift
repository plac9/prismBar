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
        symbol: String = "exclamationmark.triangle.fill",
        recovery: MenuBarRecoveryAction = .refresh
    ) -> MenuBarActionResult {
        MenuBarActionResult(
            kind: .warning,
            message: message,
            symbol: symbol,
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
            success("Move verified for \(itemName).")
        case let .partial(observedIndex):
            warning(
                "\(itemName) moved to position \(observedIndex + 1), but not the requested position.",
                symbol: "arrow.trianglehead.2.clockwise.rotate.90"
            )
        case .topologyChanged:
            warning("The menu bar changed before \(itemName) could move.", symbol: "arrow.clockwise")
        case .itemUnavailable:
            failure("\(itemName) is no longer available.", symbol: "questionmark.app")
        case .permissionRevoked:
            failure(
                "Accessibility access is not currently available.",
                symbol: "hand.raised.slash",
                recovery: .recheckPermission
            )
        case .menuBarUnavailable:
            failure(
                "Exit full screen or turn off Automatically hide and show the menu bar, then refresh.",
                symbol: "menubar.dock.rectangle.badge.questionmark"
            )
        case .observationFailed:
            failure("prismBar could not verify the current menu bar.", symbol: "eye.slash")
        case .inputFailed:
            failure("macOS did not accept the move for \(itemName).", symbol: "cursorarrow.slash")
        case .timedOut:
            failure("The move for \(itemName) timed out safely.", symbol: "clock.badge.exclamationmark")
        }
    }
}
