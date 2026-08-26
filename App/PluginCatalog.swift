// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismPluginKit

enum PluginCatalog {
    static let prismCalcIdentifier = "com.laclairtech.prismbar.plugin.prismcalc"

    static func makeRegistry() throws -> BundledPluginRegistry {
        let prismCalc = try BundledPluginRegistration(
            identifier: prismCalcIdentifier,
            displayName: "prismCalc",
            version: .init(major: 0, minor: 1, patch: 0),
            capabilities: [.panel, .commands, .openApplication],
            allowedApplicationIdentifiers: ["com.laclairtech.prismcalc"],
            isEnabledByDefault: true
        )
        return try BundledPluginRegistry(registrations: [prismCalc])
    }
}
