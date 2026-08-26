// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct RecentCalculation: Equatable, Codable, Sendable {
    public let expression: String
    public let result: String

    public init(expression: String, result: String) {
        self.expression = expression
        self.result = result
    }
}

public struct CalculatorState: Equatable, Codable, Sendable {
    public static let initial = Self(display: "0", recentResults: [])

    public var display: String
    public var recentResults: [RecentCalculation]

    public init(display: String, recentResults: [RecentCalculation]) {
        self.display = display
        self.recentResults = recentResults
    }
}

public enum CalculatorKey: Equatable, Sendable {
    case digit(Int)
    case decimal
    case add
    case subtract
    case multiply
    case divide
    case percent
    case sign
    case equals
    case clear
}

public enum CalculatorError: Error, Equatable, Sendable {
    case invalidDigit(Int)
    case divisionByZero
}

public struct CalculatorReducer: Sendable {
    public private(set) var state: CalculatorState

    private let historyLimit: Int
    private var input = "0"
    private var accumulator: Decimal?
    private var pendingOperation: Operation?
    private var startsNewInput = true

    public init(historyLimit: Int = 10) {
        self.historyLimit = max(0, historyLimit)
        state = .initial
    }

    public mutating func send(_ key: CalculatorKey) throws {
        switch key {
        case let .digit(digit):
            guard (0 ... 9).contains(digit) else {
                throw CalculatorError.invalidDigit(digit)
            }
            appendDigit(digit)
        case .decimal:
            appendDecimalPoint()
        case .add, .subtract, .multiply, .divide:
            try setOperation(Operation(key: key))
        case .percent:
            try applyPercent()
        case .sign:
            toggleSign()
        case .equals:
            try evaluate()
        case .clear:
            clearInput()
        }
    }
}

private extension CalculatorReducer {
    enum Operation: String, Sendable {
        case add = "+"
        case subtract = "-"
        case multiply = "x"
        case divide = "/"

        init(key: CalculatorKey) {
            switch key {
            case .add: self = .add
            case .subtract: self = .subtract
            case .multiply: self = .multiply
            case .divide: self = .divide
            default: preconditionFailure("Calculator key is not an operation")
            }
        }
    }

    mutating func appendDigit(_ digit: Int) {
        if startsNewInput || input == "0" {
            input = String(digit)
            startsNewInput = false
        } else {
            input.append(String(digit))
        }
        state.display = input
    }

    mutating func appendDecimalPoint() {
        if startsNewInput {
            input = "0."
            startsNewInput = false
        } else if !input.contains(".") {
            input.append(".")
        }
        state.display = input
    }

    mutating func setOperation(_ operation: Operation) throws {
        if pendingOperation != nil, !startsNewInput {
            try evaluate(recordHistory: false)
        }
        accumulator = decimalValue
        pendingOperation = operation
        startsNewInput = true
    }

    mutating func applyPercent() throws {
        let value = decimalValue / 100
        setDisplay(value)
        startsNewInput = true
    }

    mutating func toggleSign() {
        if input == "0" {
            return
        }
        input = input.hasPrefix("-") ? String(input.dropFirst()) : "-" + input
        state.display = input
    }

    mutating func evaluate(recordHistory: Bool = true) throws {
        let right = decimalValue
        let left = accumulator ?? right
        let operation = pendingOperation
        let result: Decimal

        switch operation {
        case .add:
            result = left + right
        case .subtract:
            result = left - right
        case .multiply:
            result = left * right
        case .divide:
            guard right != 0 else {
                throw CalculatorError.divisionByZero
            }
            result = left / right
        case nil:
            result = right
        }

        let leftText = decimalString(left)
        let rightText = decimalString(right)
        setDisplay(result)
        accumulator = result
        pendingOperation = nil
        startsNewInput = true

        guard recordHistory, historyLimit > 0 else {
            return
        }

        let expression = operation.map { "\(leftText) \($0.rawValue) \(rightText)" } ?? rightText
        state.recentResults.insert(
            RecentCalculation(expression: expression, result: state.display),
            at: 0
        )
        if state.recentResults.count > historyLimit {
            state.recentResults.removeLast(state.recentResults.count - historyLimit)
        }
    }

    mutating func clearInput() {
        input = "0"
        accumulator = nil
        pendingOperation = nil
        startsNewInput = true
        state.display = "0"
    }

    var decimalValue: Decimal {
        Decimal(string: input, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    mutating func setDisplay(_ value: Decimal) {
        input = decimalString(value)
        state.display = input
    }

    func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
