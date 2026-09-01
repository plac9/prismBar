// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import SwiftUI

struct MenuBarApplicationIcon: View {
    let bundleIdentifier: String?
    let fallbackSymbol: String
    let size: CGFloat

    var body: some View {
        Group {
            if let applicationIcon {
                Image(nsImage: applicationIcon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: size * 0.68, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var applicationIcon: NSImage? {
        guard let bundleIdentifier,
              let applicationURL = NSWorkspace.shared.urlForApplication(
                  withBundleIdentifier: bundleIdentifier
              )
        else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: applicationURL.path)
    }
}
