// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import prismPluginKit

public enum PrismCalcPluginError: Error, Equatable, Sendable {
    case unknownCommand(String)
}

public struct PrismCalcPluginController: Sendable {
    public static let prismCalcApplicationIdentifier = "com.laclairtech.prismcalc"

    private var calculator: CalculatorReducer

    public init() {
        calculator = CalculatorReducer()
    }

    public func panel() throws -> PluginPanelUpdate {
        try makeUpdate()
    }

    public mutating func invoke(_ commandIdentifier: String) throws -> PluginPanelUpdate {
        switch commandIdentifier {
        case "calculator.copy":
            return try makeUpdate(mutations: [.copyText(calculator.state.display)])
        case "calculator.open":
            return try makeUpdate(
                mutations: [
                    .openApplication(bundleIdentifier: Self.prismCalcApplicationIdentifier)
                ]
            )
        default:
            guard let key = Self.key(for: commandIdentifier) else {
                throw PrismCalcPluginError.unknownCommand(commandIdentifier)
            }

            do {
                try calculator.send(key)
                return try makeUpdate()
            } catch CalculatorError.divisionByZero {
                return try makeUpdate(
                    status: PluginStatusDescriptor(
                        identifier: "calculator.status.error",
                        message: "Cannot divide by zero.",
                        kind: .error
                    )
                )
            }
        }
    }
}

private extension PrismCalcPluginController {
    static let allowedApplications: Set<String> = [prismCalcApplicationIdentifier]

    static func key(for commandIdentifier: String) -> CalculatorKey? {
        if commandIdentifier.hasPrefix("calculator.digit."),
           let digit = Int(commandIdentifier.dropFirst("calculator.digit.".count)),
           (0 ... 9).contains(digit) {
            return .digit(digit)
        }
        return commandKeys[commandIdentifier]
    }

    static let commandKeys: [String: CalculatorKey] = [
        "calculator.decimal": .decimal,
        "calculator.add": .add,
        "calculator.subtract": .subtract,
        "calculator.multiply": .multiply,
        "calculator.divide": .divide,
        "calculator.percent": .percent,
        "calculator.sign": .sign,
        "calculator.equals": .equals,
        "calculator.clear": .clear,
    ]

    func makeUpdate(
        mutations: [PluginMutation] = [],
        status: PluginStatusDescriptor? = nil
    ) throws -> PluginPanelUpdate {
        var elements: [PluginPanelElement] = [
            .result(
                PluginResultDescriptor(
                    identifier: "calculator.result",
                    value: calculator.state.display,
                    accessibilityLabel: "Calculator result"
                )
            ),
            .keypad(
                PluginKeypadDescriptor(
                    identifier: "calculator.keypad",
                    columns: 4,
                    keys: Self.keys
                )
            ),
            .actions(
                PluginActionGroupDescriptor(
                    identifier: "calculator.actions",
                    actions: [
                        PluginActionDescriptor(
                            identifier: "calculator.action.copy",
                            label: "Copy",
                            commandIdentifier: "calculator.copy",
                            style: .standard,
                            accessibilityLabel: "Copy calculator result"
                        ),
                        PluginActionDescriptor(
                            identifier: "calculator.action.open",
                            label: "Open prismCalc",
                            commandIdentifier: "calculator.open",
                            style: .accent,
                            accessibilityLabel: "Open prismCalc"
                        ),
                    ]
                )
            ),
        ]
        if let status {
            elements.append(.status(status))
        }

        return try PluginPanelUpdate(
            panel: PluginPanelDescriptor(
                identifier: "calculator.panel",
                title: "prismCalc",
                elements: elements
            ),
            mutations: mutations
        ).validated(allowedApplicationIdentifiers: Self.allowedApplications)
    }

    static let keys: [PluginKeyDescriptor] = [
        key("clear", "C", "calculator.clear", .secondary, "Clear"),
        key("sign", "+/-", "calculator.sign", .secondary, "Change sign"),
        key("percent", "%", "calculator.percent", .secondary, "Percent"),
        key("divide", "÷", "calculator.divide", .operation, "Divide"),
        key("7", "7", "calculator.digit.7", .standard, "Seven"),
        key("8", "8", "calculator.digit.8", .standard, "Eight"),
        key("9", "9", "calculator.digit.9", .standard, "Nine"),
        key("multiply", "×", "calculator.multiply", .operation, "Multiply"),
        key("4", "4", "calculator.digit.4", .standard, "Four"),
        key("5", "5", "calculator.digit.5", .standard, "Five"),
        key("6", "6", "calculator.digit.6", .standard, "Six"),
        key("subtract", "−", "calculator.subtract", .operation, "Subtract"),
        key("1", "1", "calculator.digit.1", .standard, "One"),
        key("2", "2", "calculator.digit.2", .standard, "Two"),
        key("3", "3", "calculator.digit.3", .standard, "Three"),
        key("add", "+", "calculator.add", .operation, "Add"),
        key("0", "0", "calculator.digit.0", .standard, "Zero"),
        key("decimal", ".", "calculator.decimal", .standard, "Decimal"),
        key("equals", "=", "calculator.equals", .accent, "Equals"),
    ]

    static func key(
        _ identifier: String,
        _ label: String,
        _ commandIdentifier: String,
        _ style: PluginKeyStyle,
        _ accessibilityLabel: String
    ) -> PluginKeyDescriptor {
        PluginKeyDescriptor(
            identifier: "calculator.key.\(identifier)",
            label: label,
            commandIdentifier: commandIdentifier,
            style: style,
            accessibilityLabel: accessibilityLabel
        )
    }
}
