// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

public enum SupportedArchitecture: String, Codable, CaseIterable, Sendable {
    case arm64
}

public enum ProductIdentity: Sendable {
    public static let displayName = "prismBar"
    public static let bundleIdentifier = "com.laclairtech.prismbar"
    public static let minimumSystemMajorVersion = 27
    public static let supportedArchitectures: Set<SupportedArchitecture> = [.arm64]
}
