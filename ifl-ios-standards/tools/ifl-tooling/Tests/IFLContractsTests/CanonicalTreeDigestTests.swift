import Darwin
import Foundation
@testable import IFLContracts
import Testing

@Suite("CanonicalTreeDigestTests", .serialized)
struct CanonicalTreeDigestTests {
    private let helloDigest = "5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03"

    @Test("one portable inventory has stable canonical bytes and digest")
    func goldenInventoryAndDigest() throws {
        let policy = try CanonicalTreePolicy(excludedRoots: [])
        let inventory = try CanonicalTreeInventory(
            policy: policy,
            rootMode: 0o755,
            entries: [
                CanonicalTreeEntry(
                    relativePath: "nested",
                    kind: .directory,
                    contentSHA256: nil,
                    mode: 0o755
                ),
                CanonicalTreeEntry(
                    relativePath: "hello.txt",
                    kind: .regularFile,
                    contentSHA256: HashDigest(validating: helloDigest),
                    mode: 0o644
                ),
            ]
        )

        let expectedJSON = #"{"entries":[{"content_sha256":"5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03","kind":"regular_file","mode":420,"relative_path":"hello.txt"},{"kind":"directory","mode":493,"relative_path":"nested"}],"policy":{"excluded_roots":[],"schema_version":1},"root_mode":493,"schema_version":1}"#
        #expect(try String(decoding: CanonicalJSON.encode(inventory), as: UTF8.self) == expectedJSON)
        #expect(try CanonicalTreeDigest.digest(inventory).rawValue == "0daeabc5879bc353dc500f71ee583d494d2da45f57cf4884c3468e1fbc1ba5ed")

        let decoded = try CanonicalJSON.decode(CanonicalTreeInventory.self, from: Data(expectedJSON.utf8))
        #expect(decoded == inventory)
    }

    @Test("root permissions participate in tree identity")
    func rootModeChangesDigest() throws {
        let policy = try CanonicalTreePolicy(excludedRoots: [])
        let first = try CanonicalTreeInventory(policy: policy, rootMode: 0o755, entries: [])
        let second = try CanonicalTreeInventory(policy: policy, rootMode: 0o700, entries: [])
        #expect(try CanonicalTreeDigest.digest(first) != CanonicalTreeDigest.digest(second))
    }

    @Test("schema decoding rejects unknown fields and explicit-null aliases")
    func schemaRuntimeParity() {
        let invalidDocuments = [
            #"{"entries":[],"policy":{"excluded_roots":[],"schema_version":1},"root_mode":493,"schema_version":1,"unknown":true}"#,
            #"{"entries":[],"policy":{"excluded_roots":[],"schema_version":1,"unknown":true},"root_mode":493,"schema_version":1}"#,
            #"{"entries":[{"kind":"directory","mode":493,"relative_path":"nested","unknown":true}],"policy":{"excluded_roots":[],"schema_version":1},"root_mode":493,"schema_version":1}"#,
            #"{"entries":[{"content_sha256":null,"kind":"directory","mode":493,"relative_path":"nested"}],"policy":{"excluded_roots":[],"schema_version":1},"root_mode":493,"schema_version":1}"#,
        ]

        for document in invalidDocuments {
            #expect(throws: (any Error).self) {
                try CanonicalJSON.decode(CanonicalTreeInventory.self, from: Data(document.utf8))
            }
        }
    }

    @Test("published schema uses a stable non-placeholder identity")
    func stableSchemaIdentity() throws {
        let schemaURL = pluginRoot.appendingPathComponent("standards/canon/schemas/v1/canonical-tree-inventory.schema.json")
        let object = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: schemaURL)) as? [String: Any]
        )
        #expect(object["$id"] as? String == "urn:ifl:standards:schema:canonical-tree-inventory:v1")
    }

    @Test("relative paths and exclusions reject aliases, traversal, and normalization hazards")
    func invalidPaths() throws {
        for invalid in ["", "/absolute", "a//b", ".", "..", "a/../b", "a\\b", "nul\0byte", "e\u{301}"] {
            #expect(throws: CanonicalTreeError.self) {
                try CanonicalRelativePath(validating: invalid)
            }
        }
        #expect(try CanonicalRelativePath(validating: "nested/value.txt").rawValue == "nested/value.txt")
        #expect(throws: CanonicalTreeError.self) {
            try CanonicalTreePolicy(excludedRoots: ["a", "a/b"])
        }
        #expect(throws: CanonicalTreeError.self) {
            try CanonicalTreePolicy(excludedRoots: ["*.json"])
        }
        #expect(throws: CanonicalTreeError.self) {
            try CanonicalTreeValidation.rejectNormalizationCollision(rawNames: ["é", "e\u{301}"])
        }
    }

    @Test("scanner produces a repeatable inventory from opened descriptors")
    func scansPortableTree() throws {
        try withTemporaryDirectory { root in
            try makePortableTree(at: root)
            let policy = try CanonicalTreePolicy(excludedRoots: [])
            let scanner = CanonicalTreeScanner()
            let first = try scanner.scan(root: root, policy: policy)
            let second = try scanner.scan(root: root, policy: policy)

            #expect(first == second)
            #expect(first.rootMode == 0o755)
            #expect(first.entries.map(\.relativePath) == ["hello.txt", "nested", "nested/value.txt"])
            #expect(first.entries.first?.contentSHA256?.rawValue == helloDigest)
        }
    }

    @Test("scanner rejects symlinks, hardlinks, FIFOs, and security mode bits")
    func rejectsUnsupportedObjects() throws {
        try withTemporaryDirectory { root in
            try makePortableTree(at: root)
            try FileManager.default.createSymbolicLink(
                at: root.appendingPathComponent("link"),
                withDestinationURL: root.appendingPathComponent("hello.txt")
            )
            #expect(throws: CanonicalTreeError.self) {
                try CanonicalTreeScanner().scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
            }
        }

        try withTemporaryDirectory { root in
            try makePortableTree(at: root)
            try FileManager.default.linkItem(
                at: root.appendingPathComponent("hello.txt"),
                to: root.appendingPathComponent("hello-copy.txt")
            )
            #expect(throws: CanonicalTreeError.self) {
                try CanonicalTreeScanner().scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
            }
        }

        try withTemporaryDirectory { root in
            try setMode(0o755, on: root)
            let fifo = root.appendingPathComponent("named-pipe")
            let result = fifo.path.withCString { mkfifo($0, 0o600) }
            #expect(result == 0)
            #expect(throws: CanonicalTreeError.self) {
                try CanonicalTreeScanner().scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
            }
        }

        try withTemporaryDirectory { root in
            try makePortableTree(at: root)
            try setMode(0o1755, on: root)
            #expect(throws: CanonicalTreeError.self) {
                try CanonicalTreeScanner().scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
            }
        }
    }

    @Test("opened-object validation rejects socket, device, and cross-device metadata")
    func rejectsUnsupportedMetadata() {
        #expect(throws: CanonicalTreeError.self) {
            try CanonicalTreeValidation.validateSupportedKind(mode: mode_t(S_IFSOCK | 0o600))
        }
        #expect(throws: CanonicalTreeError.self) {
            try CanonicalTreeValidation.validateSupportedKind(mode: mode_t(S_IFCHR | 0o600))
        }
        #expect(throws: CanonicalTreeError.self) {
            try CanonicalTreeValidation.validateSupportedKind(mode: mode_t(S_IFBLK | 0o600))
        }
        #expect(throws: CanonicalTreeError.self) {
            try CanonicalTreeValidation.requireSameDevice(rootDevice: 1, entryDevice: 2)
        }
    }

    @Test("scanner production path rejects projected special and cross-device nested metadata")
    func scannerRejectsProjectedMetadata() throws {
        for specialMode in [mode_t(S_IFSOCK | 0o600), mode_t(S_IFCHR | 0o600), mode_t(S_IFBLK | 0o600)] {
            try withTemporaryDirectory { root in
                try makePortableTree(at: root)
                let scanner = CanonicalTreeScanner(validationProjection: { path, snapshot in
                    path == "nested/value.txt" ? snapshot.replacing(rawMode: specialMode) : snapshot
                })
                #expect(throws: CanonicalTreeError.self) {
                    try scanner.scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
                }
            }
        }

        try withTemporaryDirectory { root in
            try makePortableTree(at: root)
            let scanner = CanonicalTreeScanner(validationProjection: { path, snapshot in
                path == "nested/value.txt" ? snapshot.replacing(device: snapshot.device + 1) : snapshot
            })
            #expect(throws: CanonicalTreeError.self) {
                try scanner.scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
            }
        }
    }

    @Test("exclusions are explicit, matched, and identity-bearing")
    func exclusionPolicy() throws {
        try withTemporaryDirectory { root in
            try makePortableTree(at: root)
            let excluded = try CanonicalTreePolicy(excludedRoots: ["nested"])
            let inventory = try CanonicalTreeScanner().scan(root: root, policy: excluded)
            #expect(inventory.entries.map(\.relativePath) == ["hello.txt"])
            #expect(inventory.policy.excludedRoots == ["nested"])

            let missing = try CanonicalTreePolicy(excludedRoots: ["missing"])
            #expect(throws: CanonicalTreeError.self) {
                try CanonicalTreeScanner().scan(root: root, policy: missing)
            }
        }
    }

    @Test("ancestor replacement with a symlink never yields an inventory")
    func rejectsSymlinkSwap() throws {
        try withTemporaryDirectory { root in
            try makePortableTree(at: root)
            let outside = root.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: outside) }
            var swapped = false
            let scanner = CanonicalTreeScanner(hook: { event in
                guard event == .beforeEntryClassification(relativePath: "nested"), !swapped else { return }
                swapped = true
                let original = root.appendingPathComponent("nested-original")
                try FileManager.default.moveItem(at: root.appendingPathComponent("nested"), to: original)
                try FileManager.default.createSymbolicLink(
                    at: root.appendingPathComponent("nested"),
                    withDestinationURL: outside
                )
            })
            #expect(throws: CanonicalTreeError.self) {
                try scanner.scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
            }
        }
    }

    @Test("in-place mutation and permission drift never yield an inventory")
    func rejectsMutationAndModeDrift() throws {
        try withTemporaryDirectory { root in
            try makePortableTree(at: root)
            var mutated = false
            let scanner = CanonicalTreeScanner(hook: { event in
                guard event == .afterFileRead(relativePath: "hello.txt"), !mutated else { return }
                mutated = true
                try Data("HELLO\n".utf8).write(to: root.appendingPathComponent("hello.txt"))
            })
            #expect(throws: CanonicalTreeError.self) {
                try scanner.scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
            }
        }

        try withTemporaryDirectory { root in
            try makePortableTree(at: root)
            var changed = false
            let scanner = CanonicalTreeScanner(hook: { event in
                guard event == .afterFileRead(relativePath: "hello.txt"), !changed else { return }
                changed = true
                try setMode(0o600, on: root.appendingPathComponent("hello.txt"))
            })
            #expect(throws: CanonicalTreeError.self) {
                try scanner.scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
            }
        }
    }

    @Test("every open, read, stat, and link boundary rejects a changed object")
    func rejectsMutationAtEveryBoundary() throws {
        for scenario in BoundaryMutationScenario.allCases {
            try withTemporaryDirectory { root in
                try makePortableTree(at: root)
                var mutated = false
                let scanner = CanonicalTreeScanner(hook: { event in
                    guard !mutated, scenario.matches(event) else { return }
                    mutated = true
                    try scenario.mutate(root: root)
                })
                let policy = try CanonicalTreePolicy(
                    excludedRoots: scenario == .beforeExcludedLinkRevalidation ? ["hello.txt"] : []
                )

                do {
                    _ = try scanner.scan(root: root, policy: policy)
                    Issue.record("scanner accepted mutation at \(scenario.rawValue)")
                } catch {
                    #expect(mutated)
                }
            }
        }
    }

    @Test("root path replacement at terminal revalidation never yields an inventory")
    func rejectsRootTerminalLinkSwap() throws {
        try withTemporaryDirectory { root in
            try makePortableTree(at: root)
            let relocated = root.deletingLastPathComponent().appendingPathComponent("ifl-relocated-\(UUID().uuidString)")
            defer {
                if FileManager.default.fileExists(atPath: root.path) {
                    try? FileManager.default.removeItem(at: root)
                }
                if FileManager.default.fileExists(atPath: relocated.path) {
                    try? FileManager.default.moveItem(at: relocated, to: root)
                }
            }

            var swapped = false
            let scanner = CanonicalTreeScanner(hook: { event in
                guard event == .beforeRootTerminalRevalidation, !swapped else { return }
                swapped = true
                try FileManager.default.moveItem(at: root, to: relocated)
                try FileManager.default.createSymbolicLink(at: root, withDestinationURL: relocated)
            })
            #expect(throws: CanonicalTreeError.self) {
                try scanner.scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
            }
        }
    }

    @Test("security mode bits are rejected on files, directories, and excluded roots")
    func rejectsSecurityBitsAcrossObjectClasses() throws {
        let cases: [(path: String, mode: mode_t, excludedRoots: [String])] = [
            ("hello.txt", 0o4644, []),
            ("nested", 0o2755, []),
            ("hello.txt", 0o1644, ["hello.txt"]),
            ("nested", 0o1755, ["nested"]),
        ]

        for testCase in cases {
            try withTemporaryDirectory { root in
                try makePortableTree(at: root)
                try setMode(testCase.mode, on: root.appendingPathComponent(testCase.path))
                #expect(throws: CanonicalTreeError.self) {
                    try CanonicalTreeScanner().scan(
                        root: root,
                        policy: CanonicalTreePolicy(excludedRoots: testCase.excludedRoots)
                    )
                }
            }
        }
    }

    @Test("checked-in portable tree is the end-to-end golden scanner fixture")
    func checkedInPortableTreeGolden() throws {
        let root = pluginRoot.appendingPathComponent("verification/fixtures/contracts/tree-digest/positive/portable-tree")
        let inventory = try CanonicalTreeScanner().scan(
            root: root,
            policy: CanonicalTreePolicy(excludedRoots: [])
        )

        #expect(inventory.entries.map(\.relativePath) == ["hello.txt", "nested", "nested/value.txt"])
        let expectedJSON = #"{"entries":[{"content_sha256":"5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03","kind":"regular_file","mode":420,"relative_path":"hello.txt"},{"kind":"directory","mode":493,"relative_path":"nested"},{"content_sha256":"1e1f2c881ae0608ec77ebf88a75c66d3099113a7343238f2f7a0ebb91a4ed335","kind":"regular_file","mode":420,"relative_path":"nested/value.txt"}],"policy":{"excluded_roots":[],"schema_version":1},"root_mode":493,"schema_version":1}"#
        let actualJSON = try String(decoding: CanonicalJSON.encode(inventory), as: UTF8.self)
        #expect(actualJSON == expectedJSON)
        let actualDigest = try CanonicalTreeDigest.digest(inventory).rawValue
        #expect(actualDigest == "6210b45e23d3f1ae6e6b0aa5f903f09ee2c516bca2fd0390017f3d4990013cca")
    }

    @Test("every checked-in negative fixture recipe is registered by the test matrix")
    func negativeFixtureRecipesAreConsumed() throws {
        let root = pluginRoot.appendingPathComponent("verification/fixtures/contracts/tree-digest/negative")
        let fixtureURLs = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ).map { $0.appendingPathComponent("fixture.json") }
        let descriptors = try fixtureURLs.map {
            try JSONDecoder().decode(NegativeFixtureDescriptor.self, from: Data(contentsOf: $0))
        }
        #expect(
            Set(descriptors.map(\.kind)) == [
                "path_normalization_collision",
                "symlink",
                "ancestor_symlink_swap",
                "in_place_mutation",
                "hardlink",
                "special_file",
                "mode_drift",
            ]
        )
        #expect(descriptors.allSatisfy { ["runtime", "scan_hook"].contains($0.materialization) })
        for descriptor in descriptors {
            try exerciseNegativeFixture(descriptor)
        }
    }

    private var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ifl-tree-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func makePortableTree(at root: URL) throws {
        let nested = root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: false)
        try Data("hello\n".utf8).write(to: root.appendingPathComponent("hello.txt"))
        try Data("value\n".utf8).write(to: nested.appendingPathComponent("value.txt"))
        try setMode(0o755, on: root)
        try setMode(0o755, on: nested)
        try setMode(0o644, on: root.appendingPathComponent("hello.txt"))
        try setMode(0o600, on: nested.appendingPathComponent("value.txt"))
    }

    private func exerciseNegativeFixture(_ descriptor: NegativeFixtureDescriptor) throws {
        switch descriptor.kind {
        case "path_normalization_collision":
            #expect(throws: CanonicalTreeError.self) {
                try CanonicalTreeValidation.rejectNormalizationCollision(rawNames: ["é", "e\u{301}"])
            }
        case "symlink":
            try withTemporaryDirectory { root in
                try makePortableTree(at: root)
                try FileManager.default.createSymbolicLink(
                    at: root.appendingPathComponent("link"),
                    withDestinationURL: root.appendingPathComponent("hello.txt")
                )
                #expect(throws: CanonicalTreeError.self) {
                    try CanonicalTreeScanner().scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
                }
            }
        case "ancestor_symlink_swap":
            try withTemporaryDirectory { root in
                try makePortableTree(at: root)
                var swapped = false
                let scanner = CanonicalTreeScanner(hook: { event in
                    guard event == .beforeEntryClassification(relativePath: "nested"), !swapped else { return }
                    swapped = true
                    let original = root.appendingPathComponent("nested-original")
                    try FileManager.default.moveItem(at: root.appendingPathComponent("nested"), to: original)
                    try FileManager.default.createSymbolicLink(
                        at: root.appendingPathComponent("nested"),
                        withDestinationURL: original
                    )
                })
                #expect(throws: CanonicalTreeError.self) {
                    try scanner.scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
                }
            }
        case "in_place_mutation":
            try withTemporaryDirectory { root in
                try makePortableTree(at: root)
                var mutated = false
                let scanner = CanonicalTreeScanner(hook: { event in
                    guard event == .afterFileRead(relativePath: "hello.txt"), !mutated else { return }
                    mutated = true
                    try Data("HELLO\n".utf8).write(to: root.appendingPathComponent("hello.txt"))
                })
                #expect(throws: CanonicalTreeError.self) {
                    try scanner.scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
                }
            }
        case "hardlink":
            try withTemporaryDirectory { root in
                try makePortableTree(at: root)
                try FileManager.default.linkItem(
                    at: root.appendingPathComponent("hello.txt"),
                    to: root.appendingPathComponent("hello-copy.txt")
                )
                #expect(throws: CanonicalTreeError.self) {
                    try CanonicalTreeScanner().scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
                }
            }
        case "special_file":
            let variants = try #require(descriptor.variants)
            #expect(Set(variants) == ["fifo", "socket", "character_device", "block_device"])
            for variant in variants {
                try exerciseSpecialFileVariant(variant)
            }
        case "mode_drift":
            try withTemporaryDirectory { root in
                try makePortableTree(at: root)
                var changed = false
                let scanner = CanonicalTreeScanner(hook: { event in
                    guard event == .beforeFinalDescriptorStat(relativePath: "hello.txt"), !changed else { return }
                    changed = true
                    try setMode(0o600, on: root.appendingPathComponent("hello.txt"))
                })
                #expect(throws: CanonicalTreeError.self) {
                    try scanner.scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
                }
            }
        default:
            throw CanonicalTreeError.invalidExclusion(descriptor.kind)
        }
    }

    private func exerciseSpecialFileVariant(_ variant: String) throws {
        switch variant {
        case "fifo":
            try withTemporaryDirectory { root in
                try setMode(0o755, on: root)
                let fifo = root.appendingPathComponent("named-pipe")
                guard fifo.path.withCString({ mkfifo($0, 0o600) }) == 0 else {
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
                }
                #expect(throws: CanonicalTreeError.self) {
                    try CanonicalTreeScanner().scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
                }
            }
        case "socket":
            try withShortTemporaryDirectory { root in
                try setMode(0o755, on: root)
                let socketDescriptor = try createUnixSocket(at: root.appendingPathComponent("local.socket"))
                defer { close(socketDescriptor) }
                #expect(throws: CanonicalTreeError.self) {
                    try CanonicalTreeScanner().scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
                }
            }
        case "character_device", "block_device":
            try withTemporaryDirectory { root in
                try makePortableTree(at: root)
                let projectedMode = variant == "character_device"
                    ? mode_t(S_IFCHR | 0o600)
                    : mode_t(S_IFBLK | 0o600)
                let scanner = CanonicalTreeScanner(validationProjection: { path, snapshot in
                    path == "hello.txt" ? snapshot.replacing(rawMode: projectedMode) : snapshot
                })
                #expect(throws: CanonicalTreeError.self) {
                    try scanner.scan(root: root, policy: CanonicalTreePolicy(excludedRoots: []))
                }
            }
        default:
            throw CanonicalTreeError.unsupportedObject(path: variant)
        }
    }

    private func createUnixSocket(at url: URL) throws -> Int32 {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }

        var address = sockaddr_un()
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(url.path.utf8) + [0]
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard pathBytes.count <= capacity else {
            close(descriptor)
            throw CanonicalTreeError.invalidRelativePath(url.path)
        }
        withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            pointer.withMemoryRebound(to: UInt8.self, capacity: capacity) { destination in
                for (index, byte) in pathBytes.enumerated() {
                    destination[index] = byte
                }
            }
        }
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            let capturedErrno = errno
            close(descriptor)
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(capturedErrno))
        }
        return descriptor
    }

    private func withShortTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let root = URL(fileURLWithPath: "/tmp", isDirectory: true)
            .appendingPathComponent("ifl-socket-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func setMode(_ mode: mode_t, on url: URL) throws {
        guard url.path.withCString({ chmod($0, mode) }) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }
}

private struct NegativeFixtureDescriptor: Decodable {
    let kind: String
    let materialization: String
    let variants: [String]?
}

private enum BoundaryMutationScenario: String, CaseIterable {
    case beforeRootOpen
    case afterRootOpenValidation
    case afterEntryClassification
    case afterFileOpenValidation
    case afterDirectoryOpenValidation
    case beforeDirectoryEnumeration
    case afterDirectoryEnumeration
    case afterReadChunk
    case afterFileRead
    case beforeFinalDescriptorStat
    case beforeFileLinkRevalidation
    case beforeDirectoryLinkRevalidation
    case beforeExcludedLinkRevalidation
    case beforeRootTerminalRevalidation

    func matches(_ event: CanonicalTreeScanEvent) -> Bool {
        switch (self, event) {
        case (.beforeRootOpen, .beforeRootOpen),
             (.afterRootOpenValidation, .afterRootOpenValidation),
             (.afterEntryClassification, .afterEntryClassification(relativePath: "hello.txt")),
             (.afterFileOpenValidation, .afterEntryOpenValidation(relativePath: "hello.txt")),
             (.afterDirectoryOpenValidation, .afterEntryOpenValidation(relativePath: "nested")),
             (.beforeDirectoryEnumeration, .beforeDirectoryEnumeration(relativePath: "nested")),
             (.afterDirectoryEnumeration, .afterDirectoryEnumeration(relativePath: "nested")),
             (.afterReadChunk, .afterReadChunk(relativePath: "hello.txt", offset: _)),
             (.afterFileRead, .afterFileRead(relativePath: "hello.txt")),
             (.beforeFinalDescriptorStat, .beforeFinalDescriptorStat(relativePath: "hello.txt")),
             (.beforeFileLinkRevalidation, .beforeLinkRevalidation(relativePath: "hello.txt")),
             (.beforeDirectoryLinkRevalidation, .beforeLinkRevalidation(relativePath: "nested")),
             (.beforeExcludedLinkRevalidation, .beforeLinkRevalidation(relativePath: "hello.txt")),
             (.beforeRootTerminalRevalidation, .beforeRootTerminalRevalidation):
            true
        default:
            false
        }
    }

    func mutate(root: URL) throws {
        switch self {
        case .beforeRootOpen,
             .afterRootOpenValidation,
             .beforeRootTerminalRevalidation:
            guard root.path.withCString({ chmod($0, 0o700) }) == 0 else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
        case .afterDirectoryOpenValidation,
             .beforeDirectoryLinkRevalidation:
            guard root.appendingPathComponent("nested").path.withCString({ chmod($0, 0o700) }) == 0 else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
        case .beforeDirectoryEnumeration,
             .afterDirectoryEnumeration:
            try Data("late\n".utf8).write(to: root.appendingPathComponent("nested/late.txt"))
        case .beforeExcludedLinkRevalidation:
            guard root.appendingPathComponent("hello.txt").path.withCString({ chmod($0, 0o600) }) == 0 else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
        default:
            try Data("HELLO\n".utf8).write(to: root.appendingPathComponent("hello.txt"))
        }
    }
}
