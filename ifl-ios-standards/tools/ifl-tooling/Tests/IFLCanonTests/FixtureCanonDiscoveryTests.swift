import Foundation
import Testing

@Suite("FixtureCanonDiscoveryTests")
struct FixtureCanonDiscoveryTests {
    @Test("negative fixture discovery is sorted and covers every immediate directory")
    func checkedInNegativeFixturesAreDiscovered() throws {
        let fixturePaths = try FixtureCanon.negativeFixturePaths()

        #expect(!fixturePaths.isEmpty)
        #expect(fixturePaths == fixturePaths.sorted())
        #expect(fixturePaths.allSatisfy { $0.hasPrefix("negative/") })

        for fixturePath in fixturePaths {
            let directory = fixturePath.dropFirst("negative/".count)
            let manifestURL = FixtureCanon.negativeRoot
                .appendingPathComponent(String(directory), isDirectory: true)
                .appendingPathComponent("fixture.json")
            _ = try FixtureCanon.decodeManifest(Data(contentsOf: manifestURL))
        }
    }

    @Test("negative fixture discovery rejects immediate regular files")
    func regularFileSurpriseIsRejected() throws {
        try withTemporaryDirectory { root in
            try Data("surprise".utf8).write(to: root.appendingPathComponent("README.txt"))

            #expect(throws: FixtureCanon.SupportError.self) {
                _ = try FixtureCanon.negativeFixturePaths(at: root)
            }
        }
    }

    @Test("negative fixture discovery rejects immediate symbolic links")
    func symbolicLinkSurpriseIsRejected() throws {
        try withTemporaryDirectory { root in
            let target = root.appendingPathComponent("target", isDirectory: true)
            try FileManager.default.createDirectory(
                at: target,
                withIntermediateDirectories: false
            )
            try FileManager.default.createSymbolicLink(
                at: root.appendingPathComponent("linked-fixture"),
                withDestinationURL: target
            )

            #expect(throws: FixtureCanon.SupportError.self) {
                _ = try FixtureCanon.negativeFixturePaths(at: root)
            }
        }
    }

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ifl-fixture-discovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
}
