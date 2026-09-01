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
    private var commandPopoverKeyMonitor: Any?

    private lazy var commandPopover: NSPopover = {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 440, height: PrismDeckLayoutPolicy.maximumHeight)
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PrismDeckView(
                model: AppModel.shared,
                openWorkspace: { [weak self] in
                    self?.dismissCommandCenter()
                    SceneActionRouter.shared.openWorkspace()
                },
                dismissDeck: { [weak self] in
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
        primary.button?.image = PrismStatusIcon.image
        primary.button?.setAccessibilityLabel(MenuBarControllerIdentity.primaryControlLabel)
        primary.button?.setAccessibilityHelp("Open prismDeck to arrange menu bar items")
        primary.button?.toolTip = "Open prismDeck to arrange menu bar items"
        primary.button?.target = self
        primary.button?.action = #selector(toggleCommandCenter(_:))
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

    func dismissCommandCenter() {
        commandPopover.performClose(nil)
    }

    @objc private func toggleCommandCenter(_ sender: NSStatusBarButton) {
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

extension MenuBarSectionStatusController: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        guard notification.object as? NSPopover === commandPopover,
              let window = commandPopover.contentViewController?.view.window
        else { return }

        window.autorecalculatesKeyViewLoop = true
        window.recalculateKeyViewLoop()
        installCommandPopoverKeyMonitor()
    }

    func popoverDidClose(_ notification: Notification) {
        guard notification.object as? NSPopover === commandPopover else { return }
        removeCommandPopoverKeyMonitor()
    }

    private func installCommandPopoverKeyMonitor() {
        removeCommandPopoverKeyMonitor()
        commandPopoverKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, self?.commandPopover.isShown == true else {
                return event
            }
            self?.dismissCommandCenter()
            return nil
        }
    }

    private func removeCommandPopoverKeyMonitor() {
        guard let commandPopoverKeyMonitor else { return }
        NSEvent.removeMonitor(commandPopoverKeyMonitor)
        self.commandPopoverKeyMonitor = nil
    }
}
