// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreGraphics

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
    static let maximumHeight: CGFloat = 620
    static let showsPrismCards = false
    static let showsReset = false
}
