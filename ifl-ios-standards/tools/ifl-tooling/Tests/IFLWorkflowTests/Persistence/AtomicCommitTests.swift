import Darwin
import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("AtomicCommitTests")
struct AtomicCommitTests {
    @Test("state, event, and generic receipts become visible as one canonical transaction")
    func commitsCanonicalTransaction() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        harness.barrierTrace.reset()

        let store = try harness.makeStore()
        let receipt = try store.commit(harness.transaction, lease: harness.lease)
        let persisted = try store.load(runID: harness.runID, from: harness.paths.runRoot)

        #expect(receipt.isDurable)
        #expect(receipt.transactionID == harness.transaction.id)
        #expect(receipt.stateDigest == CanonicalTreeDigest.sha256(harness.transaction.stateBytes))
        #expect(persisted.state == harness.proposedState)
        #expect(persisted.stateBytes == harness.transaction.stateBytes)
        #expect(persisted.events.count == 1)
        #expect(persisted.events[0].event == harness.event)
        #expect(persisted.eventHead == receipt.eventHead)
        #expect(persisted.receipts.count == 1)
        #expect(persisted.receipts[0].payloadBytes == harness.transaction.receiptWrites[0].payloadBytes)
        #expect(Set(harness.barrierTrace.plans.map(\.purpose)).isSuperset(of: [
            .journalIntent, .receiptParent, .payloadPublication, .statePublication,
            .journalCompletion,
        ]))
        #expect(
            harness.barrierTrace.plans.filter { $0.purpose == .receiptParent }.count == 2
        )
    }

    @Test("generic receipt tables create validated mode-0700 ancestors")
    func createsReceiptAncestors() throws {
        let harness = try PersistenceHarness.make(
            receiptKind: try ReceiptKind(validating: "architecture-review"),
            receiptID: try ReceiptID(validating: "gate-02.3")
        )
        defer { harness.remove() }
        harness.barrierTrace.reset()

        _ = try harness.makeStore().commit(harness.transaction, lease: harness.lease)
        let receiptURL = try harness.paths.receiptURL(
            kind: harness.transaction.receiptWrites[0].kind,
            id: harness.transaction.receiptWrites[0].id
        )
        #expect(FileManager.default.fileExists(atPath: receiptURL.path))
        let parentAttributes = try FileManager.default.attributesOfItem(
            atPath: receiptURL.deletingLastPathComponent().path
        )
        #expect((parentAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        #expect(FileManager.default.fileExists(
            atPath: harness.paths.receiptProvenanceURL(kind: nil).path
        ))
        #expect(FileManager.default.fileExists(
            atPath: harness.paths.receiptProvenanceURL(
                kind: harness.transaction.receiptWrites[0].kind
            ).path
        ))
        let parentPlans = harness.barrierTrace.plans.filter { $0.purpose == .receiptParent }
        #expect(parentPlans.count == 2)
        #expect(parentPlans.allSatisfy { plan in
            plan.modified.filter { $0.kind == .regularFile }.count >= 2
        })
    }

    @Test("pre-existing receipt parents without authenticated provenance are rejected")
    func rejectsUnprovenReceiptParents() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        try FileManager.default.createDirectory(
            at: harness.paths.receiptsRootURL,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.createDirectory(
            at: harness.paths.receiptsRootURL.appendingPathComponent("verification"),
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )

        #expect(throws: PersistenceError.integrityViolation) {
            try harness.makeStore().commit(harness.transaction, lease: harness.lease)
        }
        #expect(!FileManager.default.fileExists(
            atPath: harness.paths.receiptProvenanceURL(kind: nil).path
        ))
    }

    @Test("receipt-parent provenance binds both the root and kind directory inodes")
    func rejectsReceiptParentInodeSubstitution() throws {
        for substituteKindDirectory in [false, true] {
            let harness = try PersistenceHarness.make()
            defer { harness.remove() }
            let store = try harness.makeStore()
            _ = try store.commit(harness.transaction, lease: harness.lease)

            let kind = harness.transaction.receiptWrites[0].kind
            let original = substituteKindDirectory
                ? harness.paths.receiptsRootURL.appendingPathComponent(kind.rawValue)
                : harness.paths.receiptsRootURL
            let displaced = harness.temporaryRoot.appendingPathComponent(
                "displaced-receipts-\(UUID().uuidString.lowercased())",
                isDirectory: true
            )
            try FileManager.default.moveItem(at: original, to: displaced)
            try FileManager.default.copyItem(at: displaced, to: original)

            #expect(throws: PersistenceError.integrityViolation) {
                try harness.makeStore().load(
                    runID: harness.runID,
                    from: harness.paths.runRoot
                )
            }
        }
    }

    @Test("a commit never returns a receipt before the final full durability barrier")
    func noReceiptBeforeFinalBarrier() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        harness.barrierTrace.reset(failAtPurpose: .journalCompletion)
        let store = try harness.makeStore()

        #expect(throws: DurabilityBarrierError.blockedEnvironment) {
            try store.commit(harness.transaction, lease: harness.lease)
        }
        #expect(harness.barrierTrace.plans.last?.purpose == .journalCompletion)

        harness.barrierTrace.reset()
        let recovery = try harness.makeStore().recover(
            runID: harness.runID,
            from: harness.paths.runRoot
        )
        #expect(recovery.disposition == .completed)
        #expect(harness.barrierTrace.plans.contains(where: { $0.purpose == .recoveryCompletion }))
        #expect(try harness.makeStore().load(
            runID: harness.runID,
            from: harness.paths.runRoot
        ).state == harness.proposedState)
        let replay = try harness.makeStore().commit(
            harness.transaction,
            lease: harness.lease
        )
        #expect(replay.transactionDigest == harness.transaction.digest)
    }

    @Test("same transaction is idempotent and a conflicting transaction ID fails closed")
    func transactionIdentityIsExact() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        harness.barrierTrace.reset()
        let store = try harness.makeStore()
        let first = try store.commit(harness.transaction, lease: harness.lease)
        let replay = try store.commit(harness.transaction, lease: harness.lease)
        #expect(first == replay)
        #expect(try store.load(runID: harness.runID, from: harness.paths.runRoot).events.count == 1)

        let conflicting = try StateTransaction(
            id: harness.transaction.id,
            runRoot: harness.paths.runRoot,
            expectedStateDigest: nil,
            expectedEventHead: nil,
            state: harness.initialState,
            event: harness.event,
            receiptWrites: harness.transaction.receiptWrites
        )
        #expect(throws: PersistenceError.transactionConflict) {
            try store.commit(conflicting, lease: harness.lease)
        }
    }

    @Test("idempotent replay still enforces fencing token and lease owner")
    func replayEnforcesFencing() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        harness.barrierTrace.reset()
        let store = try harness.makeStore()
        let authoritative = try WriterLease(
            runID: harness.runID,
            ownerID: "authoritative-writer",
            fencingToken: try FencingToken(validating: 2),
            issuedAt: harness.now.addingTimeInterval(-10),
            expiresAt: harness.now.addingTimeInterval(300)
        )
        _ = try store.commit(harness.transaction, lease: authoritative)

        let stale = try WriterLease(
            runID: harness.runID,
            ownerID: "authoritative-writer",
            fencingToken: try FencingToken(validating: 1),
            issuedAt: harness.now.addingTimeInterval(-10),
            expiresAt: harness.now.addingTimeInterval(300)
        )
        #expect(throws: PersistenceError.fencingViolation) {
            try store.commit(harness.transaction, lease: stale)
        }
        let stolenEqualToken = try WriterLease(
            runID: harness.runID,
            ownerID: "different-writer",
            fencingToken: try FencingToken(validating: 2),
            issuedAt: harness.now.addingTimeInterval(-10),
            expiresAt: harness.now.addingTimeInterval(300)
        )
        #expect(throws: PersistenceError.fencingViolation) {
            try store.commit(harness.transaction, lease: stolenEqualToken)
        }
    }

    @Test("receipt table remains complete across successive state transactions")
    func receiptTableAccumulates() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        harness.barrierTrace.reset()
        let store = try harness.makeStore()
        let first = try store.commit(harness.transaction, lease: harness.lease)

        let secondEvent = try WorkflowEvent(
            id: "persistence-requirements",
            kind: .requirementsSubmitted
        )
        let secondContext = try TransitionContext(
            actorID: ActorID(validating: "persistence-author"),
            principalID: PrincipalID(validating: "persistence-principal"),
            currentEventHead: first.eventHead,
            satisfiedGuards: [.requirementsSubmitted]
        )
        let secondState = try WorkflowReducer().decide(
            definition: EngineeringWorkflow.definition,
            state: harness.proposedState,
            event: secondEvent,
            context: secondContext
        ).proposedState
        let secondWrite = try ReceiptTableWrite(
            kind: ReceiptKind(validating: "verification"),
            id: ReceiptID(validating: "gate-02.3-second"),
            value: PersistenceReceiptPayload(gate: "G02.3-second", result: "passed")
        )
        let secondTransaction = try StateTransaction(
            id: TransactionID(rawValue: "txn-02.3-second"),
            runRoot: harness.paths.runRoot,
            expectedStateDigest: first.stateDigest,
            expectedEventHead: first.eventHead,
            state: secondState,
            event: secondEvent,
            receiptWrites: [secondWrite]
        )
        _ = try store.commit(secondTransaction, lease: harness.lease)
        let persisted = try store.load(runID: harness.runID, from: harness.paths.runRoot)
        #expect(persisted.events.count == 2)
        #expect(Set(persisted.receipts.map(\.id.rawValue)) == ["gate-02.3", "gate-02.3-second"])
    }

    @Test("unexpected deterministic temp bytes are preserved and fail closed")
    func tempCollisionPreservesUnrelatedBytes() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        let collision = harness.paths.runRoot
            .appendingPathComponent(harness.transaction.stateTemporaryFilename)
        let unrelated = Data("unrelated-owner-bytes".utf8)
        try unrelated.write(to: collision)

        #expect(throws: PersistenceError.integrityViolation) {
            try harness.makeStore().commit(harness.transaction, lease: harness.lease)
        }
        #expect(try Data(contentsOf: collision) == unrelated)
    }

    @Test("serialized load recovers a prepared transaction instead of calling it tamper")
    func loadSerializesWithRecovery() throws {
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
        #expect(throws: PersistenceError.notFound) {
            try harness.makeStore().load(runID: harness.runID, from: harness.paths.runRoot)
        }
        #expect(!FileManager.default.fileExists(atPath: harness.paths.journalURL.path))
    }

    @Test("completed epochs support old exact replay while rejecting A-B-A ID reuse")
    func historicalTransactionIdentityIsPermanent() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        let store = try harness.makeStore()
        let first = try store.commit(harness.transaction, lease: harness.lease)
        let second = try makeSecondPersistenceTransaction(harness: harness, after: first)
        let secondReceipt = try store.commit(second.transaction, lease: harness.lease)

        #expect(FileManager.default.fileExists(
            atPath: harness.paths.epochURL(for: harness.transaction.digest).path
        ))
        #expect(FileManager.default.fileExists(
            atPath: harness.paths.epochURL(for: second.transaction.digest).path
        ))
        #expect(try store.commit(harness.transaction, lease: harness.lease) == first)

        let pauseEvent = try WorkflowEvent(id: "persistence-pause", kind: .pause)
        let pauseContext = try TransitionContext(
            actorID: ActorID(validating: "persistence-author"),
            principalID: PrincipalID(validating: "persistence-principal"),
            currentEventHead: secondReceipt.eventHead,
            satisfiedGuards: []
        )
        let pausedState = try WorkflowReducer().decide(
            definition: EngineeringWorkflow.definition,
            state: second.state,
            event: pauseEvent,
            context: pauseContext
        ).proposedState
        let conflicting = try StateTransaction(
            id: harness.transaction.id,
            runRoot: harness.paths.runRoot,
            expectedStateDigest: secondReceipt.stateDigest,
            expectedEventHead: secondReceipt.eventHead,
            state: pausedState,
            event: pauseEvent,
            receiptWrites: [
                try ReceiptTableWrite(
                    kind: ReceiptKind(validating: "verification"),
                    id: ReceiptID(validating: "gate-02.3-third"),
                    value: PersistenceReceiptPayload(gate: "G02.3-third", result: "passed")
                ),
            ]
        )
        #expect(throws: PersistenceError.transactionConflict) {
            try store.commit(conflicting, lease: harness.lease)
        }
    }

    @Test("visible completion is re-barriered with its journal and run root before unchanged or replay")
    func visibleCompletionRequiresRestartProof() throws {
        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        let committed = try harness.makeStore().commit(
            harness.transaction,
            lease: harness.lease
        )

        harness.barrierTrace.reset()
        let recovery = try harness.makeStore().recover(
            runID: harness.runID,
            from: harness.paths.runRoot
        )
        #expect(recovery.disposition == .unchanged)
        try requireCompletionProof(in: harness.barrierTrace, paths: harness.paths)

        harness.barrierTrace.reset()
        let replay = try harness.makeStore().commit(
            harness.transaction,
            lease: harness.lease
        )
        #expect(replay == committed)
        try requireCompletionProof(in: harness.barrierTrace, paths: harness.paths)
    }

    @Test("public construction permits exact absence but rejects history without authority")
    func productionConstructionIsClosed() throws {
        let constructor: (RunPaths) throws -> FileRunStateStore = FileRunStateStore.init(paths:)
        _ = constructor

        let empty = try PersistenceHarness.make()
        defer { empty.remove() }
        let emptyStore = try FileRunStateStore(paths: empty.paths)
        #expect(throws: PersistenceError.notFound) {
            try emptyStore.load(runID: empty.runID, from: empty.paths.runRoot)
        }

        let historical = try PersistenceHarness.make()
        defer { historical.remove() }
        _ = try historical.makeStore().commit(
            historical.transaction,
            lease: historical.lease
        )
        #expect(throws: PersistenceError.integrityViolation) {
            try FileRunStateStore(paths: historical.paths)
        }
    }
}

private func requireCompletionProof(in trace: TestBarrierTrace, paths: RunPaths) throws {
    let proof = try #require(
        trace.plans.last(where: { $0.purpose == .recoveryCompletion })
    )
    #expect(proof.requiredDirectoryFDs.count >= 1)
    #expect(proof.modified.filter { $0.kind == .directory }.count >= 1)
    #expect(proof.modified.filter { $0.kind == .regularFile }.count >= 2)
    let rootInode = try #require(
        FileManager.default.attributesOfItem(atPath: paths.runRoot.path)[.systemFileNumber]
            as? NSNumber
    ).uint64Value
    let journalInode = try #require(
        FileManager.default.attributesOfItem(atPath: paths.journalURL.path)[.systemFileNumber]
            as? NSNumber
    ).uint64Value
    let barrierInodes = Set(proof.modified.compactMap { target -> UInt64? in
        var value = stat()
        guard fstat(target.fd, &value) == 0 else { return nil }
        return UInt64(value.st_ino)
    })
    #expect(barrierInodes.contains(rootInode))
    #expect(barrierInodes.contains(journalInode))
}

struct PersistenceHarness {
    let temporaryRoot: URL
    let workItemRoot: URL
    let runID: RunID
    let paths: RunPaths
    let barrierTrace: TestBarrierTrace
    let initialState: RunState
    let proposedState: RunState
    let event: WorkflowEvent
    let transaction: StateTransaction
    let lease: WriterLease
    let now: Date

    static func make(
        receiptKind: ReceiptKind = try! ReceiptKind(validating: "verification"),
        receiptID: ReceiptID = try! ReceiptID(validating: "gate-02.3")
    ) throws -> PersistenceHarness {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ifl-persistence-\(UUID().uuidString)", isDirectory: true)
        let workItemRoot = temporaryRoot.appendingPathComponent("work-item", isDirectory: true)
        try FileManager.default.createDirectory(
            at: workItemRoot,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let runID = RunID(rawValue: UUID())
        let trace = TestBarrierTrace()
        let barrier = TestDurabilityBarrier(trace: trace)
        let paths = try RunPaths.prepareForTesting(
            workItemRoot: workItemRoot,
            runID: runID,
            barrier: barrier
        )
        let initial = try RunState.startEngineering(
            runID: runID,
            workItemID: "IIS-0002",
            mode: .auto,
            canonSnapshotDigest: try HashDigest(validating: String(repeating: "a", count: 64))
        )
        let event = try WorkflowEvent(id: "persistence-intake", kind: .intakeRecorded)
        let context = try TransitionContext(
            actorID: ActorID(validating: "persistence-author"),
            principalID: PrincipalID(validating: "persistence-principal"),
            currentEventHead: try HashDigest(validating: String(repeating: "b", count: 64)),
            satisfiedGuards: [.intakeRecorded]
        )
        let proposed = try WorkflowReducer().decide(
            definition: EngineeringWorkflow.definition,
            state: initial,
            event: event,
            context: context
        ).proposedState
        let write = try ReceiptTableWrite(
            kind: receiptKind,
            id: receiptID,
            value: PersistenceReceiptPayload(gate: "G02.3", result: "passed")
        )
        let transaction = try StateTransaction(
            id: TransactionID(rawValue: "txn-02.3-atomic"),
            runRoot: paths.runRoot,
            expectedStateDigest: nil,
            expectedEventHead: nil,
            state: proposed,
            event: event,
            receiptWrites: [write]
        )
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let lease = try WriterLease(
            runID: runID,
            ownerID: "agent-persistence",
            fencingToken: try FencingToken(validating: 1),
            issuedAt: now.addingTimeInterval(-10),
            expiresAt: now.addingTimeInterval(300)
        )
        return PersistenceHarness(
            temporaryRoot: temporaryRoot,
            workItemRoot: workItemRoot,
            runID: runID,
            paths: paths,
            barrierTrace: trace,
            initialState: initial,
            proposedState: proposed,
            event: event,
            transaction: transaction,
            lease: lease,
            now: now
        )
    }

    func makeStore(
        faultInjector: PersistenceFaultInjector = .none,
        trustedFact: TrustedRunFact? = nil
    ) throws -> FileRunStateStore {
        try FileRunStateStore.testing(
            paths: paths,
            barrier: TestDurabilityBarrier(trace: barrierTrace),
            faultInjector: faultInjector,
            clock: { now },
            trustedFact: trustedFact
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }
}

struct PersistenceReceiptPayload: Codable, Equatable {
    let gate: String
    let result: String
}

final class TestBarrierTrace: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedPlans: [DurabilityPlan] = []
    private var failurePlan: Int?
    private var failurePurpose: DurabilityPurpose?

    var plans: [DurabilityPlan] {
        lock.withLock { recordedPlans }
    }

    func reset(
        failAtPlan: Int? = nil,
        failAtPurpose: DurabilityPurpose? = nil
    ) {
        lock.withLock {
            recordedPlans = []
            failurePlan = failAtPlan
            failurePurpose = failAtPurpose
        }
    }

    func record(_ plan: DurabilityPlan) throws {
        let shouldFail = lock.withLock { () -> Bool in
            recordedPlans.append(plan)
            return failurePlan == recordedPlans.count || failurePurpose == plan.purpose
        }
        if shouldFail { throw DurabilityBarrierError.blockedEnvironment }
    }
}

struct TestDurabilityBarrier: WorkflowDurabilityBarrier {
    let trace: TestBarrierTrace

    func validateCapability(in directoryFD: Int32) throws {}

    func synchronize(_ plan: DurabilityPlan) throws {
        try trace.record(plan)
    }
}

struct PersistenceFixtureManifest: Codable, Equatable {
    let schemaVersion: Int
    let scenario: String
    let faultPoint: String?
    let expectedDisposition: String
    let runID: String
    let transactionID: String
    let writerOwner: String
    let fencingToken: UInt64
    let issuedAtUnixMicroseconds: Int64
    let stateBytes: String
    let stateSHA256: String
    let eventNDJSON: String
    let eventHead: String
    let receiptBytes: String
    let receiptSHA256: String
    let journalBytes: String
    let journalSHA256: String

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case scenario
        case faultPoint = "fault_point"
        case expectedDisposition = "expected_disposition"
        case runID = "run_id"
        case transactionID = "transaction_id"
        case writerOwner = "writer_owner"
        case fencingToken = "fencing_token"
        case issuedAtUnixMicroseconds = "issued_at_unix_microseconds"
        case stateBytes = "state_bytes"
        case stateSHA256 = "state_sha256"
        case eventNDJSON = "event_ndjson"
        case eventHead = "event_head"
        case receiptBytes = "receipt_bytes"
        case receiptSHA256 = "receipt_sha256"
        case journalBytes = "journal_bytes"
        case journalSHA256 = "journal_sha256"
    }
}

struct SecondPersistenceTransaction {
    let transaction: StateTransaction
    let state: RunState
}

func makeSecondPersistenceTransaction(
    harness: PersistenceHarness,
    after first: CommitReceipt
) throws -> SecondPersistenceTransaction {
    let event = try WorkflowEvent(id: "persistence-requirements", kind: .requirementsSubmitted)
    let context = try TransitionContext(
        actorID: ActorID(validating: "persistence-author"),
        principalID: PrincipalID(validating: "persistence-principal"),
        currentEventHead: first.eventHead,
        satisfiedGuards: [.requirementsSubmitted]
    )
    let state = try WorkflowReducer().decide(
        definition: EngineeringWorkflow.definition,
        state: harness.proposedState,
        event: event,
        context: context
    ).proposedState
    let write = try ReceiptTableWrite(
        kind: ReceiptKind(validating: "verification"),
        id: ReceiptID(validating: "gate-02.3-second"),
        value: PersistenceReceiptPayload(gate: "G02.3-second", result: "passed")
    )
    return try SecondPersistenceTransaction(
        transaction: StateTransaction(
            id: TransactionID(rawValue: "txn-02.3-second"),
            runRoot: harness.paths.runRoot,
            expectedStateDigest: first.stateDigest,
            expectedEventHead: first.eventHead,
            state: state,
            event: event,
            receiptWrites: [write]
        ),
        state: state
    )
}

func persistenceFixture(_ filename: String) throws -> PersistenceFixtureManifest {
    try CanonicalJSON.decode(
        PersistenceFixtureManifest.self,
        from: persistenceFixtureData(filename)
    )
}

func persistenceFixtureData(_ filename: String) throws -> Data {
    var root = URL(fileURLWithPath: #filePath)
    while root.lastPathComponent != "ifl-ios-standards", root.path != "/" {
        root.deleteLastPathComponent()
    }
    let url = root
        .appendingPathComponent("verification/fixtures/workflow/persistence")
        .appendingPathComponent(filename)
    return try Data(contentsOf: url)
}
