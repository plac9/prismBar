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
                    symbol: "wrench.and.screwdriver",
                    eyebrow: "Tools",
                    title: "Tools that stay out of your way.",
                    message: "Enable and inspect focused utilities here, then open each tool in its own window. " +
                        "The plugin framework keeps every tool isolated and capability-limited."
                )
                .accessibilityIdentifier("tools.header.wrench.and.screwdriver")

                if let registration = model.bundledPluginRegistrations.first {
                    pluginCard(registration)
                } else {
                    ContentUnavailableView(
                        "Plugin registry unavailable",
                        systemImage: "exclamationmark.shield",
                        description: Text("prismBar could not validate its bundled plugin catalog.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 280)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(32)
        }
        .task {
            model.loadPluginIfNeeded()
        }
    }

    private func pluginCard(_ registration: BundledPluginRegistration) -> some View {
        PrismGlassSurface {
            VStack(alignment: .leading, spacing: 14) {
                Label("Available tools", systemImage: "shippingbox")
                    .font(.headline)

                Divider()

                toolIdentity(registration)

                Text("prismCalc runs outside the prismBar process with no Accessibility, network, or file access. " +
                    "Only validated controls and explicit local actions cross the connection.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                toolCapabilities(registration)

                Divider()
                toolActions
            }
        }
    }

    private func toolIdentity(_ registration: BundledPluginRegistration) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.forwardslash.minus")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(registration.displayName)
                    .font(.headline)
                Text("Bundled first-party tool  •  v\(version(registration.version))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("Enable \(registration.displayName)", isOn: pluginEnabledBinding)
                .labelsHidden()
                .accessibilityIdentifier("plugin.enabled")
        }
    }

    private func toolCapabilities(_ registration: BundledPluginRegistration) -> some View {
        HStack(spacing: 8) {
            ForEach(
                registration.capabilities.sorted { $0.rawValue < $1.rawValue },
                id: \.rawValue
            ) { capability in
                capabilityBadge(capability)
            }
            Spacer()
            Label(pluginHealthTitle, systemImage: pluginHealthSymbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(pluginHealthColor)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Plugin health: \(pluginHealthTitle)")
                .accessibilityIdentifier("plugin.health")
        }
    }

    private var toolActions: some View {
        HStack(spacing: 10) {
            if model.pluginState == .unavailable || model.pluginState == .paused {
                Button("Retry", systemImage: "arrow.clockwise") {
                    model.retryPlugin()
                }
                .buttonStyle(.glass)
            }

            if let message = model.pluginMessage,
               model.pluginState != .ready {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button("Open prismCalc", systemImage: "arrow.up.forward.app") {
                AppWindowController.shared.showPrismCalc()
            }
            .buttonStyle(.glassProminent)
            .disabled(!model.isPluginEnabled || model.pluginState != .ready)
        }
    }

    private var pluginEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.isPluginEnabled },
            set: { model.setPluginEnabled($0) }
        )
    }

    private var pluginHealthTitle: String {
        switch model.pluginState {
        case .idle, .loading:
            "Verifying service"
        case .ready:
            "Verified and ready"
        case .unavailable:
            "Connection needs attention"
        case .paused:
            "Paused for safety"
        case .disabled:
            "Plugin off"
        }
    }

    private var pluginHealthSymbol: String {
        switch model.pluginState {
        case .idle, .loading:
            "lock.shield"
        case .ready:
            "checkmark.shield"
        case .unavailable:
            "exclamationmark.triangle"
        case .paused:
            "pause.circle"
        case .disabled:
            "power"
        }
    }

    private var pluginHealthColor: Color {
        switch model.pluginState {
        case .ready:
            .green
        case .unavailable, .paused:
            .orange
        case .idle, .loading, .disabled:
            .secondary
        }
    }

    private func capabilityBadge(_ capability: PluginCapability) -> some View {
        Label(capabilityTitle(capability), systemImage: capabilitySymbol(capability))
            .font(.caption.weight(.medium))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.background.secondary, in: .capsule)
    }

    private func capabilityTitle(_ capability: PluginCapability) -> String {
        switch capability {
        case .panel: "Panel"
        case .commands: "Commands"
        case .openApplication: "Open app"
        }
    }

    private func capabilitySymbol(_ capability: PluginCapability) -> String {
        switch capability {
        case .panel: "rectangle.on.rectangle"
        case .commands: "command"
        case .openApplication: "arrow.up.forward.app"
        }
    }

    private func version(_ version: SemanticVersion) -> String {
        "\(version.major).\(version.minor).\(version.patch)"
    }
}

struct PluginPanelView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .background(.background.secondary, in: .rect(cornerRadius: compact ? 14 : 16))
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 14 : 16)
                .stroke(.separator, lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plugin.panel")
    }

    @ViewBuilder
    private func elementView(_ element: PluginPanelElement) -> some View {
        switch element {
        case let .result(result):
            Text(result.value)
                .font(resultFont)
                .contentTransition(reduceMotion ? .identity : .numericText())
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
        case .operation: .indigo
        case .accent: .cyan
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
