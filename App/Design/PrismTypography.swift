// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import SwiftUI

enum PrismFontRole {
    case caption2
    case caption
    case footnote
    case callout
    case body
    case headline
    case title3
    case title2
    case title

    var baseSize: CGFloat {
        switch self {
        case .caption2: 11
        case .caption, .footnote: 12
        case .callout, .body, .headline: 13
        case .title3: 18
        case .title2: 22
        case .title: 28
        }
    }

    var defaultWeight: Font.Weight {
        switch self {
        case .headline: .semibold
        case .title, .title2, .title3: .regular
        case .caption2, .caption, .footnote, .callout, .body: .regular
        }
    }
}

private struct PrismTextSizePreferenceKey: EnvironmentKey {
    static let defaultValue = PrismTextSizePreference.standard
}

extension EnvironmentValues {
    var prismTextSizePreference: PrismTextSizePreference {
        get { self[PrismTextSizePreferenceKey.self] }
        set { self[PrismTextSizePreferenceKey.self] = newValue }
    }
}

private struct PrismFontModifier: ViewModifier {
    @Environment(\.prismTextSizePreference) private var preference
    let role: PrismFontRole
    let weight: Font.Weight?
    let design: Font.Design
    let usesMonospacedDigits: Bool

    func body(content: Content) -> some View {
        var font = Font.system(
            size: role.baseSize * CGFloat(preference.scale),
            weight: weight ?? role.defaultWeight,
            design: design
        )
        if usesMonospacedDigits {
            font = font.monospacedDigit()
        }
        return content.font(font)
    }
}

extension View {
    func prismFont(
        _ role: PrismFontRole,
        weight: Font.Weight? = nil,
        design: Font.Design = .default,
        monospacedDigits: Bool = false
    ) -> some View {
        modifier(
            PrismFontModifier(
                role: role,
                weight: weight,
                design: design,
                usesMonospacedDigits: monospacedDigits
            )
        )
    }
}

struct PrismTextSizeScope<Content: View>: View {
    @AppStorage(PrismTextSizePreference.storageKey) private var storedValue =
        PrismTextSizePreference.standard.rawValue
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let preference = PrismTextSizePreference(storedValue: storedValue)
        content
            .prismFont(.body)
            .environment(\.prismTextSizePreference, preference)
    }
}
