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
