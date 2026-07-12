import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("FencingTests")
struct FencingTests {
    @Test("production raw store rejects a direct commit before mutation")
    func directRawCommitFailsClosed() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        let store = try FileRunStateStore(paths: harness.paths)
        let lease = try WriterLease(
            runID: harness.runID,
            ownerID: "direct-raw-writer",
            fencingToken: FencingToken(validating: 1),
            issuedAt: Date(timeIntervalSince1970: 1_000_000_000),
            expiresAt: Date(timeIntervalSince1970: 2_000_000_000)
        )

        #expect(throws: PersistenceError.fencingViolation) {
            try store.commit(harness.transaction, lease: lease)
        }
        #expect(!FileManager.default.fileExists(atPath: harness.paths.stateURL.path))
        #expect(!FileManager.default.fileExists(atPath: harness.paths.eventLogURL.path))
        #expect(!FileManager.default.fileExists(atPath: harness.paths.journalURL.path))
    }

    @Test("all protocol-shaped raw entry points are production-closed while testing bypass remains")
    func rawAccessModesAreExact() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        let raw = try FileRunStateStore(paths: harness.paths)

        #expect(throws: PersistenceError.notFound) {
            try raw.load(runID: harness.runID, from: harness.paths.runRoot)
        }
        #expect(throws: PersistenceError.notFound) {
            try raw.recover(runID: harness.runID, from: harness.paths.runRoot)
        }
        #expect(!FileManager.default.fileExists(atPath: harness.paths.journalURL.path))

        let testing = try harness.makeStore()
        let committed = try testing.commit(harness.transaction, lease: harness.lease)
        #expect(committed.fencingToken == harness.lease.fencingToken)
        #expect(try testing.load(
            runID: harness.runID,
            from: harness.paths.runRoot
        ).state == harness.proposedState)
    }

    @Test("facade commit requires every active lease field and current durable token")
    func commitAuthorityIsExact() throws {
        let harness = try FencedPersistenceHarness.make(ownerID: "facade-writer")
        defer { harness.remove() }
        let nowMicros: Int64 = 1_800_000_000_000_000
        let clock = LeaseTestClock(leaseTestDate(nowMicros))
        let lease = harness.initialLease
        let store = try LeaseStore.testing(
            paths: harness.paths,
            barrier: TestDurabilityBarrier(trace: harness.barrierTrace),
            clock: { clock.sample() }
        )
        let differentExpiry = try WriterLease(
            runID: lease.runID,
            ownerID: lease.ownerID,
            fencingToken: lease.fencingToken,
            issuedAt: lease.issuedAt,
            expiresAt: lease.expiresAt.addingTimeInterval(0.000001)
        )

        #expect(throws: PersistenceError.staleLease) {
            try store.commit(harness.transaction, lease: differentExpiry)
        }
        #expect(!FileManager.default.fileExists(atPath: harness.paths.journalURL.path))
        let receipt = try store.commit(harness.transaction, lease: lease)
        #expect(receipt.fencingToken.rawValue == 1)

        clock.set(lease.expiresAt)
        let successor = try store.recover(LeaseRequest(
            runID: harness.runID,
            ownerID: "successor-writer",
            ttlMicroseconds: 300_000_000
        ))
        #expect(successor.fencingToken.rawValue == 2)
        #expect(throws: PersistenceError.staleLease) {
            try store.commit(harness.transaction, lease: lease)
        }
        #expect(try store.load(
            runID: harness.runID,
            from: harness.paths.runRoot
        ).events.count == 1)
    }

    @Test("nonterminal old-epoch journal settles before token advance and failure keeps old authority")
    func oldEpochSettlementPrecedesPublication() throws {
        let successful = try FencedPersistenceHarness.make()
        defer { successful.remove() }
        let start: Int64 = 1_800_000_000_000_000
        let token41 = try seedPreparedJournal(
            harness: successful,
            ownerID: "writer-forty-one",
            token: 41,
            issuedMicros: start,
            expiresMicros: start + 10
        )
        #expect(token41.fencingToken.rawValue == 41)
        let store = try LeaseStore.testing(
            paths: successful.paths,
            barrier: TestDurabilityBarrier(trace: successful.barrierTrace),
            clock: { leaseTestDate(start + 10) }
        )
        let token42 = try store.recover(LeaseRequest(
            runID: successful.runID,
            ownerID: "writer-forty-two",
            ttlMicroseconds: 100
        ))
        #expect(token42.fencingToken.rawValue == 42)
        #expect(!FileManager.default.fileExists(atPath: successful.paths.journalURL.path))
        #expect(!FileManager.default.fileExists(atPath: successful.paths.stateURL.path))

        let failing = try FencedPersistenceHarness.make()
        defer { failing.remove() }
        _ = try seedPreparedJournal(
            harness: failing,
            ownerID: "writer-forty-one",
            token: 41,
            issuedMicros: start,
            expiresMicros: start + 10
        )
        let record41 = try Data(contentsOf: leaseRecordURL(failing))
        failing.barrierTrace.reset(failAtPurpose: .rollbackMarker)
        let failingStore = try LeaseStore.testing(
            paths: failing.paths,
            barrier: TestDurabilityBarrier(trace: failing.barrierTrace),
            clock: { leaseTestDate(start + 10) }
        )
        #expect(throws: DurabilityBarrierError.blockedEnvironment) {
            try failingStore.recover(LeaseRequest(
                runID: failing.runID,
                ownerID: "writer-forty-two",
                ttlMicroseconds: 100
            ))
        }
        #expect(try Data(contentsOf: leaseRecordURL(failing)) == record41)
    }

    @Test("journal owner mismatch fails closed and completed old epochs remain readable")
    func journalEpochRulesAreExact() throws {
        let start: Int64 = 1_800_000_000_000_000
        let mismatch = try FencedPersistenceHarness.make()
        defer { mismatch.remove() }
        let active41 = activeLeaseRecordBytes(
            runID: mismatch.runID,
            ownerID: "record-owner",
            token: 41,
            issuedMicros: start,
            expiresMicros: start + 10
        )
        _ = try LeaseStore.testing(
            paths: mismatch.paths,
            barrier: TestDurabilityBarrier(trace: mismatch.barrierTrace),
            clock: { leaseTestDate(start) }
        )
        try writeLeaseRecord(active41, for: mismatch)
        let mismatchedLease = try WriterLease(
            runID: mismatch.runID,
            ownerID: "journal-owner",
            fencingToken: FencingToken(validating: 41),
            issuedAt: leaseTestDate(start),
            expiresAt: leaseTestDate(start + 10)
        )
        let injector = PersistenceFaultInjector { point in
            if point == .afterJournalBarrier {
                throw PersistenceError.injectedInterruption(point)
            }
        }
        #expect(throws: PersistenceError.injectedInterruption(.afterJournalBarrier)) {
            try mismatch.makeRawStore(faultInjector: injector).commit(
                mismatch.transaction,
                lease: mismatchedLease
            )
        }
        let mismatchStore = try LeaseStore.testing(
            paths: mismatch.paths,
            barrier: TestDurabilityBarrier(trace: mismatch.barrierTrace),
            clock: { leaseTestDate(start + 10) }
        )
        #expect(throws: PersistenceError.integrityViolation) {
            try mismatchStore.recover(LeaseRequest(
                runID: mismatch.runID,
                ownerID: "successor",
                ttlMicroseconds: 100
            ))
        }
        #expect(try Data(contentsOf: leaseRecordURL(mismatch)) == active41)

        let historical = try FencedPersistenceHarness.make()
        defer { historical.remove() }
        _ = try LeaseStore.testing(
            paths: historical.paths,
            barrier: TestDurabilityBarrier(trace: historical.barrierTrace),
            clock: { leaseTestDate(start) }
        )
        try writeLeaseRecord(activeLeaseRecordBytes(
            runID: historical.runID,
            ownerID: "historical-writer",
            token: 41,
            issuedMicros: start,
            expiresMicros: start + 10
        ), for: historical)
        let historicalLease = try WriterLease(
            runID: historical.runID,
            ownerID: "historical-writer",
            fencingToken: FencingToken(validating: 41),
            issuedAt: leaseTestDate(start),
            expiresAt: leaseTestDate(start + 10)
        )
        _ = try historical.makeRawStore().commit(
            historical.transaction,
            lease: historicalLease
        )
        let historicalStore = try LeaseStore.testing(
            paths: historical.paths,
            barrier: TestDurabilityBarrier(trace: historical.barrierTrace),
            clock: { leaseTestDate(start + 10) }
        )
        let successor = try historicalStore.recover(LeaseRequest(
            runID: historical.runID,
            ownerID: "current-writer",
            ttlMicroseconds: 100
        ))
        #expect(successor.fencingToken.rawValue == 42)
        historical.barrierTrace.reset(failAtPlan: 1)
        let persisted = try historicalStore.load(
            runID: historical.runID,
            from: historical.paths.runRoot
        )
        #expect(persisted.events.last?.fencingToken.rawValue == 41)
        #expect(persisted.events.last?.writerOwnerID == "historical-writer")
        #expect(historical.barrierTrace.plans.isEmpty)
    }

    @Test("successor overflow leaves a prepared journal and lease bytes untouched")
    func overflowPreflightPrecedesSettlement() throws {
        let start: Int64 = 1_800_000_000_000_000
        for scenario in ["token", "timestamp"] {
            let harness = try FencedPersistenceHarness.make()
            defer { harness.remove() }
            let token: UInt64 = scenario == "token" ? .max : 41
            _ = try seedPreparedJournal(
                harness: harness,
                ownerID: "overflow-writer",
                token: token,
                issuedMicros: start,
                expiresMicros: start + 10
            )
            let leaseBefore = try Data(contentsOf: leaseRecordURL(harness))
            let runBefore = try persistenceByteSnapshot(root: harness.paths.runRoot)
            let store = try LeaseStore.testing(
                paths: harness.paths,
                barrier: TestDurabilityBarrier(trace: harness.barrierTrace),
                clock: { leaseTestDate(start + 10) }
            )
            let ttl: Int64 = scenario == "timestamp" ? .max : 100
            #expect(throws: PersistenceError.invalidLease) {
                try store.recover(LeaseRequest(
                    runID: harness.runID,
                    ownerID: "successor-writer",
                    ttlMicroseconds: ttl
                ))
            }
            #expect(try Data(contentsOf: leaseRecordURL(harness)) == leaseBefore)
            #expect(try persistenceByteSnapshot(root: harness.paths.runRoot) == runBefore)
        }
    }
}

func seedPreparedJournal(
    harness: FencedPersistenceHarness,
    ownerID: String,
    token: UInt64,
    issuedMicros: Int64,
    expiresMicros: Int64
) throws -> WriterLease {
    _ = try LeaseStore.testing(
        paths: harness.paths,
        barrier: TestDurabilityBarrier(trace: harness.barrierTrace),
        clock: { leaseTestDate(issuedMicros) }
    )
    try writeLeaseRecord(activeLeaseRecordBytes(
        runID: harness.runID,
        ownerID: ownerID,
        token: token,
        issuedMicros: issuedMicros,
        expiresMicros: expiresMicros
    ), for: harness)
    let lease = try WriterLease(
        runID: harness.runID,
        ownerID: ownerID,
        fencingToken: FencingToken(validating: token),
        issuedAt: leaseTestDate(issuedMicros),
        expiresAt: leaseTestDate(expiresMicros)
    )
    let injector = PersistenceFaultInjector { point in
        if point == .afterJournalBarrier {
            throw PersistenceError.injectedInterruption(point)
        }
    }
    #expect(throws: PersistenceError.injectedInterruption(.afterJournalBarrier)) {
        try harness.makeRawStore(faultInjector: injector).commit(
            harness.transaction,
            lease: lease
        )
    }
    return lease
}

private func persistenceByteSnapshot(root: URL) throws -> [String: Data] {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: []
    ) else { return [:] }
    var snapshot: [String: Data] = [:]
    for case let url as URL in enumerator {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else { continue }
        snapshot[url.path.replacingOccurrences(of: root.path, with: "")] = try Data(
            contentsOf: url
        )
    }
    return snapshot
}
