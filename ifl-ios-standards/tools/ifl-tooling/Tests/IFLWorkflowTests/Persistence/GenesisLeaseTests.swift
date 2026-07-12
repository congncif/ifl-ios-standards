import Dispatch
import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("GenesisLeaseTests")
struct GenesisLeaseTests {
    @Test("token one is durable before RunPaths and authorizes the first transaction")
    func leasePrecedesRunBootstrap() throws {
        let genesis = try GenesisLeaseHarness.make()
        defer { genesis.remove() }
        let start: Int64 = 1_800_000_000_000_000
        let store = try LeaseStore.testing(
            workItemRoot: genesis.workItemRoot,
            runID: genesis.runID,
            barrier: TestDurabilityBarrier(trace: genesis.barrierTrace),
            clock: { leaseTestDate(start) }
        )
        #expect(!FileManager.default.fileExists(atPath: genesis.runRoot.path))

        let lease = try store.acquire(LeaseRequest(
            runID: genesis.runID,
            ownerID: "genesis-writer",
            ttlMicroseconds: 1_000_000
        ))
        #expect(lease.fencingToken.rawValue == 1)
        #expect(FileManager.default.fileExists(atPath: genesis.recordURL.path))
        #expect(!FileManager.default.fileExists(atPath: genesis.runRoot.path))
        let lockInode = try genesis.lockInode()

        let paths = try RunPaths.prepareForTesting(
            workItemRoot: genesis.workItemRoot,
            runID: genesis.runID,
            barrier: TestDurabilityBarrier(trace: genesis.barrierTrace)
        )
        let transaction = try makeGenesisTransaction(paths: paths)
        let bound = try LeaseStore.testing(
            paths: paths,
            barrier: TestDurabilityBarrier(trace: genesis.barrierTrace),
            clock: { leaseTestDate(start) }
        )
        let receipt = try bound.commit(transaction, lease: lease)
        #expect(receipt.fencingToken.rawValue == 1)
        #expect(try genesis.lockInode() == lockInode)
        #expect(try bound.load(runID: genesis.runID, from: paths.runRoot).events.count == 1)
    }

    @Test("run bootstrap without token one rejects both lease constructors")
    func runBootstrapCannotPrecedeGenesisLease() throws {
        let genesis = try GenesisLeaseHarness.make()
        defer { genesis.remove() }
        let paths = try RunPaths.prepareForTesting(
            workItemRoot: genesis.workItemRoot,
            runID: genesis.runID,
            barrier: TestDurabilityBarrier(trace: genesis.barrierTrace)
        )
        #expect(throws: PersistenceError.integrityViolation) {
            try LeaseStore.testing(
                paths: paths,
                barrier: TestDurabilityBarrier(trace: genesis.barrierTrace),
                clock: { leaseTestDate(1_800_000_000_000_000) }
            )
        }
        #expect(throws: PersistenceError.integrityViolation) {
            try LeaseStore.testing(
                workItemRoot: genesis.workItemRoot,
                runID: genesis.runID,
                barrier: TestDurabilityBarrier(trace: genesis.barrierTrace),
                clock: { leaseTestDate(1_800_000_000_000_000) }
            )
        }
        #expect(!FileManager.default.fileExists(atPath: genesis.recordURL.path))
    }

    @Test("identical genesis contenders serialize and publish one token-one record")
    func genesisContendersShareStableAuthority() throws {
        let genesis = try GenesisLeaseHarness.make()
        defer { genesis.remove() }
        let start: Int64 = 1_800_000_000_000_000
        let startBarrier = LeaseStartBarrier(parties: 2)
        let group = DispatchGroup()
        let results = LeaseRaceResults()

        for owner in ["genesis-one", "genesis-two"] {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                guard startBarrier.arriveAndWait() else {
                    results.record(error: LeaseTestSynchronizationError.timeout)
                    return
                }
                do {
                    let store = try LeaseStore.testing(
                        workItemRoot: genesis.workItemRoot,
                        runID: genesis.runID,
                        barrier: TestDurabilityBarrier(trace: genesis.barrierTrace),
                        clock: { leaseTestDate(start) }
                    )
                    results.record(lease: try store.acquire(LeaseRequest(
                        runID: genesis.runID,
                        ownerID: owner,
                        ttlMicroseconds: 100
                    )))
                } catch {
                    results.record(error: error)
                }
            }
        }
        #expect(waitForLeaseRace(group))

        let snapshot = results.snapshot()
        #expect(snapshot.leases.count == 1)
        #expect(snapshot.leases.first?.fencingToken.rawValue == 1)
        #expect(snapshot.persistenceErrors == [.blockedEnvironment])
        #expect(snapshot.otherErrorCount == 0)
        #expect(try genesis.lockInode() > 0)
        #expect(FileManager.default.fileExists(atPath: genesis.recordURL.path))
        #expect(!FileManager.default.fileExists(atPath: genesis.pendingURL.path))
    }

    @Test("expired crashed genesis holder recovers to a larger token before bootstrap")
    func crashedGenesisCannotCommitAfterRecovery() throws {
        let genesis = try GenesisLeaseHarness.make()
        defer { genesis.remove() }
        let start: Int64 = 1_800_000_000_000_000
        let clock = LeaseTestClock(leaseTestDate(start))
        let authority = try LeaseStore.testing(
            workItemRoot: genesis.workItemRoot,
            runID: genesis.runID,
            barrier: TestDurabilityBarrier(trace: genesis.barrierTrace),
            clock: { clock.sample() }
        )
        let crashed = try authority.acquire(LeaseRequest(
            runID: genesis.runID,
            ownerID: "crashed-genesis",
            ttlMicroseconds: 10
        ))
        clock.set(leaseTestDate(start + 10))
        let recovered = try authority.recover(LeaseRequest(
            runID: genesis.runID,
            ownerID: "recovery-genesis",
            ttlMicroseconds: 1_000_000
        ))
        #expect(recovered.fencingToken.rawValue == 2)

        let paths = try RunPaths.prepareForTesting(
            workItemRoot: genesis.workItemRoot,
            runID: genesis.runID,
            barrier: TestDurabilityBarrier(trace: genesis.barrierTrace)
        )
        let transaction = try makeGenesisTransaction(paths: paths)
        let bound = try LeaseStore.testing(
            paths: paths,
            barrier: TestDurabilityBarrier(trace: genesis.barrierTrace),
            clock: { clock.sample() }
        )
        #expect(throws: PersistenceError.staleLease) {
            try bound.commit(transaction, lease: crashed)
        }
        #expect(!FileManager.default.fileExists(atPath: paths.journalURL.path))
        #expect(try bound.commit(transaction, lease: recovered).fencingToken.rawValue == 2)
    }

    @Test("lock, record symlink, and hardlink substitution fail closed")
    func namespaceIdentitySubstitutionIsRejected() throws {
        let lockGenesis = try GenesisLeaseHarness.make()
        defer { lockGenesis.remove() }
        let start: Int64 = 1_800_000_000_000_000
        let lockStore = try LeaseStore.testing(
            workItemRoot: lockGenesis.workItemRoot,
            runID: lockGenesis.runID,
            barrier: TestDurabilityBarrier(trace: lockGenesis.barrierTrace),
            clock: { leaseTestDate(start) }
        )
        let lockLease = try lockStore.acquire(LeaseRequest(
            runID: lockGenesis.runID,
            ownerID: "identity-writer",
            ttlMicroseconds: 100
        ))
        let displacedLock = lockGenesis.lockURL.appendingPathExtension("displaced")
        try FileManager.default.moveItem(at: lockGenesis.lockURL, to: displacedLock)
        try Data().write(to: lockGenesis.lockURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: lockGenesis.lockURL.path
        )
        #expect(throws: PersistenceError.integrityViolation) {
            try lockStore.renew(lockLease, ttlMicroseconds: 100)
        }

        let symlinkGenesis = try GenesisLeaseHarness.make()
        defer { symlinkGenesis.remove() }
        let symlinkStore = try LeaseStore.testing(
            workItemRoot: symlinkGenesis.workItemRoot,
            runID: symlinkGenesis.runID,
            barrier: TestDurabilityBarrier(trace: symlinkGenesis.barrierTrace),
            clock: { leaseTestDate(start) }
        )
        let symlinkLease = try symlinkStore.acquire(LeaseRequest(
            runID: symlinkGenesis.runID,
            ownerID: "symlink-writer",
            ttlMicroseconds: 100
        ))
        let displacedRecord = symlinkGenesis.recordURL.appendingPathExtension("displaced")
        try FileManager.default.moveItem(at: symlinkGenesis.recordURL, to: displacedRecord)
        try FileManager.default.createSymbolicLink(
            at: symlinkGenesis.recordURL,
            withDestinationURL: displacedRecord
        )
        #expect(throws: PersistenceError.integrityViolation) {
            try symlinkStore.renew(symlinkLease, ttlMicroseconds: 100)
        }

        let hardlinkGenesis = try GenesisLeaseHarness.make()
        defer { hardlinkGenesis.remove() }
        let hardlinkStore = try LeaseStore.testing(
            workItemRoot: hardlinkGenesis.workItemRoot,
            runID: hardlinkGenesis.runID,
            barrier: TestDurabilityBarrier(trace: hardlinkGenesis.barrierTrace),
            clock: { leaseTestDate(start) }
        )
        let hardlinkLease = try hardlinkStore.acquire(LeaseRequest(
            runID: hardlinkGenesis.runID,
            ownerID: "hardlink-writer",
            ttlMicroseconds: 100
        ))
        try FileManager.default.linkItem(
            at: hardlinkGenesis.recordURL,
            to: hardlinkGenesis.recordURL.appendingPathExtension("alias")
        )
        #expect(throws: PersistenceError.integrityViolation) {
            try hardlinkStore.renew(hardlinkLease, ttlMicroseconds: 100)
        }
    }
}

struct GenesisLeaseHarness: @unchecked Sendable {
    let temporaryRoot: URL
    let workItemRoot: URL
    let runID: RunID
    let barrierTrace: TestBarrierTrace

    static func make() throws -> GenesisLeaseHarness {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ifl-genesis-\(UUID().uuidString)", isDirectory: true)
        let workItemRoot = temporaryRoot.appendingPathComponent("work-item", isDirectory: true)
        try FileManager.default.createDirectory(
            at: workItemRoot,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        return GenesisLeaseHarness(
            temporaryRoot: temporaryRoot,
            workItemRoot: workItemRoot,
            runID: RunID(rawValue: UUID()),
            barrierTrace: TestBarrierTrace()
        )
    }

    var leaseRoot: URL {
        workItemRoot.appendingPathComponent("artifacts/workflow/leases", isDirectory: true)
    }

    var recordURL: URL {
        leaseRoot.appendingPathComponent("\(runID.filesystemComponent).json")
    }

    var pendingURL: URL {
        recordURL.appendingPathExtension("pending")
    }

    var lockURL: URL {
        leaseRoot.appendingPathComponent("\(runID.filesystemComponent).lock")
    }

    var runRoot: URL {
        workItemRoot
            .appendingPathComponent("artifacts/workflow/runs", isDirectory: true)
            .appendingPathComponent(runID.filesystemComponent, isDirectory: true)
    }

    func lockInode() throws -> UInt64 {
        try #require(
            FileManager.default.attributesOfItem(atPath: lockURL.path)[.systemFileNumber]
                as? NSNumber
        ).uint64Value
    }

    func remove() {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }
}

func makeGenesisTransaction(paths: RunPaths) throws -> StateTransaction {
    let initial = try RunState.startEngineering(
        runID: paths.runID,
        workItemID: "IIS-0002",
        mode: .auto,
        canonSnapshotDigest: HashDigest(validating: String(repeating: "a", count: 64))
    )
    let event = try WorkflowEvent(id: "genesis-intake", kind: .intakeRecorded)
    let context = try TransitionContext(
        actorID: ActorID(validating: "genesis-author"),
        principalID: PrincipalID(validating: "genesis-principal"),
        currentEventHead: HashDigest(validating: String(repeating: "b", count: 64)),
        satisfiedGuards: [.intakeRecorded]
    )
    let state = try WorkflowReducer().decide(
        definition: EngineeringWorkflow.definition,
        state: initial,
        event: event,
        context: context
    ).proposedState
    return try StateTransaction(
        id: TransactionID(rawValue: "txn-genesis"),
        runRoot: paths.runRoot,
        expectedStateDigest: nil,
        expectedEventHead: nil,
        state: state,
        event: event,
        receiptWrites: [
            ReceiptTableWrite(
                kind: ReceiptKind(validating: "verification"),
                id: ReceiptID(validating: "genesis-receipt"),
                value: PersistenceReceiptPayload(gate: "G02.5", result: "passed")
            ),
        ]
    )
}
