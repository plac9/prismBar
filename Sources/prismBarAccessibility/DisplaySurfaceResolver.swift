// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@preconcurrency import ApplicationServices
import prismBarCore

struct DisplaySurfaceDescriptor: Equatable, Sendable {
    let token: String
    let frame: MenuBarItemFrame
}

struct DisplaySurfaceResolver: Sendable {
    let surfaces: [DisplaySurfaceDescriptor]

    func surfaceToken(for itemFrame: MenuBarItemFrame) -> String? {
        let midpointX = itemFrame.minX + itemFrame.width / 2
        let midpointY = itemFrame.minY + itemFrame.height / 2
        return surfaces.first { surface in
            midpointX >= surface.frame.minX &&
                midpointX < surface.frame.minX + surface.frame.width &&
                midpointY >= surface.frame.minY &&
                midpointY < surface.frame.minY + surface.frame.height
        }?.token
    }
}

enum ActiveDisplaySurfaceCatalog {
    static func current() -> DisplaySurfaceResolver {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success,
              displayCount > 0
        else {
            return DisplaySurfaceResolver(surfaces: [])
        }

        var displayIdentifiers = [CGDirectDisplayID](
            repeating: CGDirectDisplayID(),
            count: Int(displayCount)
        )
        guard CGGetActiveDisplayList(
            displayCount,
            &displayIdentifiers,
            &displayCount
        ) == .success else {
            return DisplaySurfaceResolver(surfaces: [])
        }

        let uniqueFrames = displayIdentifiers
            .prefix(Int(displayCount))
            .map(CGDisplayBounds)
            .filter { !$0.isNull && !$0.isInfinite && $0.width > 0 && $0.height > 0 }
            .reduce(into: [CGRect]()) { frames, frame in
                if !frames.contains(frame) {
                    frames.append(frame)
                }
            }
            .sorted { lhs, rhs in
                if lhs.minY == rhs.minY {
                    return lhs.minX < rhs.minX
                }
                return lhs.minY < rhs.minY
            }

        return DisplaySurfaceResolver(surfaces: uniqueFrames.enumerated().map { index, frame in
            DisplaySurfaceDescriptor(
                token: "display.\(index)",
                frame: MenuBarItemFrame(
                    minX: frame.minX,
                    minY: frame.minY,
                    width: frame.width,
                    height: frame.height
                )
            )
        })
    }
}
