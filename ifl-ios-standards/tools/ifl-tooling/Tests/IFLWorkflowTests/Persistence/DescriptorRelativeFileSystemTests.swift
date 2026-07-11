import Darwin
import Foundation
@testable import IFLWorkflow
import Testing

@Suite("DescriptorRelativeFileSystemTests")
struct DescriptorRelativeFileSystemTests {
    @Test("components are traversed one retained descriptor at a time with no-follow semantics")
    func createsAndReadsRelativeFiles() throws {
        let root = try descriptorRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileSystem = try DescriptorRelativeFileSystem(rootURL: root)
        try fileSystem.createDirectories(["one", "two"], mode: 0o700)
        try fileSystem.writeExclusive(
            Data("canonical".utf8),
            named: "value.json",
            in: ["one", "two"],
            mode: 0o600
        )
        #expect(try fileSystem.readFile(named: "value.json", in: ["one", "two"])
            == Data("canonical".utf8))
        #expect(throws: PersistenceError.invalidPathComponent) {
            try fileSystem.readFile(named: "../escape", in: ["one"])
        }
    }

    @Test("a symlink traversal component and hardlinked replacement target fail closed")
    func rejectsSymlinkAndHardlinkTargets() throws {
        let root = try descriptorRoot()
        let outside = root.deletingLastPathComponent()
            .appendingPathComponent("outside-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("link"),
            withDestinationURL: outside
        )
        let fileSystem = try DescriptorRelativeFileSystem(rootURL: root)
        #expect(throws: PersistenceError.integrityViolation) {
            try fileSystem.readFile(named: "value", in: ["link"])
        }

        try fileSystem.writeExclusive(Data("old".utf8), named: "target", in: [], mode: 0o600)
        let expectedTarget = try fileSystem.entryIdentity(named: "target", in: [])
        try FileManager.default.linkItem(
            at: root.appendingPathComponent("target"),
            to: root.appendingPathComponent("alias")
        )
        try fileSystem.writeExclusive(Data("new".utf8), named: "temp", in: [], mode: 0o600)
        #expect(throws: PersistenceError.integrityViolation) {
            _ = try fileSystem.replaceFile(
                temporaryName: "temp",
                destinationName: "target",
                in: [],
                expectedDestination: .exact(expectedTarget)
            )
        }
    }

    @Test("ancestor swaps stay anchored to the retained descriptor and never escape")
    func ancestorSwapCannotEscape() throws {
        let root = try descriptorRoot()
        let outside = root.deletingLastPathComponent()
            .appendingPathComponent("outside-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("safe"), withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let fileSystem = try DescriptorRelativeFileSystem(rootURL: root)
        let hook = DescriptorRelativeOperationHook { point in
            guard point == .directoryOpened else { return }
            try FileManager.default.moveItem(
                at: root.appendingPathComponent("safe"),
                to: root.appendingPathComponent("retained")
            )
            try FileManager.default.createSymbolicLink(
                at: root.appendingPathComponent("safe"),
                withDestinationURL: outside
            )
        }
        #expect(throws: PersistenceError.integrityViolation) {
            try fileSystem.writeExclusive(
                Data("anchored".utf8),
                named: "value",
                in: ["safe"],
                mode: 0o600,
                hook: hook
            )
        }
        #expect(!FileManager.default.fileExists(
            atPath: root.appendingPathComponent("retained/value").path
        ))
        #expect(!FileManager.default.fileExists(atPath: outside.appendingPathComponent("value").path))
    }

    @Test("destination swaps after validation fail without mutating the replacement")
    func destinationSwapFailsClosed() throws {
        let root = try descriptorRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileSystem = try DescriptorRelativeFileSystem(rootURL: root)
        try fileSystem.writeExclusive(Data("old".utf8), named: "target", in: [], mode: 0o600)
        try fileSystem.writeExclusive(Data("new".utf8), named: "temp", in: [], mode: 0o600)
        let expectedTarget = try fileSystem.entryIdentity(named: "target", in: [])
        let hook = DescriptorRelativeOperationHook { point in
            guard point == .destinationValidated else { return }
            try FileManager.default.removeItem(at: root.appendingPathComponent("target"))
            try FileManager.default.createSymbolicLink(
                at: root.appendingPathComponent("target"),
                withDestinationURL: root.appendingPathComponent("unrelated")
            )
        }
        #expect(throws: PersistenceError.integrityViolation) {
            _ = try fileSystem.replaceFile(
                temporaryName: "temp",
                destinationName: "target",
                in: [],
                expectedDestination: .exact(expectedTarget),
                hook: hook
            )
        }
        #expect(try Data(contentsOf: root.appendingPathComponent("temp")) == Data("new".utf8))
    }

    @Test("a regular destination swapped after final validation is restored without mutation")
    func postValidationRegularSwapIsRolledBack() throws {
        let root = try descriptorRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileSystem = try DescriptorRelativeFileSystem(rootURL: root)
        try fileSystem.writeExclusive(Data("old".utf8), named: "target", in: [], mode: 0o600)
        try fileSystem.writeExclusive(Data("new".utf8), named: "temp", in: [], mode: 0o600)
        let expectedTarget = try fileSystem.entryIdentity(named: "target", in: [])
        let hook = DescriptorRelativeOperationHook { point in
            guard point == .beforeRename else { return }
            try FileManager.default.removeItem(at: root.appendingPathComponent("target"))
            try Data("unrelated".utf8).write(to: root.appendingPathComponent("target"))
        }
        #expect(throws: PersistenceError.integrityViolation) {
            _ = try fileSystem.replaceFile(
                temporaryName: "temp",
                destinationName: "target",
                in: [],
                expectedDestination: .exact(expectedTarget),
                hook: hook
            )
        }
        #expect(try Data(contentsOf: root.appendingPathComponent("target")) == Data("unrelated".utf8))
        #expect(try Data(contentsOf: root.appendingPathComponent("temp")) == Data("new".utf8))
    }

    @Test("publication carries expected absence or exact prior identity into the namespace CAS")
    func publicationRequiresDestinationExpectation() throws {
        let root = try descriptorRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileSystem = try DescriptorRelativeFileSystem(rootURL: root)
        let temporaryBytes = Data("new".utf8)
        let unrelatedBytes = Data("unrelated".utf8)
        try fileSystem.writeExclusive(temporaryBytes, named: "temp", in: [], mode: 0o600)
        try fileSystem.writeExclusive(unrelatedBytes, named: "target", in: [], mode: 0o600)

        #expect(throws: PersistenceError.integrityViolation) {
            _ = try fileSystem.replaceFile(
                temporaryName: "temp",
                destinationName: "target",
                in: [],
                expectedDestination: .absent
            )
        }
        #expect(try Data(contentsOf: root.appendingPathComponent("target")) == unrelatedBytes)
        #expect(try Data(contentsOf: root.appendingPathComponent("temp")) == temporaryBytes)

        let expected = try fileSystem.entryIdentity(named: "target", in: [])
        try FileManager.default.removeItem(at: root.appendingPathComponent("target"))
        try Data("replacement".utf8).write(to: root.appendingPathComponent("target"))
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: root.appendingPathComponent("target").path
        )
        #expect(throws: PersistenceError.integrityViolation) {
            _ = try fileSystem.replaceFile(
                temporaryName: "temp",
                destinationName: "target",
                in: [],
                expectedDestination: .exact(expected)
            )
        }
        #expect(
            try Data(contentsOf: root.appendingPathComponent("target"))
                == Data("replacement".utf8)
        )
        #expect(try Data(contentsOf: root.appendingPathComponent("temp")) == temporaryBytes)
    }

    @Test("the post-swap hard-crash surface leaves both identities recoverable")
    func swapInterruptionPreservesBothObjects() throws {
        let root = try descriptorRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileSystem = try DescriptorRelativeFileSystem(rootURL: root)
        let oldBytes = Data("old".utf8)
        let newBytes = Data("new".utf8)
        try fileSystem.writeExclusive(oldBytes, named: "target", in: [], mode: 0o600)
        try fileSystem.writeExclusive(newBytes, named: "temp", in: [], mode: 0o600)
        let expected = try fileSystem.entryIdentity(named: "target", in: [])
        let hook = DescriptorRelativeOperationHook { point in
            if point == .afterSwapBeforeCleanup {
                throw ResidualDescriptorTestInterruption.stop
            }
        }

        #expect(throws: ResidualDescriptorTestInterruption.stop) {
            _ = try fileSystem.replaceFile(
                temporaryName: "temp",
                destinationName: "target",
                in: [],
                expectedDestination: .exact(expected),
                hook: hook
            )
        }
        #expect(try Data(contentsOf: root.appendingPathComponent("target")) == newBytes)
        #expect(try Data(contentsOf: root.appendingPathComponent("temp")) == oldBytes)
    }

    @Test("displaced objects become authenticated quarantine and cleanup preserves replacements")
    func displacedObjectQuarantineIsChecked() throws {
        let root = try descriptorRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileSystem = try DescriptorRelativeFileSystem(rootURL: root)
        let oldBytes = Data("old".utf8)
        let newBytes = Data("new".utf8)
        try fileSystem.writeExclusive(oldBytes, named: "target", in: [], mode: 0o600)
        try fileSystem.writeExclusive(newBytes, named: "temp", in: [], mode: 0o600)
        let expected = try fileSystem.entryIdentity(named: "target", in: [])
        let replacement = try #require(
            try fileSystem.replaceFile(
                temporaryName: "temp",
                destinationName: "target",
                in: [],
                expectedDestination: .exact(expected)
            )
        )
        #expect(replacement.identity == expected)
        try fileSystem.quarantineNamespaceReplacement(replacement, hook: .none)
        #expect(try Data(contentsOf: root.appendingPathComponent("target")) == newBytes)
        #expect(
            try Data(contentsOf: root.appendingPathComponent(replacement.quarantineName))
                == oldBytes
        )

        let secondRoot = try descriptorRoot()
        defer { try? FileManager.default.removeItem(at: secondRoot) }
        let secondFileSystem = try DescriptorRelativeFileSystem(rootURL: secondRoot)
        try secondFileSystem.writeExclusive(oldBytes, named: "target", in: [], mode: 0o600)
        try secondFileSystem.writeExclusive(newBytes, named: "temp", in: [], mode: 0o600)
        let secondExpected = try secondFileSystem.entryIdentity(named: "target", in: [])
        let secondReplacement = try #require(
            try secondFileSystem.replaceFile(
                temporaryName: "temp",
                destinationName: "target",
                in: [],
                expectedDestination: .exact(secondExpected)
            )
        )
        try FileManager.default.removeItem(at: secondRoot.appendingPathComponent("temp"))
        let unrelated = Data("unrelated-owner".utf8)
        try unrelated.write(to: secondRoot.appendingPathComponent("temp"))
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: secondRoot.appendingPathComponent("temp").path
        )
        #expect(throws: PersistenceError.integrityViolation) {
            try secondFileSystem.quarantineNamespaceReplacement(secondReplacement, hook: .none)
        }
        #expect(try Data(contentsOf: secondRoot.appendingPathComponent("temp")) == unrelated)
        #expect(!FileManager.default.fileExists(
            atPath: secondRoot.appendingPathComponent(secondReplacement.quarantineName).path
        ))
    }

    @Test("special entries are rejected through nonblocking preflight")
    func rejectsFIFOWithoutBlocking() throws {
        let root = try descriptorRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fifo = root.appendingPathComponent("fifo")
        #expect(mkfifo(fifo.path, 0o600) == 0)
        let fileSystem = try DescriptorRelativeFileSystem(rootURL: root)
        #expect(throws: PersistenceError.integrityViolation) {
            try fileSystem.readFile(named: "fifo", in: [])
        }
    }

    @Test("directory mode and ancestry edges are checked on every reopen")
    func validatesExactDirectoryMode() throws {
        let root = try descriptorRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("secure"),
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o755]
        )
        let fileSystem = try DescriptorRelativeFileSystem(rootURL: root)
        #expect(throws: PersistenceError.integrityViolation) {
            try fileSystem.openDirectory(["secure"], requiredMode: 0o700)
        }
    }

    @Test("checked unlink preserves a replacement with a different identity")
    func cleanupUsesEntryCAS() throws {
        let root = try descriptorRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileSystem = try DescriptorRelativeFileSystem(rootURL: root)
        try fileSystem.writeExclusive(Data("owned".utf8), named: "temporary", in: [], mode: 0o600)
        let expected = try fileSystem.entryIdentity(named: "temporary", in: [])
        try FileManager.default.removeItem(at: root.appendingPathComponent("temporary"))
        let replacement = Data("replacement".utf8)
        try replacement.write(to: root.appendingPathComponent("temporary"))
        #expect(throws: PersistenceError.integrityViolation) {
            try fileSystem.removeExpectedFile(
                named: "temporary",
                in: [],
                expectedIdentity: expected
            )
        }
        #expect(try Data(contentsOf: root.appendingPathComponent("temporary")) == replacement)
    }
}

private func descriptorRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ifl-descriptor-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    return root
}

private enum ResidualDescriptorTestInterruption: Error, Equatable {
    case stop
}
