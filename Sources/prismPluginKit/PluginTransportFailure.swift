// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// A bounded description of an XPC transport failure.
///
/// The classifier intentionally discards domains, messages, paths, process
/// details, and user-info values before a failure crosses into application UI.
public enum PluginTransportFailure: Equatable, Sendable {
    case codeSigningRequirement
    case interrupted
    case invalidConnection
    case invalidReply
    case unknown

    public static func classify(_ error: any Error) -> Self {
        let error = error as NSError
        guard error.domain == NSCocoaErrorDomain else { return .unknown }

        switch error.code {
        case 4_102:
            return .codeSigningRequirement
        case 4_097:
            return .interrupted
        case 4_099:
            return .invalidConnection
        case 4_101:
            return .invalidReply
        default:
            return .unknown
        }
    }
}

/// Failure stages returned by a bundled plugin service.
///
/// Only this fixed domain and these codes are accepted. The associated NSError
/// intentionally carries no user-info payload.
public enum PluginServiceFailure: Int, CaseIterable, Equatable, Sendable {
    case invalidRequest = 1
    case requestRejected = 2
    case invalidResponse = 3

    public static let errorDomain = "com.laclairtech.prismbar.plugin.service"

    public var error: NSError {
        NSError(domain: Self.errorDomain, code: rawValue)
    }

    public static func classify(_ error: any Error) -> Self? {
        let error = error as NSError
        guard error.domain == errorDomain else { return nil }
        return Self(rawValue: error.code)
    }
}
