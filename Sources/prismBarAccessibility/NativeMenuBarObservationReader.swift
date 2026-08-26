// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
@preconcurrency import ApplicationServices
import Foundation
import prismBarCore

@MainActor
public enum RunningApplicationCatalog {
    public static func current() -> [RunningApplicationDescriptor] {
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier

        return NSWorkspace.shared.runningApplications
            .filter {
                !$0.isTerminated &&
                    $0.processIdentifier > 0 &&
                    $0.activationPolicy != .prohibited
            }
            .prefix(256)
            .map { application in
                RunningApplicationDescriptor(
                    processIdentifier: application.processIdentifier,
                    bundleIdentifier: application.bundleIdentifier,
                    displayName: application.localizedName ?? "Application",
                    isSelf: application.processIdentifier == currentProcessIdentifier
                )
            }
            .sorted { $0.processIdentifier < $1.processIdentifier }
    }
}

public actor NativeMenuBarObservationReader: MenuBarObservationReading {
    private static let applicationTimeout: Float = 0.25
    private static let maximumTraversalDepth = 4
    private static let maximumElementsPerApplication = 256

    public init() {}

    public func observations(
        for applications: [RunningApplicationDescriptor]
    ) throws -> MenuBarObservationBatch {
        guard AXIsProcessTrusted() else {
            throw MenuBarAuthorizationError.permissionRevoked
        }

        var observations: [MenuBarObservation] = []
        var unavailableSourceCount = 0
        observations.reserveCapacity(applications.count)

        for application in applications {
            do {
                try observations.append(contentsOf: readObservations(for: application))
            } catch MenuBarAuthorizationError.permissionRevoked {
                throw MenuBarAuthorizationError.permissionRevoked
            } catch {
                unavailableSourceCount += 1
            }
        }

        guard AXIsProcessTrusted() else {
            throw MenuBarAuthorizationError.permissionRevoked
        }

        return MenuBarObservationBatch(
            observations: observations,
            unavailableSourceCount: unavailableSourceCount
        )
    }

    private func readObservations(
        for application: RunningApplicationDescriptor
    ) throws -> [MenuBarObservation] {
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        let timeoutResult = AXUIElementSetMessagingTimeout(
            applicationElement,
            Self.applicationTimeout
        )
        if timeoutResult == .apiDisabled {
            throw MenuBarAuthorizationError.permissionRevoked
        }
        guard timeoutResult == .success else {
            throw MenuBarDiscoveryError.communicationFailure
        }

        guard let extrasMenuBar = try optionalElementAttribute(
            kAXExtrasMenuBarAttribute as CFString,
            from: applicationElement
        ) else {
            return []
        }

        var visitedElementCount = 0
        let items = try menuBarItems(
            below: extrasMenuBar,
            depth: 0,
            visitedElementCount: &visitedElementCount
        )

        return items.enumerated().map { index, element in
            let role = stringAttribute(kAXRoleAttribute as CFString, from: element)
            let identifier = stringAttribute(kAXIdentifierAttribute as CFString, from: element)
            let description = stringAttribute(kAXDescriptionAttribute as CFString, from: element)
            let title = stringAttribute(kAXTitleAttribute as CFString, from: element)
            let stableToken = identifier ?? description ?? title ?? "\(role ?? "item"):\(index)"

            return MenuBarObservation(
                owner: application,
                stableToken: stableToken,
                displayName: description ?? title,
                frame: frame(of: element),
                isEnabled: boolAttribute(kAXEnabledAttribute as CFString, from: element) ?? true
            )
        }
    }

    private func menuBarItems(
        below element: AXUIElement,
        depth: Int,
        visitedElementCount: inout Int
    ) throws -> [AXUIElement] {
        guard depth <= Self.maximumTraversalDepth,
              visitedElementCount < Self.maximumElementsPerApplication
        else {
            return []
        }

        visitedElementCount += 1
        if stringAttribute(kAXRoleAttribute as CFString, from: element) == kAXMenuBarItemRole as String {
            return [element]
        }

        guard let children = try optionalElementArrayAttribute(
            kAXChildrenAttribute as CFString,
            from: element
        ) else {
            return []
        }

        var results: [AXUIElement] = []
        for child in children {
            guard visitedElementCount < Self.maximumElementsPerApplication else {
                break
            }
            try results.append(contentsOf: menuBarItems(
                below: child,
                depth: depth + 1,
                visitedElementCount: &visitedElementCount
            ))
        }
        return results
    }

    private func optionalElementAttribute(
        _ attribute: CFString,
        from element: AXUIElement
    ) throws -> AXUIElement? {
        let value = try optionalAttribute(attribute, from: element)
        guard let value else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            throw MenuBarDiscoveryError.malformedAccessibilityValue
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func optionalElementArrayAttribute(
        _ attribute: CFString,
        from element: AXUIElement
    ) throws -> [AXUIElement]? {
        let value = try optionalAttribute(attribute, from: element)
        guard let value else { return nil }
        guard let values = value as? [CFTypeRef] else {
            throw MenuBarDiscoveryError.malformedAccessibilityValue
        }

        return try values.map { child in
            guard CFGetTypeID(child) == AXUIElementGetTypeID() else {
                throw MenuBarDiscoveryError.malformedAccessibilityValue
            }
            return unsafeDowncast(child, to: AXUIElement.self)
        }
    }

    private func optionalAttribute(
        _ attribute: CFString,
        from element: AXUIElement
    ) throws -> CFTypeRef? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute, &value)

        switch error {
        case .success:
            return value
        case .attributeUnsupported, .noValue, .invalidUIElement:
            return nil
        case .apiDisabled:
            throw MenuBarAuthorizationError.permissionRevoked
        case .actionUnsupported, .cannotComplete, .failure, .illegalArgument, .invalidUIElementObserver,
             .notificationAlreadyRegistered, .notificationNotRegistered,
             .notificationUnsupported, .notEnoughPrecision, .notImplemented,
             .parameterizedAttributeUnsupported:
            throw MenuBarDiscoveryError.communicationFailure
        @unknown default:
            throw MenuBarDiscoveryError.communicationFailure
        }
    }

    private func stringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func boolAttribute(_ attribute: CFString, from element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value as? Bool
    }

    private func frame(of element: AXUIElement) -> MenuBarItemFrame? {
        guard let position = pointAttribute(kAXPositionAttribute as CFString, from: element),
              let size = sizeAttribute(kAXSizeAttribute as CFString, from: element),
              position.x.isFinite,
              position.y.isFinite,
              size.width.isFinite,
              size.height.isFinite,
              size.width > 0,
              size.height > 0
        else {
            return nil
        }

        return MenuBarItemFrame(
            minX: position.x,
            minY: position.y,
            width: size.width,
            height: size.height
        )
    }

    private func pointAttribute(_ attribute: CFString, from element: AXUIElement) -> CGPoint? {
        guard let value = axValueAttribute(attribute, from: element, expectedType: .cgPoint) else {
            return nil
        }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    private func sizeAttribute(_ attribute: CFString, from element: AXUIElement) -> CGSize? {
        guard let value = axValueAttribute(attribute, from: element, expectedType: .cgSize) else {
            return nil
        }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    private func axValueAttribute(
        _ attribute: CFString,
        from element: AXUIElement,
        expectedType: AXValueType
    ) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }
        let axValue = unsafeDowncast(value, to: AXValue.self)
        return AXValueGetType(axValue) == expectedType ? axValue : nil
    }
}
