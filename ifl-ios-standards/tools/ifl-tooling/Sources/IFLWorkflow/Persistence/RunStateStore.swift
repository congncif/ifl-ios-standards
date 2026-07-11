import Foundation
import IFLContracts

public protocol RunStateStore: Sendable {
    func load(runID: RunID, from runRoot: URL) throws -> PersistedRun
    func commit(_ transaction: StateTransaction, lease: WriterLease) throws -> CommitReceipt
    func recover(runID: RunID, from runRoot: URL) throws -> RecoveryResult
}

struct TrustedRunFact: Hashable, Sendable {
    let runID: RunID
    let stateDigest: HashDigest
    let eventHead: HashDigest
    let minimumFencingToken: FencingToken

    init(
        runID: RunID,
        stateDigest: HashDigest,
        eventHead: HashDigest,
        minimumFencingToken: FencingToken
    ) {
        self.runID = runID
        self.stateDigest = stateDigest
        self.eventHead = eventHead
        self.minimumFencingToken = minimumFencingToken
    }
}

public struct PersistedReceipt: Hashable, Sendable {
    public let kind: ReceiptKind
    public let id: ReceiptID
    public let transactionID: TransactionID
    public let transactionDigest: HashDigest
    public let payloadDigest: HashDigest
    public let payloadBytes: Data
}

public struct PersistedRun: Hashable, Sendable {
    public let state: RunState
    public let stateBytes: Data
    public let stateDigest: HashDigest
    public let events: [EventLogRecord]
    public let eventHead: HashDigest
    public let receipts: [PersistedReceipt]
}

public struct CommitReceipt: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let runID: RunID
    public let transactionID: TransactionID
    public let transactionDigest: HashDigest
    public let stateDigest: HashDigest
    public let eventHead: HashDigest
    public let fencingToken: FencingToken
    public let isDurable: Bool

    init(
        runID: RunID,
        transactionID: TransactionID,
        transactionDigest: HashDigest,
        stateDigest: HashDigest,
        eventHead: HashDigest,
        fencingToken: FencingToken
    ) {
        schemaVersion = 1
        self.runID = runID
        self.transactionID = transactionID
        self.transactionDigest = transactionDigest
        self.stateDigest = stateDigest
        self.eventHead = eventHead
        self.fencingToken = fencingToken
        isDurable = true
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.stringValue)))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        let isDurable = try container.decode(Bool.self, forKey: .isDurable)
        guard schemaVersion == 1, isDurable else {
            throw PersistenceError.integrityViolation
        }
        self.schemaVersion = schemaVersion
        runID = try container.decode(RunID.self, forKey: .runID)
        transactionID = try container.decode(TransactionID.self, forKey: .transactionID)
        transactionDigest = try container.decode(HashDigest.self, forKey: .transactionDigest)
        stateDigest = try container.decode(HashDigest.self, forKey: .stateDigest)
        eventHead = try container.decode(HashDigest.self, forKey: .eventHead)
        fencingToken = try container.decode(FencingToken.self, forKey: .fencingToken)
        self.isDurable = isDurable
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case runID = "run_id"
        case transactionID = "transaction_id"
        case transactionDigest = "transaction_digest"
        case stateDigest = "state_digest"
        case eventHead = "event_head"
        case fencingToken = "fencing_token"
        case isDurable = "is_durable"
    }
}

public enum RecoveryDisposition: String, Codable, Hashable, Sendable {
    case absent
    case rolledBack = "rolled_back"
    case completed
    case unchanged
}

public struct RecoveryResult: Hashable, Sendable {
    public let disposition: RecoveryDisposition
    public let persistedRun: PersistedRun?

    init(disposition: RecoveryDisposition, persistedRun: PersistedRun? = nil) {
        self.disposition = disposition
        self.persistedRun = persistedRun
    }
}
