// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import prismPluginKit
import SwiftUI

#if DEBUG
enum UIAuditPluginFixture {
    static let panel = PluginPanelUpdate(
        panel: PluginPanelDescriptor(
            identifier: "calculator.panel",
            title: "prismCalc",
            elements: [
                .result(
                    PluginResultDescriptor(
                        identifier: "calculator.result",
                        value: "42",
                        accessibilityLabel: "Calculator result"
                    )
                ),
                .keypad(
                    PluginKeypadDescriptor(
                        identifier: "calculator.keypad",
                        columns: 4,
                        keys: calculatorKeys
                    )
                ),
                .actions(
                    PluginActionGroupDescriptor(
                        identifier: "calculator.actions",
                        actions: [
                            PluginActionDescriptor(
                                identifier: "calculator.action.copy",
                                label: "Copy result",
                                commandIdentifier: "calculator.copy",
                                style: .standard,
                                accessibilityLabel: "Copy result"
                            ),
                        ]
                    )
                ),
            ]
        ),
        mutations: []
    )

    private static let calculatorKeys = [
        key("clear", "C", .secondary, "Clear"),
        key("sign", "+/-", .secondary, "Change sign"),
        key("percent", "%", .secondary, "Percent"),
        key("divide", "÷", .operation, "Divide"),
        key("7", "7", .standard, "Seven"),
        key("8", "8", .standard, "Eight"),
        key("9", "9", .standard, "Nine"),
        key("multiply", "×", .operation, "Multiply"),
        key("4", "4", .standard, "Four"),
        key("5", "5", .standard, "Five"),
        key("6", "6", .standard, "Six"),
        key("subtract", "−", .operation, "Subtract"),
        key("1", "1", .standard, "One"),
        key("2", "2", .standard, "Two"),
        key("3", "3", .standard, "Three"),
        key("add", "+", .operation, "Add"),
        key("0", "0", .standard, "Zero"),
        key("decimal", ".", .standard, "Decimal"),
        key("equals", "=", .accent, "Equals"),
    ]

    private static func key(
        _ identifier: String,
        _ label: String,
        _ style: PluginKeyStyle,
        _ accessibilityLabel: String
    ) -> PluginKeyDescriptor {
        PluginKeyDescriptor(
            identifier: "calculator.key.\(identifier)",
            label: label,
            commandIdentifier: "calculator.\(identifier)",
            style: style,
            accessibilityLabel: accessibilityLabel
        )
    }
}
#endif

/// Makes revision-bound screenshots deterministic without changing normal window restoration.
struct UIAuditWindowConfiguration: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        UIAuditWindowView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class UIAuditWindowView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard ProcessInfo.processInfo.arguments.contains("--prismbar-ui-audit"),
              let window
        else {
            return
        }

        var frame = window.frame
        frame.size = NSSize(width: 920, height: 640)
        window.setFrame(frame, display: true)
        window.center()
    }
}
