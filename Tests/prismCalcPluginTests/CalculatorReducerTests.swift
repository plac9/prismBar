// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismCalcPlugin
import Foundation
import prismPluginKit
import Testing

@Suite("prismCalc plugin reducer")
struct CalculatorReducerTests {
    @Test("starts with a deterministic zero result")
    func initialState() {
        #expect(CalculatorState.initial.display == "0")
        #expect(CalculatorState.initial.recentResults.isEmpty)
    }

    @Test("evaluates everyday arithmetic")
    func addition() throws {
        var calculator = CalculatorReducer()

        for key in [CalculatorKey.digit(1), .digit(2), .add, .digit(7), .equals] {
            try calculator.send(key)
        }

        #expect(calculator.state.display == "19")
        #expect(calculator.state.recentResults.first?.result == "19")
    }

    @Test("bounds local recent results")
    func boundedHistory() throws {
        var calculator = CalculatorReducer(historyLimit: 3)

        for value in 1 ... 5 {
            try calculator.send(.digit(value))
            try calculator.send(.equals)
            try calculator.send(.clear)
        }

        #expect(calculator.state.recentResults.count == 3)
    }

    @Test("bounds a hostile stream of digit input")
    func boundedDigitInput() throws {
        var calculator = CalculatorReducer()

        for _ in 0 ..< 1_000 {
            try calculator.send(.digit(9))
        }

        #expect(calculator.state.display.count <= CalculatorReducer.maximumInputCharacters)
        #expect(Decimal(
            string: calculator.state.display,
            locale: Locale(identifier: "en_US_POSIX")
        ) != nil)
    }

    @Test("survives a deterministic hostile command stream within every bound")
    func hostileCommandStream() {
        var generator = DeterministicCommandGenerator(seed: 0x4341_4C43_554C_4154)
        var calculator = CalculatorReducer()

        for index in 0 ..< 25_000 {
            let key = generator.nextKey()
            do {
                try calculator.send(key)
            } catch let error as CalculatorError {
                #expect(error == .divisionByZero || error == .invalidDigit(99))
            } catch {
                Issue.record("Calculator emitted an unexpected error category")
            }

            guard index.isMultiple(of: 100) else { continue }
            #expect(calculator.state.display.count <= PluginPanelLimits.maximumValueCharacters)
            #expect(calculator.state.recentResults.count <= 10)
            #expect(calculator.state.display.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            })
        }
    }
}

private struct DeterministicCommandGenerator {
    private static let keys: [CalculatorKey] = (0 ... 9).map(CalculatorKey.digit) + [
        .decimal,
        .add,
        .subtract,
        .multiply,
        .divide,
        .percent,
        .sign,
        .equals,
        .clear,
        .digit(99),
    ]

    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextKey() -> CalculatorKey {
        state = state &* 2_862_933_555_777_941_757 &+ 3_037_000_493
        return Self.keys[Int(state % UInt64(Self.keys.count))]
    }
}
