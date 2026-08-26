// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import prismBarCore
import SwiftUI

@MainActor
final class MenuBarSectionStatusController: NSObject {
    static let shared = MenuBarSectionStatusController()

    private static let expandedSpacerLength: CGFloat = 6
    private var primaryItem: NSStatusItem?
    private var anchorItem: NSStatusItem?
    private var spacerItem: NSStatusItem?

    private lazy var commandPopover: NSPopover = {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 320, height: 560)
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: StatusMenuView(
                model: AppModel.shared,
                dismissCommandCenter: { [weak self] in
                    self?.dismissCommandCenter()
                }
            )
        )
        return popover
    }()

    private(set) var isCollapsed = false

    override private init() {
        super.init()
    }

    func installIfNeeded() {
        guard primaryItem == nil, anchorItem == nil, spacerItem == nil else { return }

        let primary = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        primary.autosaveName = "com.laclairtech.prismbar.primary-control"
        primary.button?.image = Self.makePrimaryControlImage()
        primary.button?.setAccessibilityLabel(MenuBarControllerIdentity.primaryControlLabel)
        primary.button?.toolTip = "Open prismBar"
        primary.expandedInterfaceDelegate = self
        primaryItem = primary

        let anchor = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        anchor.autosaveName = "com.laclairtech.prismbar.section-anchor.v3"
        anchor.button?.image = NSImage(
            systemSymbolName: "line.vertical",
            accessibilityDescription: "prismBar Section Divider"
        )
        anchor.button?.image?.isTemplate = true
        anchor.button?.setAccessibilityLabel("prismBar Section Divider")
        anchorItem = anchor

        let spacer = NSStatusBar.system.statusItem(withLength: Self.expandedSpacerLength)
        spacer.autosaveName = "com.laclairtech.prismbar.hidden-section.v3"
        spacer.button?.title = ""
        spacer.button?.setAccessibilityLabel(MenuBarControllerIdentity.hiddenSectionDividerLabel)
        spacerItem = spacer
    }

    private static func makePrimaryControlImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { bounds in
            let strokeColor = NSColor.labelColor
            strokeColor.setStroke()

            let prism = NSBezierPath()
            prism.lineWidth = 1.3
            prism.lineJoinStyle = .round
            prism.lineCapStyle = .round
            prism.move(to: NSPoint(x: 9, y: 15.7))
            prism.line(to: NSPoint(x: 2.2, y: 3.1))
            prism.line(to: NSPoint(x: 15.8, y: 3.1))
            prism.close()
            prism.move(to: NSPoint(x: 9, y: 15.2))
            prism.line(to: NSPoint(x: 9, y: 6.3))
            prism.move(to: NSPoint(x: 2.8, y: 3.5))
            prism.line(to: NSPoint(x: 9, y: 6.3))
            prism.line(to: NSPoint(x: 15.2, y: 3.5))
            prism.move(to: NSPoint(x: 1.2, y: 9.2))
            prism.line(to: NSPoint(x: 5.4, y: 9.2))
            prism.move(to: NSPoint(x: 12.6, y: 9.2))
            prism.line(to: NSPoint(x: 16.8, y: 11.1))
            prism.stroke()
            return bounds.width > 0
        }
        image.isTemplate = true
        image.accessibilityDescription = MenuBarControllerIdentity.primaryControlLabel
        return image
    }

    func dismissCommandCenter() {
        primaryItem?.expandedInterfaceSession?.cancel()
    }

    @discardableResult
    func setCollapsed(_ collapsed: Bool, dividerFrame: MenuBarItemFrame?) -> Bool {
        installIfNeeded()
        guard let spacerItem else { return isCollapsed }

        if collapsed {
            guard let dividerFrame,
                  let screen = screen(containing: dividerFrame)
            else {
                return isCollapsed
            }
            let rightEdge = dividerFrame.minX + dividerFrame.width
            let widthToScreenEdge = rightEdge - screen.frame.minX
            spacerItem.length = min(
                screen.frame.width,
                max(NSStatusItem.squareLength, widthToScreenEdge)
            )
        } else {
            spacerItem.length = Self.expandedSpacerLength
        }
        isCollapsed = collapsed
        return isCollapsed
    }

    private func screen(containing frame: MenuBarItemFrame) -> NSScreen? {
        guard let primaryScreen = NSScreen.screens.first else { return nil }
        let accessibilityPoint = NSPoint(
            x: frame.minX + frame.width / 2,
            y: frame.minY + frame.height / 2
        )
        let appKitPoint = NSPoint(
            x: accessibilityPoint.x,
            y: primaryScreen.frame.maxY - accessibilityPoint.y
        )
        return NSScreen.screens.first { NSMouseInRect(appKitPoint, $0.frame, false) }
    }
}

extension MenuBarSectionStatusController: NSStatusItemExpandedInterfaceDelegate {
    func statusItem(
        _ statusItem: NSStatusItem,
        didBegin _: NSStatusItemExpandedInterfaceSession
    ) {
        guard statusItem === primaryItem,
              let button = statusItem.button
        else {
            statusItem.expandedInterfaceSession?.cancel()
            return
        }

        commandPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func statusItemDidEndExpandedInterfaceSession(_ statusItem: NSStatusItem, animated _: Bool) {
        guard statusItem === primaryItem, commandPopover.isShown else { return }
        commandPopover.performClose(statusItem.button)
    }
}

extension MenuBarSectionStatusController: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        guard notification.object as? NSPopover === commandPopover,
              let window = commandPopover.contentViewController?.view.window
        else { return }

        window.autorecalculatesKeyViewLoop = true
        window.recalculateKeyViewLoop()
    }

    func popoverDidClose(_ notification: Notification) {
        guard notification.object as? NSPopover === commandPopover else { return }
        primaryItem?.expandedInterfaceSession?.cancel()
    }
}
