// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import prismBarCore
import SwiftUI

@MainActor
final class MenuBarSectionStatusController {
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
        popover.contentViewController = NSHostingController(
            rootView: StatusMenuView(model: AppModel.shared)
        )
        return popover
    }()

    private(set) var isCollapsed = false

    private init() {}

    func installIfNeeded() {
        guard primaryItem == nil, anchorItem == nil, spacerItem == nil else { return }

        let primary = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        primary.autosaveName = "com.laclairtech.prismbar.primary-control"
        primary.button?.image = Self.makePrimaryControlImage()
        primary.button?.setAccessibilityLabel(MenuBarControllerIdentity.primaryControlLabel)
        primary.button?.target = self
        primary.button?.action = #selector(toggleCommandPopover(_:))
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

            let cube = NSBezierPath()
            cube.lineWidth = 1.35
            cube.lineJoinStyle = .round
            cube.lineCapStyle = .round
            cube.move(to: NSPoint(x: 3.1, y: 12.2))
            cube.line(to: NSPoint(x: 9, y: 15.5))
            cube.line(to: NSPoint(x: 14.9, y: 12.2))
            cube.line(to: NSPoint(x: 14.9, y: 6.3))
            cube.line(to: NSPoint(x: 9, y: 3.1))
            cube.line(to: NSPoint(x: 3.1, y: 6.3))
            cube.close()
            cube.move(to: NSPoint(x: 3.3, y: 12.1))
            cube.line(to: NSPoint(x: 9, y: 8.9))
            cube.line(to: NSPoint(x: 14.7, y: 12.1))
            cube.move(to: NSPoint(x: 9, y: 8.9))
            cube.line(to: NSPoint(x: 9, y: 3.3))
            cube.stroke()

            let drip = NSBezierPath()
            drip.lineWidth = 1.25
            drip.lineJoinStyle = .round
            drip.move(to: NSPoint(x: 11.2, y: 4.1))
            drip.curve(
                to: NSPoint(x: 12.8, y: 0.9),
                controlPoint1: NSPoint(x: 11.2, y: 2.8),
                controlPoint2: NSPoint(x: 11.7, y: 0.9)
            )
            drip.curve(
                to: NSPoint(x: 14.4, y: 4.1),
                controlPoint1: NSPoint(x: 13.9, y: 0.9),
                controlPoint2: NSPoint(x: 14.4, y: 2.8)
            )
            drip.stroke()
            return bounds.width > 0
        }
        image.isTemplate = true
        image.accessibilityDescription = MenuBarControllerIdentity.primaryControlLabel
        return image
    }

    @objc private func toggleCommandPopover(_ sender: NSStatusBarButton) {
        if commandPopover.isShown {
            commandPopover.performClose(sender)
        } else {
            commandPopover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
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
