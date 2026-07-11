import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("RunPathTests")
struct RunPathTests {
    @Test("first run creates every missing ancestor and lowercase UUID beneath the work item")
    func createsRunTreeDurably() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ifl-run-paths-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let trace = TestBarrierTrace()
        let runID = RunID(rawValue: UUID())
        let paths = try RunPaths.prepareForTesting(
            workItemRoot: root,
            runID: runID,
            barrier: TestDurabilityBarrier(trace: trace)
        )

        #expect(paths.runRoot.path.hasSuffix(
            "artifacts/workflow/runs/\(runID.filesystemComponent)"
        ))
        #expect(paths.runRoot.lastPathComponent == paths.runRoot.lastPathComponent.lowercased())
        #expect(FileManager.default.fileExists(atPath: paths.runRoot.path))
        #expect(FileManager.default.fileExists(atPath: paths.durabilityAnchorURL.path))
        #expect(FileManager.default.fileExists(atPath: paths.identityRecordURL.path))
        #expect(FileManager.default.fileExists(atPath: paths.lockURL.path))
        #expect(paths.eventLogURL.lastPathComponent == "events.ndjson")
        #expect(trace.plans.count >= 5)
    }

    @Test("receipt paths derive only from validated kind and ID values")
    func validatesReceiptComponents() throws {
        #expect(throws: PersistenceError.invalidPathComponent) {
            try ReceiptKind(validating: "../review")
        }
        #expect(throws: PersistenceError.invalidPathComponent) {
            try ReceiptID(validating: "review/one")
        }
        #expect(throws: PersistenceError.invalidPathComponent) {
            try TransactionID(rawValue: ".")
        }
        #expect(throws: PersistenceError.invalidPathComponent) {
            try ReceiptKind(validating: "Verification")
        }
        #expect(throws: PersistenceError.invalidPathComponent) {
            try ReceiptID(validating: "Gate-02.3")
        }
    }

    @Test("a symlinked ancestor fails closed without creating anything outside the work item")
    func rejectsSymlinkAncestor() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("ifl-run-symlink-\(UUID().uuidString)", isDirectory: true)
        let workItem = base.appendingPathComponent("work-item", isDirectory: true)
        let outside = base.appendingPathComponent("outside", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: workItem, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: workItem.appendingPathComponent("artifacts"),
            withDestinationURL: outside
        )

        #expect(throws: PersistenceError.integrityViolation) {
            try RunPaths.prepareForTesting(
                workItemRoot: workItem,
                runID: RunID(rawValue: UUID()),
                barrier: TestDurabilityBarrier(trace: TestBarrierTrace())
            )
        }
        #expect(!FileManager.default.fileExists(atPath: outside.appendingPathComponent("workflow").path))
    }

    @Test("a run-root identity swap after bootstrap is rejected even with a copied anchor")
    func rejectsRunRootIdentitySwap() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        let displaced = harness.paths.runRoot
            .deletingLastPathComponent()
            .appendingPathComponent("displaced-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.moveItem(at: harness.paths.runRoot, to: displaced)
        try FileManager.default.createDirectory(
            at: harness.paths.runRoot,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        try Data("ifl-workflow-durability-anchor-v1\n".utf8).write(
            to: harness.paths.durabilityAnchorURL
        )
        #expect(throws: PersistenceError.integrityViolation) {
            try FileRunStateStore.testing(
                paths: harness.paths,
                barrier: TestDurabilityBarrier(trace: TestBarrierTrace()),
                clock: { harness.now }
            )
        }
    }

    @Test("a retained bootstrap chain rejects ancestor substitution between component barriers")
    func rejectsInterBarrierAncestorSubstitution() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ifl-bootstrap-chain-\(UUID().uuidString)", isDirectory: true)
        let displaced = root.deletingLastPathComponent().appendingPathComponent(
            "ifl-displaced-artifacts-\(UUID().uuidString)",
            isDirectory: true
        )
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: displaced)
        }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let artifacts = root.appendingPathComponent("artifacts", isDirectory: true)

        #expect(throws: PersistenceError.integrityViolation) {
            try RunPaths.prepareForTesting(
                workItemRoot: root,
                runID: RunID(rawValue: UUID()),
                barrier: TestDurabilityBarrier(trace: TestBarrierTrace()),
                bootstrapHook: { completedComponents in
                    guard completedComponents == 1 else { return }
                    try FileManager.default.moveItem(at: artifacts, to: displaced)
                    try FileManager.default.createDirectory(
                        at: artifacts,
                        withIntermediateDirectories: false,
                        attributes: [.posixPermissions: 0o700]
                    )
                }
            )
        }
        #expect(FileManager.default.fileExists(atPath: displaced.path))
        #expect(!FileManager.default.fileExists(
            atPath: artifacts.appendingPathComponent("workflow").path
        ))
    }

    @Test("durable run identity is singular across reopen and rejects a copied-root rebase")
    func persistentRunIdentityCannotRebase() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ifl-run-reopen-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let runID = RunID(rawValue: UUID())
        let barrier = TestDurabilityBarrier(trace: TestBarrierTrace())
        let first = try RunPaths.prepareForTesting(
            workItemRoot: root,
            runID: runID,
            barrier: barrier
        )
        let reopened = try RunPaths.prepareForTesting(
            workItemRoot: root,
            runID: runID,
            barrier: barrier
        )
        #expect(reopened.runIdentityDigest == first.runIdentityDigest)

        let displaced = first.runRoot.deletingLastPathComponent()
            .appendingPathComponent("displaced-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.moveItem(at: first.runRoot, to: displaced)
        try FileManager.default.copyItem(at: displaced, to: first.runRoot)
        #expect(throws: PersistenceError.integrityViolation) {
            try RunPaths.prepareForTesting(
                workItemRoot: root,
                runID: runID,
                barrier: barrier
            )
        }
    }

    @Test("wrong run/receipt modes and a replaced immutable lock identity fail closed")
    func rejectsModeAndLockRebase() throws {
        let modeHarness = try PersistenceHarness.make()
        defer { modeHarness.remove() }
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: modeHarness.paths.runRoot.path
        )
        #expect(throws: PersistenceError.integrityViolation) {
            try modeHarness.makeStore()
        }

        let receiptHarness = try PersistenceHarness.make()
        defer { receiptHarness.remove() }
        try FileManager.default.createDirectory(
            at: receiptHarness.paths.receiptsRootURL,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o755]
        )
        #expect(throws: PersistenceError.integrityViolation) {
            try receiptHarness.makeStore().commit(
                receiptHarness.transaction,
                lease: receiptHarness.lease
            )
        }

        let lockHarness = try PersistenceHarness.make()
        defer { lockHarness.remove() }
        try FileManager.default.removeItem(at: lockHarness.paths.lockURL)
        try Data("replacement-lock".utf8).write(to: lockHarness.paths.lockURL)
        #expect(throws: PersistenceError.integrityViolation) {
            try lockHarness.makeStore()
        }
    }

    @Test("bootstrap interruption resumes only the exact retained component identities")
    func bootstrapIsRestartable() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ifl-bootstrap-restart-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let runID = RunID(rawValue: UUID())
        let trace = TestBarrierTrace()
        #expect(throws: ResidualPersistenceTestInterruption.stop) {
            try RunPaths.prepareForTesting(
                workItemRoot: root,
                runID: runID,
                barrier: TestDurabilityBarrier(trace: trace),
                bootstrapHook: { completedComponents in
                    if completedComponents == 1 {
                        throw ResidualPersistenceTestInterruption.stop
                    }
                }
            )
        }
        let artifactsURL = root.appendingPathComponent("artifacts", isDirectory: true)
        let retainedInode = try #require(
            FileManager.default.attributesOfItem(atPath: artifactsURL.path)[.systemFileNumber]
                as? NSNumber
        ).uint64Value
        trace.reset()
        let recovered = try RunPaths.prepareForTesting(
            workItemRoot: root,
            runID: runID,
            barrier: TestDurabilityBarrier(trace: trace)
        )
        let reopened = try RunPaths.prepareForTesting(
            workItemRoot: root,
            runID: runID,
            barrier: TestDurabilityBarrier(trace: trace)
        )
        let recoveredInode = try #require(
            FileManager.default.attributesOfItem(atPath: artifactsURL.path)[.systemFileNumber]
                as? NSNumber
        ).uint64Value
        #expect(recoveredInode == retainedInode)
        #expect(recovered.runIdentityDigest == reopened.runIdentityDigest)
    }

    @Test("fixed anchor and lock bytes cannot mint authority for an unproven hierarchy")
    func rejectsPreexistingInfrastructureWithoutBootstrapProvenance() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ifl-unproven-bootstrap-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let runID = RunID(rawValue: UUID())
        var current = root
        for component in ["artifacts", "workflow", "runs", runID.filesystemComponent] {
            current.appendPathComponent(component, isDirectory: true)
            try FileManager.default.createDirectory(
                at: current,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
        }
        let epochs = current.appendingPathComponent("epochs", isDirectory: true)
        try FileManager.default.createDirectory(
            at: epochs,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let anchor = current.appendingPathComponent(".durability-anchor")
        let lock = current.appendingPathComponent("writer.lock")
        try Data("ifl-workflow-durability-anchor-v1\n".utf8).write(to: anchor)
        try Data().write(to: lock)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: anchor.path
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: lock.path
        )

        #expect(throws: PersistenceError.integrityViolation) {
            try RunPaths.prepareForTesting(
                workItemRoot: root,
                runID: runID,
                barrier: TestDurabilityBarrier(trace: TestBarrierTrace())
            )
        }
        #expect(!FileManager.default.fileExists(
            atPath: current.appendingPathComponent(".run-identity.json").path
        ))
    }

    @Test("the immutable lock identity remains held for the entire scoped critical section")
    func lockLifetimeIsScoped() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        let fileSystem = try DescriptorRelativeFileSystem(rootURL: harness.paths.runRoot)
        let first = try FileLock.acquire(
            in: fileSystem,
            expectedIdentity: harness.paths.lockIdentity
        )
        _ = withExtendedLifetime(first) {
            #expect(throws: PersistenceError.blockedEnvironment) {
                try FileLock.acquire(
                    in: fileSystem,
                    expectedIdentity: harness.paths.lockIdentity
                )
            }
        }
    }
}

private enum ResidualPersistenceTestInterruption: Error, Equatable {
    case stop
}
