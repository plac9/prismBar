// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit

enum PrismStatusIcon {
    static let image: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { bounds in
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
            NSColor.labelColor.setStroke()
            prism.stroke()
            return bounds.width > 0
        }
        image.isTemplate = true
        image.accessibilityDescription = "prismBar"
        return image
    }()
}
