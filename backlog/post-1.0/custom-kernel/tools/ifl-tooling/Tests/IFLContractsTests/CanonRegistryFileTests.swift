import Foundation
@testable import IFLContracts
import Testing

@Suite("CanonRegistryFileTests")
struct CanonRegistryFileTests {
    @Test("production Canon VERSION is the exact snapshot major bytes")
    func canonVersionBytes() throws {
        let data = try Data(contentsOf: canonRoot.appendingPathComponent("VERSION"))
        #expect(data == Data([0x31, 0x0A]))
    }

    @Test("production registry directory has the exact bootstrap filename set")
    func exactRegistryFilenames() throws {
        let filenames = try FileManager.default
            .contentsOfDirectory(atPath: registryRoot.path)
            .sorted()
        #expect(filenames == Self.registryFilenames)
    }
}
