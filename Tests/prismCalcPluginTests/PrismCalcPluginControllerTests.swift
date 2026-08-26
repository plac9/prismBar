// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismCalcPlugin
import prismPluginKit
import Testing

@Suite("prismCalc plugin controller")
struct PrismCalcPluginControllerTests {
    @Test("builds a useful initial panel without the full app")
    func buildsInitialPanel() throws {
        let update = try PrismCalcPluginController().panel()

        #expect(update.panel.title == "prismCalc")
        #expect(resultValue(in: update) == "0")
        #expect(update.mutations.isEmpty)
        #expect(try update.validated(allowedApplicationIdentifiers: ["com.laclairtech.prismcalc"]) == update)
    }

    @Test("evaluates commands and returns a refreshed declarative panel")
    func evaluatesCommands() throws {
        var controller = PrismCalcPluginController()

        _ = try controller.invoke("calculator.digit.7")
        _ = try controller.invoke("calculator.add")
        _ = try controller.invoke("calculator.digit.5")
        let update = try controller.invoke("calculator.equals")

        #expect(resultValue(in: update) == "12")
        #expect(update.mutations.isEmpty)
    }

    @Test("copy and open actions remain explicit bounded mutations")
    func producesBoundedMutations() throws {
        var controller = PrismCalcPluginController()
        _ = try controller.invoke("calculator.digit.4")

        let copy = try controller.invoke("calculator.copy")
        let open = try controller.invoke("calculator.open")

        #expect(copy.mutations == [.copyText("4")])
        #expect(open.mutations == [.openApplication(bundleIdentifier: "com.laclairtech.prismcalc")])
    }

    @Test("rejects unknown commands without changing calculator state")
    func rejectsUnknownCommand() throws {
        var controller = PrismCalcPluginController()
        _ = try controller.invoke("calculator.digit.8")

        #expect(throws: PrismCalcPluginError.unknownCommand("calculator.shell")) {
            try controller.invoke("calculator.shell")
        }
        #expect(resultValue(in: try controller.panel()) == "8")
    }

    @Test("reports division by zero without crashing or emitting an unbounded error")
    func reportsDivisionByZero() throws {
        var controller = PrismCalcPluginController()
        _ = try controller.invoke("calculator.digit.8")
        _ = try controller.invoke("calculator.divide")
        _ = try controller.invoke("calculator.digit.0")

        let update = try controller.invoke("calculator.equals")

        #expect(resultValue(in: update) == "0")
        #expect(update.mutations.isEmpty)
        #expect(update.panel.elements.contains { element in
            if case let .status(status) = element {
                return status.kind == .error && status.message == "Cannot divide by zero."
            }
            return false
        })
    }

    private func resultValue(in update: PluginPanelUpdate) -> String? {
        for element in update.panel.elements {
            if case let .result(result) = element {
                return result.value
            }
        }
        return nil
    }
}

@Suite("prismCalc plugin session")
struct PrismCalcPluginSessionTests {
    @Test("requires a valid handshake before any panel data")
    func requiresHandshake() {
        var session = PrismCalcPluginSession()

        #expect(throws: PrismCalcPluginSessionError.handshakeRequired) {
            try session.process(.panel)
        }
    }

    @Test("serves a bounded panel after an exact-capability handshake")
    func servesPanelAfterHandshake() throws {
        var session = PrismCalcPluginSession()
        let response = try session.process(.handshake(.init(
            hostProtocol: .current,
            requestedCapabilities: [.panel, .commands, .openApplication]
        )))

        guard case let .manifest(manifest) = response else {
            Issue.record("Expected manifest response")
            return
        }
        #expect(manifest.identifier == "com.laclairtech.prismbar.plugin.prismcalc")

        guard case let .panel(update) = try session.process(.panel) else {
            Issue.record("Expected panel response")
            return
        }
        #expect(update.panel.title == "prismCalc")
    }

    @Test("keeps controller state within one authenticated connection session")
    func keepsControllerState() throws {
        var session = PrismCalcPluginSession()
        _ = try session.process(.handshake(.init(
            hostProtocol: .current,
            requestedCapabilities: [.panel, .commands, .openApplication]
        )))
        _ = try session.process(.invoke(.init(commandIdentifier: "calculator.digit.9")))

        guard case let .panel(update) = try session.process(.panel) else {
            Issue.record("Expected panel response")
            return
        }
        #expect(update.panel.elements.contains { element in
            if case let .result(result) = element {
                return result.value == "9"
            }
            return false
        })
    }

    @Test("a rejected handshake never authorizes the session")
    func rejectedHandshakeRemainsLocked() {
        var session = PrismCalcPluginSession()

        #expect(throws: (any Error).self) {
            try session.process(.handshake(.init(
                hostProtocol: .current,
                requestedCapabilities: [.panel]
            )))
        }
        #expect(throws: PrismCalcPluginSessionError.handshakeRequired) {
            try session.process(.panel)
        }
    }
}
