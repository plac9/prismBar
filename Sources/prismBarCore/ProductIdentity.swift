// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public enum SupportedArchitecture: String, Codable, CaseIterable, Sendable {
    case arm64
}

public enum ProductIdentity: Sendable {
    public static let displayName = "prismBar"
    public static let bundleIdentifier = "com.laclairtech.prismbar"
    public static let sourceRepositoryURL: URL = {
        guard let url = URL(string: "https://github.com/plac9/prismBar") else {
            preconditionFailure("The compile-time source repository URL is invalid.")
        }
        return url
    }()
    public static let minimumSystemMajorVersion = 27
    public static let supportedArchitectures: Set<SupportedArchitecture> = [.arm64]

    public static func sourceURL(for revision: String) -> URL {
        guard revision.utf8.count == 40,
              revision.utf8.allSatisfy({ byte in
                  (48 ... 57).contains(byte) || (97 ... 102).contains(byte)
              })
        else {
            return sourceRepositoryURL
        }

        return sourceRepositoryURL
            .appendingPathComponent("tree", isDirectory: true)
            .appendingPathComponent(revision, isDirectory: false)
    }
}
