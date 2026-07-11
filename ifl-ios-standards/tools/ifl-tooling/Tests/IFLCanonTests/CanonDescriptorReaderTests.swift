import Darwin
import Foundation
@testable import IFLCanon
import IFLContracts
import Testing

@Suite("CanonDescriptorReaderTests", .serialized)
struct CanonDescriptorReaderTests {
    @Test("a file swapped to a symlink after inventory scan is rejected")
    func transientFileSymlinkIsRejected() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            let target = root.appendingPathComponent("rules/core/minimal.rules.json")
            let outside = root.deletingLastPathComponent().appendingPathComponent("outside.json")
            try FileManager.default.copyItem(at: target, to: outside)
            let mutation = CanonRepositoryMutationHook {
                try FileManager.default.removeItem(at: target)
                try FileManager.default.createSymbolicLink(at: target, withDestinationURL: outside)
            }
            let repository = FileCanonRepository(root: root) { event in
                if event == .willOpenFile("rules/core/minimal.rules.json") {
                    try mutation.runOnce()
                }
            }

            let error = CanonRepositoryFixture.contractError {
                _ = try repository.snapshot(profiles: [CanonRepositoryFixture.coreProfileID()])
            }
            #expect(error?.code == "invalid_contract")
        }
    }

    @Test("a parent directory swapped to a symlink after inventory scan is rejected")
    func transientParentSymlinkIsRejected() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            let target = root.appendingPathComponent("rules/core", isDirectory: true)
            let outside = root.deletingLastPathComponent().appendingPathComponent(
                "outside-rules",
                isDirectory: true
            )
            try FileManager.default.copyItem(at: target, to: outside)
            let mutation = CanonRepositoryMutationHook {
                try FileManager.default.removeItem(at: target)
                try FileManager.default.createSymbolicLink(at: target, withDestinationURL: outside)
            }
            let repository = FileCanonRepository(root: root) { event in
                if event == .willOpenDirectory("rules/core") {
                    try mutation.runOnce()
                }
            }

            let error = CanonRepositoryFixture.contractError {
                _ = try repository.snapshot(profiles: [CanonRepositoryFixture.coreProfileID()])
            }
            #expect(error?.code == "invalid_contract")
        }
    }

    @Test("a file replaced after bytes are read is rejected before decode")
    func postReadMutationIsRejected() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            let target = root.appendingPathComponent("rules/core/minimal.rules.json")
            let mutation = CanonRepositoryMutationHook {
                var data = try Data(contentsOf: target)
                data.append(0x20)
                try data.write(to: target, options: .atomic)
                try CanonRepositoryFixture.setPermissions(0o644, at: target)
            }
            let repository = FileCanonRepository(root: root) { event in
                if event == .didReadFile("rules/core/minimal.rules.json") {
                    try mutation.runOnce()
                }
            }

            let error = CanonRepositoryFixture.contractError {
                _ = try repository.snapshot(profiles: [CanonRepositoryFixture.coreProfileID()])
            }
            #expect(error?.code == "invalid_contract")
        }
    }

    @Test("the full-root stability scan still observes excluded activation content")
    func activationMutationDuringLoadIsRejected() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            let activations = root.appendingPathComponent("activations", isDirectory: true)
            try FileManager.default.createDirectory(
                at: activations,
                withIntermediateDirectories: false
            )
            try CanonRepositoryFixture.setPermissions(0o755, at: activations)
            let activation = activations.appendingPathComponent("receipt.json")
            try Data("{\"state\":\"before\"}\n".utf8).write(to: activation)
            try CanonRepositoryFixture.setPermissions(0o644, at: activation)

            let mutation = CanonRepositoryMutationHook {
                try Data("{\"state\":\"after\"}\n".utf8).write(to: activation, options: .atomic)
                try CanonRepositoryFixture.setPermissions(0o644, at: activation)
            }
            let repository = FileCanonRepository(root: root) { event in
                if event == .didReadFile("registry/requirements.v1.json") {
                    try mutation.runOnce()
                }
            }

            let error = CanonRepositoryFixture.contractError {
                _ = try repository.snapshot(profiles: [CanonRepositoryFixture.coreProfileID()])
            }
            #expect(error?.code == "digest_mismatch")
        }
    }

    @Test("inventory and semantic reads remain bound to the retained root across an ancestor pivot")
    func retainedRootScanCannotMixRoots() throws {
        let fileManager = FileManager.default
        let workspace = fileManager.temporaryDirectory
            .appendingPathComponent("ifl-retained-root-\(UUID().uuidString)", isDirectory: true)
        let activeParent = workspace.appendingPathComponent("active", isDirectory: true)
        let alternateParent = workspace.appendingPathComponent("alternate", isDirectory: true)
        let retainedParent = workspace.appendingPathComponent("retained", isDirectory: true)
        let activeRoot = activeParent.appendingPathComponent("canon", isDirectory: true)
        let alternateRoot = alternateParent.appendingPathComponent("canon", isDirectory: true)

        try fileManager.createDirectory(at: workspace, withIntermediateDirectories: false)
        try fileManager.createDirectory(at: activeParent, withIntermediateDirectories: false)
        try fileManager.createDirectory(at: alternateParent, withIntermediateDirectories: false)
        try fileManager.copyItem(at: CanonRepositoryFixture.positiveRoot, to: activeRoot)
        try fileManager.copyItem(at: CanonRepositoryFixture.positiveRoot, to: alternateRoot)
        try Data("2\n".utf8).write(
            to: alternateRoot.appendingPathComponent("VERSION"),
            options: .atomic
        )
        try CanonRepositoryFixture.setPermissions(
            0o644,
            at: alternateRoot.appendingPathComponent("VERSION")
        )

        var isPivoted = false
        defer {
            if isPivoted {
                if fileManager.fileExists(atPath: activeParent.path) {
                    try? fileManager.moveItem(at: activeParent, to: alternateParent)
                }
                if fileManager.fileExists(atPath: retainedParent.path) {
                    try? fileManager.moveItem(at: retainedParent, to: activeParent)
                }
            }
            try? fileManager.removeItem(at: workspace)
        }

        let reader = try CanonDescriptorReader(root: activeRoot, eventHandler: { _ in })
        try fileManager.moveItem(at: activeParent, to: retainedParent)
        try fileManager.moveItem(at: alternateParent, to: activeParent)
        isPivoted = true

        let pathnameBytes = try Data(
            contentsOf: activeRoot.appendingPathComponent("VERSION")
        )
        let inventory = try reader.scan(policy: CanonicalTreePolicy(excludedRoots: []))

        try fileManager.moveItem(at: activeParent, to: alternateParent)
        try fileManager.moveItem(at: retainedParent, to: activeParent)
        isPivoted = false

        let retainedBytes = try reader.read(
            relativePath: CanonicalRelativePath(validating: "VERSION")
        )
        let versionEntry = try #require(
            inventory.entries.first { $0.relativePath == "VERSION" }
        )

        #expect(pathnameBytes == Data("2\n".utf8))
        #expect(retainedBytes == Data("1\n".utf8))
        #expect(versionEntry.contentSHA256 == CanonicalTreeDigest.sha256(retainedBytes))
        #expect(versionEntry.contentSHA256 != CanonicalTreeDigest.sha256(pathnameBytes))
    }

    @Test("an anchored repository cannot be redirected by replacing its pathname")
    func anchoredRepositoryCannotBeRedirected() throws {
        let fileManager = FileManager.default
        let workspace = fileManager.temporaryDirectory
            .appendingPathComponent("ifl-anchor-pivot-\(UUID().uuidString)", isDirectory: true)
        let activeRoot = workspace.appendingPathComponent("canon", isDirectory: true)
        let retainedRoot = workspace.appendingPathComponent("retained", isDirectory: true)
        let replacementRoot = workspace.appendingPathComponent("replacement", isDirectory: true)

        try fileManager.createDirectory(at: workspace, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: workspace) }
        try fileManager.copyItem(at: CanonRepositoryFixture.positiveRoot, to: activeRoot)
        try fileManager.copyItem(at: CanonRepositoryFixture.positiveRoot, to: replacementRoot)
        try Data("2\n".utf8).write(
            to: replacementRoot.appendingPathComponent("VERSION"),
            options: .atomic
        )
        try CanonRepositoryFixture.setPermissions(
            0o644,
            at: replacementRoot.appendingPathComponent("VERSION")
        )

        let repository = try anchoredRepository(root: activeRoot)
        try fileManager.moveItem(at: activeRoot, to: retainedRoot)
        try fileManager.moveItem(at: replacementRoot, to: activeRoot)

        let pathnameVersion = try Data(
            contentsOf: activeRoot.appendingPathComponent("VERSION")
        )
        let snapshot = try repository.snapshot(
            profiles: [CanonRepositoryFixture.coreProfileID()]
        )

        #expect(pathnameVersion == Data("2\n".utf8))
        #expect(snapshot.canonVersion == 1)
    }

    private func anchoredRepository(root: URL) throws -> FileCanonRepository {
        let descriptor = root.path.withCString {
            Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        try #require(descriptor >= 0)
        defer { Darwin.close(descriptor) }
        let anchor = try CanonRootAnchor(
            duplicatingRootDirectoryDescriptor: descriptor,
            path: root.path
        )
        return FileCanonRepository(anchor: anchor)
    }
}
