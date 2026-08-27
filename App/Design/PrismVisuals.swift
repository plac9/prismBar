// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import SwiftUI

struct PrismCanvasBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            LinearGradient(
                colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.16 : 0.10),
                    .clear,
                    Color.indigo.opacity(colorScheme == .dark ? 0.12 : 0.07),
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            RadialGradient(
                colors: [
                    Color.cyan.opacity(colorScheme == .dark ? 0.10 : 0.07),
                    .clear,
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct PrismGlassSurface<Content: View>: View {
    private let tint: Color?
    private let content: Content

    init(
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .glassEffect(glass, in: .rect(cornerRadius: 20))
    }

    private var glass: Glass {
        guard let tint else { return .regular }
        return .regular.tint(tint.opacity(0.16))
    }
}

struct PageHeader: View {
    let symbol: String
    let eyebrow: String
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(eyebrow, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
