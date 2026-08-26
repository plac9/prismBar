// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarAccessibility
import prismBarCore
import prismBarEngine

actor LiveMenuBarController: MenuBarSnapshotReading {
    private let discovery = MenuBarTopologyDiscovery(reader: NativeMenuBarObservationReader())
    private let performer = NativeMenuBarMovePerformer()

    func snapshot(deadline: OperationDeadline) async throws -> MenuBarSnapshot {
        try deadline.check()
        let applications = await RunningApplicationCatalog.current()
        let snapshot = try await discovery.snapshot(
            applications: applications,
            deadline: deadline
        )
        try deadline.check()
        return snapshot
    }

    func execute(_ plan: MovePlan) async -> MoveExecutionOutcome {
        let coordinator = VerifiedMoveCoordinator(reader: self, performer: performer)
        return await coordinator.execute(plan)
    }
}
