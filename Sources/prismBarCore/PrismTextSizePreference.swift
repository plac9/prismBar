// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

public enum PrismTextSizePreference: String, CaseIterable, Codable, Sendable {
    case standard
    case large
    case extraLarge
    case accessibility

    public static let storageKey = "prismBar.textSize"

    public init(storedValue: String?) {
        self = storedValue.flatMap(Self.init(rawValue:)) ?? .standard
    }

    public var scale: Double {
        switch self {
        case .standard: 1
        case .large: 1.25
        case .extraLarge: 1.5
        case .accessibility: 2
        }
    }

    public var title: String {
        switch self {
        case .standard: "Standard"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        case .accessibility: "Accessibility"
        }
    }

    public var percentageLabel: String {
        "\(Int(scale * 100))%"
    }
}
