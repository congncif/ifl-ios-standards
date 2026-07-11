import Darwin
import Foundation
@testable import IFLCanon
import IFLContracts
import Testing

@Suite("CandidateOverlayRetainedSourceTests", .serialized)
struct CandidateOverlayRetainedSourceTests {
    @Test("one retained plugin authority binds complete plugin and Canon evidence")
    func retainedAuthorityBindsCompleteEvidence() throws {
        try withPlugin { plugin in
            let anchor = try retainedAnchor(at: plugin)
            let baseEvidence = try anchor.captureBaseEvidence()
            let repeatedEvidence = try anchor.captureBaseEvidence()
            let canonAnchor = try anchor.canonRootAnchor()
            let snapshot = try FileCanonRepository(anchor: canonAnchor).snapshot(
                profiles: [CanonRepositoryFixture.coreProfileID()]
            )
            let canonEvidence = try #require(snapshot.candidateOverlayEvidence)

            #expect(baseEvidence.inventory.policy.excludedRoots.isEmpty)
            #expect(baseEvidence.inventory.entries.contains {
                $0.relativePath == "standards/canon/VERSION"
            })
            #expect(
                try baseEvidence.inventoryDigest
                    == (CanonicalTreeDigest.digest(baseEvidence.inventory))
            )
            #expect(canonEvidence.fullInventory.policy.excludedRoots.isEmpty)
            #expect(
                try canonEvidence.projectedInventory
                    == (CanonSnapshotContentPolicy.project(canonEvidence.fullInventory))
            )
            #expect(canonEvidence.projectedDigest == snapshot.snapshotContentDigest)
            #expect(canonEvidence.fileBytesByRelativePath["VERSION"] == Data("1\n".utf8))
            #expect(anchor.owns(canonEvidence))
            #expect(repeatedEvidence.inventory == baseEvidence.inventory)
            #expect(repeatedEvidence.inventoryDigest == baseEvidence.inventoryDigest)
        }
    }

    @Test("ordinary and independently retained snapshots cannot borrow candidate authority")
    func unanchoredAndCrossAnchorSnapshotsHaveNoAuthority() throws {
        try withPlugin { plugin in
            let canon = plugin.appendingPathComponent("standards/canon", isDirectory: true)
            let ordinary = try FileCanonRepository(root: canon).snapshot(profiles: [])
            #expect(ordinary.candidateOverlayEvidence == nil)

            let first = try retainedAnchor(at: plugin)
            let second = try retainedAnchor(at: plugin)
            let retained = try FileCanonRepository(
                anchor: first.canonRootAnchor()
            ).snapshot(profiles: [])
            let evidence = try #require(retained.candidateOverlayEvidence)

            #expect(first.owns(evidence))
            #expect(!second.owns(evidence))
        }
    }

    @Test(
        "complete plugin evidence rejects aliases, hardlinks, special nodes, unsafe modes, and caches",
        arguments: RetainedSourceHazard.allCases
    )
    func completePluginHazardMatrix(_ hazard: RetainedSourceHazard) throws {
        try withPlugin { plugin in
            try install(hazard, in: plugin)
            let anchor = try retainedAnchor(at: plugin)

            do {
                _ = try anchor.captureBaseEvidence()
                Issue.record("Expected retained-source hazard to fail")
            } catch let error as CanonDescriptorFailure {
                #expect(error == hazard.expectedFailure)
            } catch {
                Issue.record("Unexpected retained-source error: \(error)")
            }
        }
    }

    @Test("the selected candidate is a fixed sibling below the retained standards directory")
    func fixedCandidateSiblingAndCanonicalID() throws {
        try withPlugin { plugin in
            let candidate = plugin.appendingPathComponent(
                "standards/canon-candidates/enterprise-v1",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: candidate,
                withIntermediateDirectories: true
            )
            try CanonRepositoryFixture.setPermissions(0o755, at: candidate)
            let anchor = try retainedAnchor(at: plugin)
            let overlayID = try CandidateOverlayID(validating: "enterprise-v1")

            let candidateAnchor = try anchor.candidateRootAnchor(overlayID: overlayID)
            #expect(candidateAnchor.path.hasSuffix("standards/canon-candidates/enterprise-v1"))
            #expect(throws: (any Error).self) {
                _ = try CandidateOverlayID(validating: "enterprise-v1/../canon")
            }
            #expect(throws: (any Error).self) {
                _ = try CandidateOverlayID(validating: "Enterprise-v1")
            }
        }
    }

    @Test("a missing selected candidate is a deterministic missing binding")
    func missingCandidateIsBlocked() throws {
        try withPlugin { plugin in
            let anchor = try retainedAnchor(at: plugin)
            let overlayID = try CandidateOverlayID(validating: "enterprise-v1")

            do {
                _ = try anchor.candidateRootAnchor(overlayID: overlayID)
                Issue.record("Expected missing candidate root")
            } catch let error as ContractError {
                #expect(error == .unresolvedReference(
                    kind: "canon file",
                    id: "standards/canon-candidates/enterprise-v1"
                ))
            } catch {
                Issue.record("Unexpected missing-candidate error: \(error)")
            }
        }
    }

    @Test("Canon-as-candidate aliasing is an integrity failure")
    func canonCandidateAliasIsRejected() throws {
        try withPlugin { plugin in
            let candidates = plugin.appendingPathComponent(
                "standards/canon-candidates",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: candidates,
                withIntermediateDirectories: false
            )
            try CanonRepositoryFixture.setPermissions(0o755, at: candidates)
            try FileManager.default.createSymbolicLink(
                at: candidates.appendingPathComponent("enterprise-v1"),
                withDestinationURL: plugin.appendingPathComponent("standards/canon")
            )
            let anchor = try retainedAnchor(at: plugin)

            do {
                _ = try anchor.candidateRootAnchor(
                    overlayID: CandidateOverlayID(validating: "enterprise-v1")
                )
                Issue.record("Expected Canon/candidate alias rejection")
            } catch let error as CanonDescriptorFailure {
                guard case .integrityViolation = error else {
                    Issue.record("Expected integrity failure, got \(error)")
                    return
                }
            } catch {
                Issue.record("Unexpected alias error: \(error)")
            }
        }
    }

    @Test("same-byte Canon object replacement is metadata integrity drift")
    func repositoryMetadataDriftIsNotEqualDigestMismatch() throws {
        try withPlugin { plugin in
            let anchor = try retainedAnchor(at: plugin)
            let mutation = CandidateOverlayMutation {
                let version = plugin.appendingPathComponent("standards/canon/VERSION")
                let replacement = version.deletingLastPathComponent().appendingPathComponent(
                    ".VERSION-replacement"
                )
                try Data("1\n".utf8).write(to: replacement)
                try CanonRepositoryFixture.setPermissions(0o644, at: replacement)
                let result = replacement.path.withCString { source in
                    version.path.withCString { destination in
                        Darwin.rename(source, destination)
                    }
                }
                try #require(result == 0)
            }
            let repository = try FileCanonRepository(
                anchor: anchor.canonRootAnchor(),
                readEventHandler: { event in
                    if event == .willOpenFile("registry/rules.index.json") {
                        try mutation.runOnce()
                    }
                }
            )

            do {
                _ = try repository.snapshot(profiles: [])
                Issue.record("Expected metadata-only Canon replacement rejection")
            } catch let error as CanonDescriptorFailure {
                #expect(error == .integrityViolation(
                    "retained Canon object metadata changed at VERSION"
                ))
            } catch {
                Issue.record("Unexpected Canon drift error: \(error)")
            }
        }
    }
}

enum RetainedSourceHazard: CaseIterable, CustomTestStringConvertible {
    case symlink
    case hardlink
    case fifo
    case unsafeMode
    case packageCache

    var testDescription: String {
        switch self {
        case .symlink: "symlink"
        case .hardlink: "hardlink"
        case .fifo: "fifo"
        case .unsafeMode: "unsafe mode"
        case .packageCache: "package cache"
        }
    }

    var expectedFailure: CanonDescriptorFailure {
        let path = switch self {
        case .symlink: "unsafe-link"
        case .hardlink: "hardlink"
        case .fifo: "unsafe-fifo"
        case .unsafeMode: "standards/canon/VERSION"
        case .packageCache: "nested/.cache"
        }
        let reason = switch self {
        case .packageCache:
            "package-local artifact node is forbidden: \(path)"
        default:
            "\(path) changed or crossed a descriptor-confined file boundary"
        }
        return .integrityViolation(reason)
    }
}

private extension CandidateOverlayRetainedSourceTests {
    func withPlugin<T>(_ body: (URL) throws -> T) throws -> T {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "ifl-candidate-retained-\(UUID().uuidString)",
            isDirectory: true
        )
        let plugin = root.appendingPathComponent("plugin", isDirectory: true)
        let canon = plugin.appendingPathComponent("standards/canon", isDirectory: true)
        try fileManager.createDirectory(
            at: canon.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.copyItem(at: CanonRepositoryFixture.positiveRoot, to: canon)
        try CanonRepositoryFixture.setPermissions(0o755, at: plugin)
        try CanonRepositoryFixture.setPermissions(
            0o755,
            at: plugin.appendingPathComponent("standards", isDirectory: true)
        )
        defer { try? fileManager.removeItem(at: root) }
        return try body(plugin)
    }

    func retainedAnchor(at plugin: URL) throws -> RetainedPluginRootAnchor {
        let descriptor = plugin.path.withCString {
            Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        try #require(descriptor >= 0)
        defer { Darwin.close(descriptor) }
        return try RetainedPluginRootAnchor(
            duplicatingPluginRootDirectoryDescriptor: descriptor,
            path: plugin.path
        )
    }

    func install(_ hazard: RetainedSourceHazard, in plugin: URL) throws {
        let fileManager = FileManager.default
        let version = plugin.appendingPathComponent("standards/canon/VERSION")
        switch hazard {
        case .symlink:
            let outside = plugin.deletingLastPathComponent().appendingPathComponent("outside")
            try Data("outside\n".utf8).write(to: outside)
            try fileManager.createSymbolicLink(
                at: plugin.appendingPathComponent("unsafe-link"),
                withDestinationURL: outside
            )
        case .hardlink:
            let result = version.path.withCString { source in
                plugin.appendingPathComponent("hardlink").path.withCString { target in
                    Darwin.link(source, target)
                }
            }
            try #require(result == 0)
        case .fifo:
            let result = plugin.appendingPathComponent("unsafe-fifo").path.withCString {
                Darwin.mkfifo($0, 0o600)
            }
            try #require(result == 0)
        case .unsafeMode:
            let result = version.path.withCString { Darwin.chmod($0, 0o4644) }
            try #require(result == 0)
        case .packageCache:
            try fileManager.createDirectory(
                at: plugin.appendingPathComponent("nested/.cache"),
                withIntermediateDirectories: true
            )
        }
    }
}
