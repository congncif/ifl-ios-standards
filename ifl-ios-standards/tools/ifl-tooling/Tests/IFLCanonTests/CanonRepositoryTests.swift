import Darwin
import Foundation
@testable import IFLCanon
import IFLContracts
import Testing

@Suite("CanonRepositoryTests", .serialized)
struct CanonRepositoryTests {
    @Test("snapshot content policy v1 has the exact activation exclusion")
    func exactSnapshotContentPolicy() {
        #expect(CanonSnapshotContentPolicy.currentSchemaVersion == 1)
        #expect(CanonSnapshotContentPolicy.excludedRoots == ["activations"])
    }

    @Test("positive minimal loads index-first into one immutable digest-bound snapshot")
    func positiveMinimalSnapshot() throws {
        let repository: any CanonRepository = FileCanonRepository(
            root: CanonRepositoryFixture.positiveRoot
        )
        let snapshot = try repository.snapshot(
            profiles: [CanonRepositoryFixture.coreProfileID()]
        )
        assertSendable(snapshot)

        #expect(snapshot.canonVersion == 1)
        #expect(snapshot.rules.map(\.id.rawValue) == ["CAN-MINIMAL-001"])
        #expect(snapshot.profiles.map(\.id.rawValue) == ["core"])
        #expect(snapshot.adrs.map(\.id.rawValue) == ["ADR-9999"])
        #expect(snapshot.chapters.isEmpty)
        #expect(snapshot.derivedArtifacts.isEmpty)
        #expect(
            snapshot.requirementRegistry.requirements.map(\.id.rawValue)
                == Self.expectedRequirementIDs
        )

        #expect(
            try canonicalFileDigest(snapshot.rules[0])
                == "963e5f02faf0df9d688ed21a982a6b70173b43b7a7ae916d0f70772f787e78c2"
        )
        #expect(
            try canonicalFileDigest(snapshot.profiles[0])
                == "20f1a41e951bcd3b199b1a2794bc3b79342718b876617b35364feb292c156e80"
        )
        #expect(
            try canonicalFileDigest(snapshot.adrs[0])
                == "60ef1231ab1f7ff50bf6c3d3c2edf1d174a6a50ba7eb1abf798e78cf35cac829"
        )
        #expect(
            try canonicalFileDigest(snapshot.requirementRegistry)
                == "ef2e346a91e5bb3586643d336670b192bac8d27bc49aeb5e4fc64faca3a1e647"
        )
    }

    @Test("snapshot projection excludes exactly the activation subtree")
    func snapshotDigestProjection() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            let baseline = try snapshot(root: root)
            let fullInventory = try CanonicalTreeScanner().scan(
                root: root,
                policy: CanonicalTreePolicy(excludedRoots: [])
            )
            let projection = try CanonSnapshotContentPolicy.project(fullInventory)
            let projectionDigest = try CanonicalTreeDigest.digest(projection)
            #expect(
                projection.policy.schemaVersion
                    == CanonSnapshotContentPolicy.currentSchemaVersion
            )
            #expect(projection.policy.excludedRoots == CanonSnapshotContentPolicy.excludedRoots)
            #expect(baseline.snapshotContentDigest == projectionDigest)

            let activations = root.appendingPathComponent("activations", isDirectory: true)
            try FileManager.default.createDirectory(
                at: activations,
                withIntermediateDirectories: false
            )
            try CanonRepositoryFixture.setPermissions(0o755, at: activations)
            let activation = activations.appendingPathComponent("receipt.json")
            try Data("{}\n".utf8).write(to: activation)
            try CanonRepositoryFixture.setPermissions(0o644, at: activation)
            let withActivation = try snapshot(root: root)
            #expect(withActivation.snapshotContentDigest == baseline.snapshotContentDigest)

            let other = root.appendingPathComponent("unindexed.txt")
            try Data("bound content\n".utf8).write(to: other)
            try CanonRepositoryFixture.setPermissions(0o644, at: other)
            let withOtherContent = try snapshot(root: root)
            #expect(withOtherContent.snapshotContentDigest != baseline.snapshotContentDigest)
        }
    }

    @Test("all inherited profile IDs are validated before either selection mode")
    func inheritedProfileValidationIsCompleteAndDeterministic() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try CanonRepositoryFixture.mutateObject(
                at: "profiles/minimal.profile.json",
                in: root
            ) { profile in
                profile["inherits_profile_ids"] = ["a-missing", "z-missing"]
            }
            try CanonRepositoryFixture.updateRecordDigest(
                for: "profiles/minimal.profile.json",
                in: "profiles.index.json",
                root: root
            )
            let repository = FileCanonRepository(root: root)
            let emptySelectionError = CanonRepositoryFixture.contractError {
                _ = try repository.snapshot(profiles: [])
            }
            let explicitSelectionError = CanonRepositoryFixture.contractError {
                _ = try repository.snapshot(
                    profiles: [CanonRepositoryFixture.coreProfileID()]
                )
            }

            #expect(emptySelectionError == explicitSelectionError)
            #expect(
                emptySelectionError == .unresolvedReference(
                    kind: "inherited profile",
                    id: "a-missing"
                )
            )
        }
    }

    @Test("ADR sidecar remains digest-bound while extra contained Markdown references are allowed")
    func adrAllowsAdditionalMarkdownReferences() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            let extraReference = root.appendingPathComponent("adrs/context.md")
            try Data("# Additional context\n".utf8).write(to: extraReference)
            try CanonRepositoryFixture.setPermissions(0o644, at: extraReference)
            try CanonRepositoryFixture.mutateObject(
                at: "adrs/ADR-9999-minimal-test.json",
                in: root
            ) { adr in
                adr["reference_artifact_ids"] = [
                    "adrs/ADR-9999-minimal-test.md",
                    "adrs/context.md",
                ]
            }
            try CanonRepositoryFixture.updateRecordDigest(
                for: "adrs/ADR-9999-minimal-test.json",
                in: "adrs.index.json",
                root: root
            )

            let loaded = try snapshot(root: root)
            #expect(loaded.adrs[0].referenceArtifactIDs.count == 2)
            #expect(loaded.adrMarkdownByID[loaded.adrs[0].id]?.hasPrefix("# ADR-9999") == true)
        }
    }

    @Test("ADR sidecar bytes remain bound to markdown_digest")
    func adrSidecarDigestIsEnforced() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            let sidecar = root.appendingPathComponent("adrs/ADR-9999-minimal-test.md")
            var data = try Data(contentsOf: sidecar)
            data.append(contentsOf: Data("Tampered.\n".utf8))
            try data.write(to: sidecar, options: .atomic)
            try CanonRepositoryFixture.setPermissions(0o644, at: sidecar)

            let error = CanonRepositoryFixture.contractError {
                _ = try snapshot(root: root)
            }
            #expect(error?.code == "digest_mismatch")
        }
    }

    @Test("requesting a profile absent from the profile index fails closed")
    func missingRequestedProfileFails() throws {
        let repository: any CanonRepository = FileCanonRepository(
            root: CanonRepositoryFixture.positiveRoot
        )
        let missingProfile = try ProfileID(validating: "missing-profile")
        let error = CanonRepositoryFixture.contractError {
            _ = try repository.snapshot(profiles: [missingProfile])
        }
        #expect(error?.code == "unresolved_reference")
    }

    @Test("every non-empty record index enforces its referenced file digest")
    func indexedRecordDigestMismatchMatrix() throws {
        let cases = [
            DigestTamperCase(
                relativePath: "rules/core/minimal.rules.json",
                expected: "The minimal Canon fixture must remain deterministic.",
                replacement: "The minimal Canon fixture was tampered."
            ),
            DigestTamperCase(
                relativePath: "profiles/minimal.profile.json",
                expected: "Minimal profile for deterministic Canon contract tests.",
                replacement: "Tampered profile for deterministic Canon contract tests."
            ),
            DigestTamperCase(
                relativePath: "adrs/ADR-9999-minimal-test.json",
                expected: "Minimal Canon Fixture",
                replacement: "Tampered Canon Fixture"
            ),
        ]

        for testCase in cases {
            try CanonRepositoryFixture.withPositiveRoot { root in
                let url = root.appendingPathComponent(testCase.relativePath)
                let source = try String(decoding: Data(contentsOf: url), as: UTF8.self)
                let range = try #require(source.range(of: testCase.expected))
                let updated = source.replacingCharacters(in: range, with: testCase.replacement)
                try Data(updated.utf8).write(to: url, options: .atomic)
                try CanonRepositoryFixture.setPermissions(0o644, at: url)

                let error = CanonRepositoryFixture.contractError {
                    _ = try snapshot(root: root)
                }
                #expect(
                    error?.code == "digest_mismatch",
                    "\(testCase.relativePath) must remain bound to its index digest"
                )
            }
        }
    }

    @Test("a valid unindexed decoy cannot replace the missing indexed target")
    func missingIndexedTargetDoesNotFallBackToRecursiveDiscovery() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            let indexedRule = root.appendingPathComponent("rules/core/minimal.rules.json")
            let unindexedDecoy = root.appendingPathComponent("rules/core/decoy.rules.json")
            try FileManager.default.moveItem(at: indexedRule, to: unindexedDecoy)

            let error = CanonRepositoryFixture.contractError {
                _ = try snapshot(root: root)
            }
            #expect(error != nil)
        }
    }

    @Test("the anchored repository matches the public URL repository")
    func anchoredRepositoryParity() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            let publicSnapshot = try FileCanonRepository(root: root).snapshot(
                profiles: [CanonRepositoryFixture.coreProfileID()]
            )
            let anchoredSnapshot = try anchoredRepository(root: root).snapshot(
                profiles: [CanonRepositoryFixture.coreProfileID()]
            )

            #expect(anchoredSnapshot.canonVersion == publicSnapshot.canonVersion)
            #expect(anchoredSnapshot.rules.map(\.id) == publicSnapshot.rules.map(\.id))
            #expect(anchoredSnapshot.profiles.map(\.id) == publicSnapshot.profiles.map(\.id))
            #expect(anchoredSnapshot.selectedProfileIDs == publicSnapshot.selectedProfileIDs)
            #expect(anchoredSnapshot.adrs.map(\.id) == publicSnapshot.adrs.map(\.id))
            #expect(anchoredSnapshot.snapshotContentDigest == publicSnapshot.snapshotContentDigest)
        }
    }

    @Test("an anchored repository owns the anchor beyond temporary construction")
    func repositoryOwnsAnchorLifetime() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            let repository = try anchoredRepository(root: root)

            for _ in 0 ..< 3 {
                let snapshot = try repository.snapshot(
                    profiles: [CanonRepositoryFixture.coreProfileID()]
                )
                #expect(snapshot.canonVersion == 1)
            }
        }
    }

    @Test("concurrent anchored snapshots own independent descriptor lifetimes")
    func concurrentAnchoredSnapshots() async throws {
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("ifl-concurrent-anchor-\(UUID().uuidString)")
        let root = workspace.appendingPathComponent("canon")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: workspace) }
        try FileManager.default.copyItem(at: CanonRepositoryFixture.positiveRoot, to: root)

        let expected = try anchoredRepository(root: root).snapshot(
            profiles: [CanonRepositoryFixture.coreProfileID()]
        ).snapshotContentDigest

        let overlap = SnapshotReadOverlapBarrier(participants: 2)
        let repository = try anchoredRepository(root: root) { event in
            if event == .willOpenFile("VERSION") {
                try overlap.arriveAndWait()
            }
        }
        let outcomes = SnapshotOutcomeStore()
        let group = DispatchGroup()
        let queues = [
            DispatchQueue(label: "CanonRepositoryTests.snapshot.first"),
            DispatchQueue(label: "CanonRepositoryTests.snapshot.second"),
        ]
        for queue in queues {
            group.enter()
            queue.async {
                defer { group.leave() }
                do {
                    try outcomes.record(digest: repository.snapshot(
                        profiles: [CanonRepositoryFixture.coreProfileID()]
                    ).snapshotContentDigest)
                } catch {
                    overlap.abort()
                    outcomes.record(error: error)
                }
            }
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            group.notify(queue: .global()) {
                continuation.resume()
            }
        }

        #expect(overlap.arrivalCount == 2)
        #expect(overlap.wasAborted == false)
        #expect(outcomes.errors.isEmpty)
        #expect(outcomes.digests.count == 2)
        #expect(outcomes.digests.allSatisfy { $0 == expected })

        let reused = try repository.snapshot(
            profiles: [CanonRepositoryFixture.coreProfileID()]
        ).snapshotContentDigest
        #expect(reused == expected)
        #expect(overlap.arrivalCount == 3)
    }

    private static let expectedRequirementIDs = [
        "ENT-ACCESSIBILITY", "ENT-CONCURRENCY", "ENT-DATA", "ENT-OBSERVABILITY",
        "ENT-PERFORMANCE", "ENT-PRIVACY", "ENT-SECURITY", "ENT-SUPPLY", "ENT-SWIFTUI",
        "ENT-TESTING", "P0-1", "P0-2", "P0-3", "P0-4", "P0-5", "P0-6", "P0-7",
        "REQ-AGENTS", "REQ-BOARDY", "REQ-CANON", "REQ-CONVERGENCE", "REQ-EFFECTS",
        "REQ-MIGRATION", "REQ-RC", "REQ-RUNTIME", "REQ-VERIFY",
    ]

    private func snapshot(root: URL) throws -> CanonSnapshot {
        try FileCanonRepository(root: root).snapshot(
            profiles: [CanonRepositoryFixture.coreProfileID()]
        )
    }

    private func canonicalFileDigest(_ value: some Encodable) throws -> String {
        var data = try CanonicalJSON.encode(value)
        data.append(0x0A)
        return CanonicalTreeDigest.sha256(data).rawValue
    }

    private func anchoredRepository(
        root: URL,
        readEventHandler: @escaping CanonRepositoryReadEventHandler = { _ in }
    ) throws -> FileCanonRepository {
        let descriptor = root.path.withCString {
            Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        try #require(descriptor >= 0)
        defer { Darwin.close(descriptor) }
        let anchor = try CanonRootAnchor(
            duplicatingRootDirectoryDescriptor: descriptor,
            path: root.path
        )
        return FileCanonRepository(
            anchor: anchor,
            readEventHandler: readEventHandler
        )
    }
}

private struct DigestTamperCase {
    let relativePath: String
    let expected: String
    let replacement: String
}

private func assertSendable(_ value: some Sendable) {
    _ = value
}

private final class SnapshotReadOverlapBarrier: @unchecked Sendable {
    private let condition = NSCondition()
    private let participants: Int
    private var arrivals = 0
    private var aborted = false

    init(participants: Int) {
        self.participants = participants
    }

    var arrivalCount: Int {
        condition.lock()
        defer { condition.unlock() }
        return arrivals
    }

    var wasAborted: Bool {
        condition.lock()
        defer { condition.unlock() }
        return aborted
    }

    func arriveAndWait() throws {
        condition.lock()
        defer { condition.unlock() }
        guard !aborted else {
            throw SnapshotReadOverlapError.aborted
        }
        arrivals += 1
        condition.broadcast()
        let deadline = Date().addingTimeInterval(5)
        while arrivals < participants, !aborted {
            guard condition.wait(until: deadline) else {
                aborted = true
                condition.broadcast()
                throw SnapshotReadOverlapError.timedOut
            }
        }
        guard !aborted else {
            throw SnapshotReadOverlapError.aborted
        }
    }

    func abort() {
        condition.lock()
        aborted = true
        condition.broadcast()
        condition.unlock()
    }
}

private enum SnapshotReadOverlapError: Error {
    case aborted
    case timedOut
}

private final class SnapshotOutcomeStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storedDigests: [HashDigest] = []
    private var storedErrors: [String] = []

    var digests: [HashDigest] {
        lock.lock()
        defer { lock.unlock() }
        return storedDigests
    }

    var errors: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedErrors
    }

    func record(digest: HashDigest) {
        lock.lock()
        storedDigests.append(digest)
        lock.unlock()
    }

    func record(error: any Error) {
        lock.lock()
        storedErrors.append(String(describing: error))
        lock.unlock()
    }
}
