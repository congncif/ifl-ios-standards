import Foundation
import IFLContracts

public struct ReceiptManifestEntry: Codable, Hashable, Sendable {
    public let kind: ReceiptKind
    public let id: ReceiptID
    public let envelopeDigest: HashDigest
    public let payloadDigest: HashDigest
    public let envelopeBytes: Data

    init(
        kind: ReceiptKind,
        id: ReceiptID,
        envelopeDigest: HashDigest,
        payloadDigest: HashDigest,
        envelopeBytes: Data
    ) {
        self.kind = kind
        self.id = id
        self.envelopeDigest = envelopeDigest
        self.payloadDigest = payloadDigest
        self.envelopeBytes = envelopeBytes
    }

    public init(from decoder: any Decoder) throws {
        do {
            try rejectUnknownFields(
                from: decoder,
                allowed: Set(CodingKeys.allCases.map(\.stringValue))
            )
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                kind: try container.decode(ReceiptKind.self, forKey: .kind),
                id: try container.decode(ReceiptID.self, forKey: .id),
                envelopeDigest: try container.decode(HashDigest.self, forKey: .envelopeDigest),
                payloadDigest: try container.decode(HashDigest.self, forKey: .payloadDigest),
                envelopeBytes: try container.decode(Data.self, forKey: .envelopeBytes)
            )
            _ = try validatedEnvelope()
        } catch {
            throw PersistenceError.integrityViolation
        }
    }

    func validatedEnvelope(
        transactionID: TransactionID? = nil,
        transactionDigest: HashDigest? = nil
    ) throws -> ReceiptEnvelope {
        do {
            guard CanonicalTreeDigest.sha256(envelopeBytes) == envelopeDigest else {
                throw PersistenceError.integrityViolation
            }
            let envelope = try CanonicalJSON.decode(ReceiptEnvelope.self, from: envelopeBytes)
            try envelope.validate()
            guard try CanonicalJSON.encode(envelope) == envelopeBytes,
                  envelope.kind == kind,
                  envelope.id == id,
                  envelope.payloadDigest == payloadDigest,
                  transactionID.map({ envelope.transactionID == $0 }) ?? true,
                  transactionDigest.map({ envelope.transactionDigest == $0 }) ?? true
            else { throw PersistenceError.integrityViolation }
            return envelope
        } catch {
            throw PersistenceError.integrityViolation
        }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case id
        case envelopeDigest = "envelope_digest"
        case payloadDigest = "payload_digest"
        case envelopeBytes = "envelope_bytes"
    }
}

public struct EventLogRecord: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let sequence: UInt64
    public let runID: RunID
    public let transactionID: TransactionID
    public let previousDigest: HashDigest?
    public let previousStateDigest: HashDigest?
    public let stateDigest: HashDigest
    public let transactionDigest: HashDigest
    public let fencingToken: FencingToken
    public let writerOwnerID: String
    public let receiptManifest: [ReceiptManifestEntry]
    public let event: WorkflowEvent
    public let recordDigest: HashDigest
    public let eventBytes: Data

    init(
        sequence: UInt64,
        runID: RunID,
        transactionID: TransactionID,
        previousDigest: HashDigest?,
        previousStateDigest: HashDigest?,
        stateDigest: HashDigest,
        transactionDigest: HashDigest,
        fencingToken: FencingToken,
        writerOwnerID: String,
        receiptManifest: [ReceiptManifestEntry],
        event: WorkflowEvent
    ) throws {
        try self.init(
            sequence: sequence,
            runID: runID,
            transactionID: transactionID,
            previousDigest: previousDigest,
            previousStateDigest: previousStateDigest,
            stateDigest: stateDigest,
            transactionDigest: transactionDigest,
            fencingToken: fencingToken,
            writerOwnerID: writerOwnerID,
            receiptManifest: receiptManifest,
            event: event,
            allowsEmptyManifest: false,
            validatesTransactionDigest: true
        )
    }

    // Retained only for the corruption-construction test. A record encoded through this
    // compatibility initializer cannot pass strict decoding because it has no receipt manifest.
    init(
        sequence: UInt64,
        previousDigest: HashDigest?,
        stateDigest: HashDigest,
        transactionDigest: HashDigest,
        event: WorkflowEvent
    ) throws {
        try self.init(
            sequence: sequence,
            runID: RunID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!),
            transactionID: TransactionID(rawValue: "compatibility-record"),
            previousDigest: previousDigest,
            previousStateDigest: sequence == 1 ? nil : stateDigest,
            stateDigest: stateDigest,
            transactionDigest: transactionDigest,
            fencingToken: FencingToken(validating: 1),
            writerOwnerID: "compatibility-record",
            receiptManifest: [],
            event: event,
            allowsEmptyManifest: true,
            validatesTransactionDigest: false
        )
    }

    private init(
        sequence: UInt64,
        runID: RunID,
        transactionID: TransactionID,
        previousDigest: HashDigest?,
        previousStateDigest: HashDigest?,
        stateDigest: HashDigest,
        transactionDigest: HashDigest,
        fencingToken: FencingToken,
        writerOwnerID: String,
        receiptManifest: [ReceiptManifestEntry],
        event: WorkflowEvent,
        allowsEmptyManifest: Bool,
        validatesTransactionDigest: Bool
    ) throws {
        guard sequence > 0,
              (sequence == 1) == (previousDigest == nil),
              (sequence == 1) == (previousStateDigest == nil),
              isValidatedPersistenceIdentifier(writerOwnerID),
              allowsEmptyManifest || !receiptManifest.isEmpty,
              receiptManifest == receiptManifest.sorted(by: Self.manifestOrder),
              Set(receiptManifest.map(Self.manifestIdentity)).count == receiptManifest.count
        else { throw PersistenceError.integrityViolation }
        for entry in receiptManifest {
            _ = try entry.validatedEnvelope(
                transactionID: transactionID,
                transactionDigest: transactionDigest
            )
        }
        let canonicalEventBytes = try CanonicalJSON.encode(event)
        if validatesTransactionDigest {
            let transactionPreimage = EventTransactionPreimage(
                schemaVersion: 1,
                id: transactionID,
                runID: runID,
                expectedStateDigest: previousStateDigest,
                expectedEventHead: previousDigest,
                stateDigest: stateDigest,
                eventDigest: CanonicalTreeDigest.sha256(canonicalEventBytes),
                receipts: receiptManifest.map {
                    EventTransactionReceiptDigest(
                        kind: $0.kind,
                        id: $0.id,
                        payloadDigest: $0.payloadDigest
                    )
                }
            )
            guard CanonicalTreeDigest.sha256(try CanonicalJSON.encode(transactionPreimage))
                    == transactionDigest
            else { throw PersistenceError.integrityViolation }
        }
        let preimage = EventLogRecordPreimage(
            schemaVersion: 1,
            sequence: sequence,
            runID: runID,
            transactionID: transactionID,
            previousDigest: previousDigest,
            previousStateDigest: previousStateDigest,
            stateDigest: stateDigest,
            transactionDigest: transactionDigest,
            fencingToken: fencingToken,
            writerOwnerID: writerOwnerID,
            receiptManifest: receiptManifest,
            event: event
        )
        schemaVersion = 1
        self.sequence = sequence
        self.runID = runID
        self.transactionID = transactionID
        self.previousDigest = previousDigest
        self.previousStateDigest = previousStateDigest
        self.stateDigest = stateDigest
        self.transactionDigest = transactionDigest
        self.fencingToken = fencingToken
        self.writerOwnerID = writerOwnerID
        self.receiptManifest = receiptManifest
        self.event = event
        eventBytes = canonicalEventBytes
        recordDigest = CanonicalTreeDigest.sha256(try CanonicalJSON.encode(preimage))
    }

    public init(from decoder: any Decoder) throws {
        do {
            try rejectUnknownFields(
                from: decoder,
                allowed: Set(CodingKeys.allCases.map(\.stringValue))
            )
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
            let claimed = try container.decode(HashDigest.self, forKey: .recordDigest)
            let validated = try EventLogRecord(
                sequence: container.decode(UInt64.self, forKey: .sequence),
                runID: container.decode(RunID.self, forKey: .runID),
                transactionID: container.decode(TransactionID.self, forKey: .transactionID),
                previousDigest: container.decodeIfPresent(
                    HashDigest.self,
                    forKey: .previousDigest
                ),
                previousStateDigest: container.decodeIfPresent(
                    HashDigest.self,
                    forKey: .previousStateDigest
                ),
                stateDigest: container.decode(HashDigest.self, forKey: .stateDigest),
                transactionDigest: container.decode(
                    HashDigest.self,
                    forKey: .transactionDigest
                ),
                fencingToken: container.decode(FencingToken.self, forKey: .fencingToken),
                writerOwnerID: container.decode(String.self, forKey: .writerOwnerID),
                receiptManifest: container.decode(
                    [ReceiptManifestEntry].self,
                    forKey: .receiptManifest
                ),
                event: container.decode(WorkflowEvent.self, forKey: .event)
            )
            guard schemaVersion == 1, claimed == validated.recordDigest else {
                throw PersistenceError.integrityViolation
            }
            self = validated
        } catch {
            throw PersistenceError.integrityViolation
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(sequence, forKey: .sequence)
        try container.encode(runID, forKey: .runID)
        try container.encode(transactionID, forKey: .transactionID)
        try container.encodeIfPresent(previousDigest, forKey: .previousDigest)
        try container.encodeIfPresent(previousStateDigest, forKey: .previousStateDigest)
        try container.encode(stateDigest, forKey: .stateDigest)
        try container.encode(transactionDigest, forKey: .transactionDigest)
        try container.encode(fencingToken, forKey: .fencingToken)
        try container.encode(writerOwnerID, forKey: .writerOwnerID)
        try container.encode(receiptManifest, forKey: .receiptManifest)
        try container.encode(event, forKey: .event)
        try container.encode(recordDigest, forKey: .recordDigest)
    }

    fileprivate static func manifestIdentity(_ entry: ReceiptManifestEntry) -> String {
        "\(entry.kind.rawValue)/\(entry.id.rawValue)"
    }

    fileprivate static func manifestOrder(
        _ lhs: ReceiptManifestEntry,
        _ rhs: ReceiptManifestEntry
    ) -> Bool {
        (lhs.kind.rawValue, lhs.id.rawValue) < (rhs.kind.rawValue, rhs.id.rawValue)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case sequence
        case runID = "run_id"
        case transactionID = "transaction_id"
        case previousDigest = "previous_digest"
        case previousStateDigest = "previous_state_digest"
        case stateDigest = "state_digest"
        case transactionDigest = "transaction_digest"
        case fencingToken = "fencing_token"
        case writerOwnerID = "writer_owner_id"
        case receiptManifest = "receipt_manifest"
        case event
        case recordDigest = "record_digest"
    }
}

enum EventLog {
    static func append(
        transaction: StateTransaction,
        stateDigest: HashDigest,
        lease: WriterLease,
        receiptManifest: [ReceiptManifestEntry],
        to existingBytes: Data?
    ) throws -> (bytes: Data, record: EventLogRecord, records: [EventLogRecord]) {
        var records = try existingBytes.map(decode) ?? []
        guard transaction.state.runID == lease.runID,
              transaction.expectedEventHead == records.last?.recordDigest,
              transaction.expectedStateDigest == records.last?.stateDigest
        else { throw PersistenceError.integrityViolation }
        let canonicalManifest = receiptManifest.sorted(by: EventLogRecord.manifestOrder)
        let record = try EventLogRecord(
            sequence: UInt64(records.count + 1),
            runID: transaction.state.runID,
            transactionID: transaction.id,
            previousDigest: records.last?.recordDigest,
            previousStateDigest: records.last?.stateDigest,
            stateDigest: stateDigest,
            transactionDigest: transaction.digest,
            fencingToken: lease.fencingToken,
            writerOwnerID: lease.ownerID,
            receiptManifest: canonicalManifest,
            event: transaction.event
        )
        records.append(record)
        let bytes = try records.reduce(into: Data()) { result, value in
            result.append(try CanonicalJSON.encode(value))
            result.append(0x0A)
        }
        return (bytes, record, records)
    }

    static func decode(_ bytes: Data) throws -> [EventLogRecord] {
        guard !bytes.isEmpty, bytes.last == 0x0A else {
            throw PersistenceError.integrityViolation
        }
        let lines = bytes.dropLast().split(separator: 0x0A, omittingEmptySubsequences: false)
        guard !lines.isEmpty, lines.allSatisfy({ !$0.isEmpty }) else {
            throw PersistenceError.integrityViolation
        }
        var previous: EventLogRecord?
        var runID: RunID?
        var transactionIDs: Set<TransactionID> = []
        var receiptIdentities: Set<String> = []
        var records: [EventLogRecord] = []
        do {
            for (index, line) in lines.enumerated() {
                let data = Data(line)
                let record = try CanonicalJSON.decode(EventLogRecord.self, from: data)
                guard try CanonicalJSON.encode(record) == data,
                      record.sequence == UInt64(index + 1),
                      record.previousDigest == previous?.recordDigest,
                      record.previousStateDigest == previous?.stateDigest,
                      runID.map({ record.runID == $0 }) ?? true,
                      transactionIDs.insert(record.transactionID).inserted
                else { throw PersistenceError.integrityViolation }
                if let previous {
                    guard record.fencingToken >= previous.fencingToken,
                          record.fencingToken != previous.fencingToken
                            || record.writerOwnerID == previous.writerOwnerID
                    else { throw PersistenceError.integrityViolation }
                }
                for entry in record.receiptManifest {
                    guard receiptIdentities.insert(EventLogRecord.manifestIdentity(entry)).inserted
                    else { throw PersistenceError.integrityViolation }
                }
                runID = record.runID
                previous = record
                records.append(record)
            }
            return records
        } catch {
            throw PersistenceError.integrityViolation
        }
    }
}

private struct EventLogRecordPreimage: Codable {
    let schemaVersion: Int
    let sequence: UInt64
    let runID: RunID
    let transactionID: TransactionID
    let previousDigest: HashDigest?
    let previousStateDigest: HashDigest?
    let stateDigest: HashDigest
    let transactionDigest: HashDigest
    let fencingToken: FencingToken
    let writerOwnerID: String
    let receiptManifest: [ReceiptManifestEntry]
    let event: WorkflowEvent

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case sequence
        case runID = "run_id"
        case transactionID = "transaction_id"
        case previousDigest = "previous_digest"
        case previousStateDigest = "previous_state_digest"
        case stateDigest = "state_digest"
        case transactionDigest = "transaction_digest"
        case fencingToken = "fencing_token"
        case writerOwnerID = "writer_owner_id"
        case receiptManifest = "receipt_manifest"
        case event
    }
}

private struct EventTransactionReceiptDigest: Codable {
    let kind: ReceiptKind
    let id: ReceiptID
    let payloadDigest: HashDigest

    enum CodingKeys: String, CodingKey {
        case kind
        case id
        case payloadDigest = "payload_digest"
    }
}

private struct EventTransactionPreimage: Codable {
    let schemaVersion: Int
    let id: TransactionID
    let runID: RunID
    let expectedStateDigest: HashDigest?
    let expectedEventHead: HashDigest?
    let stateDigest: HashDigest
    let eventDigest: HashDigest
    let receipts: [EventTransactionReceiptDigest]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case id
        case runID = "run_id"
        case expectedStateDigest = "expected_state_digest"
        case expectedEventHead = "expected_event_head"
        case stateDigest = "state_digest"
        case eventDigest = "event_digest"
        case receipts
    }
}
