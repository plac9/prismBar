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
        #expect(ProductIdentity.sourceRepositoryURL.absoluteString == "https://github.com/plac9/prismBar")
    }

    @Test("supports only the intentional platform baseline")
    func platformBaseline() {
        #expect(ProductIdentity.minimumSystemMajorVersion == 27)
        #expect(ProductIdentity.supportedArchitectures == [.arm64])
    }

    @Test("maps only a complete Git revision to an immutable public source tree")
    func immutableSourceURL() {
        let revision = "0123456789abcdef0123456789abcdef01234567"
        #expect(
            ProductIdentity.sourceURL(for: revision).absoluteString ==
                "https://github.com/plac9/prismBar/tree/\(revision)"
        )
        #expect(ProductIdentity.sourceURL(for: "local-development") == ProductIdentity.sourceRepositoryURL)
        #expect(ProductIdentity.sourceURL(for: "0123456") == ProductIdentity.sourceRepositoryURL)
    }
}
