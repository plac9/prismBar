// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct PrismDeckApplicationRow: Identifiable, Equatable, Sendable {
    public let id: MenuBarItemID
    public let name: String
    public let ownerBundleIdentifier: String?
    public let section: MenuBarSection
    public let sectionPosition: Int
    public let sectionCount: Int
    public let availability: MenuBarItemAvailability
    public let allowsVerifiedMovement: Bool
    public let firstDestinationPosition: Int?
    public let lastDestinationPosition: Int?

    public init(
        id: MenuBarItemID,
        name: String,
        ownerBundleIdentifier: String?,
        section: MenuBarSection,
        sectionPosition: Int,
        sectionCount: Int,
        availability: MenuBarItemAvailability,
        allowsVerifiedMovement: Bool,
        firstDestinationPosition: Int?,
        lastDestinationPosition: Int?
    ) {
        self.id = id
        self.name = name
        self.ownerBundleIdentifier = ownerBundleIdentifier
        self.section = section
        self.sectionPosition = sectionPosition
        self.sectionCount = sectionCount
        self.availability = availability
        self.allowsVerifiedMovement = allowsVerifiedMovement
        self.firstDestinationPosition = firstDestinationPosition
        self.lastDestinationPosition = lastDestinationPosition
    }
}

public struct PrismDeckApplicationsPresentation: Equatable, Sendable {
    public let visibleRows: [PrismDeckApplicationRow]
    public let hiddenRows: [PrismDeckApplicationRow]
    public let totalApplicationCount: Int
    public let queryIsEmpty: Bool
    private let applicationIDs: Set<MenuBarItemID>

    public init(
        visibleRows: [PrismDeckApplicationRow],
        hiddenRows: [PrismDeckApplicationRow],
        totalApplicationCount: Int,
        queryIsEmpty: Bool,
        applicationIDs: Set<MenuBarItemID>
    ) {
        self.visibleRows = visibleRows
        self.hiddenRows = hiddenRows
        self.totalApplicationCount = totalApplicationCount
        self.queryIsEmpty = queryIsEmpty
        self.applicationIDs = applicationIDs
    }

    public var filteredRows: [PrismDeckApplicationRow] {
        visibleRows + hiddenRows
    }

    public func containsApplication(itemID: MenuBarItemID) -> Bool {
        applicationIDs.contains(itemID)
    }
}

public struct PrismDeckApplicationsPresenter: Sendable {
    public init() {}

    public func make(
        snapshot: MenuBarSnapshot,
        surfaceID: MenuBarSurfaceID,
        query: String
    ) -> PrismDeckApplicationsPresentation {
        let layout = PrismRailLayout(snapshot: snapshot, surfaceID: surfaceID)
        let allVisibleRows = rows(for: layout.visibleItems, section: .visible, snapshot: snapshot)
        let allHiddenRows = rows(for: layout.hiddenItems, section: .hidden, snapshot: snapshot)
        let allRows = allVisibleRows + allHiddenRows

        return PrismDeckApplicationsPresentation(
            visibleRows: filtered(allVisibleRows, query: query),
            hiddenRows: filtered(allHiddenRows, query: query),
            totalApplicationCount: allRows.count,
            queryIsEmpty: query.isEmpty,
            applicationIDs: Set(allRows.map(\.id))
        )
    }

    private func rows(
        for laneItems: [MenuBarItem],
        section: MenuBarSection,
        snapshot: MenuBarSnapshot
    ) -> [PrismDeckApplicationRow] {
        laneItems.enumerated().compactMap { offset, item in
            guard item.role == .item, item.ownership == .application else {
                return nil
            }

            let firstDestination = item.allowsVerifiedMovement
                ? PrismRailKeyboardMoveResolver().resolve(.first, itemID: item.id, in: snapshot)
                : nil
            let lastDestination = item.allowsVerifiedMovement
                ? PrismRailKeyboardMoveResolver().resolve(.last, itemID: item.id, in: snapshot)
                : nil

            return PrismDeckApplicationRow(
                id: item.id,
                name: item.displayName,
                ownerBundleIdentifier: item.ownerBundleIdentifier,
                section: section,
                sectionPosition: offset + 1,
                sectionCount: laneItems.count,
                availability: item.availability,
                allowsVerifiedMovement: item.allowsVerifiedMovement,
                firstDestinationPosition: firstDestination,
                lastDestinationPosition: lastDestination
            )
        }
    }

    private func filtered(
        _ rows: [PrismDeckApplicationRow],
        query: String
    ) -> [PrismDeckApplicationRow] {
        guard !query.isEmpty else { return rows }
        return rows.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}
