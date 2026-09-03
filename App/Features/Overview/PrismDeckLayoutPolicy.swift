// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreGraphics
import prismBarCore

enum PrismDeckManagementSection: Equatable {
    case topology
    case rail
    case applications
    case actionStatus
}

enum PrismDeckLayoutPolicy {
    static let managementSections: [PrismDeckManagementSection] = [
        .topology,
        .rail,
        .applications,
        .actionStatus,
    ]
    private static let standardWidth: CGFloat = 440
    private static let standardCompactHeight: CGFloat = 360
    private static let standardMaximumHeight: CGFloat = 620
    private static let horizontalScreenMargin: CGFloat = 48
    private static let verticalScreenMargin: CGFloat = 40
    static let showsPrismCards = false
    static let showsReset = false

    static func width(for textSize: PrismTextSizePreference) -> CGFloat {
        standardWidth + CGFloat(textSize.scale - 1) * 120
    }

    static func compactHeight(for textSize: PrismTextSizePreference) -> CGFloat {
        standardCompactHeight + CGFloat(textSize.scale - 1) * 120
    }

    static func maximumHeight(for textSize: PrismTextSizePreference) -> CGFloat {
        standardMaximumHeight + CGFloat(textSize.scale - 1) * 100
    }

    static func height(
        accessibilityGranted: Bool,
        textSize: PrismTextSizePreference
    ) -> CGFloat {
        accessibilityGranted ? maximumHeight(for: textSize) : compactHeight(for: textSize)
    }

    static func contentSize(
        accessibilityGranted: Bool,
        textSize: PrismTextSizePreference,
        visibleFrameSize: CGSize
    ) -> CGSize {
        let preferredWidth = width(for: textSize)
        let preferredHeight = height(
            accessibilityGranted: accessibilityGranted,
            textSize: textSize
        )
        return CGSize(
            width: min(preferredWidth, max(0, visibleFrameSize.width - horizontalScreenMargin)),
            height: min(preferredHeight, max(0, visibleFrameSize.height - verticalScreenMargin))
        )
    }
}
