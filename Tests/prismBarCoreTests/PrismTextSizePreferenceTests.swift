// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarCore
import Testing

struct PrismTextSizePreferenceTests {
    @Test
    func supportedSizesIncreaseMonotonicallyThroughTwoHundredPercent() {
        let preferences = PrismTextSizePreference.allCases

        #expect(preferences.map(\.scale) == [1, 1.25, 1.5, 2])
        #expect(preferences.first == .standard)
        #expect(preferences.last == .accessibility)
    }

    @Test
    func storedValuesFailClosedToTheStandardSize() {
        #expect(PrismTextSizePreference(storedValue: nil) == .standard)
        #expect(PrismTextSizePreference(storedValue: "") == .standard)
        #expect(PrismTextSizePreference(storedValue: "unsupported") == .standard)
        #expect(PrismTextSizePreference(storedValue: "large") == .large)
    }

    @Test
    func everySizeHasStableUserFacingCopy() {
        #expect(PrismTextSizePreference.standard.title == "Standard")
        #expect(PrismTextSizePreference.large.title == "Large")
        #expect(PrismTextSizePreference.extraLarge.title == "Extra Large")
        #expect(PrismTextSizePreference.accessibility.title == "Accessibility")
        #expect(PrismTextSizePreference.accessibility.percentageLabel == "200%")
    }
}
