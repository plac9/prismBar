// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct PrismCanvasBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            canvasBase

            if !reduceTransparency {
                AngularGradient(
                    colors: [
                        Color(red: 0.14, green: 0.55, blue: 1.00).opacity(0.30),
                        Color(red: 0.44, green: 0.84, blue: 1.00).opacity(0.18),
                        Color(red: 0.48, green: 0.42, blue: 1.00).opacity(0.22),
                        .clear,
                        Color(red: 0.14, green: 0.55, blue: 1.00).opacity(0.30),
                    ],
                    center: .topLeading,
                    startAngle: .degrees(-30),
                    endAngle: .degrees(250)
                )
                .blur(radius: 54)

                LinearGradient(
                    colors: [
                        .clear,
                        canvasBase.opacity(0.30),
                        canvasBase.opacity(0.88),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.26)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var canvasBase: Color {
        colorScheme == .dark
            ? Color(red: 0.045, green: 0.065, blue: 0.095)
            : Color(red: 0.925, green: 0.955, blue: 0.985)
    }
}

struct PrismContentSection<Content: View>: View {
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
            .padding(.vertical, 16)
            .padding(.leading, tint == nil ? 0 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                Divider()
            }
            .overlay(alignment: .leading) {
                if let tint {
                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: 3)
                        .padding(.vertical, 16)
                        .accessibilityHidden(true)
                }
            }
    }
}

struct PageHeader: View {
    let symbol: String
    let eyebrow: String
    let title: String
    let message: String
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(eyebrow, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(identifier)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
