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

    @Test("keeps menu bars on separate displays in independent surfaces")
    func separatesDisplaySurfaces() {
        let observations = [
            observation(token: "right-a", horizontalPosition: 100, surfaceToken: "right-display"),
            observation(token: "left-b", horizontalPosition: 200, surfaceToken: "left-display"),
            observation(token: "left-a", horizontalPosition: 100, surfaceToken: "left-display"),
            observation(token: "right-b", horizontalPosition: 200, surfaceToken: "right-display"),
        ]
        let assembler = TopologyAssembler()

        let first = assembler.assemble(generation: 1, observations: observations)
        let second = assembler.assemble(generation: 2, observations: observations.reversed())

        #expect(Set(first.items.map(\.surfaceID)).count == 2)
        #expect(first.items.map(\.surfaceID) == second.items.map(\.surfaceID))
        #expect(first.items.map(\.id) == second.items.map(\.id))
        let groupedPositions = Dictionary(grouping: first.items, by: \.surfaceID)
            .values
            .map { $0.map(\.position) }
            .sorted { $0[0] < $1[0] }
        #expect(groupedPositions == [[0, 1], [2, 3]])
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

    @Test("bounds untrusted accessibility metadata before assembly")
    func boundsObservationMetadata() {
        let oversized = String(repeating: "x", count: 20_000)
        let owner = RunningApplicationDescriptor(
            processIdentifier: 42,
            bundleIdentifier: "com.example." + oversized,
            displayName: oversized,
            isSelf: false
        )
        let observation = MenuBarObservation(
            owner: owner,
            stableToken: oversized,
            displayName: oversized,
            frame: MenuBarItemFrame(minX: 100, minY: 0, width: 24, height: 24),
            isEnabled: true,
            surfaceToken: oversized
        )

        #expect(owner.bundleIdentifier?.count == 255)
        #expect(owner.displayName.count == 120)
        #expect(observation.stableToken.count == 512)
        #expect(observation.displayName?.count == 120)
        #expect(observation.surfaceToken?.count == 120)

        let snapshot = TopologyAssembler().assemble(generation: 1, observations: [observation])
        #expect(snapshot.items.count == 1)
        #expect(snapshot.items[0].displayName.count == 120)

        let oversizedScalarSequence = "a" + String(repeating: "\u{0301}", count: 20_000)
        let scalarBoundedObservation = MenuBarObservation(
            owner: owner,
            stableToken: oversizedScalarSequence,
            displayName: oversizedScalarSequence,
            frame: nil,
            isEnabled: true,
            surfaceToken: oversizedScalarSequence
        )
        #expect(scalarBoundedObservation.stableToken.unicodeScalars.count == 512)
        #expect(scalarBoundedObservation.displayName?.unicodeScalars.count == 120)
        #expect(scalarBoundedObservation.surfaceToken?.unicodeScalars.count == 120)
    }

    @Test("caps the authoritative snapshot when aggregate observations exceed the limit")
    func capsAggregateObservations() {
        let observations = (0 ..< 2_050).map { index in
            observation(token: "item-\(index)", horizontalPosition: Double(index))
        }

        let snapshot = TopologyAssembler().assemble(generation: 1, observations: observations)

        #expect(snapshot.items.count == 2_048)
        #expect(snapshot.unavailableSourceCount == 1)
        #expect(!snapshot.isComplete)
    }

    @Test("recognizes the exact hidden section divider without exposing it as movable")
    func recognizesHiddenDivider() {
        let snapshot = TopologyAssembler().assemble(
            generation: 1,
            observations: [
                observation(
                    token: MenuBarControllerIdentity.hiddenSectionDividerLabel,
                    horizontalPosition: 100,
                    bundleIdentifier: "com.laclairtech.prismbar",
                    isSelf: true
                ),
            ]
        )

        #expect(snapshot.items[0].role == .hiddenSectionDivider)
        #expect(!snapshot.items[0].isMovable)
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
        isSelf: Bool = false,
        surfaceToken: String? = nil
    ) -> MenuBarObservation {
        MenuBarObservation(
            owner: owner(bundleIdentifier: bundleIdentifier, isSelf: isSelf),
            stableToken: token,
            displayName: token,
            frame: MenuBarItemFrame(minX: horizontalPosition, minY: 0, width: 24, height: 24),
            isEnabled: true,
            surfaceToken: surfaceToken
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

@Suite("Display surface resolution")
struct DisplaySurfaceResolverTests {
    @Test("maps menu items to side-by-side and stacked displays")
    func resolvesDisplayGeometry() {
        let resolver = DisplaySurfaceResolver(surfaces: [
            .init(token: "left", frame: frame(x: -1_920, y: 0, width: 1_920, height: 1_080)),
            .init(token: "main", frame: frame(x: 0, y: 0, width: 2_560, height: 1_440)),
            .init(token: "upper", frame: frame(x: 0, y: -900, width: 1_600, height: 900)),
        ])

        #expect(resolver.surfaceToken(for: frame(x: -200, y: 0, width: 24, height: 24)) == "left")
        #expect(resolver.surfaceToken(for: frame(x: 2_000, y: 0, width: 24, height: 24)) == "main")
        #expect(resolver.surfaceToken(for: frame(x: 600, y: -900, width: 24, height: 24)) == "upper")
        #expect(resolver.surfaceToken(for: frame(x: 4_000, y: 0, width: 24, height: 24)) == nil)
    }

    private func frame(
        x horizontalPosition: Double,
        y verticalPosition: Double,
        width: Double,
        height: Double
    ) -> MenuBarItemFrame {
        MenuBarItemFrame(
            minX: horizontalPosition,
            minY: verticalPosition,
            width: width,
            height: height
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
        let deadline = OperationDeadline(timeout: .seconds(1))

        let first = try await discovery.snapshot(
            applications: [observation.owner],
            deadline: deadline
        )
        let second = try await discovery.snapshot(
            applications: [observation.owner],
            deadline: deadline
        )

        #expect(first.generation == 1)
        #expect(second.generation == 2)
        #expect(second.items.count == 1)
    }

    @Test("preserves partial-source status without exposing source identities")
    func preservesPartialStatus() async throws {
        let reader = FixtureObservationReader(observations: [], unavailableSourceCount: 2)
        let discovery = MenuBarTopologyDiscovery(reader: reader)

        let snapshot = try await discovery.snapshot(
            applications: [],
            deadline: OperationDeadline(timeout: .seconds(1))
        )

        #expect(snapshot.unavailableSourceCount == 2)
        #expect(!snapshot.isComplete)
    }

    @Test("does not turn a failed observation into an empty authoritative snapshot")
    func preservesFailure() async {
        let discovery = MenuBarTopologyDiscovery(reader: FailingObservationReader())

        await #expect(throws: MenuBarAuthorizationError.permissionRevoked) {
            try await discovery.snapshot(
                applications: [],
                deadline: OperationDeadline(timeout: .seconds(1))
            )
        }
    }

    @Test("forwards the exact operation deadline to observation")
    func forwardsDeadline() async throws {
        let reader = DeadlineRecordingObservationReader()
        let discovery = MenuBarTopologyDiscovery(reader: reader)
        let deadline = OperationDeadline(timeout: .seconds(2))

        _ = try await discovery.snapshot(applications: [], deadline: deadline)

        #expect(await reader.receivedDeadline == deadline.expiresAt)
    }
}

private struct FixtureObservationReader: MenuBarObservationReading {
    let observations: [MenuBarObservation]
    var unavailableSourceCount = 0

    func observations(
        for _: [RunningApplicationDescriptor],
        deadline _: OperationDeadline
    ) async throws -> MenuBarObservationBatch {
        MenuBarObservationBatch(
            observations: observations,
            unavailableSourceCount: unavailableSourceCount
        )
    }
}

private struct FailingObservationReader: MenuBarObservationReading {
    func observations(
        for _: [RunningApplicationDescriptor],
        deadline _: OperationDeadline
    ) async throws -> MenuBarObservationBatch {
        throw MenuBarAuthorizationError.permissionRevoked
    }
}

private actor DeadlineRecordingObservationReader: MenuBarObservationReading {
    private(set) var receivedDeadline: ContinuousClock.Instant?

    func observations(
        for _: [RunningApplicationDescriptor],
        deadline: OperationDeadline
    ) -> MenuBarObservationBatch {
        receivedDeadline = deadline.expiresAt
        return MenuBarObservationBatch(observations: [])
    }
}
