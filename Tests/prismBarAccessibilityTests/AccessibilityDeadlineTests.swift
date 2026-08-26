// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@preconcurrency import ApplicationServices
@testable import prismBarAccessibility
import Foundation
import prismBarCore
import Testing

@Suite("Accessibility deadline boundary")
struct AccessibilityDeadlineTests {
    @Test("configures the exact element before reading its attribute")
    func configuresElementBeforeRead() throws {
        let clock = ContinuousClock()
        let start = clock.now
        let deadline = OperationDeadline(
            expiresAt: start.advanced(by: .milliseconds(80))
        )
        let client = RecordingAccessibilityElementClient(value: "fixture" as CFString)
        let bounded = DeadlineBoundAccessibilityClient(
            client: client,
            maximumSlice: .milliseconds(250)
        )
        let element = AXUIElementCreateSystemWide()

        let value = try bounded.attribute(
            kAXRoleAttribute as CFString,
            from: element,
            deadline: deadline,
            at: start
        )

        #expect(value as? String == "fixture")
        #expect(client.events.count == 2)
        #expect(client.events[0].kind == .timeout)
        #expect(client.events[1].kind == .attribute)
        #expect(client.events[0].element === element)
        #expect(client.events[1].element === element)
        #expect(abs((client.events[0].timeout ?? 0) - 0.08) < 0.000_001)
    }

    @Test("does not configure or read an element after expiry")
    func stopsBeforeExpiredRead() {
        let clock = ContinuousClock()
        let now = clock.now
        let client = RecordingAccessibilityElementClient(value: nil)
        let bounded = DeadlineBoundAccessibilityClient(client: client)

        #expect(throws: OperationDeadlineError.expired) {
            try bounded.attribute(
                kAXRoleAttribute as CFString,
                from: AXUIElementCreateSystemWide(),
                deadline: OperationDeadline(expiresAt: now),
                at: now
            )
        }
        #expect(client.events.isEmpty)
    }

    @Test("uses the configured slice when it is smaller than remaining time")
    func usesMaximumSlice() throws {
        let clock = ContinuousClock()
        let start = clock.now
        let client = RecordingAccessibilityElementClient(value: nil)
        let bounded = DeadlineBoundAccessibilityClient(
            client: client,
            maximumSlice: .milliseconds(25)
        )

        _ = try bounded.attribute(
            kAXRoleAttribute as CFString,
            from: AXUIElementCreateSystemWide(),
            deadline: OperationDeadline(
                expiresAt: start.advanced(by: .seconds(1))
            ),
            at: start
        )

        #expect(abs((client.events[0].timeout ?? 0) - 0.025) < 0.000_001)
    }

    @Test("does not start an attribute read when timeout configuration consumes the budget")
    func rechecksBeforeAttributeRead() {
        let client = RecordingAccessibilityElementClient(
            value: nil,
            timeoutConfigurationDelay: 0.02
        )
        let bounded = DeadlineBoundAccessibilityClient(client: client)

        #expect(throws: OperationDeadlineError.expired) {
            try bounded.attribute(
                kAXRoleAttribute as CFString,
                from: AXUIElementCreateSystemWide(),
                deadline: OperationDeadline(timeout: .milliseconds(5))
            )
        }
        #expect(client.events.map(\.kind) == [.timeout])
    }
}

private final class RecordingAccessibilityElementClient:
    AccessibilityElementClient,
    @unchecked Sendable
{
    enum EventKind: Equatable {
        case timeout
        case attribute
    }

    struct Event {
        let kind: EventKind
        let element: AXUIElement
        let timeout: Float?
    }

    private(set) var events: [Event] = []
    private let value: CFTypeRef?
    private let timeoutConfigurationDelay: TimeInterval

    init(
        value: CFTypeRef?,
        timeoutConfigurationDelay: TimeInterval = 0
    ) {
        self.value = value
        self.timeoutConfigurationDelay = timeoutConfigurationDelay
    }

    func setMessagingTimeout(_ timeout: Float, on element: AXUIElement) throws {
        events.append(Event(kind: .timeout, element: element, timeout: timeout))
        if timeoutConfigurationDelay > 0 {
            Thread.sleep(forTimeInterval: timeoutConfigurationDelay)
        }
    }

    func attribute(_ attribute: CFString, from element: AXUIElement) throws -> CFTypeRef? {
        events.append(Event(kind: .attribute, element: element, timeout: nil))
        return value
    }
}
