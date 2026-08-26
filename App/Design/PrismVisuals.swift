// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct PrismBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.windowBackground)

            if !reduceTransparency {
                GeometryReader { proxy in
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.20), .clear],
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: proxy.size.width * 0.72
                    )
                    RadialGradient(
                        colors: [Color.indigo.opacity(0.17), .clear],
                        center: .bottomTrailing,
                        startRadius: 20,
                        endRadius: proxy.size.width * 0.66
                    )
                    LinearGradient(
                        colors: [.clear, Color.blue.opacity(0.04), .clear],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct PrismMark: View {
    var size: CGFloat = 44

    var body: some View {
        Image("PrismMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: .blue.opacity(0.20), radius: size * 0.16, y: size * 0.08)
            .accessibilityHidden(true)
    }
}

struct GlassCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .glassEffect(
                .regular.tint(Color.accentColor.opacity(0.07)),
                in: .rect(cornerRadius: 22)
            )
    }
}

struct PageHeader: View {
    let eyebrow: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            PrismMark(size: 48)
                .fixedSize()

            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text(message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
