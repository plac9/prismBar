// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarAccessibility
import prismBarCore
import Testing

@Suite("Accessibility topology assembly")
struct TopologyAssemblerTests {
    @Test("orders observed items by their physical menu bar position")
    func ordersByPosition() {
        let observations = [
            observation(token: "right", horizontalPosition: 900),
            observation(token: "left", horizontalPosition: 700),
            observation(token: "middle", horizontalPosition: 800),
        ]

        let snapshot = TopologyAssembler().assemble(generation: 9, observations: observations)

        #expect(snapshot.generation == 9)
        #expect(snapshot.items.map(\.displayName) == ["left", "middle", "right"])
        #expect(snapshot.items.map(\.position) == [0, 1, 2])
    }

    @Test("classifies application, system, and self-owned items")
    func classifiesOwnership() {
        let observations = [
            observation(token: "application", horizontalPosition: 100, bundleIdentifier: "com.example.utility"),
            observation(token: "system", horizontalPosition: 200, bundleIdentifier: "com.apple.controlcenter"),
            observation(
                token: "self",
                horizontalPosition: 300,
                bundleIdentifier: "com.laclairtech.prismbar",
                isSelf: true
            ),
        ]

        let snapshot = TopologyAssembler().assemble(generation: 1, observations: observations)

        #expect(snapshot.items.map(\.ownership) == [.application, .system, .selfOwned])
        #expect(snapshot.items.map(\.isMovable) == [true, true, false])
    }

    @Test("does not expose observed labels in stable identifiers")
    func hashesStableIdentifiers() {
        let sensitiveLabel = "Private Account Status"
        let snapshot = TopologyAssembler().assemble(
            generation: 1,
            observations: [observation(token: sensitiveLabel, horizontalPosition: 100)]
        )

        let identifier = snapshot.items[0].id.rawValue
        #expect(!identifier.contains(sensitiveLabel))
        #expect(identifier.count == 64)
    }

    @Test("keeps identifiers stable only within one private discovery session")
    func scopesIdentifiersToSession() {
        let observations = [observation(token: "fixture", horizontalPosition: 100)]
        let firstSession = TopologyAssembler()
        let secondSession = TopologyAssembler()

        let firstIdentifier = firstSession.assemble(generation: 1, observations: observations).items[0].id
        let repeatedIdentifier = firstSession.assemble(generation: 2, observations: observations).items[0].id
        let otherSessionIdentifier = secondSession.assemble(generation: 1, observations: observations).items[0].id

        #expect(firstIdentifier == repeatedIdentifier)
        #expect(firstIdentifier != otherSessionIdentifier)
    }

    @Test("keeps discovered but unusable items visible and unavailable")
    func marksMissingFramesUnavailable() {
        let observation = MenuBarObservation(
            owner: owner(),
            stableToken: "missing-frame",
            displayName: "Needs recovery",
            frame: nil,
            isEnabled: true
        )

        let snapshot = TopologyAssembler().assemble(generation: 1, observations: [observation])

        #expect(snapshot.items[0].availability == .unavailable)
        #expect(!snapshot.items[0].isMovable)
    }

    private func observation(
        token: String,
        horizontalPosition: Double,
        bundleIdentifier: String = "com.example.utility",
        isSelf: Bool = false
    ) -> MenuBarObservation {
        MenuBarObservation(
            owner: owner(bundleIdentifier: bundleIdentifier, isSelf: isSelf),
            stableToken: token,
            displayName: token,
            frame: MenuBarItemFrame(minX: horizontalPosition, minY: 0, width: 24, height: 24),
            isEnabled: true
        )
    }

    private func owner(
        bundleIdentifier: String = "com.example.utility",
        isSelf: Bool = false
    ) -> RunningApplicationDescriptor {
        RunningApplicationDescriptor(
            processIdentifier: 42,
            bundleIdentifier: bundleIdentifier,
            displayName: "Fixture App",
            isSelf: isSelf
        )
    }
}

@Suite("Serialized topology discovery")
struct MenuBarTopologyDiscoveryTests {
    @Test("publishes a new generation only after a successful read")
    func advancesSuccessfulGenerations() async throws {
        let observation = MenuBarObservation(
            owner: RunningApplicationDescriptor(
                processIdentifier: 42,
                bundleIdentifier: "com.example.utility",
                displayName: "Fixture App",
                isSelf: false
            ),
            stableToken: "fixture",
            displayName: "Fixture",
            frame: MenuBarItemFrame(minX: 100, minY: 0, width: 24, height: 24),
            isEnabled: true
        )
        let discovery = MenuBarTopologyDiscovery(reader: FixtureObservationReader(observations: [observation]))

        let first = try await discovery.snapshot(applications: [observation.owner])
        let second = try await discovery.snapshot(applications: [observation.owner])

        #expect(first.generation == 1)
        #expect(second.generation == 2)
        #expect(second.items.count == 1)
    }

    @Test("preserves partial-source status without exposing source identities")
    func preservesPartialStatus() async throws {
        let reader = FixtureObservationReader(observations: [], unavailableSourceCount: 2)
        let discovery = MenuBarTopologyDiscovery(reader: reader)

        let snapshot = try await discovery.snapshot(applications: [])

        #expect(snapshot.unavailableSourceCount == 2)
        #expect(!snapshot.isComplete)
    }

    @Test("does not turn a failed observation into an empty authoritative snapshot")
    func preservesFailure() async {
        let discovery = MenuBarTopologyDiscovery(reader: FailingObservationReader())

        await #expect(throws: MenuBarDiscoveryError.notTrusted) {
            try await discovery.snapshot(applications: [])
        }
    }
}

private struct FixtureObservationReader: MenuBarObservationReading {
    let observations: [MenuBarObservation]
    var unavailableSourceCount = 0

    func observations(for _: [RunningApplicationDescriptor]) async throws -> MenuBarObservationBatch {
        MenuBarObservationBatch(
            observations: observations,
            unavailableSourceCount: unavailableSourceCount
        )
    }
}

private struct FailingObservationReader: MenuBarObservationReading {
    func observations(for _: [RunningApplicationDescriptor]) async throws -> MenuBarObservationBatch {
        throw MenuBarDiscoveryError.notTrusted
    }
}
