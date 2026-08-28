// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarEngine
import Testing

@Suite("Menu bar action results")
struct MenuBarActionResultTests {
    @Test(
        "maps every move outcome to typed accessible feedback",
        arguments: [
            (MoveExecutionOutcome.success, MenuBarActionResultKind.success, MenuBarRecoveryAction.none),
            (.partial(observedIndex: 2), .warning, .refresh),
            (.topologyChanged, .warning, .refresh),
            (.itemUnavailable, .failure, .refresh),
            (.permissionRevoked, .failure, .recheckPermission),
            (.menuBarUnavailable, .failure, .refresh),
            (.observationFailed, .failure, .refresh),
            (.inputFailed, .failure, .refresh),
            (.timedOut, .failure, .refresh),
        ]
    )
    func mapsEveryOutcome(
        outcome: MoveExecutionOutcome,
        expectedKind: MenuBarActionResultKind,
        expectedRecovery: MenuBarRecoveryAction
    ) {
        let result = MenuBarActionResult.move(outcome, itemName: "Fixture")

        #expect(result.kind == expectedKind)
        #expect(result.recovery == expectedRecovery)
        #expect(!result.symbol.isEmpty)
        #expect(!result.message.isEmpty)
    }

    @Test("timeout names the item and offers refresh")
    func timeoutRecovery() {
        let result = MenuBarActionResult.move(.timedOut, itemName: "Fixture")

        #expect(result.kind == .failure)
        #expect(result.symbol == "clock.badge.exclamationmark")
        #expect(result.recovery == .refresh)
        #expect(result.message.contains("Fixture"))
    }

    @Test("an unavailable menu bar explains the safe recovery")
    func unavailableMenuBarRecovery() {
        let result = MenuBarActionResult.move(.menuBarUnavailable, itemName: "Fixture")

        #expect(result.kind == .failure)
        #expect(result.message.contains("Exit full screen"))
        #expect(result.message.contains("Automatically hide"))
        #expect(result.recovery == .refresh)
    }
}
