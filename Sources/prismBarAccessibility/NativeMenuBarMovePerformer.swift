// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics
import Foundation
import prismBarCore

public struct MenuBarDragPoint: Equatable, Sendable {
    public let horizontal: Double
    public let vertical: Double
}

public struct MenuBarDragGesture: Equatable, Sendable {
    public let start: MenuBarDragPoint
    public let end: MenuBarDragPoint
}

struct MenuBarInputSurface: Equatable, Sendable {
    let frame: MenuBarItemFrame
    let reservedMenuBarHeight: Double
}

struct MenuBarInputSafetyValidator: Sendable {
    func allows(
        source: MenuBarItemFrame,
        destination: MenuBarItemFrame,
        surfaces: [MenuBarInputSurface]
    ) -> Bool {
        guard let sourceSurfaceIndex = surfaces.firstIndex(where: { contains(source, in: $0) }),
              let destinationSurfaceIndex = surfaces.firstIndex(where: { contains(destination, in: $0) })
        else {
            return false
        }
        return sourceSurfaceIndex == destinationSurfaceIndex
    }

    private func contains(_ item: MenuBarItemFrame, in surface: MenuBarInputSurface) -> Bool {
        let frame = surface.frame
        let itemMaxX = item.minX + item.width
        let itemMidY = item.minY + item.height / 2
        let frameMaxX = frame.minX + frame.width
        let menuBarMaxY = frame.minY + surface.reservedMenuBarHeight

        return surface.reservedMenuBarHeight > 0 &&
            surface.reservedMenuBarHeight <= 128 &&
            item.minX >= frame.minX &&
            itemMaxX <= frameMaxX &&
            itemMidY >= frame.minY &&
            itemMidY <= menuBarMaxY
    }
}

private enum NativeMenuBarSurfaceCatalog {
    @MainActor
    static func current() -> [MenuBarInputSurface] {
        NSScreen.screens.compactMap { screen in
            guard let screenNumber = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? NSNumber else {
                return nil
            }

            let displayFrame = CGDisplayBounds(CGDirectDisplayID(screenNumber.uint32Value))
            guard displayFrame.width > 0, displayFrame.height > 0 else { return nil }

            return MenuBarInputSurface(
                frame: MenuBarItemFrame(
                    minX: displayFrame.minX,
                    minY: displayFrame.minY,
                    width: displayFrame.width,
                    height: displayFrame.height
                ),
                reservedMenuBarHeight: max(0, screen.frame.maxY - screen.visibleFrame.maxY)
            )
        }
    }
}

public struct MenuBarDragGeometry: Sendable {
    public init() {}

    public func gesture(
        source: MenuBarItemFrame,
        destination: MenuBarItemFrame,
        insertionEdge: MenuBarInsertionEdge
    ) -> MenuBarDragGesture {
        let edgeInset = min(1, destination.width / 4)
        let endX = switch insertionEdge {
        case .before:
            destination.minX + edgeInset
        case .after:
            destination.minX + destination.width - edgeInset
        }

        return MenuBarDragGesture(
            start: MenuBarDragPoint(
                horizontal: source.minX + source.width / 2,
                vertical: source.minY + source.height / 2
            ),
            end: MenuBarDragPoint(
                horizontal: endX,
                vertical: destination.minY + destination.height / 2
            )
        )
    }
}

public enum NativeMenuBarMoveError: Error, Equatable, Sendable {
    case eventCreationFailed
    case cancelled
}

public actor NativeMenuBarMovePerformer: MenuBarMovePerforming {
    private struct PreparedDrag: @unchecked Sendable {
        let moveToStart: CGEvent
        let mouseDown: CGEvent
        let midpointDrag: CGEvent
        let endpointDrag: CGEvent
        let mouseUp: CGEvent
        let restorePointer: CGEvent
    }

    private let geometry = MenuBarDragGeometry()
    private let lifecycle = DeadlineAwareMenuBarDragLifecycle(
        pauser: SystemMenuBarDragPauser()
    )

    public init() {}

    public func move(
        source: MenuBarItemFrame,
        destination: MenuBarItemFrame,
        insertionEdge: MenuBarInsertionEdge,
        deadline: OperationDeadline
    ) async throws {
        try deadline.check()
        guard AXIsProcessTrusted() else {
            throw MenuBarAuthorizationError.permissionRevoked
        }
        guard !Task.isCancelled else {
            throw NativeMenuBarMoveError.cancelled
        }
        let surfaces = await NativeMenuBarSurfaceCatalog.current()
        guard MenuBarInputSafetyValidator().allows(
            source: source,
            destination: destination,
            surfaces: surfaces
        ) else {
            throw MenuBarInputError.menuBarUnavailable
        }

        let gesture = geometry.gesture(
            source: source,
            destination: destination,
            insertionEdge: insertionEdge
        )
        let prepared = try prepare(gesture: gesture)
        try await perform(prepared, deadline: deadline)
    }

    private func prepare(gesture: MenuBarDragGesture) throws -> PreparedDrag {
        guard let eventSource = CGEventSource(stateID: .hidSystemState),
              let currentPointer = CGEvent(source: nil)?.location,
              let moveToStart = mouseEvent(
                  source: eventSource,
                  type: .mouseMoved,
                  point: gesture.start
              ),
              let mouseDown = mouseEvent(
                  source: eventSource,
                  type: .leftMouseDown,
                  point: gesture.start
              ),
              let midpointDrag = mouseEvent(
                  source: eventSource,
                  type: .leftMouseDragged,
                  point: midpoint(of: gesture)
              ),
              let endpointDrag = mouseEvent(
                  source: eventSource,
                  type: .leftMouseDragged,
                  point: gesture.end
              ),
              let mouseUp = mouseEvent(
                  source: eventSource,
                  type: .leftMouseUp,
                  point: gesture.end
              ),
              let restorePointer = CGEvent(
                  mouseEventSource: eventSource,
                  mouseType: .mouseMoved,
                  mouseCursorPosition: currentPointer,
                  mouseButton: .left
              )
        else {
            throw NativeMenuBarMoveError.eventCreationFailed
        }

        let commandFlag = CGEventFlags.maskCommand
        mouseDown.flags = commandFlag
        midpointDrag.flags = commandFlag
        endpointDrag.flags = commandFlag
        mouseUp.flags = commandFlag

        return PreparedDrag(
            moveToStart: moveToStart,
            mouseDown: mouseDown,
            midpointDrag: midpointDrag,
            endpointDrag: endpointDrag,
            mouseUp: mouseUp,
            restorePointer: restorePointer
        )
    }

    private func perform(
        _ drag: PreparedDrag,
        deadline: OperationDeadline
    ) async throws {
        try await lifecycle.perform(deadline: deadline) { stage in
            switch stage {
            case .position:
                drag.moveToStart.post(tap: .cghidEventTap)
            case .press:
                drag.mouseDown.post(tap: .cghidEventTap)
            case .midpoint:
                drag.midpointDrag.post(tap: .cghidEventTap)
            case .endpoint:
                drag.endpointDrag.post(tap: .cghidEventTap)
            case .release:
                drag.mouseUp.post(tap: .cghidEventTap)
            case .restore:
                drag.restorePointer.post(tap: .cghidEventTap)
            }
        }
    }

    private func mouseEvent(
        source: CGEventSource,
        type: CGEventType,
        point: MenuBarDragPoint
    ) -> CGEvent? {
        CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: CGPoint(x: point.horizontal, y: point.vertical),
            mouseButton: .left
        )
    }

    private func midpoint(of gesture: MenuBarDragGesture) -> MenuBarDragPoint {
        MenuBarDragPoint(
            horizontal: (gesture.start.horizontal + gesture.end.horizontal) / 2,
            vertical: (gesture.start.vertical + gesture.end.vertical) / 2
        )
    }
}
