@testable import prismCalcPlugin
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
}
