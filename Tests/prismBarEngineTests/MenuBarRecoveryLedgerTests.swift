// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarEngine
import prismBarCore
import Testing

@Suite("Menu bar recovery ledger")
struct MenuBarRecoveryLedgerTests {
    @Test("issues monotonic process-local identifiers")
    func issuesMonotonicIdentifiers() {
        var ledger = MenuBarRecoveryLedger()

        let first = ledger.begin(kind: .directMove, before: snapshot(generation: 1))
        let second = ledger.begin(kind: .sectionMove, before: snapshot(generation: 2))

        #expect(first.id == MenuBarActionID(rawValue: 1))
        #expect(second.id == MenuBarActionID(rawValue: 2))
        #expect(first.phase == .verifying)
        #expect(second.phase == .verifying)
    }

    @Test("does not expose an incomplete operation as recoverable")
    func incompleteOperationIsNotRecoverable() {
        var ledger = MenuBarRecoveryLedger()
        _ = ledger.begin(kind: .directMove, before: snapshot(generation: 1))

        #expect(ledger.entries.isEmpty)
        #expect(ledger.latestCompatible(with: snapshot(generation: 2)) == nil)
    }

    @Test("retains only verified successful or partial operations")
    func retainsVerifiedOperations() {
        var ledger = MenuBarRecoveryLedger()
        let before = snapshot(generation: 1)
        let after = snapshot(generation: 2, reversed: true)

        let success = ledger.begin(kind: .directMove, before: before)
        let successReceipt = ledger.complete(
            id: success.id,
            result: .success("Verified"),
            after: after
        )
        let partial = ledger.begin(kind: .directMove, before: after)
        let partialReceipt = ledger.complete(
            id: partial.id,
            result: .warning("Partially applied"),
            after: before
        )
        let blocked = ledger.begin(kind: .directMove, before: before)
        let blockedReceipt = ledger.complete(
            id: blocked.id,
            result: .failure("Blocked"),
            after: nil
        )

        #expect(successReceipt?.canRecover == true)
        #expect(partialReceipt?.canRecover == true)
        #expect(blockedReceipt?.canRecover == false)
        #expect(ledger.entries.map(\.receipt.id) == [success.id, partial.id])
    }

    @Test("does not retain a verified no-op as recoverable")
    func rejectsNoOp() {
        var ledger = MenuBarRecoveryLedger()
        let before = snapshot(generation: 1)
        let pending = ledger.begin(kind: .reset, before: before)

        let receipt = ledger.complete(
            id: pending.id,
            result: .success("Nothing changed"),
            after: snapshot(generation: 2)
        )

        #expect(receipt?.canRecover == false)
        #expect(ledger.entries.isEmpty)
    }

    @Test("retains only the newest ten completed entries")
    func enforcesEntryLimit() {
        var ledger = MenuBarRecoveryLedger()

        for generation in 1 ... 12 {
            let before = snapshot(generation: UInt64(generation))
            let pending = ledger.begin(kind: .directMove, before: before)
            _ = ledger.complete(
                id: pending.id,
                result: .success("Verified"),
                after: snapshot(generation: UInt64(generation + 100), reversed: true)
            )
        }

        #expect(ledger.entries.count == MenuBarRecoveryLedger.maximumEntries)
        #expect(ledger.entries.first?.receipt.id == MenuBarActionID(rawValue: 3))
        #expect(ledger.entries.last?.receipt.id == MenuBarActionID(rawValue: 12))
    }

    @Test("requires the exact verified after topology for recovery")
    func validatesCompatibility() {
        var ledger = MenuBarRecoveryLedger()
        let pending = ledger.begin(kind: .directMove, before: snapshot(generation: 1))
        _ = ledger.complete(
            id: pending.id,
            result: .success("Verified"),
            after: snapshot(generation: 2, reversed: true)
        )

        #expect(ledger.latestCompatible(with: snapshot(generation: 3)) == nil)
        #expect(ledger.latestCompatible(with: snapshot(generation: 3, reversed: true)) != nil)
        #expect(ledger.latestCompatible(with: snapshot(generation: 3, missingItem: true)) == nil)
        #expect(ledger.latestCompatible(with: snapshot(generation: 3, alternateSurface: true)) == nil)
        #expect(ledger.latestCompatible(with: snapshot(
            generation: 3,
            reversed: true,
            systemOwnedVisibleItem: true
        )) == nil)
    }

    @Test("begins recovery only from the exact verified after topology")
    func beginsCompatibleRecovery() throws {
        var ledger = completedLedger()

        #expect(ledger.beginRecovery(with: snapshot(generation: 3)) == nil)

        let candidate = ledger.beginRecovery(with: snapshot(generation: 3, reversed: true))
        let attempt = try #require(candidate)
        #expect(attempt.receipt.kind == .recovery)
        #expect(attempt.receipt.phase == .verifying)
        #expect(attempt.entry.before == snapshot(generation: 1))
    }

    @Test("consumes the recovery candidate only after exact restoration")
    func completesVerifiedRecovery() throws {
        var ledger = completedLedger()
        let candidate = ledger.beginRecovery(with: snapshot(generation: 3, reversed: true))
        let attempt = try #require(candidate)

        let receipt = ledger.completeRecovery(
            id: attempt.receipt.id,
            result: .success("Previous layout restored."),
            after: snapshot(generation: 4)
        )

        #expect(receipt?.phase == .recovered)
        #expect(receipt?.kind == .recovery)
        #expect(ledger.entries.isEmpty)
    }

    @Test("does not consume or misreport an unverified recovery")
    func rejectsUnverifiedRecovery() throws {
        var ledger = completedLedger()
        let candidate = ledger.beginRecovery(with: snapshot(generation: 3, reversed: true))
        let attempt = try #require(candidate)

        let receipt = ledger.completeRecovery(
            id: attempt.receipt.id,
            result: .success("Previous layout restored."),
            after: snapshot(generation: 4, reversed: true)
        )

        #expect(receipt?.phase == .blocked)
        #expect(receipt?.canRecover == true)
        #expect(ledger.entries.count == 1)
    }

    @Test("a partial recovery is retryable only while the verified after topology remains")
    func retrySafety() throws {
        var unchangedLedger = completedLedger()
        let unchangedCandidate = unchangedLedger.beginRecovery(
            with: snapshot(generation: 3, reversed: true)
        )
        let unchangedAttempt = try #require(unchangedCandidate)
        let unchangedReceipt = unchangedLedger.completeRecovery(
            id: unchangedAttempt.receipt.id,
            result: .failure("Recovery stopped safely."),
            after: snapshot(generation: 4, reversed: true)
        )

        #expect(unchangedReceipt?.canRecover == true)
        #expect(unchangedLedger.latestCompatible(
            with: snapshot(generation: 5, reversed: true)
        ) != nil)

        var changedLedger = completedLedger()
        let changedCandidate = changedLedger.beginRecovery(
            with: snapshot(generation: 3, reversed: true)
        )
        let changedAttempt = try #require(changedCandidate)
        let changedReceipt = changedLedger.completeRecovery(
            id: changedAttempt.receipt.id,
            result: .failure("Recovery stopped safely."),
            after: snapshot(generation: 4)
        )

        #expect(changedReceipt?.canRecover == false)
        #expect(changedLedger.latestCompatible(with: snapshot(generation: 4)) == nil)
        #expect(changedLedger.entries.count == 1)
    }

    @Test("clears completed and pending recovery state")
    func clearsAllState() {
        var ledger = MenuBarRecoveryLedger()
        let completed = ledger.begin(kind: .directMove, before: snapshot(generation: 1))
        _ = ledger.complete(
            id: completed.id,
            result: .success("Verified"),
            after: snapshot(generation: 2, reversed: true)
        )
        let pending = ledger.begin(kind: .sectionMove, before: snapshot(generation: 3))

        ledger.clear()

        #expect(ledger.entries.isEmpty)
        #expect(ledger.complete(
            id: pending.id,
            result: .success("Verified"),
            after: snapshot(generation: 4)
        ) == nil)
    }
}

private extension MenuBarRecoveryLedgerTests {
    private func completedLedger() -> MenuBarRecoveryLedger {
        var ledger = MenuBarRecoveryLedger()
        let pending = ledger.begin(kind: .directMove, before: snapshot(generation: 1))
        _ = ledger.complete(
            id: pending.id,
            result: .success("Verified"),
            after: snapshot(generation: 2, reversed: true)
        )
        return ledger
    }

    private func snapshot(
        generation: UInt64,
        reversed: Bool = false,
        missingItem: Bool = false,
        alternateSurface: Bool = false,
        systemOwnedVisibleItem: Bool = false,
        unavailableSourceCount: Int = 0
    ) -> MenuBarSnapshot {
        let surface = MenuBarSurfaceID(
            rawValue: alternateSurface ? "fixture.display.alternate" : "fixture.display.primary"
        )
        var items = [
            item("fixture.hidden", position: 0, surface: surface),
            item(
                "fixture.divider",
                position: 1,
                surface: surface,
                role: .hiddenSectionDivider
            ),
            item(
                "fixture.visible",
                position: 2,
                surface: surface,
                ownership: systemOwnedVisibleItem ? .system : .application
            ),
        ]
        if missingItem {
            items.removeLast()
        } else if reversed {
            items = [items[2], items[1], items[0]].enumerated().map { offset, item in
                MenuBarItem(
                    id: item.id,
                    position: offset,
                    isMovable: item.isMovable,
                    displayName: item.displayName,
                    ownership: item.ownership,
                    availability: item.availability,
                    role: item.role,
                    frame: item.frame,
                    surfaceID: item.surfaceID
                )
            }
        }
        return MenuBarSnapshot(
            generation: generation,
            items: items,
            unavailableSourceCount: unavailableSourceCount
        )
    }

    private func item(
        _ identifier: String,
        position: Int,
        surface: MenuBarSurfaceID,
        role: MenuBarItemRole = .item,
        ownership: MenuBarItemOwnership = .application
    ) -> MenuBarItem {
        MenuBarItem(
            id: MenuBarItemID(rawValue: identifier),
            position: position,
            isMovable: role == .item,
            displayName: "Synthetic item",
            ownership: ownership,
            availability: .controllable,
            role: role,
            frame: MenuBarItemFrame(minX: Double(position * 24), minY: 0, width: 20, height: 20),
            surfaceID: surface
        )
    }
}

extension MenuBarRecoveryLedgerTests {
    @Test("retains recovery when partial coverage stays identical")
    func retainsStablePartialCoverage() {
        var ledger = MenuBarRecoveryLedger()
        let before = snapshot(generation: 1, unavailableSourceCount: 3)
        let after = snapshot(
            generation: 2,
            reversed: true,
            unavailableSourceCount: 3
        )
        let pending = ledger.begin(kind: .directMove, before: before)

        let receipt = ledger.complete(
            id: pending.id,
            result: .success("Verified"),
            after: after
        )

        #expect(receipt?.canRecover == true)
        #expect(ledger.latestCompatible(with: snapshot(
            generation: 3,
            reversed: true,
            unavailableSourceCount: 3
        )) != nil)
        #expect(ledger.latestCompatible(with: snapshot(
            generation: 4,
            reversed: true,
            unavailableSourceCount: 2
        )) != nil)
        #expect(ledger.latestCompatible(with: snapshot(
            generation: 5,
            reversed: true,
            unavailableSourceCount: 0
        )) == nil)
    }
}
