// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarCore
import Testing

@Suite("Product identity")
struct ProductIdentityTests {
    @Test("uses the exact public identity")
    func exactIdentity() {
        #expect(ProductIdentity.displayName == "prismBar")
        #expect(ProductIdentity.bundleIdentifier == "com.laclairtech.prismbar")
    }

    @Test("supports only the intentional platform baseline")
    func platformBaseline() {
        #expect(ProductIdentity.minimumSystemMajorVersion == 27)
        #expect(ProductIdentity.supportedArchitectures == [.arm64])
    }
}
