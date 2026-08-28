// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
@testable import prismBarCore

@Suite("Presentation catalog")
struct PresentationCatalogTests {
    @Test("uses stable unique scene identifiers")
    func sceneIdentifiers() {
        let identifiers = [
            PrismSceneID.workspace,
            PrismSceneID.prismCalc,
        ]

        #expect(Set(identifiers).count == identifiers.count)
        #expect(PrismSceneID.workspace == "prismbar.workspace")
        #expect(PrismSceneID.prismCalc == "prismbar.tool.prismcalc")
    }

    @Test("presents the approved workspace order and copy")
    func workspaceDestinations() {
        #expect(WorkspaceDestination.primary == [.home, .menuBar, .tools, .automation])
        #expect(WorkspaceDestination.information == [.privacy, .about])
        #expect(WorkspaceDestination.tools.title == "Tools")
        #expect(WorkspaceDestination.automation.title == "Automation")
        #expect(WorkspaceDestination.allCases.map(\.id).allSatisfy { !$0.isEmpty })
    }

    @Test("limits Prism Deck to Bar and Tools")
    func prismDeckModes() {
        #expect(PrismDeckMode.allCases == [.bar, .tools])
        #expect(PrismDeckMode.bar.title == "Bar")
        #expect(PrismDeckMode.tools.title == "Tools")
    }

    @Test("uses the approved compact menu bar control name")
    func railName() {
        #expect(PrismRailPresentation.title == "Rail")
    }

    @Test("registers prismCalc as the first closed tool identifier")
    func toolIdentifiers() {
        #expect(PrismToolID.allCases == [.prismCalc])
        #expect(PrismToolID.prismCalc.displayName == "prismCalc")
    }

    @Test("distinguishes observed items from unavailable sources")
    func menuBarObservationSummary() {
        let partial = MenuBarObservationPresentation(
            itemCount: 18,
            unavailableSourceCount: 25
        )
        let complete = MenuBarObservationPresentation(
            itemCount: 1,
            unavailableSourceCount: 0
        )

        #expect(partial.summary == "18 items, 25 sources unavailable")
        #expect(partial.isComplete == false)
        #expect(complete.summary == "1 item")
        #expect(complete.isComplete)
    }

    @Test("pluralizes unavailable menu bar source warnings")
    func unavailableSourceWarnings() {
        let single = MenuBarObservationPresentation(
            itemCount: 1,
            unavailableSourceCount: 1
        )
        let multiple = MenuBarObservationPresentation(
            itemCount: 1,
            unavailableSourceCount: 2
        )

        #expect(
            single.unavailableSourcesWarning ==
                "1 menu bar source did not respond. Visible items remain available and every move is still verified."
        )
        #expect(
            multiple.unavailableSourcesWarning ==
                "2 menu bar sources did not respond. Visible items remain available and every move is still verified."
        )
    }
}
