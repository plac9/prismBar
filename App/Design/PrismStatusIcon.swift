// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit

enum PrismStatusIcon {
    static let image: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { bounds in
            let silhouette = NSBezierPath()
            silhouette.windingRule = .evenOdd
            silhouette.move(to: NSPoint(x: 9, y: 16.2))
            silhouette.line(to: NSPoint(x: 1.3, y: 2.4))
            silhouette.line(to: NSPoint(x: 16.7, y: 2.4))
            silhouette.close()
            silhouette.move(to: NSPoint(x: 9, y: 12.3))
            silhouette.line(to: NSPoint(x: 5.2, y: 5.2))
            silhouette.line(to: NSPoint(x: 12.8, y: 5.2))
            silhouette.close()

            NSColor.labelColor.setFill()
            silhouette.fill()

            let refraction = NSBezierPath()
            refraction.lineWidth = 1.45
            refraction.lineJoinStyle = .round
            refraction.lineCapStyle = .round
            refraction.move(to: NSPoint(x: 0.8, y: 8.1))
            refraction.line(to: NSPoint(x: 4.2, y: 8.1))
            refraction.move(to: NSPoint(x: 13.8, y: 8.1))
            refraction.line(to: NSPoint(x: 17.2, y: 10.3))
            refraction.move(to: NSPoint(x: 13.8, y: 7.6))
            refraction.line(to: NSPoint(x: 17.2, y: 5.9))
            NSColor.labelColor.setStroke()
            refraction.stroke()
            return bounds.width > 0
        }
        image.isTemplate = true
        image.accessibilityDescription = "prismBar"
        return image
    }()
}
