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
    static let maximumConcurrentSources = 2

    private let reader = ResilientMenuBarObservationReader(
        source: ConcurrentMenuBarObservationReader(
            sourceReader: NativeApplicationObservationReader(),
            maximumConcurrentSources: maximumConcurrentSources
        ),
        attemptLimit: 3
    )

    public init() {}

    public func observations(
        for applications: [RunningApplicationDescriptor],
        deadline: OperationDeadline
    ) async throws -> MenuBarObservationBatch {
        try deadline.check()
        guard AXIsProcessTrusted() else {
            throw MenuBarAuthorizationError.permissionRevoked
        }

        let batch = try await reader.observations(
            for: applications,
            deadline: deadline
        )

        try deadline.check()
        guard AXIsProcessTrusted() else {
            throw MenuBarAuthorizationError.permissionRevoked
        }

        return batch
    }
}

private struct NativeApplicationObservationReader:
    MenuBarApplicationObservationReading,
    Sendable {
    private static let maximumAccessibilitySlice: Duration = .milliseconds(250)
    private static let maximumTraversalDepth = 4
    private static let maximumElementsPerApplication = 256
    private let accessibility = DeadlineBoundAccessibilityClient(
        client: SystemAccessibilityElementClient(),
        maximumSlice: maximumAccessibilitySlice
    )
    private let surfaceResolver = ActiveDisplaySurfaceCatalog.current()

    func observations(
        for application: RunningApplicationDescriptor,
        deadline: OperationDeadline
    ) async throws -> [MenuBarObservation] {
        try readObservations(
            for: application,
            surfaceResolver: surfaceResolver,
            deadline: deadline
        )
    }

    private func readObservations(
        for application: RunningApplicationDescriptor,
        surfaceResolver: DisplaySurfaceResolver,
        deadline: OperationDeadline
    ) throws -> [MenuBarObservation] {
        try deadline.check()
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)

        guard let extrasMenuBar = try optionalElementAttribute(
            kAXExtrasMenuBarAttribute as CFString,
            from: applicationElement,
            deadline: deadline
        ) else {
            return []
        }

        var visitedElementCount = 0
        let items = try menuBarItems(
            below: extrasMenuBar,
            depth: 0,
            visitedElementCount: &visitedElementCount,
            deadline: deadline
        )

        return try items.enumerated().map { index, element in
            try observation(
                for: element,
                index: index,
                owner: application,
                surfaceResolver: surfaceResolver,
                deadline: deadline
            )
        }
    }

    private func observation(
        for element: AXUIElement,
        index: Int,
        owner: RunningApplicationDescriptor,
        surfaceResolver: DisplaySurfaceResolver,
        deadline: OperationDeadline
    ) throws -> MenuBarObservation {
        try deadline.check()
        let role = try stringAttribute(kAXRoleAttribute as CFString, from: element, deadline: deadline)
        let identifier = try stringAttribute(
            kAXIdentifierAttribute as CFString,
            from: element,
            deadline: deadline
        )
        let description = try stringAttribute(
            kAXDescriptionAttribute as CFString,
            from: element,
            deadline: deadline
        )
        let title = try stringAttribute(kAXTitleAttribute as CFString, from: element, deadline: deadline)
        let itemFrame = try frame(of: element, deadline: deadline)

        return MenuBarObservation(
            owner: owner,
            stableToken: identifier ?? description ?? title ?? "\(role ?? "item"):\(index)",
            displayName: description ?? title,
            frame: itemFrame,
            isEnabled: try boolAttribute(
                kAXEnabledAttribute as CFString,
                from: element,
                deadline: deadline
            ) ?? true,
            surfaceToken: itemFrame.flatMap { surfaceResolver.surfaceToken(for: $0) }
        )
    }

    private func menuBarItems(
        below element: AXUIElement,
        depth: Int,
        visitedElementCount: inout Int,
        deadline: OperationDeadline
    ) throws -> [AXUIElement] {
        try deadline.check()
        guard depth <= Self.maximumTraversalDepth,
              visitedElementCount < Self.maximumElementsPerApplication
        else {
            return []
        }

        visitedElementCount += 1
        if try stringAttribute(
            kAXRoleAttribute as CFString,
            from: element,
            deadline: deadline
        ) == kAXMenuBarItemRole as String {
            return [element]
        }

        guard let children = try optionalElementArrayAttribute(
            kAXChildrenAttribute as CFString,
            from: element,
            deadline: deadline
        ) else {
            return []
        }

        var results: [AXUIElement] = []
        for child in children {
            try deadline.check()
            guard visitedElementCount < Self.maximumElementsPerApplication else {
                break
            }
            try results.append(contentsOf: menuBarItems(
                below: child,
                depth: depth + 1,
                visitedElementCount: &visitedElementCount,
                deadline: deadline
            ))
        }
        return results
    }
}

private extension NativeApplicationObservationReader {
    private func optionalElementAttribute(
        _ attribute: CFString,
        from element: AXUIElement,
        deadline: OperationDeadline
    ) throws -> AXUIElement? {
        let value = try optionalAttribute(attribute, from: element, deadline: deadline)
        guard let value else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            throw MenuBarDiscoveryError.malformedAccessibilityValue
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func optionalElementArrayAttribute(
        _ attribute: CFString,
        from element: AXUIElement,
        deadline: OperationDeadline
    ) throws -> [AXUIElement]? {
        let value = try optionalAttribute(attribute, from: element, deadline: deadline)
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
        from element: AXUIElement,
        deadline: OperationDeadline
    ) throws -> CFTypeRef? {
        try accessibility.attribute(
            attribute,
            from: element,
            deadline: deadline
        )
    }

    private func stringAttribute(
        _ attribute: CFString,
        from element: AXUIElement,
        deadline: OperationDeadline
    ) throws -> String? {
        let value = try optionalAttribute(attribute, from: element, deadline: deadline)
        return value as? String
    }

    private func boolAttribute(
        _ attribute: CFString,
        from element: AXUIElement,
        deadline: OperationDeadline
    ) throws -> Bool? {
        let value = try optionalAttribute(attribute, from: element, deadline: deadline)
        return value as? Bool
    }

    private func frame(
        of element: AXUIElement,
        deadline: OperationDeadline
    ) throws -> MenuBarItemFrame? {
        guard let position = try pointAttribute(
            kAXPositionAttribute as CFString,
            from: element,
            deadline: deadline
        ),
              let size = try sizeAttribute(
                  kAXSizeAttribute as CFString,
                  from: element,
                  deadline: deadline
              ),
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

    private func pointAttribute(
        _ attribute: CFString,
        from element: AXUIElement,
        deadline: OperationDeadline
    ) throws -> CGPoint? {
        guard let value = try axValueAttribute(
            attribute,
            from: element,
            expectedType: .cgPoint,
            deadline: deadline
        ) else {
            return nil
        }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    private func sizeAttribute(
        _ attribute: CFString,
        from element: AXUIElement,
        deadline: OperationDeadline
    ) throws -> CGSize? {
        guard let value = try axValueAttribute(
            attribute,
            from: element,
            expectedType: .cgSize,
            deadline: deadline
        ) else {
            return nil
        }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    private func axValueAttribute(
        _ attribute: CFString,
        from element: AXUIElement,
        expectedType: AXValueType,
        deadline: OperationDeadline
    ) throws -> AXValue? {
        guard let value = try optionalAttribute(
            attribute,
            from: element,
            deadline: deadline
        ),
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }
        let axValue = unsafeDowncast(value, to: AXValue.self)
        return AXValueGetType(axValue) == expectedType ? axValue : nil
    }
}
