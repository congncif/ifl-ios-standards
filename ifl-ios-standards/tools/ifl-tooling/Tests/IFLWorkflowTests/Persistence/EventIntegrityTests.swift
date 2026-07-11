import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("EventIntegrityTests")
struct EventIntegrityTests {
    @Test("tampered state is rejected with the integrity exit classification")
    func rejectsTamperedState() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        harness.barrierTrace.reset()
        let store = try harness.makeStore()
        _ = try store.commit(harness.transaction, lease: harness.lease)
        var bytes = try Data(contentsOf: harness.paths.stateURL)
        bytes.append(0x20)
        try bytes.write(to: harness.paths.stateURL)

        #expect(throws: PersistenceError.integrityViolation) {
            try store.load(runID: harness.runID, from: harness.paths.runRoot)
        }
        #expect(PersistenceError.integrityViolation.exitCode == .integrityViolation)
        #expect(
            try persistenceFixture("tampered-state.json").expectedDisposition
                == "integrity_violation"
        )
    }

    @Test("truncated event tail is rejected rather than silently ignored")
    func rejectsTruncatedEvent() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        harness.barrierTrace.reset()
        let store = try harness.makeStore()
        _ = try store.commit(harness.transaction, lease: harness.lease)
        var bytes = try Data(contentsOf: harness.paths.eventLogURL)
        bytes.removeLast()
        try bytes.write(to: harness.paths.eventLogURL)

        #expect(throws: PersistenceError.integrityViolation) {
            try store.load(runID: harness.runID, from: harness.paths.runRoot)
        }
        #expect(
            try persistenceFixture("truncated-event.json").expectedDisposition
                == "integrity_violation"
        )
    }

    @Test("event records bind state, transaction, predecessor, and canonical event bytes")
    func eventChainBindsCanonicalTransaction() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        harness.barrierTrace.reset()
        let store = try harness.makeStore()
        let receipt = try store.commit(harness.transaction, lease: harness.lease)
        let persisted = try store.load(runID: harness.runID, from: harness.paths.runRoot)
        let record = try #require(persisted.events.first)
        #expect(record.sequence == 1)
        #expect(record.runID == harness.runID)
        #expect(record.transactionID == harness.transaction.id)
        #expect(record.previousDigest == nil)
        #expect(record.previousStateDigest == nil)
        #expect(record.stateDigest == receipt.stateDigest)
        #expect(record.transactionDigest == harness.transaction.digest)
        #expect(record.fencingToken == harness.lease.fencingToken)
        #expect(record.writerOwnerID == harness.lease.ownerID)
        #expect(record.receiptManifest.count == 1)
        #expect(record.receiptManifest[0].kind == harness.transaction.receiptWrites[0].kind)
        #expect(record.receiptManifest[0].id == harness.transaction.receiptWrites[0].id)
        #expect(record.recordDigest == receipt.eventHead)
        let eventBytes = try CanonicalJSON.encode(harness.event)
        #expect(record.eventBytes == eventBytes)
    }

    @Test("historical receipt deletion and unmanifested injection are integrity violations")
    func receiptHistoryIsExact() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        let store = try harness.makeStore()
        let first = try store.commit(harness.transaction, lease: harness.lease)
        let second = try makeSecondPersistenceTransaction(harness: harness, after: first)
        _ = try store.commit(second.transaction, lease: harness.lease)

        let firstReceiptURL = try harness.paths.receiptURL(
            kind: harness.transaction.receiptWrites[0].kind,
            id: harness.transaction.receiptWrites[0].id
        )
        let firstReceiptBytes = try Data(contentsOf: firstReceiptURL)
        try FileManager.default.removeItem(at: firstReceiptURL)
        #expect(throws: PersistenceError.integrityViolation) {
            try store.load(runID: harness.runID, from: harness.paths.runRoot)
        }

        try firstReceiptBytes.write(to: firstReceiptURL)
        var injected = try #require(
            JSONSerialization.jsonObject(with: firstReceiptBytes) as? [String: Any]
        )
        injected["id"] = "injected-receipt"
        let injectedBytes = try JSONSerialization.data(
            withJSONObject: injected,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        let injectedURL = firstReceiptURL.deletingLastPathComponent()
            .appendingPathComponent("injected-receipt.json")
        try injectedBytes.write(to: injectedURL)
        #expect(throws: PersistenceError.integrityViolation) {
            try store.load(runID: harness.runID, from: harness.paths.runRoot)
        }
    }

    @Test("journal fencing rewrite cannot substitute the historical commit receipt")
    func journalCannotRewriteFencing() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        let store = try harness.makeStore()
        _ = try store.commit(harness.transaction, lease: harness.lease)
        try mutateCanonicalJSONObject(at: harness.paths.journalURL) { object in
            var lease = try #require(object["lease"] as? [String: Any])
            lease["fencing_token"] = 99
            object["lease"] = lease
        }
        #expect(throws: PersistenceError.integrityViolation) {
            try store.load(runID: harness.runID, from: harness.paths.runRoot)
        }
    }

    @Test("trusted head and token floor reject a coherent older canonical surface")
    func trustedHeadRejectsRollback() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        let store = try harness.makeStore()
        let receipt = try store.commit(harness.transaction, lease: harness.lease)
        let trusted = TrustedRunFact(
            runID: harness.runID,
            stateDigest: receipt.stateDigest,
            eventHead: try HashDigest(validating: String(repeating: "f", count: 64)),
            minimumFencingToken: try FencingToken(validating: 2)
        )
        #expect(throws: PersistenceError.integrityViolation) {
            try harness.makeStore(trustedFact: trusted).load(
                runID: harness.runID,
                from: harness.paths.runRoot
            )
        }
    }

    @Test("an empty public store cannot later adopt history without an authoritative fact")
    func publicStoreCannotAdoptUntrustedHistory() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        let publicStore = try FileRunStateStore(paths: harness.paths)
        #expect(throws: PersistenceError.notFound) {
            try publicStore.load(runID: harness.runID, from: harness.paths.runRoot)
        }

        _ = try harness.makeStore().commit(harness.transaction, lease: harness.lease)
        #expect(throws: PersistenceError.integrityViolation) {
            try publicStore.load(runID: harness.runID, from: harness.paths.runRoot)
        }
        #expect(throws: PersistenceError.integrityViolation) {
            try publicStore.recover(runID: harness.runID, from: harness.paths.runRoot)
        }
        #expect(throws: PersistenceError.integrityViolation) {
            try publicStore.commit(harness.transaction, lease: harness.lease)
        }
    }

    @Test("lease, receipt payload, and commit receipt wires are closed canonical contracts")
    func strictPersistedWires() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        let leaseBytes = try CanonicalJSON.encode(harness.lease)
        let leaseObject = try #require(
            JSONSerialization.jsonObject(with: leaseBytes) as? [String: Any]
        )
        #expect(leaseObject["issued_at_unix_microseconds"] as? Int64 == 1_799_999_990_000_000)
        #expect(leaseObject["expires_at_unix_microseconds"] as? Int64 == 1_800_000_300_000_000)
        var leaseUnknown = leaseObject
        leaseUnknown["unknown"] = true
        #expect(throws: Error.self) {
            try CanonicalJSON.decode(
                WriterLease.self,
                from: JSONSerialization.data(
                    withJSONObject: leaseUnknown,
                    options: [.sortedKeys, .withoutEscapingSlashes]
                )
            )
        }
        #expect(throws: PersistenceError.invalidLease) {
            try WriterLease(
                runID: harness.runID,
                ownerID: "agent-persistence",
                fencingToken: try FencingToken(validating: 1),
                issuedAt: Date(timeIntervalSince1970: 1_800_000_000.000_000_5),
                expiresAt: Date(timeIntervalSince1970: 1_800_000_001)
            )
        }

        #expect(throws: PersistenceError.invalidReceiptPayload) {
            try ReceiptTableWrite(
                kind: ReceiptKind(validating: "verification"),
                id: ReceiptID(validating: "fragment"),
                value: 1
            )
        }
        #expect(throws: PersistenceError.invalidReceiptPayload) {
            try ReceiptTableWrite(
                kind: ReceiptKind(validating: "verification"),
                id: ReceiptID(validating: "floating"),
                value: ["value": 1.5]
            )
        }

        let receipt = try harness.makeStore().commit(harness.transaction, lease: harness.lease)
        let receiptObject = try #require(
            JSONSerialization.jsonObject(with: CanonicalJSON.encode(receipt)) as? [String: Any]
        )
        for mutation in ["schema", "durable", "unknown"] {
            var invalid = receiptObject
            switch mutation {
            case "schema": invalid["schema_version"] = 2
            case "durable": invalid["is_durable"] = false
            default: invalid["unknown"] = true
            }
            #expect(throws: Error.self) {
                try CanonicalJSON.decode(
                    CommitReceipt.self,
                    from: JSONSerialization.data(
                        withJSONObject: invalid,
                        options: [.sortedKeys, .withoutEscapingSlashes]
                    )
                )
            }
        }
    }

    @Test("persisted invalid path values are classified as integrity, not caller input")
    func persistedValueErrorsMapToIntegrity() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        let injector = PersistenceFaultInjector { point in
            if point == .afterJournalBarrier {
                throw PersistenceError.injectedInterruption(point)
            }
        }
        #expect(throws: PersistenceError.injectedInterruption(.afterJournalBarrier)) {
            try harness.makeStore(faultInjector: injector).commit(
                harness.transaction,
                lease: harness.lease
            )
        }
        try mutateCanonicalJSONObject(at: harness.paths.journalURL) { object in
            var receipts = try #require(object["receipts"] as? [[String: Any]])
            receipts[0]["kind"] = "Verification"
            object["receipts"] = receipts
        }
        do {
            _ = try harness.makeStore().recover(
                runID: harness.runID,
                from: harness.paths.runRoot
            )
            Issue.record("expected persisted invalid value to fail")
        } catch let error as PersistenceError {
            #expect(error == .integrityViolation)
        }
    }
}
