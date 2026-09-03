// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import prismBarCore
import SwiftUI

enum UIAuditWindowSizePolicy {
    static func size(for textSize: PrismTextSizePreference) -> NSSize {
        NSSize(
            width: 920 + CGFloat(textSize.scale - 1) * 240,
            height: 640 + CGFloat(textSize.scale - 1) * 120
        )
    }
}

/// Makes revision-bound screenshots deterministic without changing normal window restoration.
struct UIAuditWindowConfiguration: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        UIAuditWindowView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class UIAuditWindowView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard ProcessInfo.processInfo.arguments.contains("--prismbar-ui-audit"),
              let window
        else {
            return
        }

        let textSize = PrismTextSizePreference(
            storedValue: UserDefaults.standard.string(
                forKey: PrismTextSizePreference.storageKey
            )
        )
        var frame = window.frame
        frame.size = UIAuditWindowSizePolicy.size(for: textSize)
        window.setFrame(frame, display: true)
        window.center()
    }
}
