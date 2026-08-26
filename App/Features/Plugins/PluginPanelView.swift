// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismPluginKit
import SwiftUI

struct PluginsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    eyebrow: "Extensions",
                    title: "Plugins",
                    message: "Focused tools in isolated, signed services. Plugins never receive " +
                        "Accessibility, file, or network access."
                )

                pluginContent
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(32)
        }
        .task {
            model.loadPluginIfNeeded()
        }
    }

    @ViewBuilder
    private var pluginContent: some View {
        switch model.pluginState {
        case .idle, .loading:
            ProgressView("Connecting to prismCalc…")
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: 280)
        case .ready:
            if let update = model.pluginPanel {
                PluginPanelView(update: update, compact: false)
            }
        case .unavailable, .disabled:
            ContentUnavailableView {
                Label("prismCalc unavailable", systemImage: "puzzlepiece.extension")
            } description: {
                Text(model.pluginMessage ?? "The isolated plugin service did not respond.")
            } actions: {
                Button("Retry", systemImage: "arrow.clockwise") {
                    model.retryPlugin()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 280)
        }
    }
}

struct PluginPanelView: View {
    @Environment(AppModel.self) private var model

    let update: PluginPanelUpdate
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 16) {
            if !compact {
                HStack {
                    Label(update.panel.title, systemImage: "plus.forwardslash.minus")
                        .font(.title2.bold())
                    Spacer()
                    Label("Isolated service", systemImage: "checkmark.shield")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(Array(update.panel.elements.enumerated()), id: \.offset) { _, element in
                elementView(element)
            }

            if let message = model.pluginMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("plugin.message")
            }
        }
        .padding(compact ? 10 : 20)
        .glassEffect(.regular, in: .rect(cornerRadius: compact ? 14 : 22))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plugin.panel")
    }

    @ViewBuilder
    private func elementView(_ element: PluginPanelElement) -> some View {
        switch element {
        case let .result(result):
            Text(result.value)
                .font(resultFont)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .accessibilityLabel(result.accessibilityLabel)
                .accessibilityValue(result.value)
                .accessibilityIdentifier(result.identifier)
        case let .keypad(keypad):
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: compact ? 5 : 8),
                    count: keypad.columns
                ),
                spacing: compact ? 5 : 8
            ) {
                ForEach(keypad.keys, id: \.identifier) { key in
                    keyButton(key)
                }
            }
        case let .actions(group):
            HStack(spacing: 8) {
                ForEach(group.actions, id: \.identifier) { action in
                    actionButton(action)
                }
            }
        case let .status(status):
            Label(status.message, systemImage: statusSymbol(status.kind))
                .font(.caption)
                .foregroundStyle(status.kind == .error ? .red : .secondary)
                .accessibilityIdentifier(status.identifier)
        }
    }

    @ViewBuilder
    private func keyButton(_ key: PluginKeyDescriptor) -> some View {
        if key.style == .accent {
            Button {
                model.invokePluginCommand(key.commandIdentifier)
            } label: {
                Text(key.label)
                    .frame(maxWidth: .infinity, minHeight: compact ? 26 : 40)
            }
            .buttonStyle(.glassProminent)
            .tint(keyTint(key.style))
            .disabled(model.isPluginActionInProgress)
            .accessibilityLabel(key.accessibilityLabel)
            .accessibilityIdentifier(key.identifier)
        } else {
            Button {
                model.invokePluginCommand(key.commandIdentifier)
            } label: {
                Text(key.label)
                    .frame(maxWidth: .infinity, minHeight: compact ? 26 : 40)
            }
            .buttonStyle(.glass)
            .tint(keyTint(key.style))
            .disabled(model.isPluginActionInProgress)
            .accessibilityLabel(key.accessibilityLabel)
            .accessibilityIdentifier(key.identifier)
        }
    }

    @ViewBuilder
    private func actionButton(_ action: PluginActionDescriptor) -> some View {
        if action.style == .accent {
            Button(action.label) {
                model.invokePluginCommand(action.commandIdentifier)
            }
            .buttonStyle(.glassProminent)
            .disabled(model.isPluginActionInProgress)
            .accessibilityLabel(action.accessibilityLabel)
            .accessibilityIdentifier(action.identifier)
        } else {
            Button(action.label) {
                model.invokePluginCommand(action.commandIdentifier)
            }
            .buttonStyle(.glass)
            .disabled(model.isPluginActionInProgress)
            .accessibilityLabel(action.accessibilityLabel)
            .accessibilityIdentifier(action.identifier)
        }
    }

    private func keyTint(_ style: PluginKeyStyle) -> Color {
        switch style {
        case .standard: .secondary
        case .secondary: .gray
        case .operation: .orange
        case .accent: .blue
        }
    }

    private var resultFont: Font {
        if compact {
            return .title2.monospacedDigit()
        }
        return .system(size: 44, weight: .medium, design: .rounded).monospacedDigit()
    }

    private func statusSymbol(_ kind: PluginStatusKind) -> String {
        switch kind {
        case .information: "info.circle"
        case .success: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.circle"
        }
    }
}
