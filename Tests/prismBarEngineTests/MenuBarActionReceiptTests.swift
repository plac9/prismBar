// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarEngine
import Testing

@Suite("Menu bar action receipts")
struct MenuBarActionReceiptTests {
    @Test("starts in verifying state without a result")
    func startsVerifying() {
        let receipt = MenuBarActionReceipt.verifying(
            id: MenuBarActionID(rawValue: 7),
            kind: .directMove
        )

        #expect(receipt.phase == .verifying)
        #expect(receipt.result == nil)
        #expect(!receipt.canRecover)
    }

    @Test("maps results to an explicit terminal phase")
    func mapsTerminalPhases() {
        let id = MenuBarActionID(rawValue: 1)

        let applied = MenuBarActionReceipt.completed(
            id: id,
            kind: .directMove,
            result: .success("Verified"),
            canRecover: true
        )
        let partial = MenuBarActionReceipt.completed(
            id: id,
            kind: .directMove,
            result: .warning("Partial"),
            canRecover: true
        )
        let blocked = MenuBarActionReceipt.completed(
            id: id,
            kind: .directMove,
            result: .failure("Blocked"),
            canRecover: false
        )

        #expect(applied.phase == .applied)
        #expect(partial.phase == .partial)
        #expect(blocked.phase == .blocked)
    }

    @Test("recovery has its own terminal phase")
    func recordsRecovery() {
        let receipt = MenuBarActionReceipt.recovered(
            id: MenuBarActionID(rawValue: 9),
            result: .success("Previous layout restored")
        )

        #expect(receipt.kind == .recovery)
        #expect(receipt.phase == .recovered)
        #expect(!receipt.canRecover)
    }
}
