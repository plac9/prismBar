// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@preconcurrency import ApplicationServices
import Foundation
import prismBarCore

protocol AccessibilityElementClient: Sendable {
    func setMessagingTimeout(_ timeout: Float, on element: AXUIElement) throws
    func attribute(_ attribute: CFString, from element: AXUIElement) throws -> CFTypeRef?
}

struct SystemAccessibilityElementClient: AccessibilityElementClient {
    func setMessagingTimeout(_ timeout: Float, on element: AXUIElement) throws {
        try Self.validate(AXUIElementSetMessagingTimeout(element, timeout))
    }

    func attribute(_ attribute: CFString, from element: AXUIElement) throws -> CFTypeRef? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute, &value)
        switch error {
        case .success:
            return value
        case .attributeUnsupported, .noValue, .invalidUIElement:
            return nil
        default:
            try Self.validate(error)
            return nil
        }
    }

    private static func validate(_ error: AXError) throws {
        switch error {
        case .success:
            return
        case .apiDisabled:
            throw MenuBarAuthorizationError.permissionRevoked
        case .actionUnsupported, .attributeUnsupported, .cannotComplete, .failure,
             .illegalArgument, .invalidUIElement, .invalidUIElementObserver,
             .noValue, .notificationAlreadyRegistered, .notificationNotRegistered,
             .notificationUnsupported, .notEnoughPrecision, .notImplemented,
             .parameterizedAttributeUnsupported:
            throw MenuBarDiscoveryError.communicationFailure
        @unknown default:
            throw MenuBarDiscoveryError.communicationFailure
        }
    }
}

struct DeadlineBoundAccessibilityClient<Client: AccessibilityElementClient>: Sendable {
    private let client: Client
    private let maximumSlice: Duration

    init(
        client: Client,
        maximumSlice: Duration = .milliseconds(250)
    ) {
        self.client = client
        self.maximumSlice = maximumSlice
    }

    func attribute(
        _ attribute: CFString,
        from element: AXUIElement,
        deadline: OperationDeadline,
        at now: ContinuousClock.Instant = ContinuousClock().now
    ) throws -> CFTypeRef? {
        let timeout = try deadline.accessibilityTimeout(
            at: now,
            maximum: maximumSlice
        )
        try client.setMessagingTimeout(timeout, on: element)
        try deadline.check()
        return try client.attribute(attribute, from: element)
    }
}
