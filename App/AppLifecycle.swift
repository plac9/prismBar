// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import SwiftUI

@MainActor
final class AppWindowController: NSObject, NSWindowDelegate {
    static let shared = AppWindowController()

    private var isObservingLaunch = false

    private lazy var window: NSWindow = {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "prismBar"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.styleMask.insert(.fullSizeContentView)
        window.toolbarStyle = .unified
        window.contentMinSize = NSSize(width: 760, height: 520)
        window.contentViewController = NSHostingController(rootView: MainWindowRootView())
        window.setContentSize(NSSize(width: 920, height: 640))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }()

    override private init() {
        super.init()
    }

    func startObservingLaunch() {
        guard !isObservingLaunch else { return }
        isObservingLaunch = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidFinishLaunching(_:)),
            name: NSApplication.didFinishLaunchingNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    func show() {
        NSApplication.shared.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
    }

    func windowWillClose(_: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    @objc private func applicationDidFinishLaunching(_: Notification) {
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didFinishLaunchingNotification,
            object: nil
        )
        isObservingLaunch = false
        AppModel.shared.refreshAccessibility()
        show()
    }

    @objc private func applicationDidBecomeActive(_: Notification) {
        AppModel.shared.refreshAccessibility()
    }
}

private struct MainWindowRootView: View {
    var body: some View {
        MainWindowView()
            .environment(AppModel.shared)
    }
}
