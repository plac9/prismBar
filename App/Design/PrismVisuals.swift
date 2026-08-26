// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct PrismBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(baseGradient)

            if !reduceTransparency {
                PrismLightField(opacity: contrast == .increased ? 0.28 : 0.46)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var baseGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.035, blue: 0.07),
                    Color(red: 0.015, green: 0.02, blue: 0.04),
                    Color(red: 0.035, green: 0.055, blue: 0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.975, blue: 1),
                Color(nsColor: .windowBackgroundColor),
                Color(red: 0.91, green: 0.95, blue: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct PrismLightField: View {
    @Environment(\.colorScheme) private var colorScheme
    let opacity: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Ellipse()
                    .fill(Color.cyan.opacity(colorScheme == .dark ? 0.24 : 0.18))
                    .frame(width: proxy.size.width * 0.72, height: proxy.size.height * 0.54)
                    .blur(radius: 90)
                    .offset(x: -proxy.size.width * 0.31, y: -proxy.size.height * 0.30)

                Ellipse()
                    .fill(Color.blue.opacity(colorScheme == .dark ? 0.30 : 0.14))
                    .frame(width: proxy.size.width * 0.64, height: proxy.size.height * 0.62)
                    .blur(radius: 110)
                    .offset(x: proxy.size.width * 0.34, y: proxy.size.height * 0.30)

                PrismRay()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.cyan.opacity(0.22), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * 0.86, height: proxy.size.height * 0.28)
                    .rotationEffect(.degrees(-14))
                    .offset(x: proxy.size.width * 0.18, y: -proxy.size.height * 0.08)
                    .blur(radius: 20)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .opacity(opacity)
        }
    }
}

private struct PrismRay: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY * 0.72))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if reduceTransparency {
            content
                .padding(20)
                .background(.background.opacity(contrast == .increased ? 1 : 0.92))
                .clipShape(.rect(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.separator, lineWidth: contrast == .increased ? 1.5 : 0.5)
                }
        } else {
            content
                .padding(20)
                .glassEffect(
                    .regular.tint(Color.accentColor.opacity(contrast == .increased ? 0.04 : 0.08)),
                    in: .rect(cornerRadius: 20)
                )
        }
    }
}

struct SectionHeading: View {
    let title: String
    let message: String?
    let symbol: String

    init(_ title: String, message: String? = nil, systemImage symbol: String) {
        self.title = title
        self.message = message
        self.symbol = symbol
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(.tint)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let message {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct PageHeader: View {
    let eyebrow: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            PrismMark(size: 44)
                .fixedSize()

            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
    }
}
