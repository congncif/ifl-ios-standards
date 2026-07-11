import Foundation
import IFLContracts

enum CommitJournalPhase: String, Codable, Sendable {
    case prepared
    case rollingBack = "rolling_back"
    case rolledBack = "rolled_back"
    case complete
}

struct JournalReceiptIntent: Codable, Hashable, Sendable {
    let kind: ReceiptKind
    let id: ReceiptID
    let temporaryName: String
    let envelopeBytes: Data
    let envelopeDigest: HashDigest

    init(
        kind: ReceiptKind,
        id: ReceiptID,
        temporaryName: String,
        envelopeBytes: Data,
        envelopeDigest: HashDigest
    ) {
        self.kind = kind
        self.id = id
        self.temporaryName = temporaryName
        self.envelopeBytes = envelopeBytes
        self.envelopeDigest = envelopeDigest
    }

    init(from decoder: any Decoder) throws {
        do {
            try rejectUnknownFields(
                from: decoder,
                allowed: Set(CodingKeys.allCases.map(\.stringValue))
            )
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                kind: try container.decode(ReceiptKind.self, forKey: .kind),
                id: try container.decode(ReceiptID.self, forKey: .id),
                temporaryName: try container.decode(String.self, forKey: .temporaryName),
                envelopeBytes: try container.decode(Data.self, forKey: .envelopeBytes),
                envelopeDigest: try container.decode(HashDigest.self, forKey: .envelopeDigest)
            )
            guard isValidatedPersistenceComponent(temporaryName),
                  CanonicalTreeDigest.sha256(envelopeBytes) == envelopeDigest
            else { throw PersistenceError.integrityViolation }
        } catch {
            throw PersistenceError.integrityViolation
        }
    }

    func manifestEntry(
        transactionID: TransactionID,
        transactionDigest: HashDigest
    ) throws -> ReceiptManifestEntry {
        do {
            let envelope = try CanonicalJSON.decode(ReceiptEnvelope.self, from: envelopeBytes)
            try envelope.validate()
            guard try CanonicalJSON.encode(envelope) == envelopeBytes,
                  CanonicalTreeDigest.sha256(envelopeBytes) == envelopeDigest,
                  envelope.kind == kind,
                  envelope.id == id,
                  envelope.transactionID == transactionID,
                  envelope.transactionDigest == transactionDigest
            else { throw PersistenceError.integrityViolation }
            return ReceiptManifestEntry(
                kind: kind,
                id: id,
                envelopeDigest: envelopeDigest,
                payloadDigest: envelope.payloadDigest,
                envelopeBytes: envelopeBytes
            )
        } catch {
            throw PersistenceError.integrityViolation
        }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case id
        case temporaryName = "temporary_name"
        case envelopeBytes = "envelope_bytes"
        case envelopeDigest = "envelope_digest"
    }
}

struct CommitJournalRecord: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let phase: CommitJournalPhase
    let runID: RunID
    let transactionID: TransactionID
    let transactionDigest: HashDigest
    let expectedStateDigest: HashDigest?
    let expectedEventHead: HashDigest?
    let targetStateDigest: HashDigest
    let targetEventHead: HashDigest
    let priorStateBytes: Data?
    let priorJournalBytes: Data?
    let stateBytes: Data
    let priorEventLogBytes: Data?
    let targetEventLogBytes: Data
    let stateTemporaryName: String
    let eventTemporaryName: String
    let receipts: [JournalReceiptIntent]
    let lease: WriterLease

    init(
        schemaVersion: Int,
        phase: CommitJournalPhase,
        runID: RunID,
        transactionID: TransactionID,
        transactionDigest: HashDigest,
        expectedStateDigest: HashDigest?,
        expectedEventHead: HashDigest?,
        targetStateDigest: HashDigest,
        targetEventHead: HashDigest,
        priorStateBytes: Data? = nil,
        priorJournalBytes: Data? = nil,
        stateBytes: Data,
        priorEventLogBytes: Data?,
        targetEventLogBytes: Data,
        stateTemporaryName: String,
        eventTemporaryName: String,
        receipts: [JournalReceiptIntent],
        lease: WriterLease
    ) {
        self.schemaVersion = schemaVersion
        self.phase = phase
        self.runID = runID
        self.transactionID = transactionID
        self.transactionDigest = transactionDigest
        self.expectedStateDigest = expectedStateDigest
        self.expectedEventHead = expectedEventHead
        self.targetStateDigest = targetStateDigest
        self.targetEventHead = targetEventHead
        self.priorStateBytes = priorStateBytes
        self.priorJournalBytes = priorJournalBytes
        self.stateBytes = stateBytes
        self.priorEventLogBytes = priorEventLogBytes
        self.targetEventLogBytes = targetEventLogBytes
        self.stateTemporaryName = stateTemporaryName
        self.eventTemporaryName = eventTemporaryName
        self.receipts = receipts
        self.lease = lease
    }

    init(from decoder: any Decoder) throws {
        do {
            try rejectUnknownFields(
                from: decoder,
                allowed: Set(CodingKeys.allCases.map(\.stringValue))
            )
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                schemaVersion: try container.decode(Int.self, forKey: .schemaVersion),
                phase: try container.decode(CommitJournalPhase.self, forKey: .phase),
                runID: try container.decode(RunID.self, forKey: .runID),
                transactionID: try container.decode(TransactionID.self, forKey: .transactionID),
                transactionDigest: try container.decode(
                    HashDigest.self,
                    forKey: .transactionDigest
                ),
                expectedStateDigest: try container.decodeIfPresent(
                    HashDigest.self,
                    forKey: .expectedStateDigest
                ),
                expectedEventHead: try container.decodeIfPresent(
                    HashDigest.self,
                    forKey: .expectedEventHead
                ),
                targetStateDigest: try container.decode(
                    HashDigest.self,
                    forKey: .targetStateDigest
                ),
                targetEventHead: try container.decode(HashDigest.self, forKey: .targetEventHead),
                priorStateBytes: try container.decodeIfPresent(
                    Data.self,
                    forKey: .priorStateBytes
                ),
                priorJournalBytes: try container.decodeIfPresent(
                    Data.self,
                    forKey: .priorJournalBytes
                ),
                stateBytes: try container.decode(Data.self, forKey: .stateBytes),
                priorEventLogBytes: try container.decodeIfPresent(
                    Data.self,
                    forKey: .priorEventLogBytes
                ),
                targetEventLogBytes: try container.decode(Data.self, forKey: .targetEventLogBytes),
                stateTemporaryName: try container.decode(
                    String.self,
                    forKey: .stateTemporaryName
                ),
                eventTemporaryName: try container.decode(
                    String.self,
                    forKey: .eventTemporaryName
                ),
                receipts: try container.decode([JournalReceiptIntent].self, forKey: .receipts),
                lease: try container.decode(WriterLease.self, forKey: .lease)
            )
            try validate()
        } catch {
            throw PersistenceError.integrityViolation
        }
    }

    func completing() -> CommitJournalRecord {
        transitioning(to: .complete)
    }

    func preparing() -> CommitJournalRecord {
        transitioning(to: .prepared)
    }

    func startingRollback() -> CommitJournalRecord {
        transitioning(to: .rollingBack)
    }

    func markingRolledBack() -> CommitJournalRecord {
        transitioning(to: .rolledBack)
    }

    private func transitioning(to phase: CommitJournalPhase) -> CommitJournalRecord {
        CommitJournalRecord(
            schemaVersion: schemaVersion,
            phase: phase,
            runID: runID,
            transactionID: transactionID,
            transactionDigest: transactionDigest,
            expectedStateDigest: expectedStateDigest,
            expectedEventHead: expectedEventHead,
            targetStateDigest: targetStateDigest,
            targetEventHead: targetEventHead,
            priorStateBytes: priorStateBytes,
            priorJournalBytes: priorJournalBytes,
            stateBytes: stateBytes,
            priorEventLogBytes: priorEventLogBytes,
            targetEventLogBytes: targetEventLogBytes,
            stateTemporaryName: stateTemporaryName,
            eventTemporaryName: eventTemporaryName,
            receipts: receipts,
            lease: lease
        )
    }

    func validate() throws {
        do {
            guard schemaVersion == 1,
                  lease.runID == runID,
                  stateTemporaryName == ".state-\(transactionDigest.rawValue).tmp",
                  eventTemporaryName == ".events-\(transactionDigest.rawValue).tmp",
                  CanonicalTreeDigest.sha256(stateBytes) == targetStateDigest,
                  !receipts.isEmpty,
                  Set(receipts.map { "\($0.kind.rawValue)/\($0.id.rawValue)" }).count
                    == receipts.count
            else { throw PersistenceError.integrityViolation }

            let state = try CanonicalJSON.decode(RunState.self, from: stateBytes)
            guard try CanonicalJSON.encode(state) == stateBytes, state.runID == runID else {
                throw PersistenceError.integrityViolation
            }
            if let expectedStateDigest {
                guard let priorStateBytes,
                      CanonicalTreeDigest.sha256(priorStateBytes) == expectedStateDigest,
                      let priorJournalBytes
                else { throw PersistenceError.integrityViolation }
                let priorState = try CanonicalJSON.decode(RunState.self, from: priorStateBytes)
                let priorJournal = try CanonicalJSON.decode(
                    CommitJournalRecord.self,
                    from: priorJournalBytes
                )
                guard try CanonicalJSON.encode(priorState) == priorStateBytes,
                      priorState.runID == runID,
                      try CanonicalJSON.encode(priorJournal) == priorJournalBytes,
                      priorJournal.phase == .complete,
                      priorJournal.runID == runID,
                      priorJournal.targetStateDigest == expectedStateDigest,
                      priorJournal.targetEventHead == expectedEventHead,
                      priorJournal.stateBytes == priorStateBytes,
                      priorJournal.targetEventLogBytes == priorEventLogBytes
                else { throw PersistenceError.integrityViolation }
            } else {
                guard priorStateBytes == nil, priorJournalBytes == nil else {
                    throw PersistenceError.integrityViolation
                }
            }
            let priorRecords = try priorEventLogBytes.map(EventLog.decode) ?? []
            let targetRecords = try EventLog.decode(targetEventLogBytes)
            guard expectedEventHead == priorRecords.last?.recordDigest,
                  expectedStateDigest == priorRecords.last?.stateDigest,
                  targetRecords.count == priorRecords.count + 1,
                  Array(targetRecords.dropLast()) == priorRecords,
                  let targetEvent = targetRecords.last,
                  targetEvent.recordDigest == targetEventHead,
                  targetEvent.runID == runID,
                  targetEvent.transactionID == transactionID,
                  targetEvent.previousDigest == expectedEventHead,
                  targetEvent.previousStateDigest == expectedStateDigest,
                  targetEvent.stateDigest == targetStateDigest,
                  targetEvent.transactionDigest == transactionDigest,
                  targetEvent.fencingToken == lease.fencingToken,
                  targetEvent.writerOwnerID == lease.ownerID,
                  state.processedEvents.count == targetRecords.count,
                  state.processedEvents.last?.id == targetEvent.event.id,
                  state.processedEvents.last?.kind == targetEvent.event.kind,
                  state.processedEvents.last?.candidateGenerationID
                    == targetEvent.event.candidateGenerationID,
                  state.processedEvents.last?.eventDigest
                    == CanonicalTreeDigest.sha256(targetEvent.eventBytes)
            else { throw PersistenceError.integrityViolation }

            var writes: [ReceiptTableWrite] = []
            var manifest: [ReceiptManifestEntry] = []
            for receipt in receipts {
                guard receipt.temporaryName == journalReceiptTemporaryName(
                    kind: receipt.kind,
                    id: receipt.id,
                    transactionDigest: transactionDigest
                ) else { throw PersistenceError.integrityViolation }
                let envelope = try CanonicalJSON.decode(
                    ReceiptEnvelope.self,
                    from: receipt.envelopeBytes
                )
                try envelope.validate()
                guard try CanonicalJSON.encode(envelope) == receipt.envelopeBytes,
                      CanonicalTreeDigest.sha256(receipt.envelopeBytes)
                        == receipt.envelopeDigest,
                      envelope.kind == receipt.kind,
                      envelope.id == receipt.id,
                      envelope.transactionID == transactionID,
                      envelope.transactionDigest == transactionDigest
                else { throw PersistenceError.integrityViolation }
                writes.append(
                    try ReceiptTableWrite(
                        kind: envelope.kind,
                        id: envelope.id,
                        canonicalPayloadBytes: envelope.payloadBytes
                    )
                )
                manifest.append(
                    try receipt.manifestEntry(
                        transactionID: transactionID,
                        transactionDigest: transactionDigest
                    )
                )
            }
            manifest.sort {
                ($0.kind.rawValue, $0.id.rawValue) < ($1.kind.rawValue, $1.id.rawValue)
            }
            guard targetEvent.receiptManifest == manifest else {
                throw PersistenceError.integrityViolation
            }

            let validationRoot = URL(fileURLWithPath: "/journal-validation", isDirectory: true)
                .appendingPathComponent(runID.filesystemComponent, isDirectory: true)
            let reconstructed = try StateTransaction(
                id: transactionID,
                runRoot: validationRoot,
                expectedStateDigest: expectedStateDigest,
                expectedEventHead: expectedEventHead,
                state: state,
                event: targetEvent.event,
                receiptWrites: writes
            )
            guard reconstructed.digest == transactionDigest,
                  reconstructed.stateTemporaryFilename == stateTemporaryName,
                  reconstructed.eventTemporaryFilename == eventTemporaryName
            else { throw PersistenceError.integrityViolation }
        } catch {
            throw PersistenceError.integrityViolation
        }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case phase
        case runID = "run_id"
        case transactionID = "transaction_id"
        case transactionDigest = "transaction_digest"
        case expectedStateDigest = "expected_state_digest"
        case expectedEventHead = "expected_event_head"
        case targetStateDigest = "target_state_digest"
        case targetEventHead = "target_event_head"
        case priorStateBytes = "prior_state_bytes"
        case priorJournalBytes = "prior_journal_bytes"
        case stateBytes = "state_bytes"
        case priorEventLogBytes = "prior_event_log_bytes"
        case targetEventLogBytes = "target_event_log_bytes"
        case stateTemporaryName = "state_temporary_name"
        case eventTemporaryName = "event_temporary_name"
        case receipts
        case lease
    }
}

private func journalReceiptTemporaryName(
    kind: ReceiptKind,
    id: ReceiptID,
    transactionDigest: HashDigest
) -> String {
    let identity = Data(
        "\(kind.rawValue)\u{0}\(id.rawValue)\u{0}\(transactionDigest.rawValue)".utf8
    )
    return ".receipt-\(CanonicalTreeDigest.sha256(identity).rawValue).tmp"
}
