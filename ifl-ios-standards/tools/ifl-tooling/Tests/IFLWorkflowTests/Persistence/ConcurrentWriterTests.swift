import Dispatch
import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("ConcurrentWriterTests")
struct ConcurrentWriterTests {
    @Test("contending acquisitions serialize on one stable lock inode")
    func acquisitionRaceUsesOneLock() throws {
        let harness = try GenesisLeaseHarness.make()
        defer { harness.remove() }
        let nowMicros: Int64 = 1_800_000_000_000_000
        let start = LeaseStartBarrier(parties: 2)
        let group = DispatchGroup()
        let results = LeaseRaceResults()
        let runID = harness.runID

        for owner in ["racer-one", "racer-two"] {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                guard start.arriveAndWait() else {
                    results.record(error: LeaseTestSynchronizationError.timeout)
                    return
                }
                do {
                    let store = try LeaseStore.testing(
                        workItemRoot: harness.workItemRoot,
                        runID: runID,
                        barrier: TestDurabilityBarrier(trace: harness.barrierTrace),
                        clock: { leaseTestDate(nowMicros) }
                    )
                    results.record(lease: try store.acquire(LeaseRequest(
                        runID: runID,
                        ownerID: owner,
                        ttlMicroseconds: 1_000_000
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
        #expect(try leaseLockInode(harness) > 0)
        #expect(FileManager.default.fileExists(atPath: leaseRecordURL(harness).path))
        #expect(!FileManager.default.fileExists(atPath: leasePendingURL(harness).path))
    }

    @Test("stale and current writers race without a split state or reverse lock order")
    func currentWriterWinsCommitRace() throws {
        let harness = try FencedPersistenceHarness.make(
            ownerID: "stale-writer",
            ttlMicroseconds: 10
        )
        defer { harness.remove() }
        let startMicros: Int64 = 1_800_000_000_000_000
        let clock = LeaseTestClock(leaseTestDate(startMicros))
        let authority = try LeaseStore.testing(
            paths: harness.paths,
            barrier: TestDurabilityBarrier(trace: harness.barrierTrace),
            clock: { clock.sample() }
        )
        let stale = harness.initialLease
        clock.set(leaseTestDate(startMicros + 10))
        let current = try authority.recover(LeaseRequest(
            runID: harness.runID,
            ownerID: "current-writer",
            ttlMicroseconds: 1_000_000
        ))
        let staleStore = try LeaseStore.testing(
            paths: harness.paths,
            barrier: TestDurabilityBarrier(trace: harness.barrierTrace),
            clock: { clock.sample() }
        )
        let phase = LeaseWriterPhaseGate()
        let currentStore = try LeaseStore.testing(
            paths: harness.paths,
            barrier: TestDurabilityBarrier(trace: harness.barrierTrace),
            clock: { clock.sample() },
            rawFaultInjector: PersistenceFaultInjector { point in
                if point == .lockAcquired {
                    try phase.holdWriterLock()
                }
            }
        )
        let group = DispatchGroup()
        let results = LeaseRaceResults()
        let transaction = harness.transaction

        group.enter()
        DispatchQueue.global().async {
            defer { group.leave() }
            do {
                results.record(receipt: try currentStore.commit(transaction, lease: current))
            } catch {
                results.record(error: error)
            }
        }
        #expect(phase.waitUntilWriterLocked())
        group.enter()
        DispatchQueue.global().async {
            defer { group.leave() }
            phase.markStaleStarted()
            do {
                results.record(receipt: try staleStore.commit(transaction, lease: stale))
            } catch {
                results.record(error: error)
            }
        }
        #expect(phase.waitUntilStaleStarted())
        phase.releaseWriter()
        #expect(waitForLeaseRace(group))

        let snapshot = results.snapshot()
        #expect(snapshot.receipts.count == 1)
        #expect(snapshot.receipts.first?.fencingToken == current.fencingToken)
        #expect(snapshot.persistenceErrors == [.staleLease])
        #expect(snapshot.otherErrorCount == 0)
        let persisted = try currentStore.load(
            runID: harness.runID,
            from: harness.paths.runRoot
        )
        #expect(persisted.events.count == 1)
        #expect(persisted.events.last?.fencingToken == current.fencingToken)
        #expect(try Data(contentsOf: leaseRecordURL(harness)) == activeLeaseRecordBytes(
            runID: harness.runID,
            ownerID: current.ownerID,
            token: current.fencingToken.rawValue,
            issuedMicros: startMicros + 10,
            expiresMicros: startMicros + 1_000_010
        ))
    }

    @Test("crash-left fixed pending files are discarded according to rename order")
    func pendingCrashOrderIsDeterministic() throws {
        let beforeRename = try GenesisLeaseHarness.make()
        defer { beforeRename.remove() }
        let nowMicros: Int64 = 1_800_000_000_000_000
        let pendingInjector = LeaseStoreFaultInjector { point in
            if point == .afterPendingBarrier {
                throw LeaseStoreInterruption.injected(point)
            }
        }
        let interrupted = try LeaseStore.testing(
            workItemRoot: beforeRename.workItemRoot,
            runID: beforeRename.runID,
            barrier: TestDurabilityBarrier(trace: beforeRename.barrierTrace),
            clock: { leaseTestDate(nowMicros) },
            faultInjector: pendingInjector
        )
        let inode = try leaseLockInode(beforeRename)
        let request = try LeaseRequest(
            runID: beforeRename.runID,
            ownerID: "pending-writer",
            ttlMicroseconds: 100
        )
        #expect(throws: LeaseStoreInterruption.injected(.afterPendingBarrier)) {
            try interrupted.acquire(request)
        }
        #expect(FileManager.default.fileExists(atPath: leasePendingURL(beforeRename).path))
        #expect(!FileManager.default.fileExists(atPath: leaseRecordURL(beforeRename).path))

        let successor = try LeaseStore.testing(
            workItemRoot: beforeRename.workItemRoot,
            runID: beforeRename.runID,
            barrier: TestDurabilityBarrier(trace: beforeRename.barrierTrace),
            clock: { leaseTestDate(nowMicros) }
        )
        let acquired = try successor.acquire(request)
        #expect(acquired.fencingToken.rawValue == 1)
        #expect(!FileManager.default.fileExists(atPath: leasePendingURL(beforeRename).path))
        #expect(try leaseLockInode(beforeRename) == inode)

        let afterRename = try GenesisLeaseHarness.make()
        defer { afterRename.remove() }
        let renameInjector = LeaseStoreFaultInjector { point in
            if point == .afterRecordRenameBeforeBarrier {
                throw LeaseStoreInterruption.injected(point)
            }
        }
        let renamed = try LeaseStore.testing(
            workItemRoot: afterRename.workItemRoot,
            runID: afterRename.runID,
            barrier: TestDurabilityBarrier(trace: afterRename.barrierTrace),
            clock: { leaseTestDate(nowMicros) },
            faultInjector: renameInjector
        )
        let renamedRequest = try LeaseRequest(
            runID: afterRename.runID,
            ownerID: "renamed-writer",
            ttlMicroseconds: 100
        )
        #expect(throws: LeaseStoreInterruption.injected(.afterRecordRenameBeforeBarrier)) {
            try renamed.acquire(renamedRequest)
        }
        #expect(FileManager.default.fileExists(atPath: leaseRecordURL(afterRename).path))

        let renamedSuccessor = try LeaseStore.testing(
            workItemRoot: afterRename.workItemRoot,
            runID: afterRename.runID,
            barrier: TestDurabilityBarrier(trace: afterRename.barrierTrace),
            clock: { leaseTestDate(nowMicros) }
        )
        #expect(try renamedSuccessor.acquire(renamedRequest).fencingToken.rawValue == 1)
        #expect(!FileManager.default.fileExists(atPath: leasePendingURL(afterRename).path))
    }

    @Test("final publication barrier failure durably restores absent and prior authority")
    func finalBarrierRollbackIsDurable() throws {
        let start: Int64 = 1_800_000_000_000_000
        let absent = try GenesisLeaseHarness.make()
        defer { absent.remove() }
        let absentStore = try LeaseStore.testing(
            workItemRoot: absent.workItemRoot,
            runID: absent.runID,
            barrier: TestDurabilityBarrier(trace: absent.barrierTrace),
            clock: { leaseTestDate(start) }
        )
        absent.barrierTrace.reset(failAtPlan: 2)
        #expect(throws: DurabilityBarrierError.blockedEnvironment) {
            try absentStore.acquire(LeaseRequest(
                runID: absent.runID,
                ownerID: "absent-writer",
                ttlMicroseconds: 100
            ))
        }
        #expect(!FileManager.default.fileExists(atPath: leaseRecordURL(absent).path))
        #expect(!FileManager.default.fileExists(atPath: leasePendingURL(absent).path))
        #expect(absent.barrierTrace.plans.contains { $0.purpose == .rollbackMarker })

        let update = try GenesisLeaseHarness.make()
        defer { update.remove() }
        let clock = LeaseTestClock(leaseTestDate(start))
        let updateStore = try LeaseStore.testing(
            workItemRoot: update.workItemRoot,
            runID: update.runID,
            barrier: TestDurabilityBarrier(trace: update.barrierTrace),
            clock: { clock.sample() }
        )
        let first = try updateStore.acquire(LeaseRequest(
            runID: update.runID,
            ownerID: "update-writer",
            ttlMicroseconds: 1_000_000
        ))
        let prior = try Data(contentsOf: leaseRecordURL(update))
        clock.set(leaseTestDate(start + 10))
        update.barrierTrace.reset(failAtPlan: 2)
        #expect(throws: DurabilityBarrierError.blockedEnvironment) {
            try updateStore.renew(first, ttlMicroseconds: 1_000_000)
        }
        #expect(try Data(contentsOf: leaseRecordURL(update)) == prior)
        #expect(!FileManager.default.fileExists(atPath: leasePendingURL(update).path))
        #expect(update.barrierTrace.plans.contains { $0.purpose == .rollbackMarker })
    }
}

final class LeaseStartBarrier: @unchecked Sendable {
    private let condition = NSCondition()
    private let parties: Int
    private var arrivals = 0

    init(parties: Int) {
        self.parties = parties
    }

    func arriveAndWait(timeout: TimeInterval = 10) -> Bool {
        condition.lock()
        defer { condition.unlock() }
        arrivals += 1
        if arrivals == parties {
            condition.broadcast()
        } else {
            let deadline = Date().addingTimeInterval(timeout)
            while arrivals < parties {
                guard condition.wait(until: deadline) else { return false }
            }
        }
        return true
    }
}

final class LeaseWriterPhaseGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var writerLocked = false
    private var staleStarted = false
    private var writerReleased = false

    func holdWriterLock(timeout: TimeInterval = 10) throws {
        condition.lock()
        writerLocked = true
        condition.broadcast()
        let deadline = Date().addingTimeInterval(timeout)
        while !writerReleased {
            guard condition.wait(until: deadline) else {
                condition.unlock()
                throw LeaseTestSynchronizationError.timeout
            }
        }
        condition.unlock()
    }

    func waitUntilWriterLocked(timeout: TimeInterval = 10) -> Bool {
        wait(timeout: timeout) { writerLocked }
    }

    func markStaleStarted() {
        condition.lock()
        staleStarted = true
        condition.broadcast()
        condition.unlock()
    }

    func waitUntilStaleStarted(timeout: TimeInterval = 10) -> Bool {
        wait(timeout: timeout) { staleStarted }
    }

    func releaseWriter() {
        condition.lock()
        writerReleased = true
        condition.broadcast()
        condition.unlock()
    }

    private func wait(
        timeout: TimeInterval,
        predicate: () -> Bool
    ) -> Bool {
        condition.lock()
        defer { condition.unlock() }
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() {
            guard condition.wait(until: deadline) else { return false }
        }
        return true
    }
}

final class LeaseRaceResults: @unchecked Sendable {
    struct Snapshot {
        let leases: [WriterLease]
        let receipts: [CommitReceipt]
        let persistenceErrors: [PersistenceError]
        let otherErrorCount: Int
    }

    private let lock = NSLock()
    private var leases: [WriterLease] = []
    private var receipts: [CommitReceipt] = []
    private var persistenceErrors: [PersistenceError] = []
    private var otherErrorCount = 0

    func record(lease: WriterLease) {
        lock.withLock { leases.append(lease) }
    }

    func record(receipt: CommitReceipt) {
        lock.withLock { receipts.append(receipt) }
    }

    func record(error: any Error) {
        lock.withLock {
            if let error = error as? PersistenceError {
                persistenceErrors.append(error)
            } else {
                otherErrorCount += 1
            }
        }
    }

    func snapshot() -> Snapshot {
        lock.withLock {
            Snapshot(
                leases: leases,
                receipts: receipts,
                persistenceErrors: persistenceErrors,
                otherErrorCount: otherErrorCount
            )
        }
    }
}

enum LeaseTestSynchronizationError: Error {
    case timeout
}

func waitForLeaseRace(_ group: DispatchGroup, timeout: TimeInterval = 10) -> Bool {
    group.wait(timeout: .now() + timeout) == .success
}

private func leaseLockInode(_ harness: some LeasePathHarness) throws -> UInt64 {
    try #require(
        FileManager.default.attributesOfItem(atPath: leaseLockURL(harness).path)[
            .systemFileNumber
        ] as? NSNumber
    ).uint64Value
}
