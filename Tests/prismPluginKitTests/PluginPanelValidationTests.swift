// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismPluginKit
import Testing

@Suite("Plugin panel validation")
struct PluginPanelValidationTests {
    @Test("accepts a bounded calculator panel")
    func acceptsCalculatorPanel() throws {
        let update = fixtureUpdate()

        #expect(try update.validated(allowedApplicationIdentifiers: ["com.laclairtech.prismcalc"]) == update)
    }

    @Test("rejects duplicate element identifiers")
    func rejectsDuplicateIdentifiers() {
        let result = PluginResultDescriptor(
            identifier: "calculator.display",
            value: "42",
            accessibilityLabel: "Result"
        )
        let update = PluginPanelUpdate(
            panel: PluginPanelDescriptor(
                identifier: "calculator.panel",
                title: "prismCalc",
                elements: [.result(result), .result(result)]
            ),
            mutations: []
        )

        #expect(throws: PluginPanelValidationError.duplicateIdentifier("calculator.display")) {
            try update.validated(allowedApplicationIdentifiers: [])
        }
    }

    @Test("rejects oversized result values")
    func rejectsOversizedValues() {
        let update = PluginPanelUpdate(
            panel: PluginPanelDescriptor(
                identifier: "calculator.panel",
                title: "prismCalc",
                elements: [
                    .result(.init(
                        identifier: "calculator.display",
                        value: String(repeating: "9", count: PluginPanelLimits.maximumValueCharacters + 1),
                        accessibilityLabel: "Result"
                    )),
                ]
            ),
            mutations: []
        )

        #expect(throws: PluginPanelValidationError.valueTooLong) {
            try update.validated(allowedApplicationIdentifiers: [])
        }
    }

    @Test("rejects application launches outside the host allowlist")
    func rejectsUnapprovedApplicationLaunch() {
        let update = PluginPanelUpdate(
            panel: fixtureUpdate().panel,
            mutations: [.openApplication(bundleIdentifier: "com.example.unapproved")]
        )

        #expect(
            throws: PluginPanelValidationError.unapprovedApplication("com.example.unapproved")
        ) {
            try update.validated(allowedApplicationIdentifiers: ["com.laclairtech.prismcalc"])
        }
    }

    @Test("rejects executable-shaped identifiers")
    func rejectsInvalidIdentifiers() {
        let update = PluginPanelUpdate(
            panel: PluginPanelDescriptor(
                identifier: "../../calculator",
                title: "prismCalc",
                elements: []
            ),
            mutations: []
        )

        #expect(throws: PluginPanelValidationError.invalidIdentifier("../../calculator")) {
            try update.validated(allowedApplicationIdentifiers: [])
        }
    }

    @Test("rejects control characters while accepting ordinary text")
    func validatesTextSafety() throws {
        #expect(try fixtureUpdate().validated(
            allowedApplicationIdentifiers: ["com.laclairtech.prismcalc"]
        ) == fixtureUpdate())

        let update = PluginPanelUpdate(
            panel: PluginPanelDescriptor(
                identifier: "calculator.panel",
                title: "prismCalc\nInjected",
                elements: []
            ),
            mutations: []
        )
        #expect(throws: PluginPanelValidationError.controlCharacters) {
            try update.validated(allowedApplicationIdentifiers: [])
        }
    }

    @Test("rejects URL-bearing content before rendering or mutation")
    func rejectsURLContent() {
        for unsafeValue in [
            "https://example.invalid",
            "FILE:///private/example",
            "javascript:run()",
            "data:text/plain,example",
        ] {
            let update = PluginPanelUpdate(
                panel: PluginPanelDescriptor(
                    identifier: "calculator.panel",
                    title: "prismCalc",
                    elements: [
                        .result(.init(
                            identifier: "calculator.display",
                            value: unsafeValue,
                            accessibilityLabel: "Result"
                        )),
                    ]
                ),
                mutations: []
            )

            #expect(throws: PluginPanelValidationError.urlContent) {
                try update.validated(allowedApplicationIdentifiers: [])
            }
        }
    }

    @Test("rejects oversized descriptor collections")
    func rejectsOversizedCollections() {
        let elements = (0 ... PluginPanelLimits.maximumElements).map { index in
            PluginPanelElement.status(.init(
                identifier: "status.\(index)",
                message: "Ready",
                kind: .information
            ))
        }
        let tooManyElements = PluginPanelUpdate(
            panel: .init(identifier: "calculator.panel", title: "prismCalc", elements: elements),
            mutations: []
        )
        #expect(throws: PluginPanelValidationError.tooManyElements) {
            try tooManyElements.validated(allowedApplicationIdentifiers: [])
        }

        let tooManyMutations = PluginPanelUpdate(
            panel: fixtureUpdate().panel,
            mutations: Array(
                repeating: .copyText("42"),
                count: PluginPanelLimits.maximumMutations + 1
            )
        )
        #expect(throws: PluginPanelValidationError.tooManyMutations) {
            try tooManyMutations.validated(allowedApplicationIdentifiers: [])
        }
    }

    private func fixtureUpdate() -> PluginPanelUpdate {
        PluginPanelUpdate(
            panel: PluginPanelDescriptor(
                identifier: "calculator.panel",
                title: "prismCalc",
                elements: [
                    .result(.init(
                        identifier: "calculator.display",
                        value: "42",
                        accessibilityLabel: "Result"
                    )),
                    .keypad(.init(
                        identifier: "calculator.keypad",
                        columns: 2,
                        keys: [
                            .init(
                                identifier: "calculator.key.1",
                                label: "1",
                                commandIdentifier: "calculator.digit.1",
                                style: .standard,
                                accessibilityLabel: "One"
                            ),
                            .init(
                                identifier: "calculator.key.equals",
                                label: "=",
                                commandIdentifier: "calculator.equals",
                                style: .accent,
                                accessibilityLabel: "Equals"
                            ),
                        ]
                    )),
                ]
            ),
            mutations: [.copyText("42")]
        )
    }
}
