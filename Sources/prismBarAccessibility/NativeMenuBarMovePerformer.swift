// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics
import Dispatch
import Foundation
import prismBarCore

public struct MenuBarDragPoint: Equatable, Sendable {
    public let horizontal: Double
    public let vertical: Double
}

public struct MenuBarDragGesture: Equatable, Sendable {
    public let start: MenuBarDragPoint
    public let end: MenuBarDragPoint
    public let path: [MenuBarDragPoint]
}

struct MenuBarEventTimestampRefresher: Sendable {
    func refresh(
        _ event: CGEvent,
        now: CGEventTimestamp = DispatchTime.now().uptimeNanoseconds
    ) {
        event.timestamp = now
    }
}

struct MenuBarEventSourceFactory: Sendable {
    func make() -> CGEventSource? {
        CGEventSource(stateID: .combinedSessionState)
    }
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
    private let maximumStepDistance = 16.0

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

        let start = MenuBarDragPoint(
            horizontal: source.minX + source.width / 2,
            vertical: source.minY + source.height / 2
        )
        let end = MenuBarDragPoint(
            horizontal: endX,
            vertical: destination.minY + destination.height / 2
        )
        return MenuBarDragGesture(start: start, end: end, path: path(from: start, to: end))
    }

    private func path(from start: MenuBarDragPoint, to end: MenuBarDragPoint) -> [MenuBarDragPoint] {
        let horizontalDistance = abs(end.horizontal - start.horizontal)
        let verticalDistance = abs(end.vertical - start.vertical)
        let stepCount = max(1, Int(ceil(max(horizontalDistance, verticalDistance) / maximumStepDistance)))
        return (1...stepCount).map { index in
            let progress = Double(index) / Double(stepCount)
            return MenuBarDragPoint(
                horizontal: start.horizontal + (end.horizontal - start.horizontal) * progress,
                vertical: start.vertical + (end.vertical - start.vertical) * progress
            )
        }
    }
}

public enum NativeMenuBarMoveError: Error, Equatable, Sendable {
    case eventCreationFailed
}

public actor NativeMenuBarMovePerformer: MenuBarMovePerforming {
    private struct PreparedDrag: @unchecked Sendable {
        let moveToStart: CGEvent
        let commandDown: CGEvent
        let mouseDown: CGEvent
        let dragPath: [CGEvent]
        let mouseUp: CGEvent
        let commandUp: CGEvent
        let restorePointer: CGEvent
    }

    private struct PreparedMouseEvents: @unchecked Sendable {
        let moveToStart: CGEvent
        let mouseDown: CGEvent
        let dragPath: [CGEvent]
        let mouseUp: CGEvent
        let restorePointer: CGEvent
    }

    private struct PreparedCommandEvents: @unchecked Sendable {
        let commandDown: CGEvent
        let commandUp: CGEvent
    }

    private let geometry = MenuBarDragGeometry()
    private let lifecycle = DeadlineAwareMenuBarDragLifecycle(
        pauser: SystemMenuBarDragPauser()
    )
    private let authorizationCheck: @Sendable () -> Bool

    public init() {
        authorizationCheck = {
            AXIsProcessTrusted() && CGPreflightPostEventAccess()
        }
    }

    init(authorizationCheck: @escaping @Sendable () -> Bool) {
        self.authorizationCheck = authorizationCheck
    }

    public func move(
        source: MenuBarItemFrame,
        destination: MenuBarItemFrame,
        insertionEdge: MenuBarInsertionEdge,
        deadline: OperationDeadline
    ) async throws {
        try deadline.check()
        guard authorizationCheck() else {
            throw MenuBarAuthorizationError.permissionRevoked
        }
        try Task.checkCancellation()
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
        guard let eventSource = MenuBarEventSourceFactory().make(),
              let currentPointer = CGEvent(source: nil)?.location,
              let mouseEvents = mouseEvents(
                  source: eventSource,
                  gesture: gesture,
                  currentPointer: currentPointer
              ),
              let commandEvents = commandEvents(source: eventSource)
        else {
            throw NativeMenuBarMoveError.eventCreationFailed
        }

        let commandFlag = CGEventFlags.maskCommand
        commandEvents.commandDown.flags = commandFlag
        mouseEvents.mouseDown.flags = commandFlag
        mouseEvents.dragPath.forEach { $0.flags = commandFlag }
        mouseEvents.mouseUp.flags = commandFlag

        return PreparedDrag(
            moveToStart: mouseEvents.moveToStart,
            commandDown: commandEvents.commandDown,
            mouseDown: mouseEvents.mouseDown,
            dragPath: mouseEvents.dragPath,
            mouseUp: mouseEvents.mouseUp,
            commandUp: commandEvents.commandUp,
            restorePointer: mouseEvents.restorePointer
        )
    }

    private func mouseEvents(
        source: CGEventSource,
        gesture: MenuBarDragGesture,
        currentPointer: CGPoint
    ) -> PreparedMouseEvents? {
        guard let moveToStart = mouseEvent(source: source, type: .mouseMoved, point: gesture.start),
              let mouseDown = mouseEvent(source: source, type: .leftMouseDown, point: gesture.start),
              let dragPath = dragEvents(source: source, path: gesture.path),
              let mouseUp = mouseEvent(source: source, type: .leftMouseUp, point: gesture.end),
              let restorePointer = CGEvent(
                  mouseEventSource: source,
                  mouseType: .mouseMoved,
                  mouseCursorPosition: currentPointer,
                  mouseButton: .left
              )
        else {
            return nil
        }
        return PreparedMouseEvents(
            moveToStart: moveToStart,
            mouseDown: mouseDown,
            dragPath: dragPath,
            mouseUp: mouseUp,
            restorePointer: restorePointer
        )
    }

    private func commandEvents(source: CGEventSource) -> PreparedCommandEvents? {
        // MARK: Apple Platform Behavior Override
        // What: Post a bounded Command key-down and key-up around the native mouse drag.
        // Why: macOS 27 does not consistently treat mouse-event flags alone as the Command-drag
        // gesture required to move a status item across multiple positions.
        // Re-evaluate: Remove this override when a public macOS API moves status items directly,
        // or when physical release testing proves mouse-event flags alone are reliable again.
        guard let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
              let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        else {
            return nil
        }
        return PreparedCommandEvents(commandDown: commandDown, commandUp: commandUp)
    }

    private func dragEvents(source: CGEventSource, path: [MenuBarDragPoint]) -> [CGEvent]? {
        let events = path.compactMap { point in
            mouseEvent(source: source, type: .leftMouseDragged, point: point)
        }
        return events.count == path.count ? events : nil
    }

    private func perform(
        _ drag: PreparedDrag,
        deadline: OperationDeadline
    ) async throws {
        let timestampRefresher = MenuBarEventTimestampRefresher()
        let postFresh: @Sendable (CGEvent) -> Void = { event in
            timestampRefresher.refresh(event)
            event.post(tap: .cghidEventTap)
        }
        try await lifecycle.perform(dragStepCount: drag.dragPath.count, deadline: deadline) { stage in
            switch stage {
            case .position:
                postFresh(drag.moveToStart)
            case .modifierDown:
                postFresh(drag.commandDown)
            case .press:
                postFresh(drag.mouseDown)
            case let .dragStep(index):
                postFresh(drag.dragPath[index])
            case .release:
                postFresh(drag.mouseUp)
            case .modifierUp:
                postFresh(drag.commandUp)
            case .restore:
                postFresh(drag.restorePointer)
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

}
