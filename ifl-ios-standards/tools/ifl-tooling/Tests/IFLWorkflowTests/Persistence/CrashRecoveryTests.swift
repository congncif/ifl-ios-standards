import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("CrashRecoveryTests")
struct CrashRecoveryTests {
    @Test("every semantic mutation boundary belongs to exactly one crash matrix")
    func crashMatrixOwnsEveryBoundary() {
        let partition = PersistenceMutationPoint.commitCases
            + PersistenceMutationPoint.rollbackRecoveryCases
            + PersistenceMutationPoint.completionRecoveryCases
        #expect(partition.count == Set(partition).count)
        #expect(Set(partition) == Set(PersistenceMutationPoint.allCases))

        let requiredPublicationOutcomes: [PersistenceMutationPoint: RecoveryDisposition] = [
            .afterEventSwapBeforeCleanup: .rolledBack,
            .afterStateSwapBeforeCleanup: .completed,
            .afterJournalCompletionRenameBeforeBarrier: .completed,
            .beforeReceiptRootBarrier: .rolledBack,
            .afterReceiptRootBarrier: .rolledBack,
            .beforeReceiptKindBarrier: .rolledBack,
            .afterReceiptKindBarrier: .rolledBack,
        ]
        #expect(Set(requiredPublicationOutcomes.keys).isSubset(
            of: Set(PersistenceMutationPoint.commitCases)
        ))
        for (point, expected) in requiredPublicationOutcomes {
            #expect(point.expectedRecoveryDisposition == expected)
        }
    }

    @Test("every declared interruption recovers to wholly absent or exactly-once canonical bytes")
    func exhaustiveInterruptionMatrix() throws {
        for point in PersistenceMutationPoint.commitCases {
            let harness = try PersistenceHarness.make()
            defer { harness.remove() }
            harness.barrierTrace.reset()
            let injector = PersistenceFaultInjector { observed in
                if observed == point {
                    throw PersistenceError.injectedInterruption(point)
                }
            }
            #expect(throws: PersistenceError.injectedInterruption(point)) {
                try harness.makeStore(faultInjector: injector).commit(
                    harness.transaction,
                    lease: harness.lease
                )
            }

            let store = try harness.makeStore()
            let recovery = try store.recover(runID: harness.runID, from: harness.paths.runRoot)
            #expect(recovery.disposition == point.expectedRecoveryDisposition)
            switch recovery.disposition {
            case .absent, .rolledBack:
                #expect(throws: PersistenceError.notFound) {
                    try store.load(runID: harness.runID, from: harness.paths.runRoot)
                }
            case .completed, .unchanged:
                let persisted = try store.load(runID: harness.runID, from: harness.paths.runRoot)
                #expect(persisted.stateBytes == harness.transaction.stateBytes)
                #expect(persisted.events.count == 1)
                #expect(persisted.receipts.count == 1)
                let second = try store.recover(runID: harness.runID, from: harness.paths.runRoot)
                #expect(second.disposition == .unchanged)
                #expect(try store.load(
                    runID: harness.runID,
                    from: harness.paths.runRoot
                ).events.count == 1)
            }
        }
    }

    @Test("recovery interruption matrix is restartable for rollback and completion paths")
    func exhaustiveRecoveryInterruptionMatrix() throws {
        for (basePoint, recoveryPoints) in [
            (PersistenceMutationPoint.afterJournalBarrier, PersistenceMutationPoint.rollbackRecoveryCases),
            (PersistenceMutationPoint.afterStateRename, PersistenceMutationPoint.completionRecoveryCases),
        ] {
            for recoveryPoint in recoveryPoints {
                let harness = try PersistenceHarness.make()
                defer { harness.remove() }
                let commitInjector = PersistenceFaultInjector { point in
                    if point == basePoint { throw PersistenceError.injectedInterruption(point) }
                }
                #expect(throws: PersistenceError.injectedInterruption(basePoint)) {
                    try harness.makeStore(faultInjector: commitInjector).commit(
                        harness.transaction,
                        lease: harness.lease
                    )
                }
                let recoveryInjector = PersistenceFaultInjector { point in
                    if point == recoveryPoint { throw PersistenceError.injectedInterruption(point) }
                }
                #expect(throws: PersistenceError.injectedInterruption(recoveryPoint)) {
                    try harness.makeStore(faultInjector: recoveryInjector).recover(
                        runID: harness.runID,
                        from: harness.paths.runRoot
                    )
                }
                let final = try harness.makeStore().recover(
                    runID: harness.runID,
                    from: harness.paths.runRoot
                )
                #expect(final.disposition == recoveryPoint.eventualRecoveryDisposition)
            }
        }
    }

    @Test("a crashed sequential transaction preserves the exact prior or next transaction")
    func sequentialTransactionCrashMatrix() throws {
        let rollbackPoints: Set<PersistenceMutationPoint> = [
            .afterJournalBarrier,
            .afterEventRename,
            .afterReceiptRename,
        ]
        let completionPoints: Set<PersistenceMutationPoint> = [
            .afterStateRename,
            .beforeJournalCompletionFlush,
        ]

        for point in rollbackPoints.union(completionPoints) {
            let harness = try PersistenceHarness.make()
            defer { harness.remove() }
            let store = try harness.makeStore()
            let first = try store.commit(harness.transaction, lease: harness.lease)
            let second = try makeSecondPersistenceTransaction(harness: harness, after: first)
            let injector = PersistenceFaultInjector { observed in
                if observed == point {
                    throw PersistenceError.injectedInterruption(point)
                }
            }

            #expect(throws: PersistenceError.injectedInterruption(point)) {
                try harness.makeStore(faultInjector: injector).commit(
                    second.transaction,
                    lease: harness.lease
                )
            }

            harness.barrierTrace.reset()
            let recovery = try harness.makeStore().recover(
                runID: harness.runID,
                from: harness.paths.runRoot
            )
            let persisted = try harness.makeStore().load(
                runID: harness.runID,
                from: harness.paths.runRoot
            )
            if rollbackPoints.contains(point) {
                #expect(recovery.disposition == .rolledBack)
                #expect(persisted.stateBytes == harness.transaction.stateBytes)
                #expect(persisted.eventHead == first.eventHead)
                #expect(persisted.events.count == 1)
                #expect(persisted.receipts.map(\.id.rawValue) == ["gate-02.3"])
            } else {
                #expect(recovery.disposition == .completed)
                #expect(persisted.stateBytes == second.transaction.stateBytes)
                #expect(persisted.events.count == 2)
                #expect(Set(persisted.receipts.map(\.id.rawValue)) == [
                    "gate-02.3", "gate-02.3-second",
                ])
                #expect(harness.barrierTrace.plans.contains {
                    $0.purpose == .recoveryCompletion
                })
            }
            #expect(try harness.makeStore().recover(
                runID: harness.runID,
                from: harness.paths.runRoot
            ).disposition == .unchanged)
        }
    }

    @Test("multi-receipt publication rolls back every partial prefix without residue")
    func multiReceiptPartialPublicationMatrix() throws {
        for point in [
            PersistenceMutationPoint.beforeReceiptRename,
            PersistenceMutationPoint.afterReceiptRename,
        ] {
            let harness = try PersistenceHarness.make()
            defer { harness.remove() }
            let transaction = try makeMultiReceiptPersistenceTransaction(harness: harness)
            let counter = PersistenceMutationHitCounter(target: point, failAtHit: 2)
            let injector = PersistenceFaultInjector { observed in
                try counter.hit(observed)
            }

            #expect(throws: PersistenceError.injectedInterruption(point)) {
                try harness.makeStore(faultInjector: injector).commit(
                    transaction,
                    lease: harness.lease
                )
            }

            let recovery = try harness.makeStore().recover(
                runID: harness.runID,
                from: harness.paths.runRoot
            )
            #expect(recovery.disposition == .rolledBack)
            #expect(throws: PersistenceError.notFound) {
                try harness.makeStore().load(
                    runID: harness.runID,
                    from: harness.paths.runRoot
                )
            }
            for write in transaction.receiptWrites {
                let url = try harness.paths.receiptURL(kind: write.kind, id: write.id)
                #expect(!FileManager.default.fileExists(atPath: url.path))
            }
            #expect(try harness.makeStore().recover(
                runID: harness.runID,
                from: harness.paths.runRoot
            ).disposition == .absent)
        }
    }

    @Test("recovery remains restartable across two consecutive interruption boundaries")
    func repeatedRecoveryInterruptionChains() throws {
        let chains: [(
            base: PersistenceMutationPoint,
            interruptions: [PersistenceMutationPoint],
            final: RecoveryDisposition,
            repeated: RecoveryDisposition
        )] = [
            (
                .afterJournalBarrier,
                [.afterRollbackPayloadBarrier, .beforeRollbackMarkerBarrier],
                .rolledBack,
                .absent
            ),
            (
                .afterStateRename,
                [.beforeRecoveryCompletionBarrier, .afterRecoveryCompletionBarrier],
                .completed,
                .unchanged
            ),
        ]

        for chain in chains {
            let harness = try PersistenceHarness.make()
            defer { harness.remove() }
            let commitInjector = PersistenceFaultInjector { observed in
                if observed == chain.base {
                    throw PersistenceError.injectedInterruption(chain.base)
                }
            }
            #expect(throws: PersistenceError.injectedInterruption(chain.base)) {
                try harness.makeStore(faultInjector: commitInjector).commit(
                    harness.transaction,
                    lease: harness.lease
                )
            }

            for interruption in chain.interruptions {
                let recoveryInjector = PersistenceFaultInjector { observed in
                    if observed == interruption {
                        throw PersistenceError.injectedInterruption(interruption)
                    }
                }
                #expect(throws: PersistenceError.injectedInterruption(interruption)) {
                    try harness.makeStore(faultInjector: recoveryInjector).recover(
                        runID: harness.runID,
                        from: harness.paths.runRoot
                    )
                }
            }

            #expect(try harness.makeStore().recover(
                runID: harness.runID,
                from: harness.paths.runRoot
            ).disposition == chain.final)
            #expect(try harness.makeStore().recover(
                runID: harness.runID,
                from: harness.paths.runRoot
            ).disposition == chain.repeated)
        }
    }

    @Test("before-rename and after-rename fixtures select deterministic recovery outcomes")
    func fixtureRecoveryScenarios() throws {
        let before = try persistenceFixture("pending-before-rename.json")
        let after = try persistenceFixture("pending-after-rename.json")
        let committed = try persistenceFixture("committed.json")
        #expect(before.faultPoint == PersistenceMutationPoint.beforeStateRename.rawValue)
        #expect(before.expectedDisposition == "rolled_back")
        #expect(after.faultPoint == PersistenceMutationPoint.afterStateRename.rawValue)
        #expect(after.expectedDisposition == "completed")
        #expect(committed.expectedDisposition == "unchanged")
        for filename in [
            "committed.json", "pending-before-rename.json", "pending-after-rename.json",
            "truncated-event.json", "tampered-state.json",
        ] {
            let fixture = try persistenceFixture(filename)
            let rawFixture = try persistenceFixtureData(filename)
            let fixtureObject = try JSONSerialization.jsonObject(with: rawFixture)
            var canonicalFixture = try JSONSerialization.data(
                withJSONObject: fixtureObject,
                options: [.sortedKeys, .withoutEscapingSlashes]
            )
            canonicalFixture.append(0x0A)
            #expect(rawFixture == canonicalFixture)
            #expect(fixture.runID == "00000000-0000-0000-0000-000000000001")
            #expect(fixture.transactionID == "txn-02.3-fixture")
            #expect(fixture.writerOwner == "fixture-writer")
            #expect(fixture.fencingToken == 7)
            #expect(fixture.issuedAtUnixMicroseconds == 1_800_000_000_000_000)

            let stateBytes = Data(fixture.stateBytes.utf8)
            let eventBytes = Data(fixture.eventNDJSON.utf8)
            let receiptBytes = Data(fixture.receiptBytes.utf8)
            let journalBytes = Data(fixture.journalBytes.utf8)
            let fixedStateSHA = "308f1628a079a567471ad2a5828fc231983033c3dd72b7d788d6160316518fd8"
            let fixedEventNDJSONSHA = "f17c428bc53a34e65f6cc968445ecd5822b4d2867cb56f8ac0dfb6954cb3d4cd"
            let fixedEventHead = "fb038301fde869c28bfdc6165be15fefbd267efcef483c40a0f3e53cdb0dce28"
            let fixedReceiptSHA = "0bd878e0d1061f7f4fb2e2796d8f4ed8b9dffe328b2d455476dc20ccfd7ab7bc"
            let fixedJournalSHA = filename == "committed.json"
                ? "b5301b13f15328f7a3d4175d783de4359d684c4e6e322ee4b32f7eee26e8f301"
                : "fed11fecd295b8ec44a709a195975c11dd4337acb0422e4b0b401266dbd07d35"

            #expect(fixture.stateSHA256 == fixedStateSHA)
            #expect(fixture.eventHead == fixedEventHead)
            #expect(fixture.receiptSHA256 == fixedReceiptSHA)
            #expect(fixture.journalSHA256 == fixedJournalSHA)
            #expect(CanonicalTreeDigest.sha256(stateBytes).rawValue == fixedStateSHA)
            #expect(CanonicalTreeDigest.sha256(eventBytes).rawValue == fixedEventNDJSONSHA)
            #expect(CanonicalTreeDigest.sha256(receiptBytes).rawValue == fixedReceiptSHA)
            #expect(CanonicalTreeDigest.sha256(journalBytes).rawValue == fixedJournalSHA)

            let state = try CanonicalJSON.decode(RunState.self, from: stateBytes)
            let events = try EventLog.decode(eventBytes)
            let envelope = try CanonicalJSON.decode(ReceiptEnvelope.self, from: receiptBytes)
            let journal = try CanonicalJSON.decode(CommitJournalRecord.self, from: journalBytes)
            try envelope.validate()
            try journal.validate()

            #expect(try CanonicalJSON.encode(state) == stateBytes)
            #expect(try canonicalEventLogFixtureBytes(events) == eventBytes)
            #expect(try CanonicalJSON.encode(envelope) == receiptBytes)
            #expect(try CanonicalJSON.encode(journal) == journalBytes)
            #expect(state.runID.filesystemComponent == fixture.runID)
            #expect(events.count == 1)
            #expect(events.last?.recordDigest.rawValue == fixedEventHead)
            #expect(events.last?.receiptManifest.map(\.envelopeBytes) == [receiptBytes])
            #expect(journal.stateBytes == stateBytes)
            #expect(journal.targetEventLogBytes == eventBytes)
            #expect(journal.targetEventHead == events.last?.recordDigest)
            #expect(journal.receipts.map(\.envelopeBytes) == [receiptBytes])
            #expect(envelope.transactionID == journal.transactionID)
            #expect(envelope.transactionDigest == journal.transactionDigest)
            #expect(journal.phase == (filename == "committed.json" ? .complete : .prepared))

            if filename == "truncated-event.json" {
                var truncated = eventBytes
                truncated.removeLast()
                #expect(throws: PersistenceError.integrityViolation) {
                    try EventLog.decode(truncated)
                }
            }
            if filename == "tampered-state.json" {
                let tamperedBytes = Data(
                    fixture.stateBytes.replacingOccurrences(
                        of: "\"stage\":\"requirements\"",
                        with: "\"stage\":\"intake\""
                    ).utf8
                )
                let tampered = try CanonicalJSON.decode(RunState.self, from: tamperedBytes)
                #expect(try CanonicalJSON.encode(tampered) == tamperedBytes)
                #expect(CanonicalTreeDigest.sha256(tamperedBytes) != journal.targetStateDigest)
            }
        }
    }

    @Test("ambiguous journal bytes are integrity failures, never best-effort recovery")
    func ambiguousJournalFailsClosed() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        try Data("{\"schema_version\":1,\"phase\":\"prepared\"".utf8)
            .write(to: harness.paths.journalURL)
        #expect(throws: PersistenceError.integrityViolation) {
            try harness.makeStore().recover(runID: harness.runID, from: harness.paths.runRoot)
        }
    }

    @Test("coordinated state and event digest rewrite cannot preserve the original transaction identity")
    func coordinatedJournalTamperFailsClosed() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        harness.barrierTrace.reset()
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
        let originalBytes = try Data(contentsOf: harness.paths.journalURL)
        let original = try CanonicalJSON.decode(CommitJournalRecord.self, from: originalBytes)
        let substitutedStateBytes = try CanonicalJSON.encode(harness.initialState)
        let substitutedStateDigest = CanonicalTreeDigest.sha256(substitutedStateBytes)
        let substitutedEvent = try EventLogRecord(
            sequence: 1,
            previousDigest: nil,
            stateDigest: substitutedStateDigest,
            transactionDigest: original.transactionDigest,
            event: harness.event
        )
        var substitutedEventBytes = try CanonicalJSON.encode(substitutedEvent)
        substitutedEventBytes.append(0x0A)
        let malicious = CommitJournalRecord(
            schemaVersion: original.schemaVersion,
            phase: original.phase,
            runID: original.runID,
            transactionID: original.transactionID,
            transactionDigest: original.transactionDigest,
            expectedStateDigest: original.expectedStateDigest,
            expectedEventHead: original.expectedEventHead,
            targetStateDigest: substitutedStateDigest,
            targetEventHead: substitutedEvent.recordDigest,
            stateBytes: substitutedStateBytes,
            priorEventLogBytes: original.priorEventLogBytes,
            targetEventLogBytes: substitutedEventBytes,
            stateTemporaryName: original.stateTemporaryName,
            eventTemporaryName: original.eventTemporaryName,
            receipts: original.receipts,
            lease: original.lease
        )
        #expect(throws: PersistenceError.integrityViolation) {
            try malicious.validate()
        }
    }

    @Test("absence requires an exact empty reserved namespace")
    func absenceRejectsResidue() throws {
        for residue in ["event", "temporary", "receipt"] {
            let harness = try PersistenceHarness.make()
            defer { harness.remove() }
            switch residue {
            case "event":
                try Data("{}\n".utf8).write(to: harness.paths.eventLogURL)
            case "temporary":
                try Data("partial".utf8).write(
                    to: harness.paths.runRoot.appendingPathComponent(".state-residue.tmp")
                )
            default:
                let directory = harness.paths.receiptsRootURL
                    .appendingPathComponent("verification", isDirectory: true)
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
                try Data("{}".utf8).write(to: directory.appendingPathComponent("residue.json"))
            }
            #expect(throws: PersistenceError.integrityViolation) {
                try harness.makeStore().recover(
                    runID: harness.runID,
                    from: harness.paths.runRoot
                )
            }
        }
    }

    @Test("journal-controlled cleanup names are derived and cannot delete an unrelated exact copy")
    func journalCleanupNameIsIdentityBound() throws {
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
        let unrelatedURL = harness.paths.runRoot.appendingPathComponent("unrelated.json")
        try harness.transaction.stateBytes.write(to: unrelatedURL)
        try mutateCanonicalJSONObject(at: harness.paths.journalURL) { object in
            object["state_temporary_name"] = "unrelated.json"
        }
        #expect(throws: PersistenceError.integrityViolation) {
            try harness.makeStore().recover(runID: harness.runID, from: harness.paths.runRoot)
        }
        #expect(try Data(contentsOf: unrelatedURL) == harness.transaction.stateBytes)
    }
}

final class PersistenceMutationHitCounter: @unchecked Sendable {
    private let lock = NSLock()
    private let target: PersistenceMutationPoint
    private let failAtHit: Int
    private var hits = 0

    init(target: PersistenceMutationPoint, failAtHit: Int) {
        self.target = target
        self.failAtHit = failAtHit
    }

    func hit(_ point: PersistenceMutationPoint) throws {
        guard point == target else { return }
        let shouldFail = lock.withLock { () -> Bool in
            hits += 1
            return hits == failAtHit
        }
        if shouldFail {
            throw PersistenceError.injectedInterruption(point)
        }
    }
}

func makeMultiReceiptPersistenceTransaction(
    harness: PersistenceHarness
) throws -> StateTransaction {
    let writes = try [
        ReceiptTableWrite(
            kind: ReceiptKind(validating: "architecture-review"),
            id: ReceiptID(validating: "gate-02.3-multi-a"),
            value: PersistenceReceiptPayload(gate: "G02.3-multi-a", result: "passed")
        ),
        ReceiptTableWrite(
            kind: ReceiptKind(validating: "verification"),
            id: ReceiptID(validating: "gate-02.3-multi-b"),
            value: PersistenceReceiptPayload(gate: "G02.3-multi-b", result: "passed")
        ),
        ReceiptTableWrite(
            kind: ReceiptKind(validating: "verification"),
            id: ReceiptID(validating: "gate-02.3-multi-c"),
            value: PersistenceReceiptPayload(gate: "G02.3-multi-c", result: "passed")
        ),
    ]
    return try StateTransaction(
        id: TransactionID(rawValue: "txn-02.3-multi"),
        runRoot: harness.paths.runRoot,
        expectedStateDigest: nil,
        expectedEventHead: nil,
        state: harness.proposedState,
        event: harness.event,
        receiptWrites: writes
    )
}

func canonicalEventLogFixtureBytes(_ records: [EventLogRecord]) throws -> Data {
    try records.reduce(into: Data()) { bytes, record in
        bytes.append(try CanonicalJSON.encode(record))
        bytes.append(0x0A)
    }
}

func mutateCanonicalJSONObject(
    at url: URL,
    _ mutation: (inout [String: Any]) throws -> Void
) throws {
    var object = try #require(
        JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    )
    try mutation(&object)
    let bytes = try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
    try bytes.write(to: url)
}
