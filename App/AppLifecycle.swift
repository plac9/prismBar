// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import SwiftUI

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        AppModel.shared.refreshAccessibility()
    }

    func applicationDidBecomeActive(_: Notification) {
        AppModel.shared.refreshAccessibility()
    }
}

@MainActor
final class AppWindowController: NSObject, NSWindowDelegate {
    static let shared = AppWindowController()

    private static let workspaceFrameName = NSWindow.FrameAutosaveName(
        "com.laclairtech.prismbar.workspace-frame"
    )
    private static let prismCalcFrameName = NSWindow.FrameAutosaveName(
        "com.laclairtech.prismbar.prismcalc-frame"
    )
    private static let settingsFrameName = NSWindow.FrameAutosaveName(
        "com.laclairtech.prismbar.settings-frame"
    )
    private var isObservingLaunch = false
    private var workspaceWindow: NSWindow?
    private var prismCalcWindow: NSWindow?
    private var settingsWindow: NSWindow?

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
    }

    func showWorkspace() {
        let window = workspaceWindow ?? makeWindow(
            title: "prismBar",
            size: NSSize(width: 920, height: 640),
            minimumSize: NSSize(width: 760, height: 520),
            frameName: Self.workspaceFrameName,
            rootView: AnyView(MainWindowView().environment(AppModel.shared))
        )
        workspaceWindow = window
        show(window)
    }

    func showPrismCalc() {
        AppModel.shared.loadPluginIfNeeded()
        let window = prismCalcWindow ?? makeWindow(
            title: "prismCalc",
            size: NSSize(width: 360, height: 520),
            minimumSize: NSSize(width: 320, height: 440),
            frameName: Self.prismCalcFrameName,
            rootView: AnyView(PrismCalcUtilityView(model: AppModel.shared))
        )
        prismCalcWindow = window
        show(window)
    }

    func showSettings() {
        let window = settingsWindow ?? makeWindow(
            title: "prismBar Settings",
            size: NSSize(width: 560, height: 420),
            minimumSize: NSSize(width: 520, height: 380),
            frameName: Self.settingsFrameName,
            rootView: AnyView(SettingsRootView().environment(AppModel.shared))
        )
        settingsWindow = window
        show(window)
    }

    func windowWillClose(_: Notification) {
        Task { @MainActor in
            await Task.yield()
            let hasVisibleWindow = NSApplication.shared.windows.contains {
                $0.isVisible && $0.canBecomeMain
            }
            if !hasVisibleWindow {
                NSApplication.shared.setActivationPolicy(.accessory)
            }
        }
    }

    @objc private func applicationDidFinishLaunching(_: Notification) {
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didFinishLaunchingNotification,
            object: nil
        )
        isObservingLaunch = false
        showWorkspace()
    }

    private func show(_ window: NSWindow) {
        NSApplication.shared.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
    }

    private func makeWindow(
        title: String,
        size: NSSize,
        minimumSize: NSSize,
        frameName: NSWindow.FrameAutosaveName,
        rootView: AnyView
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbarStyle = .unified
        window.contentMinSize = minimumSize
        window.contentViewController = NSHostingController(rootView: rootView)
        window.isReleasedWhenClosed = false
        window.isRestorable = true
        window.delegate = self
        if !window.setFrameUsingName(frameName) {
            window.center()
        }
        window.setFrameAutosaveName(frameName)
        return window
    }
}
