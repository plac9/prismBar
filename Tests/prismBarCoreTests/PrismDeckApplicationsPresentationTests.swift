// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarCore
import Testing

@Suite("prismDeck applications presentation")
struct PrismDeckApplicationsPresentationTests {
    private let primary = MenuBarSurfaceID(rawValue: "fixture.primary")

    @Test("includes only application-owned items on the selected display")
    func filtersOwnershipRoleAndSurface() {
        let presentation = PrismDeckApplicationsPresenter().make(
            snapshot: fixtureSnapshot(),
            surfaceID: primary,
            query: ""
        )

        #expect(presentation.visibleRows.map(\.name) == ["Synthetic Mail", "Synthetic Chat"])
        #expect(presentation.hiddenRows.map(\.name) == ["Synthetic Calendar"])
        #expect(presentation.totalApplicationCount == 3)
        #expect(presentation.visibleRows[0].sectionPosition == 1)
        #expect(presentation.visibleRows[1].sectionPosition == 2)
    }

    @Test("derives only valid endpoint commands")
    func derivesEndpoints() {
        let presentation = PrismDeckApplicationsPresenter().make(
            snapshot: fixtureSnapshot(),
            surfaceID: primary,
            query: ""
        )

        #expect(presentation.visibleRows[0].firstDestinationPosition == nil)
        #expect(presentation.visibleRows[0].lastDestinationPosition == 3)
        #expect(presentation.visibleRows[1].firstDestinationPosition == 2)
        #expect(presentation.visibleRows[1].lastDestinationPosition == nil)
    }

    @Test("search is localized and case insensitive")
    func searchesRenderedNameOnly() {
        let result = PrismDeckApplicationsPresenter().make(
            snapshot: fixtureSnapshot(),
            surfaceID: primary,
            query: "cHaT"
        )

        #expect(result.filteredRows.map(\.name) == ["Synthetic Chat"])
        #expect(result.totalApplicationCount == 3)
        #expect(result.queryIsEmpty == false)
    }

    @Test("unavailable applications remain visible but fail closed")
    func unavailableRowsHaveNoCommands() {
        let row = PrismDeckApplicationsPresenter().make(
            snapshot: unavailableSnapshot(),
            surfaceID: primary,
            query: ""
        ).visibleRows[0]

        #expect(row.allowsVerifiedMovement == false)
        #expect(row.firstDestinationPosition == nil)
        #expect(row.lastDestinationPosition == nil)
    }

    @Test("selection validity follows the unfiltered selected display")
    func validatesSelectionIndependentOfSearch() {
        let result = PrismDeckApplicationsPresenter().make(
            snapshot: fixtureSnapshot(),
            surfaceID: primary,
            query: "mail"
        )

        #expect(result.containsApplication(itemID: id("chat")))
        #expect(!result.containsApplication(itemID: id("secondary")))
        #expect(!result.containsApplication(itemID: id("clock")))
    }

    private func fixtureSnapshot() -> MenuBarSnapshot {
        let secondary = MenuBarSurfaceID(rawValue: "fixture.secondary")
        return MenuBarSnapshot(
            generation: 7,
            items: [
                item("calendar", name: "Synthetic Calendar", position: 0),
                item(
                    "divider",
                    name: "Synthetic Divider",
                    position: 1,
                    isMovable: false,
                    ownership: .selfOwned,
                    role: .hiddenSectionDivider
                ),
                item("mail", name: "Synthetic Mail", position: 2),
                item("chat", name: "Synthetic Chat", position: 3),
                item(
                    "clock",
                    name: "Synthetic Clock",
                    position: 4,
                    isMovable: false,
                    ownership: .system
                ),
                item(
                    "control",
                    name: "Synthetic Control",
                    position: 5,
                    isMovable: false,
                    ownership: .selfOwned,
                    role: .primaryControl
                ),
                item(
                    "secondary",
                    name: "Synthetic Secondary",
                    position: 6,
                    surface: secondary
                ),
            ]
        )
    }

    private func unavailableSnapshot() -> MenuBarSnapshot {
        MenuBarSnapshot(
            generation: 1,
            items: [
                item(
                    "divider",
                    name: "Synthetic Divider",
                    position: 0,
                    isMovable: false,
                    ownership: .selfOwned,
                    role: .hiddenSectionDivider
                ),
                item(
                    "unavailable",
                    name: "Synthetic Unavailable",
                    position: 1,
                    isMovable: false,
                    availability: .unavailable
                ),
            ]
        )
    }

    private func item(
        _ identifier: String,
        name: String,
        position: Int,
        isMovable: Bool = true,
        ownership: MenuBarItemOwnership = .application,
        availability: MenuBarItemAvailability = .controllable,
        role: MenuBarItemRole = .item,
        surface: MenuBarSurfaceID? = nil
    ) -> MenuBarItem {
        MenuBarItem(
            id: id(identifier),
            position: position,
            isMovable: isMovable,
            displayName: name,
            ownerBundleIdentifier: "com.example.synthetic",
            ownership: ownership,
            availability: availability,
            role: role,
            surfaceID: surface ?? primary
        )
    }

    private func id(_ value: String) -> MenuBarItemID {
        MenuBarItemID(rawValue: "fixture.\(value)")
    }
}
