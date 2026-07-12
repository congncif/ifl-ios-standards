import Foundation
import IFLContracts

public enum ReviewPublicationKind: String, CaseIterable, Hashable, Sendable {
    case inventoryRecorded = "inventory_recorded"
    case inventoryClosed = "inventory_closed"
    case remediationRecorded = "remediation_recorded"
    case confirmationRecorded = "confirmation_recorded"
    case exceptionOpened = "exception_opened"
    case converged
    case invalidated
}

/// Canonical pre-commit receipt plan. This type may authorize transaction construction, but never
/// persisted lineage; only `VerifiedPublishedReviewReceipt` carries committed provenance.
public struct VerifiedReviewReceipt: Hashable, Sendable {
    public let kind: ReceiptKind
    public let id: ReceiptID
    public let payloadBytes: Data
    public let payloadDigest: HashDigest
    public let runID: RunID
    public let eventID: String
    public let eventKind: WorkflowEventKind
    public let eventHead: HashDigest

    init(
        kind: ReceiptKind,
        id: ReceiptID,
        payloadBytes: Data,
        payloadDigest: HashDigest,
        runID: RunID,
        eventID: String,
        eventKind: WorkflowEventKind,
        eventHead: HashDigest
    ) {
        self.kind = kind
        self.id = id
        self.payloadBytes = payloadBytes
        self.payloadDigest = payloadDigest
        self.runID = runID
        self.eventID = eventID
        self.eventKind = eventKind
        self.eventHead = eventHead
    }
}

/// Receipt authority minted only from one exact committed receipt-table entry and its unique
/// owning record on the active event chain. Canonical payload bytes alone never create this type.
public struct VerifiedPublishedReviewReceipt: Hashable, Sendable {
    public let kind: ReceiptKind
    public let id: ReceiptID
    public let payloadBytes: Data
    public let payloadDigest: HashDigest
    public let runID: RunID
    public let eventID: String
    public let eventKind: WorkflowEventKind
    public let transactionID: TransactionID
    public let transactionDigest: HashDigest
    public let publicationAnchorEventHead: HashDigest?
    public let producedEventHead: HashDigest
    let receipt: PersistedReceipt
    let manifestEntry: ReceiptManifestEntry
    let owningRecord: EventLogRecord

    init(
        receipt: PersistedReceipt,
        manifestEntry: ReceiptManifestEntry,
        owningRecord: EventLogRecord
    ) {
        kind = receipt.kind
        id = receipt.id
        payloadBytes = receipt.payloadBytes
        payloadDigest = receipt.payloadDigest
        runID = owningRecord.runID
        eventID = owningRecord.event.id
        eventKind = owningRecord.event.kind
        transactionID = receipt.transactionID
        transactionDigest = receipt.transactionDigest
        publicationAnchorEventHead = owningRecord.previousDigest
        producedEventHead = owningRecord.recordDigest
        self.receipt = receipt
        self.manifestEntry = manifestEntry
        self.owningRecord = owningRecord
    }
}

/// Durable trace of one review publication. Planned publication capability is intentionally not
/// exposed; the receipt authorities are reconstructed from the post-commit active chain.
public struct ReviewPublicationCommit: Sendable {
    public let transaction: StateTransaction
    public let commitReceipt: CommitReceipt
    public let receipts: [VerifiedPublishedReviewReceipt]
    public let committedRemediationSuccessor: VerifiedCommittedRemediationSuccessor?

    init(
        transaction: StateTransaction,
        commitReceipt: CommitReceipt,
        receipts: [VerifiedPublishedReviewReceipt],
        committedRemediationSuccessor: VerifiedCommittedRemediationSuccessor? = nil
    ) {
        self.transaction = transaction
        self.commitReceipt = commitReceipt
        self.receipts = receipts
        self.committedRemediationSuccessor = committedRemediationSuccessor
    }
}

enum ReviewReceiptVerifier {
    static func verify(
        kind: ReceiptKind,
        id: ReceiptID,
        payloadBytes: Data,
        runID: RunID,
        eventID: String,
        eventKind: WorkflowEventKind,
        eventHead: HashDigest
    ) throws -> VerifiedReviewReceipt {
        guard WorkflowIdentifier.isValid(eventID), eventKind.isReviewPublicationEvent else {
            throw PersistenceError.integrityViolation
        }
        let write = try ReceiptTableWrite(
            kind: kind,
            id: id,
            canonicalPayloadBytes: payloadBytes
        )
        return VerifiedReviewReceipt(
            kind: kind,
            id: id,
            payloadBytes: write.payloadBytes,
            payloadDigest: write.payloadDigest,
            runID: runID,
            eventID: eventID,
            eventKind: eventKind,
            eventHead: eventHead
        )
    }
}

enum ReviewCommittedReceiptVerifier {
    static func verify(
        id: ReceiptID,
        kind: ReceiptKind,
        digest: HashDigest? = nil,
        in persistedRun: PersistedRun
    ) throws -> VerifiedPublishedReviewReceipt {
        try validateActiveChain(persistedRun)
        let receipts = persistedRun.receipts.filter { receipt in
            receipt.id == id && receipt.kind == kind &&
                (digest.map { receipt.payloadDigest == $0 } ?? true)
        }
        guard receipts.count == 1, let receipt = receipts.first,
              receipt.payloadDigest == CanonicalTreeDigest.sha256(receipt.payloadBytes)
        else { throw PersistenceError.integrityViolation }

        let owners = try persistedRun.events.compactMap { record -> (
            EventLogRecord,
            ReceiptManifestEntry
        )? in
            let entries = record.receiptManifest.filter { entry in
                entry.id == id && entry.kind == kind &&
                    (digest.map { entry.payloadDigest == $0 } ?? true)
            }
            guard entries.count <= 1 else { throw PersistenceError.integrityViolation }
            guard let entry = entries.first else { return nil }
            let envelope = try entry.validatedEnvelope(
                transactionID: record.transactionID,
                transactionDigest: record.transactionDigest
            )
            guard envelope.payloadBytes == receipt.payloadBytes,
                  envelope.payloadDigest == receipt.payloadDigest
            else { throw PersistenceError.integrityViolation }
            return (record, entry)
        }
        guard owners.count == 1, let owner = owners.first,
              receipt.transactionID == owner.0.transactionID,
              receipt.transactionDigest == owner.0.transactionDigest,
              owner.0.runID == persistedRun.state.runID,
              owner.1.payloadDigest == receipt.payloadDigest
        else { throw PersistenceError.integrityViolation }
        return VerifiedPublishedReviewReceipt(
            receipt: receipt,
            manifestEntry: owner.1,
            owningRecord: owner.0
        )
    }

    /// Shared persisted-snapshot gate. Authority verifiers call this even when no semantic receipt
    /// marker exists, so an empty confirmation slot can never bypass active-chain integrity.
    static func validateActiveChain(_ persistedRun: PersistedRun) throws {
        guard !persistedRun.events.isEmpty,
              persistedRun.events.last?.recordDigest == persistedRun.eventHead,
              persistedRun.events.last?.stateDigest == persistedRun.stateDigest,
              persistedRun.stateBytes == (try CanonicalJSON.encode(persistedRun.state)),
              persistedRun.stateDigest == CanonicalTreeDigest.sha256(persistedRun.stateBytes),
              persistedRun.state.processedEvents.count == persistedRun.events.count
        else { throw PersistenceError.integrityViolation }
        var transactionIDs: Set<TransactionID> = []
        var manifestAddresses: Set<String> = []
        for (index, record) in persistedRun.events.enumerated() {
            let predecessor = index == 0 ? nil : persistedRun.events[index - 1]
            let processed = persistedRun.state.processedEvents[index]
            guard record.sequence == UInt64(index + 1),
                  record.runID == persistedRun.state.runID,
                  record.previousDigest == predecessor?.recordDigest,
                  record.previousStateDigest == predecessor?.stateDigest,
                  transactionIDs.insert(record.transactionID).inserted,
                  processed.id == record.event.id,
                  processed.kind == record.event.kind,
                  processed.candidateGenerationID == record.event.candidateGenerationID,
                  processed.eventDigest == CanonicalTreeDigest.sha256(record.eventBytes)
            else { throw PersistenceError.integrityViolation }
            if let predecessor {
                guard record.fencingToken >= predecessor.fencingToken,
                      record.fencingToken != predecessor.fencingToken ||
                        record.writerOwnerID == predecessor.writerOwnerID
                else { throw PersistenceError.integrityViolation }
            }
            for entry in record.receiptManifest {
                let address = "\(entry.kind.rawValue)/\(entry.id.rawValue)"
                guard manifestAddresses.insert(address).inserted else {
                    throw PersistenceError.integrityViolation
                }
                _ = try entry.validatedEnvelope(
                    transactionID: record.transactionID,
                    transactionDigest: record.transactionDigest
                )
            }
        }

        let persistedAddresses = persistedRun.receipts.map {
            "\($0.kind.rawValue)/\($0.id.rawValue)"
        }
        guard Set(persistedAddresses).count == persistedAddresses.count,
              Set(persistedAddresses) == manifestAddresses
        else { throw PersistenceError.integrityViolation }
        for receipt in persistedRun.receipts {
            let owners = persistedRun.events.compactMap { record -> (
                EventLogRecord,
                ReceiptManifestEntry
            )? in
                record.receiptManifest.first {
                    $0.kind == receipt.kind && $0.id == receipt.id
                }.map { (record, $0) }
            }
            guard owners.count == 1, let owner = owners.first else {
                throw PersistenceError.integrityViolation
            }
            let envelope = try owner.1.validatedEnvelope(
                transactionID: owner.0.transactionID,
                transactionDigest: owner.0.transactionDigest
            )
            guard receipt.transactionID == owner.0.transactionID,
                  receipt.transactionDigest == owner.0.transactionDigest,
                  receipt.payloadDigest == owner.1.payloadDigest,
                  receipt.payloadDigest == CanonicalTreeDigest.sha256(receipt.payloadBytes),
                  envelope.payloadDigest == receipt.payloadDigest,
                  envelope.payloadBytes == receipt.payloadBytes
            else { throw PersistenceError.integrityViolation }
        }
    }
}

fileprivate struct ReviewPublicationPreimage: Sendable {
    let kind: ReviewPublicationKind
    let sourceState: RunState
    let event: WorkflowEvent
    let proposedState: RunState
    let eventHead: HashDigest
    let receipts: [VerifiedReviewReceipt]
    let invalidationPlan: ReviewInvalidationPlan?

    init(
        kind: ReviewPublicationKind,
        sourceState: RunState,
        event: WorkflowEvent,
        proposedState: RunState,
        eventHead: HashDigest,
        receipts: [VerifiedReviewReceipt],
        invalidationPlan: ReviewInvalidationPlan? = nil
    ) {
        self.kind = kind
        self.sourceState = sourceState
        self.event = event
        self.proposedState = proposedState
        self.eventHead = eventHead
        self.receipts = receipts
        if let invalidationPlan {
            self.invalidationPlan = invalidationPlan
        } else if kind == .invalidated,
                  let receipt = receipts.first(where: {
                      $0.kind.rawValue == "review-invalidation"
                  }) {
            self.invalidationPlan = try? ReviewInvalidationPlan.decodeCanonical(
                from: receipt.payloadBytes
            )
        } else {
            self.invalidationPlan = nil
        }
    }
}

public struct VerifiedReviewPublication: Sendable {
    public let kind: ReviewPublicationKind
    public let event: WorkflowEvent
    public let proposedState: RunState
    public let receipts: [VerifiedReviewReceipt]
    public let invalidationPlan: ReviewInvalidationPlan?
    let sourceState: RunState
    let eventHead: HashDigest

    fileprivate init(preimage: ReviewPublicationPreimage, receipts: [VerifiedReviewReceipt]) {
        kind = preimage.kind
        sourceState = preimage.sourceState
        event = preimage.event
        proposedState = preimage.proposedState
        eventHead = preimage.eventHead
        self.receipts = receipts
        invalidationPlan = preimage.invalidationPlan
    }
}

fileprivate enum ReviewPublicationVerifier {
    fileprivate static func verify(
        _ preimage: ReviewPublicationPreimage,
        additionalRequiredReceiptAddresses: [ReviewReceiptAddress] = [],
        exceptionAdmission: VerifiedReviewExceptionAdmission? = nil
    ) throws -> VerifiedReviewPublication {
        let expectedEventKind = reviewEventKind(preimage.kind)
        let semanticReceiptID = preimage.receipts.first?.id
        let expectedEventID = try reviewEventID(
            preimage.kind,
            eventHead: preimage.eventHead,
            semanticReceiptID: semanticReceiptID
        )
        guard preimage.event.kind == expectedEventKind,
              preimage.event.id == expectedEventID,
              preimage.event.candidateGenerationID == nil,
              preimage.event.reviewRound == nil,
              (preimage.kind == .invalidated) == (preimage.invalidationPlan != nil),
              (preimage.kind == .exceptionOpened) == (exceptionAdmission != nil),
              preimage.sourceState.runID == preimage.proposedState.runID,
              preimage.receipts.allSatisfy({ $0.runID == preimage.sourceState.runID }),
              try hasExactReviewStateTransition(
                  preimage,
                  exceptionAdmission: exceptionAdmission
              )
        else { throw PersistenceError.integrityViolation }

        let expectedAddresses = try (requiredReceiptAddresses(
            preimage.kind,
            eventHead: preimage.eventHead,
            semanticReceiptID: semanticReceiptID
        ) + additionalRequiredReceiptAddresses).sorted()
        let sortedReceipts = preimage.receipts.sorted(by: verifiedReviewReceiptOrder)
        let addresses = sortedReceipts.map { ReviewReceiptAddress(kind: $0.kind, id: $0.id) }
        guard addresses == expectedAddresses,
              Set(addresses).count == addresses.count,
              sortedReceipts.allSatisfy({ receipt in
                  receipt.runID == preimage.sourceState.runID &&
                      receipt.eventID == preimage.event.id &&
                      receipt.eventKind == preimage.event.kind &&
                      receipt.eventHead == preimage.eventHead &&
                      receipt.payloadDigest == CanonicalTreeDigest.sha256(receipt.payloadBytes)
              })
        else { throw PersistenceError.integrityViolation }
        for receipt in sortedReceipts {
            _ = try ReceiptTableWrite(
                kind: receipt.kind,
                id: receipt.id,
                canonicalPayloadBytes: receipt.payloadBytes
            )
        }
        guard try hasSemanticReceiptClosure(sortedReceipts, publication: preimage) else {
            throw PersistenceError.integrityViolation
        }
        return VerifiedReviewPublication(preimage: preimage, receipts: sortedReceipts)
    }

    static func verifyPublished(
        publication: VerifiedReviewPublication,
        transaction: StateTransaction,
        persistedRun: PersistedRun
    ) throws -> [VerifiedPublishedReviewReceipt] {
        guard let expectedStateDigest = transaction.expectedStateDigest,
              let expectedEventHead = transaction.expectedEventHead
        else { throw PersistenceError.integrityViolation }
        let expectedTransaction = try ReviewPublicationTransaction.make(
            publication: publication,
            runRoot: transaction.runRoot,
            expectedStateDigest: expectedStateDigest,
            expectedEventHead: expectedEventHead
        )
        guard expectedTransaction == transaction,
              expectedStateDigest == CanonicalTreeDigest.sha256(
                try CanonicalJSON.encode(publication.sourceState)
              ),
              expectedEventHead == publication.eventHead,
              transaction.state == publication.proposedState,
              transaction.event == publication.event
        else { throw PersistenceError.integrityViolation }

        let expectedWrites = transaction.receiptWrites.sorted(by: receiptWriteOrder)
        let plannedWrites = try publication.receipts.map { receipt in
            try ReceiptTableWrite(
                kind: receipt.kind,
                id: receipt.id,
                canonicalPayloadBytes: receipt.payloadBytes
            )
        }.sorted(by: receiptWriteOrder)
        guard expectedWrites == plannedWrites else {
            throw PersistenceError.integrityViolation
        }

        let owningRecords = persistedRun.events.filter {
            $0.transactionID == transaction.id && $0.transactionDigest == transaction.digest
        }
        guard owningRecords.count == 1, let owningRecord = owningRecords.first,
              owningRecord.previousDigest == expectedEventHead,
              owningRecord.previousStateDigest == expectedStateDigest,
              owningRecord.stateDigest == CanonicalTreeDigest.sha256(transaction.stateBytes),
              owningRecord.event == transaction.event,
              owningRecord.recordDigest != expectedEventHead
        else { throw PersistenceError.integrityViolation }

        let expectedManifest = expectedWrites.map {
            ReviewPublishedReceiptClosure(
                kind: $0.kind,
                id: $0.id,
                payloadDigest: $0.payloadDigest,
                payloadBytes: $0.payloadBytes
            )
        }.sorted()
        let manifestProjection = owningRecord.receiptManifest.map {
            ReviewPublishedReceiptManifest(
                kind: $0.kind,
                id: $0.id,
                payloadDigest: $0.payloadDigest
            )
        }.sorted()
        let expectedManifestProjection = expectedManifest.map {
            ReviewPublishedReceiptManifest(
                kind: $0.kind,
                id: $0.id,
                payloadDigest: $0.payloadDigest
            )
        }.sorted()
        guard manifestProjection == expectedManifestProjection else {
            throw PersistenceError.integrityViolation
        }

        let transactionReceipts = persistedRun.receipts.filter {
            $0.transactionID == transaction.id && $0.transactionDigest == transaction.digest
        }.map {
            ReviewPublishedReceiptClosure(
                kind: $0.kind,
                id: $0.id,
                payloadDigest: $0.payloadDigest,
                payloadBytes: $0.payloadBytes
            )
        }.sorted()
        guard transactionReceipts == expectedManifest else {
            throw PersistenceError.integrityViolation
        }

        return try expectedWrites.map { write in
            let published = try ReviewCommittedReceiptVerifier.verify(
                id: write.id,
                kind: write.kind,
                digest: write.payloadDigest,
                in: persistedRun
            )
            guard published.owningRecord == owningRecord,
                  published.publicationAnchorEventHead == expectedEventHead,
                  published.producedEventHead == owningRecord.recordDigest
            else { throw PersistenceError.integrityViolation }
            return published
        }
    }
}

private struct ReviewPublishedReceiptManifest: Hashable, Comparable {
    let kind: ReceiptKind
    let id: ReceiptID
    let payloadDigest: HashDigest

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.kind.rawValue, lhs.id.rawValue, lhs.payloadDigest.rawValue) <
            (rhs.kind.rawValue, rhs.id.rawValue, rhs.payloadDigest.rawValue)
    }
}

private struct ReviewPublishedReceiptClosure: Hashable, Comparable {
    let kind: ReceiptKind
    let id: ReceiptID
    let payloadDigest: HashDigest
    let payloadBytes: Data

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.kind.rawValue, lhs.id.rawValue) < (rhs.kind.rawValue, rhs.id.rawValue)
    }
}

private func receiptWriteOrder(_ lhs: ReceiptTableWrite, _ rhs: ReceiptTableWrite) -> Bool {
    (lhs.kind.rawValue, lhs.id.rawValue) < (rhs.kind.rawValue, rhs.id.rawValue)
}

private struct ReviewPublicationReceiptContent: Sendable {
    let kind: ReceiptKind
    let id: ReceiptID
    let payloadBytes: Data

    init(kind: String, id: String, payloadBytes: Data) throws {
        self.kind = try ReceiptKind(validating: kind)
        self.id = try ReceiptID(validating: id)
        self.payloadBytes = payloadBytes
    }
}

/// Production composition root for review publications. Every operation loads the exact source
/// snapshot, derives one closed transaction from sealed semantic facts, commits it once, and
/// returns only receipt authority recovered from the committed active chain.
public struct ReviewPublicationOperations: Sendable {
    private let store: any RunStateStore
    private let reducer: any WorkflowReducing

    public init(
        store: any RunStateStore,
        reducer: any WorkflowReducing = WorkflowReducer()
    ) {
        self.store = store
        self.reducer = reducer
    }

    public func publishInventoryRecorded(
        baseline: ReviewBaseline,
        inventory: ReviewerFindingInventory,
        authority: VerifiedReviewerInventoryAuthority,
        publisher: VerifiedAuthorityFact,
        runRoot: URL,
        lease: WriterLease
    ) throws -> ReviewPublicationCommit {
        let source = try loadSource(
            runID: baseline.runID,
            runRoot: runRoot,
            publisher: publisher
        )
        try requireCurrentRound(baseline, in: source)
        let payloadBytes = try CanonicalJSON.encode(inventory)
        guard authority.currentEventHead == source.eventHead,
              try ReviewSemanticIngress.verifyInventory(
                  bytes: payloadBytes,
                  baseline: baseline,
                  authority: authority
              ) == inventory
        else { throw PersistenceError.integrityViolation }
        let suffix = String(source.eventHead.rawValue.prefix(16))
        let content = try ReviewPublicationReceiptContent(
            kind: "review-inventory",
            id: "review-inventory-\(suffix)",
            payloadBytes: payloadBytes
        )
        return try composeAndPublish(
            kind: .inventoryRecorded,
            source: source,
            runRoot: runRoot,
            lease: lease,
            publisher: publisher,
            currentBaselineDigest: baseline.digest,
            contents: [content]
        ) { preimage in
            try ReviewPublicationBuilder.inventoryRecorded(preimage, authority: authority)
        }
    }

    public func publishInventoryClosed(
        register: VerifiedIssueRegister,
        currentness: VerifiedReviewScopeCurrentness,
        publisher: VerifiedAuthorityFact,
        runRoot: URL,
        lease: WriterLease
    ) throws -> ReviewPublicationCommit {
        let baseline = register.baseline
        let source = try loadSource(
            runID: baseline.runID,
            runRoot: runRoot,
            publisher: publisher
        )
        try requireCurrentRound(baseline, in: source)
        guard currentness.currentEventHead == source.eventHead else {
            throw PersistenceError.integrityViolation
        }
        let closure = try ReviewRoundClosureVerifier.verify(
            register: register,
            currentness: currentness
        )
        let suffix = String(source.eventHead.rawValue.prefix(16))
        let contents = try [
            ReviewPublicationReceiptContent(
                kind: "issue-register",
                id: "issue-register-\(suffix)",
                payloadBytes: CanonicalJSON.encode(register.register)
            ),
            ReviewPublicationReceiptContent(
                kind: "review-inventory-set",
                id: "review-inventory-set-\(suffix)",
                payloadBytes: CanonicalJSON.encode(ReviewInventorySetReceiptPayload(
                    baseline: baseline,
                    inventories: register.inventories.inventories
                ))
            ),
        ]
        return try composeAndPublish(
            kind: .inventoryClosed,
            source: source,
            runRoot: runRoot,
            lease: lease,
            publisher: publisher,
            currentBaselineDigest: baseline.digest,
            verifiedRoundClosure: closure,
            contents: contents
        ) { preimage in
            try ReviewPublicationBuilder.inventoryClosed(
                preimage,
                inventories: register.inventories,
                register: register
            )
        }
    }

    public func publishRemediationRecorded(
        successor: VerifiedRemediationSuccessor,
        publisher: VerifiedAuthorityFact,
        runRoot: URL,
        lease: WriterLease
    ) throws -> ReviewPublicationCommit {
        let baseline = successor.sourceBaseline
        let source = try loadSource(
            runID: baseline.runID,
            runRoot: runRoot,
            publisher: publisher
        )
        try requireCurrentRound(baseline, in: source)
        let evidenceIsCanonical = try successor.plannedEvidence.allSatisfy { planned in
            let encoded = try CanonicalJSON.encode(planned.payload)
            return planned.payload.publicationAnchorEventHead == source.eventHead &&
                planned.payloadBytes == encoded &&
                planned.payloadDigest == CanonicalTreeDigest.sha256(planned.payloadBytes)
        }
        guard successor.planning.publicationAnchorEventHead == source.eventHead,
              successor.implementationAuthority.publicationAnchorEventHead == source.eventHead,
              successor.sourceRegister.baseline == baseline,
              successor.batch.successorBaselineDigest == successor.successorBaseline.digest,
              evidenceIsCanonical
        else { throw PersistenceError.integrityViolation }
        let suffix = String(source.eventHead.rawValue.prefix(16))
        var contents = try [
            ReviewPublicationReceiptContent(
                kind: "review-baseline",
                id: "review-baseline-\(suffix)",
                payloadBytes: CanonicalJSON.encode(successor.successorBaseline)
            ),
            ReviewPublicationReceiptContent(
                kind: "review-remediation-batch",
                id: "review-remediation-batch-\(suffix)",
                payloadBytes: CanonicalJSON.encode(successor.batch)
            ),
            ReviewPublicationReceiptContent(
                kind: "review-resolved-transitions",
                id: "review-resolved-transitions-\(suffix)",
                payloadBytes: CanonicalJSON.encode(
                    ReviewResolvedTransitionsReceiptPayload(batch: successor.batch)
                )
            ),
        ]
        contents.append(contentsOf: try successor.plannedEvidence.map { planned in
            try ReviewPublicationReceiptContent(
                kind: planned.payload.receiptKind.rawValue,
                id: planned.payload.receiptID.rawValue,
                payloadBytes: planned.payloadBytes
            )
        })
        return try composeAndPublish(
            kind: .remediationRecorded,
            source: source,
            runRoot: runRoot,
            lease: lease,
            publisher: publisher,
            currentBaselineDigest: baseline.digest,
            contents: contents,
            recoverCommittedRemediation: { persisted in
                try ReviewCommittedRemediationVerifier.verify(
                    sourceRegister: successor.sourceRegister,
                    batch: successor.batch,
                    successorBaseline: successor.successorBaseline,
                    persistedRun: persisted
                )
            }
        ) { preimage in
            try ReviewPublicationBuilder.remediationRecorded(preimage, successor: successor)
        }
    }

    public func publishConfirmationRecorded(
        successor: VerifiedCommittedRemediationSuccessor,
        confirmationRegister: VerifiedIssueRegister,
        authority: VerifiedReviewReceiptAuthority,
        publisher: VerifiedAuthorityFact,
        runRoot: URL,
        lease: WriterLease
    ) throws -> ReviewPublicationCommit {
        let baseline = confirmationRegister.baseline
        let source = try loadSource(
            runID: baseline.runID,
            runRoot: runRoot,
            publisher: publisher
        )
        try requireCurrentRound(baseline, in: source)
        let reboundSuccessor = try reboundCommittedRemediation(
            successor,
            in: source
        )
        guard successor.successorBaseline == baseline,
              authority.runID == baseline.runID,
              authority.eventHead == source.eventHead,
              authority.persistedStateDigest == source.stateDigest
        else { throw PersistenceError.integrityViolation }
        let receipt = try ReviewConvergenceValidator.issueConfirmation(
            successor: reboundSuccessor,
            confirmationRegister: confirmationRegister,
            authority: authority,
            publicationAnchorEventHead: source.eventHead
        )
        let payloadBytes = try CanonicalJSON.encode(receipt)
        let planned = try ReviewSemanticIngress.verifyConfirmationReceipt(
            bytes: payloadBytes,
            successor: reboundSuccessor,
            confirmationRegister: confirmationRegister,
            authority: authority
        )
        let content = try ReviewPublicationReceiptContent(
            kind: planned.kind.rawValue,
            id: planned.id.rawValue,
            payloadBytes: planned.payloadBytes
        )
        return try composeAndPublish(
            kind: .confirmationRecorded,
            source: source,
            runRoot: runRoot,
            lease: lease,
            publisher: publisher,
            currentBaselineDigest: baseline.digest,
            contents: [content]
        ) { preimage in
            try ReviewPublicationBuilder.confirmationRecorded(
                preimage,
                successor: reboundSuccessor,
                register: confirmationRegister,
                authority: authority
            )
        }
    }

    public func publishExceptionOpened(
        admission: VerifiedReviewExceptionAdmission,
        publisher: VerifiedAuthorityFact,
        runRoot: URL,
        lease: WriterLease
    ) throws -> ReviewPublicationCommit {
        let predecessor = admission.remediation.sourceBaseline
        let successor = admission.successorBaseline
        let source = try loadSource(
            runID: predecessor.runID,
            runRoot: runRoot,
            publisher: publisher
        )
        try requireCurrentRound(predecessor, in: source)
        _ = try reboundCommittedRemediation(admission.remediation, in: source)
        let history = admission.activeHistory
        guard let cycle = source.state.reviewCycle,
              let confirmationReceiptID = cycle.confirmationReceiptID
        else { throw PersistenceError.integrityViolation }
        let confirmationAuthority = try ReviewCommittedReceiptVerifier.verify(
            id: confirmationReceiptID,
            kind: ReceiptKind(validating: "review-confirmation"),
            in: source
        )
        let confirmation = try ConfirmationReceipt.decodeCanonical(
            from: confirmationAuthority.payloadBytes
        )
        let currentRegisterBytes = try CanonicalJSON.encode(
            admission.remediation.sourceRegister.register
        )
        let registerCandidates = source.receipts.filter {
            $0.kind.rawValue == "issue-register" &&
                $0.payloadBytes == currentRegisterBytes
        }
        guard registerCandidates.count == 1, let registerCandidate = registerCandidates.first
        else { throw PersistenceError.integrityViolation }
        let registerAuthority = try ReviewCommittedReceiptVerifier.verify(
            id: registerCandidate.id,
            kind: registerCandidate.kind,
            digest: registerCandidate.payloadDigest,
            in: source
        )
        guard successor.runID == predecessor.runID,
              successor.cycleID == predecessor.cycleID,
              successor.gate == predecessor.gate,
              successor.predecessorBaselineDigest == predecessor.digest,
              successor.preCreationEventHead == admission.eligibility.roundAnchorEventHead,
              history.currentRegisterDigest == admission.remediation.sourceRegister.register.digest,
              history.registerJoinedEventHead == registerAuthority.producedEventHead,
              history.remediationBatchDigest == admission.remediation.batch.digest,
              history.remediationEventHead == source.eventHead,
              history.remediationEventHead == admission.remediation.producedEventHead,
              history.confirmationReceiptDigest == confirmation.digest,
              history.confirmationEventHead == confirmationAuthority.producedEventHead,
              history.confirmationRoundID == confirmation.roundID,
              history.confirmationRegisterDigest == confirmation.confirmationRegisterDigest,
              history.confirmationBaselineDigest == confirmation.successorBaselineDigest,
              cycle.didRecordConfirmation,
              cycle.lastRemediatedRoundID == predecessor.roundID,
              cycle.closedRoundID == predecessor.roundID,
              cycle.closedBaselineDigest == predecessor.digest,
              cycle.closedRegisterDigest == history.currentRegisterDigest,
              cycle.closedPathDecision == .requiresRemediation
        else { throw PersistenceError.integrityViolation }
        let suffix = String(source.eventHead.rawValue.prefix(16))
        let contents = try [ReviewPublicationReceiptContent(
            kind: "review-exception",
            id: "review-exception-\(suffix)",
            payloadBytes: CanonicalJSON.encode(ReviewExceptionReceiptPayload(
                proof: admission.eligibility,
                successorBaselineDigest: successor.digest
            ))
        )]
        return try composeAndPublish(
            kind: .exceptionOpened,
            source: source,
            runRoot: runRoot,
            lease: lease,
            publisher: publisher,
            currentBaselineDigest: predecessor.digest,
            exceptionAdmission: admission,
            contents: contents
        ) { preimage in
            try ReviewPublicationBuilder.exceptionOpened(preimage, admission: admission)
        }
    }

    public func publishDirectConvergence(
        register: VerifiedIssueRegister,
        authority: VerifiedReviewReceiptAuthority,
        publisher: VerifiedAuthorityFact,
        runRoot: URL,
        lease: WriterLease
    ) throws -> ReviewPublicationCommit {
        let baseline = register.baseline
        let source = try loadSource(
            runID: baseline.runID,
            runRoot: runRoot,
            publisher: publisher
        )
        try requireCurrentRound(baseline, in: source)
        guard authority.runID == baseline.runID,
              authority.eventHead == source.eventHead,
              authority.persistedStateDigest == source.stateDigest
        else { throw PersistenceError.integrityViolation }
        let receipt = try ReviewConvergenceValidator.issueDirectConvergence(
            register: register,
            authority: authority,
            publicationAnchorEventHead: source.eventHead
        )
        let planned = try ReviewSemanticIngress.verifyConvergenceReceipt(
            bytes: CanonicalJSON.encode(receipt),
            register: register,
            authority: authority
        )
        let content = try ReviewPublicationReceiptContent(
            kind: planned.kind.rawValue,
            id: planned.id.rawValue,
            payloadBytes: planned.payloadBytes
        )
        return try composeAndPublish(
            kind: .converged,
            source: source,
            runRoot: runRoot,
            lease: lease,
            publisher: publisher,
            currentBaselineDigest: baseline.digest,
            contents: [content]
        ) { preimage in
            try ReviewPublicationBuilder.directConvergence(preimage, register: register)
        }
    }

    public func publishConfirmedConvergence(
        lineage: VerifiedConfirmationLineage,
        authority: VerifiedReviewReceiptAuthority,
        publisher: VerifiedAuthorityFact,
        runRoot: URL,
        lease: WriterLease
    ) throws -> ReviewPublicationCommit {
        guard let baseline = lineage.baselines.last else {
            throw PersistenceError.integrityViolation
        }
        let source = try loadSource(
            runID: baseline.runID,
            runRoot: runRoot,
            publisher: publisher
        )
        try requireCurrentRound(baseline, in: source)
        guard authority.runID == baseline.runID,
              authority.eventHead == source.eventHead,
              authority.persistedStateDigest == source.stateDigest
        else { throw PersistenceError.integrityViolation }
        let receipt = try ReviewConvergenceValidator.issueConfirmedConvergence(
            lineage: lineage,
            authority: authority,
            publicationAnchorEventHead: source.eventHead
        )
        let planned = try ReviewSemanticIngress.verifyConvergenceReceipt(
            bytes: CanonicalJSON.encode(receipt),
            lineage: lineage,
            authority: authority
        )
        let content = try ReviewPublicationReceiptContent(
            kind: planned.kind.rawValue,
            id: planned.id.rawValue,
            payloadBytes: planned.payloadBytes
        )
        return try composeAndPublish(
            kind: .converged,
            source: source,
            runRoot: runRoot,
            lease: lease,
            publisher: publisher,
            currentBaselineDigest: baseline.digest,
            contents: [content]
        ) { preimage in
            try ReviewPublicationBuilder.confirmedConvergence(preimage, lineage: lineage)
        }
    }

    public func publishInvalidation(
        authorization: VerifiedReviewInvalidationAuthorization,
        publisher: VerifiedAuthorityFact,
        runRoot: URL,
        lease: WriterLease
    ) throws -> ReviewPublicationCommit {
        let baseline = authorization.latestBaseline
        let source = try loadSource(
            runID: baseline.runID,
            runRoot: runRoot,
            publisher: publisher
        )
        try requireCurrentRound(baseline, in: source)
        guard authorization.persistedStateDigest == source.stateDigest,
              authorization.eventHead == source.eventHead,
              authorization.currentness.currentEventHead == source.eventHead,
              authorization.plan.invalidationMutationDigest ==
                authorization.invalidation.mutationDigest
        else { throw PersistenceError.integrityViolation }
        let suffix = String(source.eventHead.rawValue.prefix(16))
        let content = try ReviewPublicationReceiptContent(
            kind: "review-invalidation",
            id: "review-invalidation-\(suffix)",
            payloadBytes: CanonicalJSON.encode(authorization.plan)
        )
        return try composeAndPublish(
            kind: .invalidated,
            source: source,
            runRoot: runRoot,
            lease: lease,
            publisher: publisher,
            currentBaselineDigest: baseline.digest,
            contents: [content],
            invalidationPlan: authorization.plan
        ) { preimage in
            try ReviewPublicationBuilder.invalidated(
                preimage,
                authorization: authorization
            )
        }
    }

    private func composeAndPublish(
        kind: ReviewPublicationKind,
        source: PersistedRun,
        runRoot: URL,
        lease: WriterLease,
        publisher: VerifiedAuthorityFact,
        currentBaselineDigest: HashDigest,
        verifiedRoundClosure: VerifiedReviewRoundClosureFact? = nil,
        exceptionAdmission: VerifiedReviewExceptionAdmission? = nil,
        contents: [ReviewPublicationReceiptContent],
        invalidationPlan: ReviewInvalidationPlan? = nil,
        recoverCommittedRemediation: ((PersistedRun) throws ->
            VerifiedCommittedRemediationSuccessor)? = nil,
        validate: (ReviewPublicationPreimage) throws -> VerifiedReviewPublication
    ) throws -> ReviewPublicationCommit {
        let semanticReceiptID: ReceiptID? = switch kind {
        case .confirmationRecorded, .converged:
            contents.count == 1 ? contents[0].id : nil
        default:
            nil
        }
        let event = try WorkflowEvent(
            id: reviewEventID(
                kind,
                eventHead: source.eventHead,
                semanticReceiptID: semanticReceiptID
            ),
            kind: reviewEventKind(kind)
        )
        let receipts = try contents.map { content in
            try ReviewReceiptVerifier.verify(
                kind: content.kind,
                id: content.id,
                payloadBytes: content.payloadBytes,
                runID: source.state.runID,
                eventID: event.id,
                eventKind: event.kind,
                eventHead: source.eventHead
            )
        }
        let context: TransitionContext
        if let exceptionAdmission {
            context = try .openingException(
                actorID: publisher.actorID,
                principalID: publisher.principalID,
                currentEventHead: source.eventHead,
                admission: exceptionAdmission
            )
        } else if let verifiedRoundClosure {
            context = try .closingReviewRound(
                actorID: publisher.actorID,
                principalID: publisher.principalID,
                currentEventHead: source.eventHead,
                currentReviewBaselineDigest: currentBaselineDigest,
                closure: verifiedRoundClosure
            )
        } else {
            context = try TransitionContext(
                actorID: publisher.actorID,
                principalID: publisher.principalID,
                currentEventHead: source.eventHead,
                currentReviewBaselineDigest: currentBaselineDigest,
                satisfiedGuards: []
            )
        }
        let proposedState = try reducer.decide(
            definition: reviewWorkflowDefinition(for: source.state.workType),
            state: source.state,
            event: event,
            context: context
        ).proposedState
        let publication = try validate(ReviewPublicationPreimage(
            kind: kind,
            sourceState: source.state,
            event: event,
            proposedState: proposedState,
            eventHead: source.eventHead,
            receipts: receipts,
            invalidationPlan: invalidationPlan
        ))
        let transaction = try ReviewPublicationTransaction.make(
            publication: publication,
            runRoot: runRoot,
            expectedStateDigest: source.stateDigest,
            expectedEventHead: source.eventHead
        )
        let commitReceipt = try store.commit(transaction, lease: lease)
        guard commitReceipt.transactionID == transaction.id,
              commitReceipt.transactionDigest == transaction.digest,
              commitReceipt.runID == source.state.runID,
              commitReceipt.isDurable
        else { throw PersistenceError.integrityViolation }
        let persisted = try store.load(runID: source.state.runID, from: runRoot)
        guard persisted.stateDigest == commitReceipt.stateDigest,
              persisted.eventHead == commitReceipt.eventHead
        else { throw PersistenceError.integrityViolation }
        let publishedReceipts = try ReviewPublicationVerifier.verifyPublished(
            publication: publication,
            transaction: transaction,
            persistedRun: persisted
        )
        let committedRemediationSuccessor = try recoverCommittedRemediation?(persisted)
        return ReviewPublicationCommit(
            transaction: transaction,
            commitReceipt: commitReceipt,
            receipts: publishedReceipts,
            committedRemediationSuccessor: committedRemediationSuccessor
        )
    }

    private func loadSource(
        runID: RunID,
        runRoot: URL,
        publisher: VerifiedAuthorityFact
    ) throws -> PersistedRun {
        guard publisher.principalKind == .kernel,
              publisher.roles.contains(.kernel)
        else { throw WorkflowPolicyError.invalidPolicy }
        let source = try store.load(runID: runID, from: runRoot)
        try ReviewCommittedReceiptVerifier.validateActiveChain(source)
        guard source.state.runID == runID else {
            throw PersistenceError.integrityViolation
        }
        return source
    }

    private func requireCurrentRound(
        _ baseline: ReviewBaseline,
        in source: PersistedRun
    ) throws {
        guard source.state.runID == baseline.runID,
              source.state.canonSnapshotDigest == baseline.activeProfileDigest,
              let cycle = source.state.reviewCycle,
              cycle.id == baseline.cycleID,
              cycle.gate == baseline.gate,
              cycle.currentRoundID == baseline.roundID,
              cycle.currentRoundKind == baseline.kind,
              cycle.currentSemanticOrdinal == baseline.semanticOrdinal,
              cycle.currentRoundAnchorEventHead == baseline.preCreationEventHead,
              cycle.predecessorBaselineDigest == baseline.predecessorBaselineDigest
        else { throw PersistenceError.integrityViolation }
    }

    private func reboundCommittedRemediation(
        _ successor: VerifiedCommittedRemediationSuccessor,
        in source: PersistedRun
    ) throws -> VerifiedCommittedRemediationSuccessor {
        let rebound = try ReviewCommittedRemediationVerifier.verify(
            sourceRegister: successor.sourceRegister,
            batch: successor.batch,
            successorBaseline: successor.successorBaseline,
            persistedRun: source
        )
        guard rebound.batch == successor.batch,
              rebound.sourceBaseline == successor.sourceBaseline,
              rebound.sourceRegister.baseline == successor.sourceRegister.baseline,
              rebound.sourceRegister.register == successor.sourceRegister.register,
              rebound.successorBaseline == successor.successorBaseline,
              rebound.publicationAnchorEventHead == successor.publicationAnchorEventHead,
              rebound.producedEventHead == successor.producedEventHead,
              rebound.implementingPrincipalID == successor.implementingPrincipalID,
              rebound.implementingContextDigest == successor.implementingContextDigest,
              rebound.implementationAuthorityDigest == successor.implementationAuthorityDigest,
              rebound.receipts == successor.receipts
        else { throw PersistenceError.integrityViolation }
        return rebound
    }
}

private func reviewWorkflowDefinition(for workType: WorkType) -> WorkflowDefinition {
    switch workType {
    case .engineeringRun:
        EngineeringWorkflow.definition
    case .pluginRelease:
        PluginReleaseWorkflow.definition
    }
}

/// Production-only typed entry points. The raw preimage is module-internal and every route requires
/// the sealed semantic capability that owns the corresponding publication decision.
fileprivate enum ReviewPublicationBuilder {
    static func inventoryRecorded(
        _ preimage: ReviewPublicationPreimage,
        authority: VerifiedReviewerInventoryAuthority
    ) throws -> VerifiedReviewPublication {
        guard preimage.kind == .inventoryRecorded,
              let planned = preimage.receipts.first,
              let inventory = try? ReviewerFindingInventory.decodeCanonical(
                from: planned.payloadBytes
              ),
              inventory.baselineDigest == authority.baselineDigest,
              inventory.assignmentID == authority.assignmentID
        else { throw PersistenceError.integrityViolation }
        return try ReviewPublicationVerifier.verify(preimage)
    }

    static func inventoryClosed(
        _ preimage: ReviewPublicationPreimage,
        inventories: VerifiedCompleteInventorySet,
        register: VerifiedIssueRegister
    ) throws -> VerifiedReviewPublication {
        let registerBytes = try CanonicalJSON.encode(register.register)
        let expectedDigests = inventories.inventories.map(\.digest).sorted(
            by: reviewPublicationDigestOrder
        )
        guard preimage.kind == .inventoryClosed,
              register.register.inventoryDigests == expectedDigests,
              preimage.receipts.contains(where: {
                $0.kind.rawValue == "issue-register" &&
                    $0.payloadBytes == registerBytes
              })
        else { throw PersistenceError.integrityViolation }
        return try ReviewPublicationVerifier.verify(preimage)
    }

    static func remediationRecorded(
        _ preimage: ReviewPublicationPreimage,
        successor: VerifiedRemediationSuccessor
    ) throws -> VerifiedReviewPublication {
        let baselineBytes = try CanonicalJSON.encode(successor.successorBaseline)
        let batchBytes = try CanonicalJSON.encode(successor.batch)
        let transitionBytes = try CanonicalJSON.encode(
            ReviewResolvedTransitionsReceiptPayload(batch: successor.batch)
        )
        let fixedKinds = Set([
            "review-baseline",
            "review-remediation-batch",
            "review-resolved-transitions",
        ])
        let evidenceReceipts = preimage.receipts.filter {
            !fixedKinds.contains($0.kind.rawValue)
        }
        let evidenceAddresses = successor.plannedEvidence.map { planned in
            ReviewReceiptAddress(
                kind: planned.payload.receiptKind,
                id: planned.payload.receiptID
            )
        }
        guard preimage.kind == .remediationRecorded,
              successor.planning.publicationAnchorEventHead == preimage.eventHead,
              preimage.receipts.contains(where: {
                  $0.kind.rawValue == "review-baseline" &&
                      $0.payloadBytes == baselineBytes
              }),
              preimage.receipts.contains(where: {
                  $0.kind.rawValue == "review-remediation-batch" &&
                      $0.payloadBytes == batchBytes
              }),
              preimage.receipts.contains(where: {
                  $0.kind.rawValue == "review-resolved-transitions" &&
                      $0.payloadBytes == transitionBytes
              }),
              evidenceReceipts.count == successor.plannedEvidence.count,
              successor.plannedEvidence.allSatisfy({ planned in
                  evidenceReceipts.contains(where: {
                      $0.kind == planned.payload.receiptKind &&
                          $0.id == planned.payload.receiptID &&
                          $0.payloadBytes == planned.payloadBytes &&
                          $0.payloadDigest == planned.payloadDigest
                  })
              })
        else { throw PersistenceError.integrityViolation }
        return try ReviewPublicationVerifier.verify(
            preimage,
            additionalRequiredReceiptAddresses: evidenceAddresses
        )
    }

    static func confirmationRecorded(
        _ preimage: ReviewPublicationPreimage,
        successor: VerifiedCommittedRemediationSuccessor,
        register: VerifiedIssueRegister,
        authority: VerifiedReviewReceiptAuthority
    ) throws -> VerifiedReviewPublication {
        guard preimage.kind == .confirmationRecorded,
              preimage.receipts.count == 1,
              let receipt = preimage.receipts.first,
              let planned = try? ReviewSemanticIngress.verifyConfirmationReceipt(
                  bytes: receipt.payloadBytes,
                  successor: successor,
                  confirmationRegister: register,
                  authority: authority
              )
        else { throw PersistenceError.integrityViolation }
        guard receipt == planned,
              successor.successorBaseline == register.baseline,
              authority.eventHead == preimage.eventHead
        else { throw PersistenceError.integrityViolation }
        return try ReviewPublicationVerifier.verify(preimage)
    }

    static func exceptionOpened(
        _ preimage: ReviewPublicationPreimage,
        admission: VerifiedReviewExceptionAdmission
    ) throws -> VerifiedReviewPublication {
        let proofBytes = try CanonicalJSON.encode(ReviewExceptionReceiptPayload(
            proof: admission.eligibility,
            successorBaselineDigest: admission.successorBaseline.digest
        ))
        guard preimage.kind == .exceptionOpened,
              preimage.receipts.count == 1,
              preimage.receipts.contains(where: {
                  $0.kind.rawValue == "review-exception" &&
                      $0.payloadBytes == proofBytes
              })
        else { throw PersistenceError.integrityViolation }
        return try ReviewPublicationVerifier.verify(
            preimage,
            exceptionAdmission: admission
        )
    }

    static func directConvergence(
        _ preimage: ReviewPublicationPreimage,
        register: VerifiedIssueRegister
    ) throws -> VerifiedReviewPublication {
        guard preimage.kind == .converged,
              preimage.receipts.count == 1,
              let receipt = preimage.receipts.first,
              let convergence = try? ConvergenceReceipt.decodeCanonical(
                  from: receipt.payloadBytes
              ),
              convergence.path == .directConvergenceNoAcceptedCurrentScope,
              convergence.baselineLineage == [register.baseline.digest],
              convergence.registerDigests == [register.register.digest],
              convergence.remediationBatchDigests.isEmpty
        else { throw PersistenceError.integrityViolation }
        return try ReviewPublicationVerifier.verify(preimage)
    }

    static func confirmedConvergence(
        _ preimage: ReviewPublicationPreimage,
        lineage: VerifiedConfirmationLineage
    ) throws -> VerifiedReviewPublication {
        guard let source = lineage.baselines.first,
              preimage.kind == .converged,
              preimage.receipts.count == 1,
              let receipt = preimage.receipts.first,
              let convergence = try? ConvergenceReceipt.decodeCanonical(
                from: receipt.payloadBytes
              ),
              convergence.path == .confirmedRemediation,
              convergence.baselineLineage == lineage.baselines.map(\.digest),
              convergence.registerDigests == lineage.registers.map(\.digest),
              convergence.remediationBatchDigests == lineage.remediationBatches.map(\.digest),
              try convergence.hasValidIdentity(
                runID: source.runID,
                cycleID: source.cycleID,
                gate: source.gate
              )
        else { throw PersistenceError.integrityViolation }
        return try ReviewPublicationVerifier.verify(preimage)
    }

    static func invalidated(
        _ preimage: ReviewPublicationPreimage,
        authorization: VerifiedReviewInvalidationAuthorization
    ) throws -> VerifiedReviewPublication {
        guard preimage.kind == .invalidated,
              preimage.invalidationPlan == authorization.plan,
              authorization.eventHead == preimage.eventHead,
              authorization.plan.invalidationMutationDigest ==
                authorization.invalidation.mutationDigest
        else { throw PersistenceError.integrityViolation }
        return try ReviewPublicationVerifier.verify(preimage)
    }
}

public enum ReviewPublicationTransaction {
    public static func make(
        publication: VerifiedReviewPublication,
        runRoot: URL,
        expectedStateDigest: HashDigest?,
        expectedEventHead: HashDigest?
    ) throws -> StateTransaction {
        let sourceDigest = CanonicalTreeDigest.sha256(
            try CanonicalJSON.encode(publication.sourceState)
        )
        guard let expectedStateDigest,
              let expectedEventHead,
              expectedStateDigest == sourceDigest,
              expectedEventHead == publication.eventHead
        else { throw PersistenceError.transactionConflict }
        let suffix = String(publication.eventHead.rawValue.prefix(16))
        let transactionID = try TransactionID(
            rawValue: "review-\(publication.kind.rawValue.replacingOccurrences(of: "_", with: "-"))-\(suffix)"
        )
        let writes = try publication.receipts.map {
            try ReceiptTableWrite(
                kind: $0.kind,
                id: $0.id,
                canonicalPayloadBytes: $0.payloadBytes
            )
        }.sorted {
            ($0.kind.rawValue, $0.id.rawValue) < ($1.kind.rawValue, $1.id.rawValue)
        }
        return try StateTransaction(
            id: transactionID,
            runRoot: runRoot,
            expectedStateDigest: expectedStateDigest,
            expectedEventHead: expectedEventHead,
            state: publication.proposedState,
            event: publication.event,
            receiptWrites: writes
        )
    }
}

fileprivate struct ReviewReceiptAddress: Hashable, Comparable {
    let kind: ReceiptKind
    let id: ReceiptID

    static func < (lhs: ReviewReceiptAddress, rhs: ReviewReceiptAddress) -> Bool {
        (lhs.kind.rawValue, lhs.id.rawValue) < (rhs.kind.rawValue, rhs.id.rawValue)
    }
}

struct ReviewInventorySetReceiptPayload: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let baselineDigest: HashDigest
    let rosterDigest: HashDigest
    let inventoryDigests: [HashDigest]

    init(baseline: ReviewBaseline, inventories: [ReviewerFindingInventory]) throws {
        let digests = inventories.map(\.digest).sorted(by: reviewPublicationDigestOrder)
        guard !digests.isEmpty,
              Set(digests).count == digests.count,
              inventories.allSatisfy({
                  $0.baselineDigest == baseline.digest && $0.rosterDigest == baseline.rosterDigest
              })
        else { throw WorkflowPolicyError.invalidPolicy }
        schemaVersion = 1
        baselineDigest = baseline.digest
        rosterDigest = baseline.rosterDigest
        inventoryDigests = digests
    }

    init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        baselineDigest = try values.decode(HashDigest.self, forKey: .baselineDigest)
        rosterDigest = try values.decode(HashDigest.self, forKey: .rosterDigest)
        inventoryDigests = try values.decode([HashDigest].self, forKey: .inventoryDigests)
        guard schemaVersion == 1,
              !inventoryDigests.isEmpty,
              inventoryDigests == inventoryDigests.sorted(by: reviewPublicationDigestOrder),
              Set(inventoryDigests).count == inventoryDigests.count
        else { throw WorkflowPolicyError.invalidPolicy }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case baselineDigest = "baseline_digest"
        case rosterDigest = "roster_digest"
        case inventoryDigests = "inventory_digests"
    }
}

struct ReviewRemediationEvidenceReceiptPayload: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let batchDigest: HashDigest
    let changes: [RemediationChange]

    init(batch: RemediationBatch) {
        schemaVersion = 1
        batchDigest = batch.digest
        changes = batch.changes
    }

    init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        batchDigest = try values.decode(HashDigest.self, forKey: .batchDigest)
        changes = try values.decode([RemediationChange].self, forKey: .changes)
        guard schemaVersion == 1,
              !changes.isEmpty,
              changes.map(\.fingerprint) == changes.map(\.fingerprint).sorted()
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case batchDigest = "batch_digest"
        case changes
    }
}

struct ReviewResolvedTransitionsReceiptPayload: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let batchDigest: HashDigest
    let resolvedTransitions: [RemediationResolvedTransition]

    init(batch: RemediationBatch) {
        schemaVersion = 1
        batchDigest = batch.digest
        resolvedTransitions = batch.resolvedTransitions
    }

    init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        batchDigest = try values.decode(HashDigest.self, forKey: .batchDigest)
        resolvedTransitions = try values.decode(
            [RemediationResolvedTransition].self,
            forKey: .resolvedTransitions
        )
        guard schemaVersion == 1,
              !resolvedTransitions.isEmpty,
              resolvedTransitions.map(\.fingerprint) ==
                resolvedTransitions.map(\.fingerprint).sorted(by: {
                    $0.rawValue < $1.rawValue
                })
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case batchDigest = "batch_digest"
        case resolvedTransitions = "resolved_transitions"
    }
}

struct ReviewExceptionReceiptPayload: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let proofDigest: HashDigest
    let nextRoundID: ReviewRoundID
    let successorBaselineDigest: HashDigest

    init(
        proof: ReviewExceptionEligibility,
        successorBaselineDigest: HashDigest
    ) {
        schemaVersion = 1
        proofDigest = proof.proofDigest
        nextRoundID = proof.nextRoundID
        self.successorBaselineDigest = successorBaselineDigest
    }

    init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        proofDigest = try values.decode(HashDigest.self, forKey: .proofDigest)
        nextRoundID = try values.decode(ReviewRoundID.self, forKey: .nextRoundID)
        successorBaselineDigest = try values.decode(HashDigest.self, forKey: .successorBaselineDigest)
        guard schemaVersion == 1 else { throw WorkflowPolicyError.invalidExceptionProof }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case proofDigest = "proof_digest"
        case nextRoundID = "next_round_id"
        case successorBaselineDigest = "successor_baseline_digest"
    }
}

private func hasSemanticReceiptClosure(
    _ receipts: [VerifiedReviewReceipt],
    publication: ReviewPublicationPreimage
) throws -> Bool {
    func bytes(_ kind: String) -> Data? {
        let matches = receipts.filter { $0.kind.rawValue == kind }
        return matches.count == 1 ? matches[0].payloadBytes : nil
    }

    switch publication.kind {
    case .inventoryRecorded:
        guard let payload = bytes("review-inventory"),
              let inventory = try? ReviewerFindingInventory.decodeCanonical(from: payload)
        else { return false }
        return try CanonicalJSON.encode(inventory) == payload

    case .inventoryClosed:
        guard let registerBytes = bytes("issue-register"),
              let setBytes = bytes("review-inventory-set"),
              let register = try? IssueRegister.decodeCanonical(from: registerBytes),
              let inventorySet = try? CanonicalJSON.decode(
                  ReviewInventorySetReceiptPayload.self,
                  from: setBytes
              )
        else { return false }
        let registerIsCanonical = try CanonicalJSON.encode(register) == registerBytes
        let inventorySetIsCanonical = try CanonicalJSON.encode(inventorySet) == setBytes
        return registerIsCanonical && inventorySetIsCanonical &&
            inventorySet.baselineDigest == register.baselineDigest &&
            inventorySet.rosterDigest == register.rosterDigest &&
            inventorySet.inventoryDigests == register.inventoryDigests

    case .remediationRecorded:
        guard let baselineBytes = bytes("review-baseline"),
              let batchBytes = bytes("review-remediation-batch"),
              let transitionBytes = bytes("review-resolved-transitions"),
              let baseline = try? ReviewBaseline.decodeCanonical(from: baselineBytes),
              let batch = try? RemediationBatch.decodeCanonical(from: batchBytes),
              let transitions = try? CanonicalJSON.decode(
                  ReviewResolvedTransitionsReceiptPayload.self,
                  from: transitionBytes
              )
        else { return false }
        let fixedKinds = Set([
            "review-baseline",
            "review-remediation-batch",
            "review-resolved-transitions",
        ])
        let evidenceReceipts = receipts.filter { !fixedKinds.contains($0.kind.rawValue) }
        let evidencePayloads = try evidenceReceipts.map { receipt in
            let payload = try ReviewRemediationEvidencePayload.decodeCanonical(
                from: receipt.payloadBytes
            )
            guard payload.receiptID == receipt.id,
                  payload.receiptKind == receipt.kind,
                  receipt.payloadDigest == CanonicalTreeDigest.sha256(receipt.payloadBytes),
                  payload.runID == publication.sourceState.runID,
                  payload.sourceBaselineDigest == batch.sourceBaselineDigest,
                  payload.sourceRegisterDigest == batch.sourceRegisterDigest
            else { throw PersistenceError.integrityViolation }
            return (receipt, payload)
        }
        let expectedEvidenceCount = batch.changes.reduce(0) { $0 + $1.evidence.count }
        guard evidencePayloads.count == expectedEvidenceCount else { return false }
        for change in batch.changes {
            for evidence in change.evidence {
                let matches = evidencePayloads.filter { pair in
                    let (receipt, payload) = pair
                    return receipt.id == evidence.receipt.id &&
                        receipt.payloadDigest == evidence.receipt.digest &&
                        payload.fingerprint == change.fingerprint &&
                        payload.preChangeArtifact == change.preChangeArtifact &&
                        payload.postChangeArtifact == change.postChangeArtifact &&
                        payload.evidenceKind == evidence.kind &&
                        payload.implementingActorID == batch.implementingActorID &&
                        payload.publicationAnchorEventHead == evidence.publicationAnchorEventHead
                }
                guard matches.count == 1 else { return false }
            }
        }
        let baselineIsCanonical = try CanonicalJSON.encode(baseline) == baselineBytes
        let batchIsCanonical = try CanonicalJSON.encode(batch) == batchBytes
        let transitionsAreCanonical = try CanonicalJSON.encode(transitions) == transitionBytes
        return baselineIsCanonical && batchIsCanonical && transitionsAreCanonical &&
            baseline.digest == batch.successorBaselineDigest &&
            transitions.batchDigest == batch.digest &&
            transitions.resolvedTransitions == batch.resolvedTransitions

    case .confirmationRecorded:
        guard let payload = bytes("review-confirmation"),
              let confirmation = try? ConfirmationReceipt.decodeCanonical(from: payload)
        else { return false }
        return (try CanonicalJSON.encode(confirmation)) == payload &&
            confirmation.receiptID == publication.event.id &&
            confirmation.publicationAnchorEventHead == publication.eventHead &&
            publication.sourceState.reviewCycle?.currentRoundKind == .normalConfirmation

    case .exceptionOpened:
        guard let proofBytes = bytes("review-exception"),
              let proof = try? CanonicalJSON.decode(
                  ReviewExceptionReceiptPayload.self,
                  from: proofBytes
              )
        else { return false }
        let proofIsCanonical = try CanonicalJSON.encode(proof) == proofBytes
        return proofIsCanonical &&
            proof.nextRoundID == publication.proposedState.reviewCycle?.currentRoundID

    case .converged:
        guard let payload = bytes("review-convergence"),
              let convergence = try? ConvergenceReceipt.decodeCanonical(from: payload)
        else { return false }
        let sourceCycle = publication.sourceState.reviewCycle
        let pathMatchesState: Bool
        switch convergence.path {
        case .directConvergenceNoAcceptedCurrentScope:
            pathMatchesState = sourceCycle?.currentRoundKind == .initial &&
                sourceCycle?.phase == .awaitingRemediation &&
                sourceCycle?.didRecordRemediation == false
        case .confirmedRemediation:
            pathMatchesState = sourceCycle.map {
                [ReviewRoundKind.normalConfirmation, .exception].contains($0.currentRoundKind) &&
                    $0.didRecordRemediation &&
                    $0.didRecordConfirmation
            } ?? false
        }
        return (try CanonicalJSON.encode(convergence)) == payload &&
            convergence.receiptID == publication.event.id &&
            convergence.publicationAnchorEventHead == publication.eventHead &&
            pathMatchesState

    case .invalidated:
        guard let payload = bytes("review-invalidation"),
              let expected = publication.invalidationPlan,
              let decoded = try? ReviewInvalidationPlan.decodeCanonical(from: payload)
        else { return false }
        let expectedIsCanonical = try CanonicalJSON.encode(expected) == payload
        return decoded == expected && expectedIsCanonical
    }
}

private func reviewPublicationDigestOrder(_ lhs: HashDigest, _ rhs: HashDigest) -> Bool {
    lhs.rawValue < rhs.rawValue
}

private func reviewEventKind(_ kind: ReviewPublicationKind) -> WorkflowEventKind {
    switch kind {
    case .inventoryRecorded: .reviewInventoryRecorded
    case .inventoryClosed: .reviewInventoryClosed
    case .remediationRecorded: .reviewRemediationRecorded
    case .confirmationRecorded: .reviewConfirmationRecorded
    case .exceptionOpened: .reviewExceptionOpened
    case .converged: .reviewConverged
    case .invalidated: .reviewInvalidated
    }
}

private func reviewEventID(
    _ kind: ReviewPublicationKind,
    eventHead: HashDigest,
    semanticReceiptID: ReceiptID?
) throws -> String {
    let suffix = String(eventHead.rawValue.prefix(16))
    return switch kind {
    case .inventoryRecorded: "review-inventory-\(suffix)"
    case .inventoryClosed: "review-inventory-set-\(suffix)"
    case .remediationRecorded: "review-remediation-batch-\(suffix)"
    case .confirmationRecorded:
        try requireSemanticReceiptID(semanticReceiptID, kind: "review-confirmation").rawValue
    case .exceptionOpened: "review-exception-\(suffix)"
    case .converged:
        try requireSemanticReceiptID(semanticReceiptID, kind: "review-convergence").rawValue
    case .invalidated: "review-invalidation-\(suffix)"
    }
}

private func requiredReceiptAddresses(
    _ kind: ReviewPublicationKind,
    eventHead: HashDigest,
    semanticReceiptID: ReceiptID?
) throws -> [ReviewReceiptAddress] {
    let suffix = String(eventHead.rawValue.prefix(16))
    let values: [(String, String)]
    switch kind {
    case .inventoryRecorded:
        values = [("review-inventory", "review-inventory-\(suffix)")]
    case .inventoryClosed:
        values = [
            ("issue-register", "issue-register-\(suffix)"),
            ("review-inventory-set", "review-inventory-set-\(suffix)"),
        ]
        case .remediationRecorded:
            values = [
                ("review-baseline", "review-baseline-\(suffix)"),
                ("review-remediation-batch", "review-remediation-batch-\(suffix)"),
                ("review-resolved-transitions", "review-resolved-transitions-\(suffix)"),
            ]
    case .confirmationRecorded:
        values = [("review-confirmation", try requireSemanticReceiptID(
            semanticReceiptID,
            kind: "review-confirmation"
        ).rawValue)]
    case .exceptionOpened:
        values = [("review-exception", "review-exception-\(suffix)")]
    case .converged:
        values = [("review-convergence", try requireSemanticReceiptID(
            semanticReceiptID,
            kind: "review-convergence"
        ).rawValue)]
    case .invalidated:
        values = [("review-invalidation", "review-invalidation-\(suffix)")]
    }
    return try values.map {
        ReviewReceiptAddress(
            kind: try ReceiptKind(validating: $0.0),
            id: try ReceiptID(validating: $0.1)
        )
    }.sorted()
}

private func requireSemanticReceiptID(
    _ id: ReceiptID?,
    kind: String
) throws -> ReceiptID {
    guard let id, id.rawValue.hasPrefix("\(kind)-") else {
        throw PersistenceError.integrityViolation
    }
    return id
}

private func verifiedReviewReceiptOrder(
    _ lhs: VerifiedReviewReceipt,
    _ rhs: VerifiedReviewReceipt
) -> Bool {
    (lhs.kind.rawValue, lhs.id.rawValue) < (rhs.kind.rawValue, rhs.id.rawValue)
}

private func hasExactReviewStateTransition(
    _ preimage: ReviewPublicationPreimage,
    exceptionAdmission: VerifiedReviewExceptionAdmission? = nil
) throws -> Bool {
    let source = preimage.sourceState
    let proposed = preimage.proposedState
    guard source.runID == proposed.runID,
          source.workItemID == proposed.workItemID,
          source.workType == proposed.workType,
          source.mode == proposed.mode,
          source.canonSnapshotDigest == proposed.canonSnapshotDigest,
          source.stage == proposed.stage,
          source.status == proposed.status,
          source.candidateGenerationID == proposed.candidateGenerationID,
          source.inactiveCandidateGenerationIDs == proposed.inactiveCandidateGenerationIDs,
          proposed.processedEvents == source.processedEvents + [
              try ProcessedWorkflowEvent(recording: preimage.event),
          ],
          let sourceCycle = source.reviewCycle,
          let proposedCycle = proposed.reviewCycle,
          sourceCycle.id == proposedCycle.id,
          sourceCycle.gate == proposedCycle.gate,
          sourceCycle.cycleOrdinal == proposedCycle.cycleOrdinal
    else { return false }

    switch preimage.kind {
    case .inventoryRecorded:
        return [.collectingInitial, .collectingNormalConfirmation, .collectingException]
            .contains(sourceCycle.phase) &&
            sourceCycle.closedRoundID == nil &&
            sourceCycle == proposedCycle &&
            source.nextReviewCycleOrdinal == proposed.nextReviewCycleOrdinal
    case .inventoryClosed:
        guard let registerReceipt = preimage.receipts.first(where: {
            $0.kind.rawValue == "issue-register"
        }),
            let register = try? IssueRegister.decodeCanonical(
                from: registerReceipt.payloadBytes
            )
        else { return false }
        var expected = sourceCycle
        expected.closedRoundID = sourceCycle.currentRoundID
        expected.closedBaselineDigest = register.baselineDigest
        expected.closedRegisterDigest = register.digest
        expected.closedPathDecision = register.pathDecision
        if expected.currentRoundKind == .initial ||
            register.pathDecision == .requiresRemediation {
            expected.phase = .awaitingRemediation
        }
        return [.collectingInitial, .collectingNormalConfirmation, .collectingException]
            .contains(sourceCycle.phase) &&
            sourceCycle.closedRoundID == nil &&
            register.roundID == sourceCycle.currentRoundID &&
            proposedCycle == expected &&
            source.nextReviewCycleOrdinal == proposed.nextReviewCycleOrdinal
    case .remediationRecorded:
        var expected = sourceCycle
        expected.didRecordRemediation = true
        expected.lastRemediatedRoundID = sourceCycle.currentRoundID
        return sourceCycle.phase == .awaitingRemediation &&
            sourceCycle.hasVerifiedCurrentRoundClosure &&
            sourceCycle.closedPathDecision == .requiresRemediation &&
            sourceCycle.lastRemediatedRoundID != sourceCycle.currentRoundID &&
            proposedCycle == expected &&
            source.nextReviewCycleOrdinal == proposed.nextReviewCycleOrdinal
    case .confirmationRecorded:
        var expected = sourceCycle
        expected.didRecordConfirmation = true
        expected.confirmationReceiptID = try ReceiptID(validating: preimage.event.id)
        return sourceCycle.currentRoundKind == .normalConfirmation &&
            [.collectingNormalConfirmation, .awaitingRemediation].contains(sourceCycle.phase) &&
            sourceCycle.hasVerifiedCurrentRoundClosure &&
            sourceCycle.confirmationReceiptID == nil &&
            proposedCycle == expected &&
            source.nextReviewCycleOrdinal == proposed.nextReviewCycleOrdinal
    case .exceptionOpened:
        guard let admission = exceptionAdmission,
              let predecessor = sourceCycle.closedBaselineDigest,
              sourceCycle.phase == .awaitingRemediation,
              sourceCycle.hasVerifiedCurrentRoundClosure,
              sourceCycle.closedPathDecision == .requiresRemediation,
              sourceCycle.lastRemediatedRoundID == sourceCycle.currentRoundID,
              sourceCycle.confirmationReceiptID != nil
        else { return false }
        var expected = sourceCycle
        expected.clearCurrentRoundClosure()
        expected.phase = .collectingException
        expected.currentRoundKind = admission.successorBaseline.kind
        expected.currentSemanticOrdinal = admission.successorBaseline.semanticOrdinal
        expected.currentRoundAnchorEventHead =
            admission.successorBaseline.preCreationEventHead
        expected.predecessorBaselineDigest =
            admission.successorBaseline.predecessorBaselineDigest
        expected.currentRoundID = admission.successorBaseline.roundID
        return admission.successorBaseline.kind == .exception &&
            admission.successorBaseline.predecessorBaselineDigest == predecessor &&
            admission.eligibility.nextRoundID == admission.successorBaseline.roundID &&
            admission.eligibility.roundAnchorEventHead ==
                admission.successorBaseline.preCreationEventHead &&
            proposedCycle == expected &&
            source.nextReviewCycleOrdinal == proposed.nextReviewCycleOrdinal
    case .converged:
        var expected = sourceCycle
        expected.phase = .converged
        expected.convergenceReceiptID = try ReceiptID(validating: preimage.event.id)
        let isDirect = sourceCycle.currentRoundKind == .initial &&
            sourceCycle.phase == .awaitingRemediation &&
            sourceCycle.closedPathDecision == .directConvergenceNoAcceptedCurrentScope
        let isConfirmed = sourceCycle.currentRoundKind == .normalConfirmation &&
            sourceCycle.phase == .collectingNormalConfirmation &&
            sourceCycle.closedPathDecision == .directConvergenceNoAcceptedCurrentScope &&
            sourceCycle.confirmationReceiptID != nil
        let isConfirmedException = sourceCycle.currentRoundKind == .exception &&
            sourceCycle.phase == .collectingException &&
            sourceCycle.closedPathDecision == .directConvergenceNoAcceptedCurrentScope &&
            sourceCycle.confirmationReceiptID != nil
        return sourceCycle.hasVerifiedCurrentRoundClosure &&
            sourceCycle.closedPathDecision != .requiresRemediation &&
            (isDirect || isConfirmed || isConfirmedException) &&
            proposedCycle == expected &&
            source.nextReviewCycleOrdinal == proposed.nextReviewCycleOrdinal
    case .invalidated:
        var expected = sourceCycle
        expected.phase = .invalidated
        expected.clearCurrentRoundClosure()
        expected.lastRemediatedRoundID = nil
        expected.confirmationReceiptID = nil
        let nextCycleOrdinal = try incrementChecked(sourceCycle.cycleOrdinal)
        return sourceCycle.phase != .invalidated &&
            proposedCycle == expected &&
            proposed.nextReviewCycleOrdinal == nextCycleOrdinal
    }
}

private extension WorkflowEventKind {
    var isReviewPublicationEvent: Bool {
        switch self {
        case .reviewInventoryRecorded, .reviewInventoryClosed, .reviewRemediationRecorded,
             .reviewConfirmationRecorded, .reviewExceptionOpened, .reviewConverged,
             .reviewInvalidated:
            true
        default:
            false
        }
    }
}

#if DEBUG
struct ReviewInvalidationTestScenario: Sendable {
    let lineage: VerifiedConfirmationLineage
    let persistedRun: PersistedRun
    let intersectingInvalidation: ValidatedArtifactInvalidation
    let scopedOutInvalidation: ValidatedArtifactInvalidation
    let invalidationPlan: ReviewInvalidationPlan

    var baselines: [ReviewBaseline] { lineage.baselines }
    var inventories: [ReviewerFindingInventory] { lineage.inventories }
    var registers: [IssueRegister] { lineage.registers }
    var remediationBatches: [RemediationBatch] { lineage.remediationBatches }
    var confirmationReceipts: [ConfirmationReceipt] { lineage.confirmationReceipts }
    var exceptionRounds: [ReviewExceptionEligibility] { lineage.exceptionRounds }
    var convergenceReceipts: [ConvergenceReceipt] { lineage.convergenceReceipts }
    var downstreamApprovals: [ApprovalRecord] { lineage.downstreamApprovals }
}

enum ReviewPublicationOperationTestKind: String, CaseIterable, Hashable, Sendable {
    case inventoryRecorded
    case inventoryClosed
    case remediationRecorded
    case confirmationRecorded
    case exceptionOpened
    case directConvergence
    case confirmedConvergence
    case invalidated
}

struct ReviewPublicationOperationTestScenario: Sendable {
    typealias Publish = @Sendable (
        any RunStateStore,
        VerifiedAuthorityFact,
        URL,
        WriterLease
    ) throws -> ReviewPublicationCommit

    let kind: ReviewPublicationOperationTestKind
    let source: PersistedRun
    let expectedEventKind: WorkflowEventKind
    let expectedEventID: String
    let expectedReceiptAddresses: [String]
    private let publishOperation: Publish

    init(
        kind: ReviewPublicationOperationTestKind,
        source: PersistedRun,
        expectedEventKind: WorkflowEventKind,
        expectedEventID: String,
        expectedReceiptAddresses: [String],
        publishOperation: @escaping Publish
    ) {
        self.kind = kind
        self.source = source
        self.expectedEventKind = expectedEventKind
        self.expectedEventID = expectedEventID
        self.expectedReceiptAddresses = expectedReceiptAddresses.sorted()
        self.publishOperation = publishOperation
    }

    func publish(
        store: any RunStateStore,
        publisher: VerifiedAuthorityFact,
        runRoot: URL,
        lease: WriterLease
    ) throws -> ReviewPublicationCommit {
        try publishOperation(store, publisher, runRoot, lease)
    }
}

extension ReviewCapabilityTestFactory {
    static func invalidationScenario() throws -> ReviewInvalidationTestScenario {
        try ReviewInvalidationScenarioBuilder.make()
    }

    static func publicationOperationScenarios() throws
        -> [ReviewPublicationOperationTestScenario] {
        try debugReviewPublicationOperationScenarios()
    }
}

private struct DebugReviewPolicySetup {
    let profileContext: ActivePolicyContext
    let gatePolicy: GatePolicy
    let author: VerifiedAuthorityFact
    let approvalBinding: VerifiedApprovalPolicyBinding
}

private struct DebugReviewRoundBundle: Sendable {
    let baseline: ReviewBaseline
    let inventory: ReviewerFindingInventory
    let inventoryAuthority: VerifiedReviewerInventoryAuthority
    let completeInventories: VerifiedCompleteInventorySet
    let verifiedRegister: VerifiedIssueRegister
    let policies: VerifiedReviewPolicySet
    let currentness: VerifiedReviewScopeCurrentness
    let persistedRun: PersistedRun
}

private struct DebugReceiptPayload: Codable {
    let schemaVersion: Int
    let receiptID: String

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case receiptID = "receipt_id"
    }
}

private func debugReviewDigest(_ label: String) -> HashDigest {
    CanonicalTreeDigest.sha256(Data(label.utf8))
}

private func debugReviewArtifact(
    hash: HashDigest,
    id: String = "review-source",
    scope: String = "workflow.review"
) throws -> ArtifactReference {
    try ArtifactReference(
        id: ArtifactID(validating: id),
        type: .source,
        scope: ArtifactScope(kind: .semanticSelector, value: scope),
        contentHash: hash
    )
}

private func debugReviewGraph(_ artifacts: [ArtifactReference]) throws -> ArtifactGraph {
    let roots = try artifacts.map {
        try ArtifactIndependentRoot(artifactID: $0.id, artifactHash: $0.contentHash)
    }
    let authority = try VerifiedArtifactTraceAuthority.testing(
        policyID: "review-trace-policy-v1",
        policyDigest: debugReviewDigest("review-trace-policy"),
        requiredObligations: [],
        permittedIndependentRoots: roots
    )
    return try ArtifactGraph(
        artifacts: artifacts,
        dependencies: [],
        dependencyObligations: [],
        independentRoots: roots,
        authority: authority
    )
}

private func debugReviewPolicySetup() throws -> DebugReviewPolicySetup {
    let profileID = try ProfileID(validating: "review-debug-profile")
    let profileDigest = debugReviewDigest("review-debug-profile")
    let context = try ActivePolicyContext(
        profileID: profileID,
        profileDigest: profileDigest,
        riskClass: .medium
    )
    let gatePolicy = try GatePolicy.standard(
        profileID: profileID,
        profileDigest: profileDigest,
        policyDigest: debugReviewDigest("review-gate-policy"),
        distinctPrincipalPolicy: .strict,
        specialistReviewersByRisk: [
            .high: [.securityPrivacyReviewer],
            .critical: [.securityPrivacyReviewer, .dataIntegrityReviewer],
        ]
    )
    let author = VerifiedAuthorityFact(
        actorID: try ActorID(validating: "review-debug-author"),
        principalID: try PrincipalID(validating: "review-debug-author-principal"),
        roles: [.author],
        principalKind: .agent,
        independentContextDigest: debugReviewDigest("review-debug-author-context"),
        hasAuthorshipEdge: false,
        hasSourceWriteCapability: true
    )
    let binding = try VerifiedApprovalPolicyBinding.derive(
        gatePolicy: gatePolicy,
        gate: .requirementGate,
        mode: .auto,
        policyContext: context,
        escalationFlags: [],
        author: author
    )
    return DebugReviewPolicySetup(
        profileContext: context,
        gatePolicy: gatePolicy,
        author: author,
        approvalBinding: binding
    )
}

private func debugReviewApproval(
    graph: ArtifactGraph,
    setup: DebugReviewPolicySetup
) throws -> ApprovalRecord {
    let reviewed = try VerifiedReviewedArtifactSet.derive(graph: graph, gate: .requirementGate)
    let validator = VerifiedAuthorityFact(
        actorID: try ActorID(validating: "review-debug-approver"),
        principalID: try PrincipalID(validating: "review-debug-approver-principal"),
        roles: [.requirementsValidator, .standardsValidator],
        principalKind: .agent,
        independentContextDigest: debugReviewDigest("review-debug-approver-context"),
        hasAuthorshipEdge: false,
        hasSourceWriteCapability: false
    )
    return try ApprovalRecord.issue(
        gate: .requirementGate,
        kind: .autoApproved,
        role: .requirementsValidator,
        authorityFact: validator,
        policyBinding: setup.approvalBinding,
        reviewedSet: reviewed,
        timestamp: Date(timeIntervalSince1970: 0.123),
        attestationReference: "review-debug-approval-attestation"
    )
}

private func debugReviewRoster() throws -> (FrozenReviewerRoster, ReviewerAssignment) {
    let redaction = try RedactionPolicyBinding(
        identity: "review-redaction-v1",
        digest: debugReviewDigest("review-redaction-policy")
    )
    let assignment = try ReviewerAssignment(
        id: ReviewAssignmentID(validating: "review-assignment"),
        requiredRole: AuthorityRole.standardsValidator.rawValue,
        assuranceClass: .critical,
        independenceConstraints: ReviewerIndependenceConstraint.allCases,
        checklistDigest: debugReviewDigest("review-checklist"),
        redactionPolicy: redaction,
        expectedActorID: ActorID(validating: "reviewer-agent"),
        expectedPrincipalID: PrincipalID(validating: "reviewer-principal"),
        evidenceKind: .findingProducingReview
    )
    return (
        try FrozenReviewerRoster.freeze(assignments: [assignment], redactionPolicy: redaction),
        assignment
    )
}

private func debugReviewBaseline(
    runID: RunID,
    roundInput: ReviewRoundInput,
    artifacts: [ArtifactReference],
    roster: FrozenReviewerRoster,
    setup: DebugReviewPolicySetup,
    convergencePolicyDigest: HashDigest
) throws -> ReviewBaseline {
    try ReviewBaseline.freeze(
        runID: runID,
        roundInput: roundInput,
        artifactScopes: artifacts,
        activeProfileDigest: setup.profileContext.profileDigest,
        riskPolicyDigest: setup.gatePolicy.policyDigest,
        assurancePolicyDigest: setup.approvalBinding.authorityPolicyDigest,
        convergencePolicyDigest: convergencePolicyDigest,
        roster: roster
    )
}

private func debugReviewPersistedRun(
    runID: RunID,
    profileDigest: HashDigest,
    eventKind: WorkflowEventKind,
    receipts: [PersistedReceipt],
    state: RunState? = nil
) throws -> PersistedRun {
    var value = try state ?? RunState.startEngineering(
        runID: runID,
        workItemID: "review-debug-work-item",
        mode: .auto,
        canonSnapshotDigest: profileDigest
    )
    value.stage = .requirementGate
    var effectiveReceipts = receipts
    if effectiveReceipts.isEmpty {
        let anchorID = try ReceiptID(validating: "review-debug-anchor")
        effectiveReceipts = [try debugPersistedReceipt(
            kind: "review-debug-anchor",
            id: anchorID,
            payloadBytes: CanonicalJSON.encode(
                DebugReceiptPayload(schemaVersion: 1, receiptID: anchorID.rawValue)
            )
        )]
    }
    let identityDigest = CanonicalTreeDigest.sha256(Data(([eventKind.rawValue] + effectiveReceipts
        .map { "\($0.kind.rawValue)/\($0.id.rawValue)" })
        .sorted()
        .joined(separator: "|")
        .utf8))
    let suffix = String(identityDigest.rawValue.prefix(16))
    let event = try WorkflowEvent(
        id: "review-debug-commit-\(suffix)",
        kind: eventKind
    )
    value.processedEvents = [try ProcessedWorkflowEvent(recording: event)]
    let writes = try effectiveReceipts.map {
        try ReceiptTableWrite(
            kind: $0.kind,
            id: $0.id,
            canonicalPayloadBytes: $0.payloadBytes
        )
    }.sorted(by: receiptWriteOrder)
    let transaction = try StateTransaction(
        id: TransactionID(rawValue: "review-debug-\(suffix)"),
        runRoot: FileManager.default.temporaryDirectory.appendingPathComponent(
            runID.filesystemComponent,
            isDirectory: true
        ),
        expectedStateDigest: nil,
        expectedEventHead: nil,
        state: value,
        event: event,
        receiptWrites: writes
    )
    let manifest = try debugReviewManifest(writes: writes, transaction: transaction)
    let stateBytes = try CanonicalJSON.encode(value)
    let stateDigest = CanonicalTreeDigest.sha256(stateBytes)
    let record = try EventLogRecord(
        sequence: 1,
        runID: runID,
        transactionID: transaction.id,
        previousDigest: nil,
        previousStateDigest: nil,
        stateDigest: stateDigest,
        transactionDigest: transaction.digest,
        fencingToken: FencingToken(validating: 1),
        writerOwnerID: "review-debug-writer",
        receiptManifest: manifest,
        event: event
    )
    let committedReceipts = writes.map {
        debugCommittedReceipt(write: $0, transaction: transaction)
    }
    return PersistedRun(
        state: value,
        stateBytes: stateBytes,
        stateDigest: stateDigest,
        events: [record],
        eventHead: record.recordDigest,
        receipts: committedReceipts
    )
}

private func debugAppendReviewPublication(
    to persistedRun: PersistedRun,
    event: WorkflowEvent,
    receipts: [PersistedReceipt],
    state: RunState
) throws -> PersistedRun {
    guard !receipts.isEmpty,
          persistedRun.state.runID == state.runID,
          persistedRun.events.last?.recordDigest == persistedRun.eventHead,
          persistedRun.events.last?.stateDigest == persistedRun.stateDigest
    else { throw PersistenceError.integrityViolation }
    let existingAddresses = Set(persistedRun.receipts.map {
        "\($0.kind.rawValue)/\($0.id.rawValue)"
    })
    let writes = try receipts.map {
        try ReceiptTableWrite(
            kind: $0.kind,
            id: $0.id,
            canonicalPayloadBytes: $0.payloadBytes
        )
    }.sorted(by: receiptWriteOrder)
    let writeAddresses = writes.map { "\($0.kind.rawValue)/\($0.id.rawValue)" }
    guard Set(writeAddresses).count == writeAddresses.count,
          existingAddresses.isDisjoint(with: Set(writeAddresses))
    else { throw PersistenceError.integrityViolation }

    var value = state
    value.processedEvents = persistedRun.state.processedEvents
    value.processedEvents.append(try ProcessedWorkflowEvent(recording: event))
    let transactionIdentity = CanonicalTreeDigest.sha256(Data(
        "\(persistedRun.eventHead.rawValue)/\(event.id)".utf8
    ))
    let suffix = String(transactionIdentity.rawValue.prefix(16))
    let transaction = try StateTransaction(
        id: TransactionID(rawValue: "review-debug-\(suffix)"),
        runRoot: FileManager.default.temporaryDirectory.appendingPathComponent(
            state.runID.filesystemComponent,
            isDirectory: true
        ),
        expectedStateDigest: persistedRun.stateDigest,
        expectedEventHead: persistedRun.eventHead,
        state: value,
        event: event,
        receiptWrites: writes
    )
    let manifest = try debugReviewManifest(writes: writes, transaction: transaction)
    let stateBytes = try CanonicalJSON.encode(value)
    let stateDigest = CanonicalTreeDigest.sha256(stateBytes)
    let sequence = UInt64(persistedRun.events.count + 1)
    let record = try EventLogRecord(
        sequence: sequence,
        runID: state.runID,
        transactionID: transaction.id,
        previousDigest: persistedRun.eventHead,
        previousStateDigest: persistedRun.stateDigest,
        stateDigest: stateDigest,
        transactionDigest: transaction.digest,
        fencingToken: FencingToken(validating: sequence),
        writerOwnerID: "review-debug-writer",
        receiptManifest: manifest,
        event: event
    )
    let appendedReceipts = writes.map {
        debugCommittedReceipt(write: $0, transaction: transaction)
    }
    return PersistedRun(
        state: value,
        stateBytes: stateBytes,
        stateDigest: stateDigest,
        events: persistedRun.events + [record],
        eventHead: record.recordDigest,
        receipts: (persistedRun.receipts + appendedReceipts).sorted {
            ($0.kind.rawValue, $0.id.rawValue) < ($1.kind.rawValue, $1.id.rawValue)
        }
    )
}

private func debugReviewManifest(
    writes: [ReceiptTableWrite],
    transaction: StateTransaction
) throws -> [ReceiptManifestEntry] {
    try writes.map { write -> ReceiptManifestEntry in
        let envelope = ReceiptEnvelope(write: write, transaction: transaction)
        let envelopeBytes = try CanonicalJSON.encode(envelope)
        return ReceiptManifestEntry(
            kind: write.kind,
            id: write.id,
            envelopeDigest: CanonicalTreeDigest.sha256(envelopeBytes),
            payloadDigest: write.payloadDigest,
            envelopeBytes: envelopeBytes
        )
    }.sorted {
        ($0.kind.rawValue, $0.id.rawValue) < ($1.kind.rawValue, $1.id.rawValue)
    }
}

private func debugCommittedReceipt(
    write: ReceiptTableWrite,
    transaction: StateTransaction
) -> PersistedReceipt {
    PersistedReceipt(
        kind: write.kind,
        id: write.id,
        transactionID: transaction.id,
        transactionDigest: transaction.digest,
        payloadDigest: write.payloadDigest,
        payloadBytes: write.payloadBytes
    )
}

private func debugCommittedReviewLineageReceipts(
    in persistedRun: PersistedRun
) throws -> [VerifiedPublishedReviewReceipt] {
    let semanticKinds: Set<String> = [
        "review-baseline",
        "review-inventory",
        "issue-register",
        "review-remediation-batch",
        "review-confirmation",
        "review-exception",
        "review-convergence",
    ]
    return try persistedRun.receipts
        .filter { semanticKinds.contains($0.kind.rawValue) }
        .sorted {
            ($0.kind.rawValue, $0.id.rawValue) < ($1.kind.rawValue, $1.id.rawValue)
        }
        .map {
            try ReviewCommittedReceiptVerifier.verify(
                id: $0.id,
                kind: $0.kind,
                digest: $0.payloadDigest,
                in: persistedRun
            )
        }
}

private func debugPersistedReceipt(
    kind: String,
    id: ReceiptID,
    payloadBytes: Data
) throws -> PersistedReceipt {
    PersistedReceipt(
        kind: try ReceiptKind(validating: kind),
        id: id,
        transactionID: try TransactionID(rawValue: "txn-\(id.rawValue)"),
        transactionDigest: debugReviewDigest("txn/\(id.rawValue)"),
        payloadDigest: CanonicalTreeDigest.sha256(payloadBytes),
        payloadBytes: payloadBytes
    )
}

private func debugReviewAuthorityState(
    baseline: ReviewBaseline
) throws -> RunState {
    let cycleOrdinal = baseline.cycleOrdinal ?? 0
    let phase: ReviewCyclePhase = switch baseline.kind {
    case .initial: .collectingInitial
    case .normalConfirmation: .collectingNormalConfirmation
    case .exception: .collectingException
    }
    let cycle = try ReviewCycleState(
        id: baseline.cycleID,
        gate: baseline.gate,
        cycleOrdinal: cycleOrdinal,
        phase: phase,
        currentRoundID: baseline.roundID,
        currentRoundKind: baseline.kind,
        currentSemanticOrdinal: baseline.semanticOrdinal,
        didRecordRemediation: baseline.kind != .initial,
        didRecordConfirmation: baseline.kind == .exception,
        redactionPolicy: baseline.redactionPolicy,
        cyclePreFreezeEventHead: baseline.kind == .initial
            ? baseline.preCreationEventHead
            : debugReviewDigest("review-cycle-anchor/\(baseline.cycleID.rawValue)"),
        currentRoundAnchorEventHead: baseline.preCreationEventHead,
        predecessorBaselineDigest: baseline.predecessorBaselineDigest
    )
    var state = try RunState.startEngineering(
        runID: baseline.runID,
        workItemID: "review-debug-work-item",
        mode: .auto,
        canonSnapshotDigest: baseline.activeProfileDigest
    )
    state.stage = .requirementGate
    state.reviewCycle = cycle
    return state
}

private func debugReceiptReference(
    id: String,
    kind: String
) throws -> (ImmutableReceiptReference, PersistedReceipt) {
    let receiptID = try ReceiptID(validating: id)
    let payload = try CanonicalJSON.encode(
        DebugReceiptPayload(schemaVersion: 1, receiptID: receiptID.rawValue)
    )
    return (
        ImmutableReceiptReference(
            id: receiptID,
            digest: CanonicalTreeDigest.sha256(payload)
        ),
        try debugPersistedReceipt(kind: kind, id: receiptID, payloadBytes: payload)
    )
}

private func debugReviewRound(
    baseline: ReviewBaseline,
    assignment: ReviewerAssignment,
    acceptedFinding: Bool,
    eventHead: HashDigest
) throws -> DebugReviewRoundBundle {
    let suffix = String(baseline.roundID.rawValue.prefix(12))
    let effectID = try ReceiptID(validating: "effect-\(suffix)")
    let domainID = try ReceiptID(validating: "domain-\(suffix)")
    let recordID = try ReceiptID(validating: "record-\(suffix)")
    let envelopeArtifact = try debugReviewArtifact(
        hash: debugReviewDigest("sanitized-envelope/\(suffix)"),
        id: "envelope-\(suffix)",
        scope: "workflow.review-envelope"
    )
    let findingIdentity = try ReviewFindingIdentity(kind: .rule, value: "IFL-REVIEW-001")
    let findings: [ReviewerFinding]
    if acceptedFinding {
        guard let artifact = baseline.artifactScopes.first else {
            throw WorkflowPolicyError.invalidPolicy
        }
        let components = try IssueFingerprintComponents(
            identity: findingIdentity,
            artifactID: artifact.id,
            scopeSelector: artifact.scope,
            locationSelector: "review/source",
            invariantID: "review-convergence",
            expectedClass: "complete",
            actualClass: "incomplete"
        )
        findings = [
            try ReviewerFinding(
                findingID: "finding-\(suffix)",
                components: components,
                severity: .high,
                mustFixClaim: true,
                title: "Review convergence finding",
                message: "Accepted issue requires remediation",
                evidenceReferences: [recordID.rawValue],
                confidenceBasis: "deterministic-review",
                reportedAt: "2026-07-12T00:00:00.000Z"
            ),
        ]
    } else {
        findings = []
    }
    let redactionMetadata = try ReviewRedactionMetadata(
        policy: baseline.redactionPolicy,
        sanitizedEnvelopeDigest: envelopeArtifact.contentHash,
        replacementTokenCount: findings.isEmpty ? 0 : 1,
        containsRawSensitiveData: false
    )
    let reviewerContextDigest = debugReviewDigest("reviewer/\(suffix)")
    func envelopePayload(
        id: ReceiptID,
        kind: String,
        effectReceipt: ImmutableReceiptReference? = nil,
        domainReceipt: ImmutableReceiptReference? = nil
    ) throws -> Data {
        try CanonicalJSON.encode(ReviewEnvelopeReceiptPayload(
            receiptID: id,
            receiptKind: ReceiptKind(validating: kind),
            runID: baseline.runID,
            baselineDigest: baseline.digest,
            roundID: baseline.roundID,
            rosterDigest: baseline.rosterDigest,
            assignmentID: assignment.id,
            checklistDigest: assignment.checklistDigest,
            actorID: assignment.expectedActorID,
            principalID: assignment.expectedPrincipalID,
            independentContextDigest: reviewerContextDigest,
            role: assignment.requiredRole,
            envelopeArtifact: envelopeArtifact,
            redactionPolicy: baseline.redactionPolicy,
            redactionMetadata: redactionMetadata,
            effectReceipt: effectReceipt,
            domainReceipt: domainReceipt,
            complete: true,
            findings: findings
        ))
    }
    let effectBytes = try envelopePayload(id: effectID, kind: "review-envelope-effect")
    let effectReference = ImmutableReceiptReference(
        id: effectID,
        digest: CanonicalTreeDigest.sha256(effectBytes)
    )
    let domainBytes = try envelopePayload(id: domainID, kind: "review-envelope-domain")
    let domainReference = ImmutableReceiptReference(
        id: domainID,
        digest: CanonicalTreeDigest.sha256(domainBytes)
    )
    let recordBytes = try envelopePayload(
        id: recordID,
        kind: "review-envelope-record",
        effectReceipt: effectReference,
        domainReceipt: domainReference
    )
    let recordReference = ImmutableReceiptReference(
        id: recordID,
        digest: CanonicalTreeDigest.sha256(recordBytes)
    )
    let submission = try ReviewerFindingSubmission(
        baselineDigest: baseline.digest,
        roundID: baseline.roundID,
        rosterDigest: baseline.rosterDigest,
        assignmentID: assignment.id,
        checklistDigest: assignment.checklistDigest,
        redactionPolicy: baseline.redactionPolicy,
        redactionMetadata: redactionMetadata,
        actorID: assignment.expectedActorID,
        principalID: assignment.expectedPrincipalID,
        role: assignment.requiredRole,
        envelope: ReviewerEnvelopeBinding(
            artifact: envelopeArtifact,
            effectReceipt: effectReference,
            domainReceipt: domainReference,
            recordReceipt: recordReference
        ),
        complete: true,
        findings: findings
    )
    let envelopeReceipts = try [
        debugPersistedReceipt(kind: "review-envelope-effect", id: effectID, payloadBytes: effectBytes),
        debugPersistedReceipt(kind: "review-envelope-domain", id: domainID, payloadBytes: domainBytes),
        debugPersistedReceipt(kind: "review-envelope-record", id: recordID, payloadBytes: recordBytes),
    ]
    let persisted = try debugReviewPersistedRun(
        runID: baseline.runID,
        profileDigest: baseline.activeProfileDigest,
        eventKind: .reviewInventoryRecorded,
        receipts: envelopeReceipts,
        state: debugReviewAuthorityState(baseline: baseline)
    )
    let currentness = try ReviewCapabilityTestFactory.verifyCurrentness(
        baseline: baseline,
        currentArtifacts: baseline.artifactScopes,
        currentEventHead: persisted.eventHead
    )
    guard let role = AuthorityRole(rawValue: assignment.requiredRole) else {
        throw WorkflowPolicyError.invalidPolicy
    }
    let reviewerAuthority = VerifiedAuthorityFact(
        actorID: assignment.expectedActorID,
        principalID: assignment.expectedPrincipalID,
        roles: [role],
        principalKind: .agent,
        independentContextDigest: reviewerContextDigest,
        hasAuthorshipEdge: false,
        hasSourceWriteCapability: false
    )
    let authorAuthority = VerifiedAuthorityFact(
        actorID: try ActorID(validating: "review-author-\(suffix)"),
        principalID: try PrincipalID(validating: "review-author-principal-\(suffix)"),
        roles: [.author],
        principalKind: .agent,
        independentContextDigest: debugReviewDigest("author/\(suffix)"),
        hasAuthorshipEdge: true,
        hasSourceWriteCapability: true
    )
    let authorshipContext = try ReviewAuthorshipContextVerifier.verify(
        authorAuthority: authorAuthority,
        baseline: baseline,
        currentness: currentness
    )
    let authority = try ReviewAuthorityVerifier.verifyInventoryAuthority(
        submission: submission,
        baseline: baseline,
        assignment: assignment,
        authority: reviewerAuthority,
        authorshipContext: authorshipContext,
        persistedRun: persisted,
        currentness: currentness
    )
    let inventory = try ReviewerFindingInventory.ingest(
        submission: submission,
        against: baseline,
        authority: authority
    )
    var collector = ReviewInventoryCollector(baseline: baseline)
    guard case let .complete(complete) = try collector.accept(
        inventory,
        authority: authority,
        currentness: currentness
    ) else { throw WorkflowPolicyError.invalidPolicy }

    let findingPolicy = try FrozenReviewFindingPolicy.freeze(
        mustFixIdentities: [findingIdentity]
    )
    let dispositionPolicy = try FrozenDispositionPolicy.freeze(
        authorizedPrincipalIDs: [try PrincipalID(validating: "kernel-principal")],
        mandatorySeverities: [.critical],
        permitsAuthenticatedHumanRiskAcceptance: false
    )
    let policies = try ReviewPolicyVerifier.verify(
        findingPolicy: findingPolicy,
        dispositionPolicy: dispositionPolicy,
        baseline: baseline
    )
    var verifiedEvidence: [VerifiedReviewDispositionEvidence] = []
    if let finding = findings.first {
        let fingerprint = try IssueFingerprint.derive(from: finding.components)
        let evidenceID = try ReceiptID(validating: "disposition-\(suffix)")
        let dispositionAuthority = VerifiedAuthorityFact(
            actorID: try ActorID(validating: "kernel-actor"),
            principalID: try PrincipalID(validating: "kernel-principal"),
            roles: [.kernel],
            principalKind: .kernel,
            independentContextDigest: debugReviewDigest("kernel/\(suffix)"),
            hasAuthorshipEdge: false,
            hasSourceWriteCapability: false
        )
        let evidencePayload = try CanonicalJSON.encode(
            ReviewDispositionEvidenceReceiptPayload(
                receiptID: evidenceID,
                runID: baseline.runID,
                baselineDigest: baseline.digest,
                fingerprint: fingerprint.failureFingerprint,
                severity: finding.severity,
                mustFix: true,
                evidenceKind: .acceptedScope,
                remediationAssignmentID: "remediation-\(suffix)",
                scopeDigest: baseline.artifactScopes[0].contentHash,
                humanRiskAcceptance: false,
                disputed: false,
                authorityActorID: dispositionAuthority.actorID,
                authorityPrincipalID: dispositionAuthority.principalID,
                authorityKind: .kernel,
                claimedAuthenticated: true,
                authorityPolicyDigest: dispositionPolicy.digest,
                authorityContextDigest: dispositionAuthority.independentContextDigest,
                evidenceReferences: [evidenceID.rawValue]
            )
        )
        let evidenceReceipt = try debugPersistedReceipt(
            kind: "review-disposition-evidence",
            id: evidenceID,
            payloadBytes: evidencePayload
        )
        let rationaleDigest = evidenceReceipt.payloadDigest
        let claim = try DispositionAuthorityClaim(
            actorID: dispositionAuthority.actorID,
            principalID: dispositionAuthority.principalID,
            claimedKind: .kernel,
            claimedAuthenticated: true,
            authorityPolicyDigest: dispositionPolicy.digest,
            rationaleDigest: rationaleDigest,
            evidenceReferences: [evidenceID.rawValue]
        )
        let raw = IssueDispositionEvidence(
            fingerprint: fingerprint.failureFingerprint,
            envelope: try DispositionEvidenceEnvelope(
                issueFingerprint: fingerprint.failureFingerprint,
                severity: finding.severity,
                mustFix: true,
                evidenceKind: .acceptedScope,
                remediationAssignmentID: "remediation-\(suffix)",
                scopeDigest: baseline.artifactScopes[0].contentHash,
                humanRiskAcceptance: false,
                disputed: false,
                authority: claim
            ),
            verifiedAuthority: VerifiedDispositionAuthorityFact(
                actorID: claim.actorID,
                principalID: claim.principalID,
                kind: .kernel,
                authorityPolicyDigest: claim.authorityPolicyDigest,
                rationaleDigest: claim.rationaleDigest,
                evidenceReferences: claim.evidenceReferences
            )
        )
        let dispositionPersisted = try debugReviewPersistedRun(
            runID: baseline.runID,
            profileDigest: baseline.activeProfileDigest,
            eventKind: .reviewInventoryRecorded,
            receipts: envelopeReceipts + [evidenceReceipt]
        )
        verifiedEvidence = [try ReviewAuthorityVerifier.verifyDispositionEvidence(
            evidence: raw,
            authority: dispositionAuthority,
            persistedRun: dispositionPersisted,
            policies: policies
        )]
    }
    let register = try IssueRegister.issue(
        baseline: baseline,
        inventories: complete,
        policies: policies,
        dispositionEvidence: verifiedEvidence
    )
    let verifiedRegister = try ReviewSemanticIngress.verifyRegister(
        bytes: CanonicalJSON.encode(register),
        baseline: baseline,
        inventories: complete,
        policies: policies,
        dispositionEvidence: verifiedEvidence
    )
    return DebugReviewRoundBundle(
        baseline: baseline,
        inventory: inventory,
        inventoryAuthority: authority,
        completeInventories: complete,
        verifiedRegister: verifiedRegister,
        policies: policies,
        currentness: currentness,
        persistedRun: persisted
    )
}

private struct DebugReviewRemediationBundle: Sendable {
    let planned: VerifiedRemediationSuccessor
    let committed: VerifiedCommittedRemediationSuccessor
    let source: PersistedRun
    let committedRun: PersistedRun
}

private func debugReviewRemediation(
    source: DebugReviewRoundBundle,
    successor: ReviewBaseline,
    eventHead _: HashDigest,
    persistedSource: PersistedRun? = nil
) throws -> DebugReviewRemediationBundle {
    guard let entry = source.verifiedRegister.register.entries.first,
          let preArtifact = source.baseline.artifactScopes.first,
          let postArtifact = successor.artifactScopes.first
    else { throw WorkflowPolicyError.invalidDispositionEvidence }
    let definitions: [(RemediationEvidenceKind, String)] = [
        (.command, "command"),
        (.staticAnalysis, "static"),
        (.review, "review"),
    ]
    let implementingAuthority = VerifiedAuthorityFact(
        actorID: try ActorID(validating: "review-debug-implementer"),
        principalID: try PrincipalID(validating: "review-debug-implementer-principal"),
        roles: [.author],
        principalKind: .agent,
        independentContextDigest: debugReviewDigest("review-debug-implementation"),
        hasAuthorshipEdge: true,
        hasSourceWriteCapability: true
    )
    let cycleOrdinal = source.baseline.cycleOrdinal ?? 0
    let planningCycle = try ReviewCycleState(
        id: source.baseline.cycleID,
        gate: source.baseline.gate,
        cycleOrdinal: cycleOrdinal,
        phase: .awaitingRemediation,
        currentRoundID: source.baseline.roundID,
        currentRoundKind: source.baseline.kind,
        currentSemanticOrdinal: source.baseline.semanticOrdinal,
        didRecordRemediation: source.baseline.kind != .initial,
        didRecordConfirmation: source.baseline.kind != .initial,
        redactionPolicy: source.baseline.redactionPolicy,
        cyclePreFreezeEventHead: source.baseline.kind == .initial
            ? source.baseline.preCreationEventHead
            : debugReviewDigest("review-cycle-anchor/\(source.baseline.cycleID.rawValue)"),
        currentRoundAnchorEventHead: source.baseline.preCreationEventHead,
        predecessorBaselineDigest: source.baseline.predecessorBaselineDigest,
        closedRoundID: source.baseline.roundID,
        closedBaselineDigest: source.baseline.digest,
        closedRegisterDigest: source.verifiedRegister.register.digest,
        closedPathDecision: .requiresRemediation,
        confirmationReceiptID: source.baseline.kind == .initial
            ? nil
            : try ReceiptID(validating: "review-debug-confirmation")
    )
    var planningState = try RunState.startEngineering(
        runID: source.baseline.runID,
        workItemID: "review-debug-work-item",
        mode: .auto,
        canonSnapshotDigest: source.baseline.activeProfileDigest
    )
    planningState.stage = .requirementGate
    planningState.reviewCycle = planningCycle
    let persisted: PersistedRun
    if let persistedSource {
        guard persistedSource.state.runID == source.baseline.runID,
              persistedSource.state.reviewCycle?.currentRoundID == source.baseline.roundID,
              persistedSource.state.reviewCycle?.closedRegisterDigest ==
                source.verifiedRegister.register.digest,
              persistedSource.state.reviewCycle?.closedPathDecision == .requiresRemediation
        else { throw PersistenceError.integrityViolation }
        persisted = persistedSource
    } else {
        persisted = try debugReviewPersistedRun(
            runID: source.baseline.runID,
            profileDigest: source.baseline.activeProfileDigest,
            eventKind: .reviewInventoryClosed,
            receipts: [],
            state: planningState
        )
    }
    let successorInput = try ReviewRoundInput.later(
        cycleID: source.baseline.cycleID,
        gate: successor.gate,
        kind: successor.kind,
        semanticOrdinal: successor.semanticOrdinal,
        roundAnchorEventHead: persisted.eventHead,
        predecessorBaselineDigest: source.baseline.digest,
        redactionPolicy: successor.redactionPolicy
    )
    let committedSuccessor = try ReviewBaseline.freeze(
        runID: source.baseline.runID,
        roundInput: successorInput,
        artifactScopes: successor.artifactScopes,
        activeProfileDigest: successor.activeProfileDigest,
        riskPolicyDigest: successor.riskPolicyDigest,
        assurancePolicyDigest: successor.assurancePolicyDigest,
        convergencePolicyDigest: successor.convergencePolicyDigest,
        roster: successor.roster
    )
    let planning = try ReviewRemediationPlanningVerifier.verify(
        sourceRegister: source.verifiedRegister,
        successorBaseline: committedSuccessor,
        currentGraph: debugReviewGraph(committedSuccessor.artifactScopes),
        persistedRun: persisted
    )
    let implementationAuthority = try ReviewImplementationAuthorityVerifier.verify(
        authority: implementingAuthority,
        planning: planning
    )
    let plannedEvidence = try definitions.map { evidenceKind, stem in
        try ReviewRemediationEvidencePlanner.plan(
            receiptID: ReceiptID(
                validating: "\(stem)-\(source.baseline.semanticOrdinal)-" +
                    String(entry.fingerprint.rawValue.prefix(12))
            ),
            kind: evidenceKind,
            fingerprint: entry.fingerprint,
            preChangeArtifact: preArtifact,
            postChangeArtifact: postArtifact,
            sourceRegister: source.verifiedRegister,
            implementationAuthority: implementationAuthority
        )
    }
    let change = try RemediationChange(
        fingerprint: entry.fingerprint,
        preChangeArtifact: preArtifact,
        postChangeArtifact: postArtifact,
        evidence: plannedEvidence.map(\.evidence)
    )
    let planned = try ReviewRemediationVerifier.verifySuccessor(
        sourceRegister: source.verifiedRegister,
        changes: [change],
        plannedEvidence: plannedEvidence,
        implementationAuthority: implementationAuthority,
        successorBaseline: committedSuccessor,
        planning: planning
    )
    let suffix = String(persisted.eventHead.rawValue.prefix(16))
    var publicationReceipts = try [
        debugPersistedReceipt(
            kind: "review-baseline",
            id: ReceiptID(validating: "review-baseline-\(suffix)"),
            payloadBytes: CanonicalJSON.encode(planned.successorBaseline)
        ),
        debugPersistedReceipt(
            kind: "review-remediation-batch",
            id: ReceiptID(validating: "review-remediation-batch-\(suffix)"),
            payloadBytes: CanonicalJSON.encode(planned.batch)
        ),
        debugPersistedReceipt(
            kind: "review-resolved-transitions",
            id: ReceiptID(validating: "review-resolved-transitions-\(suffix)"),
            payloadBytes: CanonicalJSON.encode(
                ReviewResolvedTransitionsReceiptPayload(batch: planned.batch)
            )
        ),
    ]
    publicationReceipts.append(contentsOf: try planned.plannedEvidence.map {
        try debugPersistedReceipt(
            kind: $0.payload.receiptKind.rawValue,
            id: $0.payload.receiptID,
            payloadBytes: $0.payloadBytes
        )
    })
    let remediationEvent = try WorkflowEvent(
        id: "review-remediation-batch-\(suffix)",
        kind: .reviewRemediationRecorded
    )
    var committedState = persisted.state
    guard var committedCycle = committedState.reviewCycle else {
        throw PersistenceError.integrityViolation
    }
    committedCycle.didRecordRemediation = true
    committedCycle.lastRemediatedRoundID = committedCycle.currentRoundID
    committedState.reviewCycle = committedCycle
    let committedRun = try debugAppendReviewPublication(
        to: persisted,
        event: remediationEvent,
        receipts: publicationReceipts,
        state: committedState
    )
    let committed = try ReviewCommittedRemediationVerifier.verify(
        sourceRegister: source.verifiedRegister,
        batch: planned.batch,
        successorBaseline: planned.successorBaseline,
        persistedRun: committedRun
    )
    return DebugReviewRemediationBundle(
        planned: planned,
        committed: committed,
        source: persisted,
        committedRun: committedRun
    )
}

private enum ReviewInvalidationScenarioBuilder {
    static func make() throws -> ReviewInvalidationTestScenario {
        guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-00000000024b") else {
            throw WorkflowError.invalidIdentifier
        }
        return try make(
            runID: RunID(rawValue: uuid),
            eventHead: debugReviewDigest("review-invalidation-final-event-head")
        )
    }

    static func make(
        runID: RunID,
        eventHead: HashDigest
    ) throws -> ReviewInvalidationTestScenario {
        return try debugTerminalConfirmationInvalidationScenario(
            runID: runID,
            eventHead: eventHead
        )
    }
}

private struct DebugTerminalConfirmationFlow: Sendable {
    let sourceRound: DebugReviewRoundBundle
    let remediation: DebugReviewRemediationBundle
    let confirmationRound: DebugReviewRoundBundle
    let lineageRun: PersistedRun
    let committedRemediation: VerifiedCommittedRemediationSuccessor
    let confirmationAuthority: VerifiedReviewReceiptAuthority
    let confirmationReceipt: ConfirmationReceipt
    let authorityRun: PersistedRun
    let preConvergenceAuthority: VerifiedReviewReceiptAuthority
    let preliminaryLineage: VerifiedConfirmationLineage
    let convergenceReceipt: ConvergenceReceipt
    let persistedRun: PersistedRun
    let finalAuthority: VerifiedReviewReceiptAuthority
    let lineage: VerifiedConfirmationLineage
    let successorArtifact: ArtifactReference
    let successorBytes: Data
}

private func debugTerminalConfirmationFlow(
    runID: RunID,
    eventHead: HashDigest
) throws -> DebugTerminalConfirmationFlow {
    let setup = try debugReviewPolicySetup()
    let (roster, assignment) = try debugReviewRoster()
    let budget = try AttemptBudget.standardV1(
        policyDigest: debugReviewDigest("review-convergence-budget-v1")
    )
    let sourceBytes = Data("review-source-v1/\(runID.rawValue.uuidString)".utf8)
    let successorBytes = Data("review-source-v2/\(runID.rawValue.uuidString)".utf8)
    let sourceArtifact = try debugReviewArtifact(
        hash: CanonicalTreeDigest.sha256(sourceBytes)
    )
    let successorArtifact = try debugReviewArtifact(
        hash: CanonicalTreeDigest.sha256(successorBytes)
    )
    let initialInput = try ReviewRoundInput.initial(
        gate: .requirements,
        cycleOrdinal: 0,
        preFreezeEventHead: debugReviewDigest("review-initial-anchor/\(runID.rawValue)"),
        redactionPolicy: roster.redactionPolicy
    )
    let sourceBaseline = try debugReviewBaseline(
        runID: runID,
        roundInput: initialInput,
        artifacts: [sourceArtifact],
        roster: roster,
        setup: setup,
        convergencePolicyDigest: budget.policyDigest
    )
    let sourceRound = try debugReviewRound(
        baseline: sourceBaseline,
        assignment: assignment,
        acceptedFinding: true,
        eventHead: debugReviewDigest("review-initial-inventory/\(runID.rawValue)")
    )
    let plannedConfirmationInput = try ReviewRoundInput.later(
        cycleID: sourceBaseline.cycleID,
        gate: sourceBaseline.gate,
        kind: .normalConfirmation,
        semanticOrdinal: 1,
        roundAnchorEventHead: debugReviewDigest("review-remediation-event/\(runID.rawValue)"),
        predecessorBaselineDigest: sourceBaseline.digest,
        redactionPolicy: sourceBaseline.redactionPolicy
    )
    let plannedConfirmationBaseline = try debugReviewBaseline(
        runID: runID,
        roundInput: plannedConfirmationInput,
        artifacts: [successorArtifact],
        roster: roster,
        setup: setup,
        convergencePolicyDigest: budget.policyDigest
    )
    let remediationBundle = try debugReviewRemediation(
        source: sourceRound,
        successor: plannedConfirmationBaseline,
        eventHead: eventHead
    )
    let confirmationBaseline = remediationBundle.committed.successorBaseline
    let confirmationRound = try debugReviewRound(
        baseline: confirmationBaseline,
        assignment: assignment,
        acceptedFinding: false,
        eventHead: eventHead
    )
    let suffix = String(confirmationBaseline.digest.rawValue.prefix(12))
    let semanticReceipts = try [
        debugPersistedReceipt(
            kind: "review-baseline",
            id: ReceiptID(validating: "review-baseline-source-\(suffix)"),
            payloadBytes: CanonicalJSON.encode(sourceBaseline)
        ),
        debugPersistedReceipt(
            kind: "review-inventory",
            id: ReceiptID(validating: "review-inventory-source-\(suffix)"),
            payloadBytes: CanonicalJSON.encode(sourceRound.inventory)
        ),
        debugPersistedReceipt(
            kind: "issue-register",
            id: ReceiptID(validating: "issue-register-source-\(suffix)"),
            payloadBytes: CanonicalJSON.encode(sourceRound.verifiedRegister.register)
        ),
        debugPersistedReceipt(
            kind: "review-inventory",
            id: ReceiptID(validating: "review-inventory-confirmation-\(suffix)"),
            payloadBytes: CanonicalJSON.encode(confirmationRound.inventory)
        ),
        debugPersistedReceipt(
            kind: "issue-register",
            id: ReceiptID(validating: "issue-register-confirmation-\(suffix)"),
            payloadBytes: CanonicalJSON.encode(confirmationRound.verifiedRegister.register)
        ),
    ]
    var confirmationState = try debugReviewAuthorityState(baseline: confirmationBaseline)
    guard var confirmationCycle = confirmationState.reviewCycle else {
        throw PersistenceError.integrityViolation
    }
    confirmationCycle.didRecordRemediation = true
    confirmationCycle.lastRemediatedRoundID = sourceBaseline.roundID
    confirmationCycle.closedRoundID = confirmationBaseline.roundID
    confirmationCycle.closedBaselineDigest = confirmationBaseline.digest
    confirmationCycle.closedRegisterDigest = confirmationRound.verifiedRegister.register.digest
    confirmationCycle.closedPathDecision = .directConvergenceNoAcceptedCurrentScope
    confirmationState.reviewCycle = confirmationCycle
    let lineageRun = try debugAppendReviewPublication(
        to: remediationBundle.committedRun,
        event: WorkflowEvent(
            id: "review-debug-confirmation-close-\(suffix)",
            kind: .reviewInventoryClosed
        ),
        receipts: semanticReceipts,
        state: confirmationState
    )
    let approval = try debugReviewApproval(
        graph: debugReviewGraph([successorArtifact]),
        setup: setup
    )
    let confirmationCurrentness = try ReviewCapabilityTestFactory.verifyCurrentness(
        baseline: confirmationBaseline,
        currentArtifacts: confirmationBaseline.artifactScopes,
        currentEventHead: lineageRun.eventHead
    )
    let confirmationAuthority = try ReviewCapabilityTestFactory.verifyReceiptAuthority(
        persistedRun: lineageRun,
        currentness: confirmationCurrentness,
        policies: confirmationRound.policies,
        approvalRecords: [approval]
    )
    let committedRemediation = try ReviewCommittedRemediationVerifier.verify(
        sourceRegister: sourceRound.verifiedRegister,
        batch: remediationBundle.planned.batch,
        successorBaseline: confirmationBaseline,
        persistedRun: lineageRun
    )
    let confirmationReceipt = try ReviewConvergenceValidator.issueConfirmation(
        successor: committedRemediation,
        confirmationRegister: confirmationRound.verifiedRegister,
        authority: confirmationAuthority,
        publicationAnchorEventHead: lineageRun.eventHead
    )
    confirmationCycle.didRecordConfirmation = true
    confirmationCycle.confirmationReceiptID = try ReceiptID(
        validating: confirmationReceipt.receiptID
    )
    confirmationState.reviewCycle = confirmationCycle
    let authorityRun = try debugAppendReviewPublication(
        to: lineageRun,
        event: WorkflowEvent(
            id: confirmationReceipt.receiptID,
            kind: .reviewConfirmationRecorded
        ),
        receipts: [try debugPersistedReceipt(
            kind: "review-confirmation",
            id: ReceiptID(validating: confirmationReceipt.receiptID),
            payloadBytes: CanonicalJSON.encode(confirmationReceipt)
        )],
        state: confirmationState
    )
    let preConvergenceCurrentness = try ReviewCapabilityTestFactory.verifyCurrentness(
        baseline: confirmationBaseline,
        currentArtifacts: confirmationBaseline.artifactScopes,
        currentEventHead: authorityRun.eventHead
    )
    let preConvergenceAuthority = try ReviewCapabilityTestFactory.verifyReceiptAuthority(
        persistedRun: authorityRun,
        currentness: preConvergenceCurrentness,
        policies: confirmationRound.policies,
        approvalRecords: [approval]
    )
    let reboundRemediation = try ReviewCommittedRemediationVerifier.verify(
        sourceRegister: sourceRound.verifiedRegister,
        batch: remediationBundle.planned.batch,
        successorBaseline: confirmationBaseline,
        persistedRun: authorityRun
    )
    let preliminary = try ReviewConfirmationLineageVerifier.verify(
        registers: [sourceRound.verifiedRegister, confirmationRound.verifiedRegister],
        remediation: [reboundRemediation],
        confirmationReceipts: [confirmationReceipt],
        exceptionRounds: [],
        convergenceReceipts: [],
        receipts: debugCommittedReviewLineageReceipts(in: authorityRun),
        persistedRun: authorityRun,
        authority: preConvergenceAuthority
    )
    let convergenceReceipt = try ReviewConvergenceValidator.issueConfirmedConvergence(
        lineage: preliminary,
        authority: preConvergenceAuthority,
        publicationAnchorEventHead: authorityRun.eventHead
    )
    confirmationCycle.phase = .converged
    confirmationCycle.convergenceReceiptID = try ReceiptID(
        validating: convergenceReceipt.receiptID
    )
    confirmationState.reviewCycle = confirmationCycle
    let persistedRun = try debugAppendReviewPublication(
        to: authorityRun,
        event: WorkflowEvent(
            id: convergenceReceipt.receiptID,
            kind: .reviewConverged
        ),
        receipts: [try debugPersistedReceipt(
            kind: "review-convergence",
            id: ReceiptID(validating: convergenceReceipt.receiptID),
            payloadBytes: CanonicalJSON.encode(convergenceReceipt)
        )],
        state: confirmationState
    )
    let finalCurrentness = try ReviewCapabilityTestFactory.verifyCurrentness(
        baseline: confirmationBaseline,
        currentArtifacts: confirmationBaseline.artifactScopes,
        currentEventHead: persistedRun.eventHead
    )
    let finalAuthority = try ReviewCapabilityTestFactory.verifyReceiptAuthority(
        persistedRun: persistedRun,
        currentness: finalCurrentness,
        policies: confirmationRound.policies,
        approvalRecords: [approval]
    )
    let finalRemediation = try ReviewCommittedRemediationVerifier.verify(
        sourceRegister: sourceRound.verifiedRegister,
        batch: remediationBundle.planned.batch,
        successorBaseline: confirmationBaseline,
        persistedRun: persistedRun
    )
    let lineage = try ReviewConfirmationLineageVerifier.verify(
        registers: [sourceRound.verifiedRegister, confirmationRound.verifiedRegister],
        remediation: [finalRemediation],
        confirmationReceipts: [confirmationReceipt],
        exceptionRounds: [],
        convergenceReceipts: [convergenceReceipt],
        receipts: debugCommittedReviewLineageReceipts(in: persistedRun),
        persistedRun: persistedRun,
        authority: finalAuthority
    )
    return DebugTerminalConfirmationFlow(
        sourceRound: sourceRound,
        remediation: remediationBundle,
        confirmationRound: confirmationRound,
        lineageRun: lineageRun,
        committedRemediation: committedRemediation,
        confirmationAuthority: confirmationAuthority,
        confirmationReceipt: confirmationReceipt,
        authorityRun: authorityRun,
        preConvergenceAuthority: preConvergenceAuthority,
        preliminaryLineage: preliminary,
        convergenceReceipt: convergenceReceipt,
        persistedRun: persistedRun,
        finalAuthority: finalAuthority,
        lineage: lineage,
        successorArtifact: successorArtifact,
        successorBytes: successorBytes
    )
}

private func debugTerminalConfirmationInvalidationScenario(
    runID: RunID,
    eventHead: HashDigest
) throws -> ReviewInvalidationTestScenario {
    let flow = try debugTerminalConfirmationFlow(runID: runID, eventHead: eventHead)
    let intersectingInvalidation = try debugArtifactInvalidation(
        artifact: flow.successorArtifact,
        storedBytes: flow.successorBytes,
        currentBytes: Data("review-source-v3/\(runID.rawValue.uuidString)".utf8),
        verifierID: ActorID(validating: "review-invalidation-verifier")
    )
    let scopedBytes = Data("review-scoped-out-v1/\(runID.rawValue.uuidString)".utf8)
    let scopedArtifact = try debugReviewArtifact(
        hash: CanonicalTreeDigest.sha256(scopedBytes),
        id: "review-scoped-out",
        scope: "workflow.other"
    )
    let scopedOutInvalidation = try debugArtifactInvalidation(
        artifact: scopedArtifact,
        storedBytes: scopedBytes,
        currentBytes: Data("review-scoped-out-v2/\(runID.rawValue.uuidString)".utf8),
        verifierID: ActorID(validating: "review-invalidation-verifier")
    )
    let decision = try ReviewConvergenceValidator.invalidate(
        lineage: flow.lineage,
        persistedRun: flow.persistedRun,
        by: intersectingInvalidation
    )
    guard case let .authorization(authorization) = decision else {
        throw PersistenceError.integrityViolation
    }
    return ReviewInvalidationTestScenario(
        lineage: flow.lineage,
        persistedRun: flow.persistedRun,
        intersectingInvalidation: intersectingInvalidation,
        scopedOutInvalidation: scopedOutInvalidation,
        invalidationPlan: authorization.plan
    )
}

private struct DebugDirectConvergenceFlow: Sendable {
    let round: DebugReviewRoundBundle
    let source: PersistedRun
    let authority: VerifiedReviewReceiptAuthority
    let receipt: ConvergenceReceipt
}

private func debugDirectConvergenceFlow(
    runID: RunID
) throws -> DebugDirectConvergenceFlow {
    let setup = try debugReviewPolicySetup()
    let (roster, assignment) = try debugReviewRoster()
    let budget = try AttemptBudget.standardV1(
        policyDigest: debugReviewDigest("review-direct-budget/\(runID.rawValue)")
    )
    let artifact = try debugReviewArtifact(
        hash: debugReviewDigest("review-direct-artifact/\(runID.rawValue)")
    )
    let input = try ReviewRoundInput.initial(
        gate: .requirements,
        cycleOrdinal: 0,
        preFreezeEventHead: debugReviewDigest("review-direct-anchor/\(runID.rawValue)"),
        redactionPolicy: roster.redactionPolicy
    )
    let baseline = try debugReviewBaseline(
        runID: runID,
        roundInput: input,
        artifacts: [artifact],
        roster: roster,
        setup: setup,
        convergencePolicyDigest: budget.policyDigest
    )
    let round = try debugReviewRound(
        baseline: baseline,
        assignment: assignment,
        acceptedFinding: false,
        eventHead: debugReviewDigest("review-direct-inventory/\(runID.rawValue)")
    )
    var state = round.persistedRun.state
    guard var cycle = state.reviewCycle else {
        throw PersistenceError.integrityViolation
    }
    cycle.phase = .awaitingRemediation
    cycle.closedRoundID = baseline.roundID
    cycle.closedBaselineDigest = baseline.digest
    cycle.closedRegisterDigest = round.verifiedRegister.register.digest
    cycle.closedPathDecision = .directConvergenceNoAcceptedCurrentScope
    state.reviewCycle = cycle
    let suffix = String(baseline.digest.rawValue.prefix(12))
    let source = try debugAppendReviewPublication(
        to: round.persistedRun,
        event: WorkflowEvent(
            id: "review-debug-direct-close-\(suffix)",
            kind: .reviewInventoryClosed
        ),
        receipts: [
            try debugPersistedReceipt(
                kind: "review-baseline",
                id: ReceiptID(validating: "review-baseline-direct-\(suffix)"),
                payloadBytes: CanonicalJSON.encode(baseline)
            ),
            try debugPersistedReceipt(
                kind: "review-inventory",
                id: ReceiptID(validating: "review-inventory-direct-\(suffix)"),
                payloadBytes: CanonicalJSON.encode(round.inventory)
            ),
            try debugPersistedReceipt(
                kind: "issue-register",
                id: ReceiptID(validating: "issue-register-direct-\(suffix)"),
                payloadBytes: CanonicalJSON.encode(round.verifiedRegister.register)
            ),
        ],
        state: state
    )
    let currentness = try ReviewCapabilityTestFactory.verifyCurrentness(
        baseline: baseline,
        currentArtifacts: baseline.artifactScopes,
        currentEventHead: source.eventHead
    )
    let authority = try ReviewCapabilityTestFactory.verifyReceiptAuthority(
        persistedRun: source,
        currentness: currentness,
        policies: round.policies,
        approvalRecords: [try debugReviewApproval(
            graph: debugReviewGraph([artifact]),
            setup: setup
        )]
    )
    let receipt = try ReviewConvergenceValidator.issueDirectConvergence(
        register: round.verifiedRegister,
        authority: authority,
        publicationAnchorEventHead: source.eventHead
    )
    return DebugDirectConvergenceFlow(
        round: round,
        source: source,
        authority: authority,
        receipt: receipt
    )
}

private struct DebugExceptionPublicationFlow: Sendable {
    let source: PersistedRun
    let admission: VerifiedReviewExceptionAdmission
}

private func debugExceptionPublicationFlow(
    runID: RunID,
    eventHead: HashDigest
) throws -> DebugExceptionPublicationFlow {
    let terminal = try debugTerminalConfirmationFlow(
        runID: runID,
        eventHead: eventHead
    )
    let setup = try debugReviewPolicySetup()
    let (roster, assignment) = try debugReviewRoster()
    let sourceRound = terminal.sourceRound
    let confirmationBaseline = terminal.remediation.committed.successorBaseline
    let confirmationRound = try debugReviewRound(
        baseline: confirmationBaseline,
        assignment: assignment,
        acceptedFinding: true,
        eventHead: debugReviewDigest("review-exception-confirmation/\(runID.rawValue)")
    )
    let suffix = String(confirmationBaseline.digest.rawValue.prefix(12))
    var confirmationState = try debugReviewAuthorityState(baseline: confirmationBaseline)
    guard var confirmationCycle = confirmationState.reviewCycle else {
        throw PersistenceError.integrityViolation
    }
    confirmationCycle.phase = .awaitingRemediation
    confirmationCycle.didRecordRemediation = true
    confirmationCycle.lastRemediatedRoundID = sourceRound.baseline.roundID
    confirmationCycle.closedRoundID = confirmationBaseline.roundID
    confirmationCycle.closedBaselineDigest = confirmationBaseline.digest
    confirmationCycle.closedRegisterDigest = confirmationRound.verifiedRegister.register.digest
    confirmationCycle.closedPathDecision = .requiresRemediation
    confirmationState.reviewCycle = confirmationCycle
    let lineageRun = try debugAppendReviewPublication(
        to: terminal.remediation.committedRun,
        event: WorkflowEvent(
            id: "review-debug-exception-close-\(suffix)",
            kind: .reviewInventoryClosed
        ),
        receipts: [
            try debugPersistedReceipt(
                kind: "review-baseline",
                id: ReceiptID(validating: "review-baseline-exception-source-\(suffix)"),
                payloadBytes: CanonicalJSON.encode(sourceRound.baseline)
            ),
            try debugPersistedReceipt(
                kind: "review-inventory",
                id: ReceiptID(validating: "review-inventory-exception-source-\(suffix)"),
                payloadBytes: CanonicalJSON.encode(sourceRound.inventory)
            ),
            try debugPersistedReceipt(
                kind: "issue-register",
                id: ReceiptID(validating: "issue-register-exception-source-\(suffix)"),
                payloadBytes: CanonicalJSON.encode(sourceRound.verifiedRegister.register)
            ),
            try debugPersistedReceipt(
                kind: "review-inventory",
                id: ReceiptID(validating: "review-inventory-exception-current-\(suffix)"),
                payloadBytes: CanonicalJSON.encode(confirmationRound.inventory)
            ),
            try debugPersistedReceipt(
                kind: "issue-register",
                id: ReceiptID(validating: "issue-register-exception-current-\(suffix)"),
                payloadBytes: CanonicalJSON.encode(confirmationRound.verifiedRegister.register)
            ),
        ],
        state: confirmationState
    )
    let currentness = try ReviewCapabilityTestFactory.verifyCurrentness(
        baseline: confirmationBaseline,
        currentArtifacts: confirmationBaseline.artifactScopes,
        currentEventHead: lineageRun.eventHead
    )
    let confirmationAuthority = try ReviewCapabilityTestFactory.verifyReceiptAuthority(
        persistedRun: lineageRun,
        currentness: currentness,
        policies: confirmationRound.policies,
        approvalRecords: [try debugReviewApproval(
            graph: debugReviewGraph(confirmationBaseline.artifactScopes),
            setup: setup
        )]
    )
    let firstRemediation = try ReviewCommittedRemediationVerifier.verify(
        sourceRegister: sourceRound.verifiedRegister,
        batch: terminal.remediation.planned.batch,
        successorBaseline: confirmationBaseline,
        persistedRun: lineageRun
    )
    let confirmationReceipt = try ReviewConvergenceValidator.issueConfirmation(
        successor: firstRemediation,
        confirmationRegister: confirmationRound.verifiedRegister,
        authority: confirmationAuthority,
        publicationAnchorEventHead: lineageRun.eventHead
    )
    confirmationCycle.didRecordConfirmation = true
    confirmationCycle.confirmationReceiptID = try ReceiptID(
        validating: confirmationReceipt.receiptID
    )
    confirmationState.reviewCycle = confirmationCycle
    let confirmationRun = try debugAppendReviewPublication(
        to: lineageRun,
        event: WorkflowEvent(
            id: confirmationReceipt.receiptID,
            kind: .reviewConfirmationRecorded
        ),
        receipts: [try debugPersistedReceipt(
            kind: "review-confirmation",
            id: ReceiptID(validating: confirmationReceipt.receiptID),
            payloadBytes: CanonicalJSON.encode(confirmationReceipt)
        )],
        state: confirmationState
    )
    let exceptionArtifact = try debugReviewArtifact(
        hash: debugReviewDigest("review-exception-artifact/\(runID.rawValue)")
    )
    let plannedExceptionInput = try ReviewRoundInput.later(
        cycleID: confirmationBaseline.cycleID,
        gate: confirmationBaseline.gate,
        kind: .exception,
        semanticOrdinal: 2,
        roundAnchorEventHead: confirmationRun.eventHead,
        predecessorBaselineDigest: confirmationBaseline.digest,
        redactionPolicy: confirmationBaseline.redactionPolicy
    )
    let plannedExceptionBaseline = try debugReviewBaseline(
        runID: runID,
        roundInput: plannedExceptionInput,
        artifacts: [exceptionArtifact],
        roster: roster,
        setup: setup,
        convergencePolicyDigest: confirmationBaseline.convergencePolicyDigest
    )
    let exceptionRemediation = try debugReviewRemediation(
        source: confirmationRound,
        successor: plannedExceptionBaseline,
        eventHead: eventHead,
        persistedSource: confirmationRun
    )
    let currentRegister = confirmationRound.verifiedRegister.register
    let context = ReviewExceptionContext(
        runID: runID,
        cycleID: confirmationBaseline.cycleID,
        gate: confirmationBaseline.gate,
        precedingRoundID: confirmationBaseline.roundID,
        precedingRegisterDigest: currentRegister.digest,
        precedingBaselineDigest: confirmationBaseline.digest,
        roundAnchorEventHead:
            exceptionRemediation.committed.successorBaseline.preCreationEventHead,
        immediatelyPreceding: debugReviewSummaries(
            sourceRound.verifiedRegister.register,
            acceptedState: .failedRemediation
        ),
        current: debugReviewSummaries(currentRegister, acceptedState: .active),
        history: KernelReviewHistory(
            entries: [
                KernelReviewHistoryEntry(
                    kind: .registerJoined,
                    roundID: confirmationBaseline.roundID,
                    registerDigest: currentRegister.digest,
                    baselineDigest: confirmationBaseline.digest,
                    eventHead: lineageRun.eventHead
                ),
                KernelReviewHistoryEntry(
                    kind: .remediationRecorded,
                    roundID: confirmationBaseline.roundID,
                    registerDigest: currentRegister.digest,
                    baselineDigest: confirmationBaseline.digest,
                    eventHead: exceptionRemediation.committed.producedEventHead
                ),
                KernelReviewHistoryEntry(
                    kind: .confirmationRecorded,
                    roundID: confirmationBaseline.roundID,
                    registerDigest: currentRegister.digest,
                    baselineDigest: confirmationBaseline.digest,
                    eventHead: confirmationRun.eventHead
                ),
            ],
            priorExceptionRoundIDs: []
        ),
        exhaustionCause: .authorityOrDecisionRequired
    )
    let budget = try AttemptBudget.standardV1(
        policyDigest: confirmationBaseline.convergencePolicyDigest
    )
    let exceptionSource = exceptionRemediation.committedRun
    let predecessorRegisterReceipt = try ReviewCommittedReceiptVerifier.verify(
        id: ReceiptID(validating: "issue-register-exception-source-\(suffix)"),
        kind: ReceiptKind(validating: "issue-register"),
        in: exceptionSource
    )
    let currentRegisterReceipt = try ReviewCommittedReceiptVerifier.verify(
        id: ReceiptID(validating: "issue-register-exception-current-\(suffix)"),
        kind: ReceiptKind(validating: "issue-register"),
        in: exceptionSource
    )
    let committedConfirmationReceipt = try ReviewCommittedReceiptVerifier.verify(
        id: ReceiptID(validating: confirmationReceipt.receiptID),
        kind: ReceiptKind(validating: "review-confirmation"),
        in: exceptionSource
    )
    guard case let .eligible(admission) = ReviewConvergenceValidator.evaluateException(
            context,
            predecessorRegister: sourceRound.verifiedRegister,
            remediation: exceptionRemediation.committed,
            predecessorRegisterReceipt: predecessorRegisterReceipt,
            currentRegisterReceipt: currentRegisterReceipt,
            confirmationReceipt: committedConfirmationReceipt,
            priorAdmissions: [],
            budget: budget,
            persistedRun: exceptionSource
        )
    else { throw WorkflowPolicyError.invalidExceptionProof }
    return DebugExceptionPublicationFlow(
        source: exceptionSource,
        admission: admission
    )
}

private func debugReviewSummaries(
    _ register: IssueRegister,
    acceptedState: ReviewFindingState
) -> [ReviewFindingSummary] {
    let dispositions = Dictionary(
        uniqueKeysWithValues: register.dispositions.map { ($0.fingerprint, $0) }
    )
    return register.entries.map { entry in
        ReviewFindingSummary(
            fingerprint: entry.fingerprint.failureFingerprint,
            severity: entry.severity,
            mustFix: entry.mustFix,
            state: dispositions[entry.fingerprint.failureFingerprint]?.entersRemediation == true
                ? acceptedState
                : .resolved
        )
    }.sorted { $0.fingerprint.rawValue < $1.fingerprint.rawValue }
}

private func debugReviewPublicationOperationScenarios() throws
    -> [ReviewPublicationOperationTestScenario] {
    guard let terminalUUID = UUID(
        uuidString: "00000000-0000-0000-0000-00000000024c"
    ), let directUUID = UUID(
        uuidString: "00000000-0000-0000-0000-00000000024d"
    ), let exceptionUUID = UUID(
        uuidString: "00000000-0000-0000-0000-00000000024e"
    ) else { throw WorkflowError.invalidIdentifier }
    let terminal = try debugTerminalConfirmationFlow(
        runID: RunID(rawValue: terminalUUID),
        eventHead: debugReviewDigest("review-publication-terminal")
    )
    let direct = try debugDirectConvergenceFlow(runID: RunID(rawValue: directUUID))
    let exception = try debugExceptionPublicationFlow(
        runID: RunID(rawValue: exceptionUUID),
        eventHead: debugReviewDigest("review-publication-exception")
    )
    let invalidation = try debugArtifactInvalidation(
        artifact: terminal.successorArtifact,
        storedBytes: terminal.successorBytes,
        currentBytes: Data("review-publication-invalidated".utf8),
        verifierID: ActorID(validating: "review-publication-invalidation-verifier")
    )
    let invalidationDecision = try ReviewConvergenceValidator.invalidate(
        lineage: terminal.lineage,
        persistedRun: terminal.persistedRun,
        by: invalidation
    )
    guard case let .authorization(invalidationAuthorization) = invalidationDecision else {
        throw PersistenceError.integrityViolation
    }

    let inventorySource = terminal.sourceRound.persistedRun
    let inventorySuffix = String(inventorySource.eventHead.rawValue.prefix(16))
    let remediationSource = terminal.remediation.source
    let remediationSuffix = String(remediationSource.eventHead.rawValue.prefix(16))
    let confirmationSource = terminal.lineageRun
    let exceptionSuffix = String(exception.source.eventHead.rawValue.prefix(16))
    let invalidationSuffix = String(terminal.persistedRun.eventHead.rawValue.prefix(16))
    let remediationAddresses = [
        "review-baseline/review-baseline-\(remediationSuffix)",
        "review-remediation-batch/review-remediation-batch-\(remediationSuffix)",
        "review-resolved-transitions/review-resolved-transitions-\(remediationSuffix)",
    ] + terminal.remediation.planned.plannedEvidence.map {
        "\($0.payload.receiptKind.rawValue)/\($0.payload.receiptID.rawValue)"
    }

    return [
        ReviewPublicationOperationTestScenario(
            kind: .inventoryRecorded,
            source: inventorySource,
            expectedEventKind: .reviewInventoryRecorded,
            expectedEventID: "review-inventory-\(inventorySuffix)",
            expectedReceiptAddresses: [
                "review-inventory/review-inventory-\(inventorySuffix)",
            ]
        ) { store, publisher, runRoot, lease in
            try ReviewPublicationOperations(store: store).publishInventoryRecorded(
                baseline: terminal.sourceRound.baseline,
                inventory: terminal.sourceRound.inventory,
                authority: terminal.sourceRound.inventoryAuthority,
                publisher: publisher,
                runRoot: runRoot,
                lease: lease
            )
        },
        ReviewPublicationOperationTestScenario(
            kind: .inventoryClosed,
            source: inventorySource,
            expectedEventKind: .reviewInventoryClosed,
            expectedEventID: "review-inventory-set-\(inventorySuffix)",
            expectedReceiptAddresses: [
                "issue-register/issue-register-\(inventorySuffix)",
                "review-inventory-set/review-inventory-set-\(inventorySuffix)",
            ]
        ) { store, publisher, runRoot, lease in
            try ReviewPublicationOperations(store: store).publishInventoryClosed(
                register: terminal.sourceRound.verifiedRegister,
                currentness: terminal.sourceRound.currentness,
                publisher: publisher,
                runRoot: runRoot,
                lease: lease
            )
        },
        ReviewPublicationOperationTestScenario(
            kind: .remediationRecorded,
            source: remediationSource,
            expectedEventKind: .reviewRemediationRecorded,
            expectedEventID: "review-remediation-batch-\(remediationSuffix)",
            expectedReceiptAddresses: remediationAddresses
        ) { store, publisher, runRoot, lease in
            try ReviewPublicationOperations(store: store).publishRemediationRecorded(
                successor: terminal.remediation.planned,
                publisher: publisher,
                runRoot: runRoot,
                lease: lease
            )
        },
        ReviewPublicationOperationTestScenario(
            kind: .confirmationRecorded,
            source: confirmationSource,
            expectedEventKind: .reviewConfirmationRecorded,
            expectedEventID: terminal.confirmationReceipt.receiptID,
            expectedReceiptAddresses: [
                "review-confirmation/\(terminal.confirmationReceipt.receiptID)",
            ]
        ) { store, publisher, runRoot, lease in
            try ReviewPublicationOperations(store: store).publishConfirmationRecorded(
                successor: terminal.committedRemediation,
                confirmationRegister: terminal.confirmationRound.verifiedRegister,
                authority: terminal.confirmationAuthority,
                publisher: publisher,
                runRoot: runRoot,
                lease: lease
            )
        },
        ReviewPublicationOperationTestScenario(
            kind: .exceptionOpened,
            source: exception.source,
            expectedEventKind: .reviewExceptionOpened,
            expectedEventID: "review-exception-\(exceptionSuffix)",
            expectedReceiptAddresses: [
                "review-exception/review-exception-\(exceptionSuffix)",
            ]
        ) { store, publisher, runRoot, lease in
            try ReviewPublicationOperations(store: store).publishExceptionOpened(
                admission: exception.admission,
                publisher: publisher,
                runRoot: runRoot,
                lease: lease
            )
        },
        ReviewPublicationOperationTestScenario(
            kind: .directConvergence,
            source: direct.source,
            expectedEventKind: .reviewConverged,
            expectedEventID: direct.receipt.receiptID,
            expectedReceiptAddresses: [
                "review-convergence/\(direct.receipt.receiptID)",
            ]
        ) { store, publisher, runRoot, lease in
            try ReviewPublicationOperations(store: store).publishDirectConvergence(
                register: direct.round.verifiedRegister,
                authority: direct.authority,
                publisher: publisher,
                runRoot: runRoot,
                lease: lease
            )
        },
        ReviewPublicationOperationTestScenario(
            kind: .confirmedConvergence,
            source: terminal.authorityRun,
            expectedEventKind: .reviewConverged,
            expectedEventID: terminal.convergenceReceipt.receiptID,
            expectedReceiptAddresses: [
                "review-convergence/\(terminal.convergenceReceipt.receiptID)",
            ]
        ) { store, publisher, runRoot, lease in
            try ReviewPublicationOperations(store: store).publishConfirmedConvergence(
                lineage: terminal.preliminaryLineage,
                authority: terminal.preConvergenceAuthority,
                publisher: publisher,
                runRoot: runRoot,
                lease: lease
            )
        },
        ReviewPublicationOperationTestScenario(
            kind: .invalidated,
            source: terminal.persistedRun,
            expectedEventKind: .reviewInvalidated,
            expectedEventID: "review-invalidation-\(invalidationSuffix)",
            expectedReceiptAddresses: [
                "review-invalidation/review-invalidation-\(invalidationSuffix)",
            ]
        ) { store, publisher, runRoot, lease in
            try ReviewPublicationOperations(store: store).publishInvalidation(
                authorization: invalidationAuthorization,
                publisher: publisher,
                runRoot: runRoot,
                lease: lease
            )
        },
    ]
}

private func debugReviewLifecycleState(
    source: ReviewBaseline,
    confirmation: ReviewBaseline,
    exception: ReviewBaseline,
    exceptionRegisterDigest: HashDigest,
    confirmationReceipt: ConfirmationReceipt,
    convergenceReceipt: ConvergenceReceipt?
) throws -> RunState {
    guard let cycleOrdinal = source.cycleOrdinal,
          confirmation.predecessorBaselineDigest == source.digest,
          exception.predecessorBaselineDigest == confirmation.digest
    else { throw WorkflowPolicyError.invalidPolicy }
    let convergenceReceiptID = try convergenceReceipt.map {
        try ReceiptID(validating: $0.receiptID)
    }
    let cycle = try ReviewCycleState(
        id: source.cycleID,
        gate: source.gate,
        cycleOrdinal: cycleOrdinal,
        phase: convergenceReceipt == nil ? .collectingException : .converged,
        currentRoundID: exception.roundID,
        currentRoundKind: .exception,
        currentSemanticOrdinal: exception.semanticOrdinal,
        didRecordRemediation: true,
        didRecordConfirmation: true,
        convergenceReceiptID: convergenceReceiptID,
        redactionPolicy: source.redactionPolicy,
        cyclePreFreezeEventHead: source.preCreationEventHead,
        currentRoundAnchorEventHead: exception.preCreationEventHead,
        predecessorBaselineDigest: confirmation.digest,
        closedRoundID: exception.roundID,
        closedBaselineDigest: exception.digest,
        closedRegisterDigest: exceptionRegisterDigest,
        closedPathDecision: .directConvergenceNoAcceptedCurrentScope,
        lastRemediatedRoundID: confirmation.roundID,
        confirmationReceiptID: try ReceiptID(validating: confirmationReceipt.receiptID)
    )
    let initialInput = try ReviewRoundInput.initial(
        gate: source.gate,
        cycleOrdinal: cycleOrdinal,
        preFreezeEventHead: source.preCreationEventHead,
        redactionPolicy: source.redactionPolicy
    )
    let confirmationInput = try ReviewRoundInput.later(
        cycleID: source.cycleID,
        gate: source.gate,
        kind: .normalConfirmation,
        semanticOrdinal: confirmation.semanticOrdinal,
        roundAnchorEventHead: confirmation.preCreationEventHead,
        predecessorBaselineDigest: source.digest,
        redactionPolicy: source.redactionPolicy
    )
    let suffix = String(source.digest.rawValue.prefix(12))
    var events = try [
        WorkflowEvent(
            id: "review-source-baseline-\(suffix)",
            kind: .reviewBaselineFrozen,
            reviewRound: initialInput
        ),
        WorkflowEvent(id: "review-source-close-\(suffix)", kind: .reviewInventoryClosed),
        WorkflowEvent(id: "review-remediation-\(suffix)", kind: .reviewRemediationRecorded),
        WorkflowEvent(
            id: "review-confirmation-baseline-\(suffix)",
            kind: .reviewBaselineFrozen,
            reviewRound: confirmationInput
        ),
        WorkflowEvent(id: "review-confirmation-close-\(suffix)", kind: .reviewInventoryClosed),
        WorkflowEvent(
            id: confirmationReceipt.receiptID,
            kind: .reviewConfirmationRecorded
        ),
        WorkflowEvent(id: "review-exception-open-\(suffix)", kind: .reviewExceptionOpened),
        WorkflowEvent(id: "review-exception-close-\(suffix)", kind: .reviewInventoryClosed),
    ]
    if let convergenceReceipt = convergenceReceipt {
        events.append(try WorkflowEvent(
            id: convergenceReceipt.receiptID,
            kind: .reviewConverged
        ))
    }
    var state = try RunState.startEngineering(
        runID: source.runID,
        workItemID: "review-invalidation-scenario",
        mode: .auto,
        canonSnapshotDigest: source.activeProfileDigest
    )
    state.stage = .requirementGate
    state.reviewCycle = cycle
    state.processedEvents = try events.map { try ProcessedWorkflowEvent(recording: $0) }
    return state
}

private func debugArtifactInvalidation(
    artifact: ArtifactReference,
    storedBytes: Data,
    currentBytes: Data,
    verifierID: ActorID
) throws -> ValidatedArtifactInvalidation {
    let graph = try debugReviewGraph([artifact])
    let mutation = try ArtifactMutationVerifier.verify(
        graph: graph,
        artifactID: artifact.id,
        storedBytes: storedBytes,
        currentBytes: currentBytes,
        changedScopes: [artifact.scope],
        sectionManifestDigest: debugReviewDigest(
            "review-section-manifest/\(artifact.id.rawValue)"
        ),
        verifierID: verifierID
    )
    return try ArtifactInvalidator().invalidate(mutation: mutation, in: graph)
}

#endif
