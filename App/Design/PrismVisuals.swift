// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import SwiftUI

struct PrismCanvasBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            if !reduceTransparency && colorSchemeContrast != .increased {
                RadialGradient(
                    colors: [
                        Color.accentColor.opacity(0.08),
                        .clear,
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 560
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct PrismGateView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.7))
                .frame(height: 1)

            HStack(spacing: 5) {
                Image(systemName: "triangle.lefthalf.filled")
                    .font(.caption2)
                    .foregroundStyle(gateStyle)
                    .accessibilityHidden(true)

                Text("PRISM GATE")
                    .font(.caption2.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(isActive ? .primary : .secondary)

                Image(systemName: "triangle.righthalf.filled")
                    .font(.caption2)
                    .foregroundStyle(gateStyle)
                    .accessibilityHidden(true)
            }

            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.7))
                .frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Visibility boundary")
    }

    // MARK: Apple/Platform Behavior Override
    // What: Uses a fixed Prism spectrum instead of a single system tint for the Rail boundary.
    // Why: The boundary is prismBar's one branded spatial landmark and never communicates status.
    // Re-evaluate: Replace it if system materials lose contrast or macOS changes gradient rendering.
    private var gateStyle: AnyShapeStyle {
        guard !differentiateWithoutColor else {
            return AnyShapeStyle(isActive ? Color.primary : Color.secondary)
        }
        guard !reduceTransparency else {
            return AnyShapeStyle(Color.accentColor)
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.52, blue: 0.98),
                    Color(red: 0.38, green: 0.30, blue: 0.92),
                    Color(red: 0.91, green: 0.28, blue: 0.68),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
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
                .foregroundStyle(.primary)

            Text(title)
                .font(.title.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(identifier)

            Text(message)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
