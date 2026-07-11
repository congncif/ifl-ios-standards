import CoreFoundation
import Foundation
import IFLContracts

public enum PersistenceMutationPoint: String, CaseIterable, Codable, Hashable, Sendable {
    case lockAcquired = "lock_acquired"
    case currentValidated = "current_validated"
    case beforeJournalFlush = "before_journal_flush"
    case afterJournalBarrier = "after_journal_barrier"
    case beforeStateFlush = "before_state_flush"
    case beforeEventFlush = "before_event_flush"
    case beforeReceiptFlush = "before_receipt_flush"
    case beforeReceiptRootBarrier = "before_receipt_root_barrier"
    case afterReceiptRootBarrier = "after_receipt_root_barrier"
    case beforeReceiptKindBarrier = "before_receipt_kind_barrier"
    case afterReceiptKindBarrier = "after_receipt_kind_barrier"
    case beforePayloadDirectoryFlush = "before_payload_directory_flush"
    case afterPayloadBarrier = "after_payload_barrier"
    case beforeEventRename = "before_event_rename"
    case afterEventRename = "after_event_rename"
    case afterEventSwapBeforeCleanup = "after_event_swap_before_cleanup"
    case beforeEventParentFlush = "before_event_parent_flush"
    case beforeReceiptRename = "before_receipt_rename"
    case afterReceiptRename = "after_receipt_rename"
    case beforeReceiptParentFlush = "before_receipt_parent_flush"
    case beforeStateRename = "before_state_rename"
    case afterStateRename = "after_state_rename"
    case afterStateSwapBeforeCleanup = "after_state_swap_before_cleanup"
    case beforeStateParentFlush = "before_state_parent_flush"
    case afterStateBarrier = "after_state_barrier"
    case beforeJournalCompletionFlush = "before_journal_completion_flush"
    case afterJournalCompletionRenameBeforeBarrier = "after_journal_completion_rename_before_barrier"
    case afterJournalCompletionBarrier = "after_journal_completion_barrier"
    case beforeRollbackPayloadBarrier = "before_rollback_payload_barrier"
    case afterRollbackPayloadBarrier = "after_rollback_payload_barrier"
    case beforeRollbackMarkerBarrier = "before_rollback_marker_barrier"
    case afterRollbackMarkerBarrier = "after_rollback_marker_barrier"
    case beforeRecoveryCompletionBarrier = "before_recovery_completion_barrier"
    case afterRecoveryCompletionBarrier = "after_recovery_completion_barrier"

    static let commitCases: [PersistenceMutationPoint] = [
        .lockAcquired, .currentValidated, .beforeJournalFlush, .afterJournalBarrier,
        .beforeStateFlush, .beforeEventFlush, .beforeReceiptFlush,
        .beforeReceiptRootBarrier, .afterReceiptRootBarrier,
        .beforeReceiptKindBarrier, .afterReceiptKindBarrier,
        .beforePayloadDirectoryFlush, .afterPayloadBarrier, .beforeEventRename,
        .afterEventRename, .afterEventSwapBeforeCleanup, .beforeEventParentFlush,
        .beforeReceiptRename,
        .afterReceiptRename, .beforeReceiptParentFlush, .beforeStateRename,
        .afterStateRename, .afterStateSwapBeforeCleanup, .beforeStateParentFlush,
        .afterStateBarrier, .beforeJournalCompletionFlush,
        .afterJournalCompletionRenameBeforeBarrier, .afterJournalCompletionBarrier,
    ]

    static let rollbackRecoveryCases: [PersistenceMutationPoint] = [
        .beforeRollbackPayloadBarrier, .afterRollbackPayloadBarrier,
        .beforeRollbackMarkerBarrier, .afterRollbackMarkerBarrier,
    ]

    static let completionRecoveryCases: [PersistenceMutationPoint] = [
        .beforeRecoveryCompletionBarrier, .afterRecoveryCompletionBarrier,
    ]

    var expectedRecoveryDisposition: RecoveryDisposition {
        switch self {
        case .lockAcquired, .currentValidated:
            .absent
        case .afterStateRename, .afterStateSwapBeforeCleanup, .beforeStateParentFlush,
             .afterStateBarrier, .beforeJournalCompletionFlush,
             .afterJournalCompletionRenameBeforeBarrier:
            .completed
        case .afterJournalCompletionBarrier:
            .unchanged
        default:
            .rolledBack
        }
    }

    var eventualRecoveryDisposition: RecoveryDisposition {
        Self.completionRecoveryCases.contains(self) ? .completed : .rolledBack
    }
}

public enum PersistenceError: Error, Equatable, Sendable {
    case invalidPathComponent
    case invalidLease
    case invalidReceiptPayload
    case staleLease
    case fencingViolation
    case notFound
    case transactionConflict
    case integrityViolation
    case blockedEnvironment
    case ioFailure(Int32)
    case injectedInterruption(PersistenceMutationPoint)

    public var exitCode: IFLExitCode {
        switch self {
        case .invalidPathComponent, .invalidLease, .invalidReceiptPayload,
             .staleLease, .fencingViolation,
             .transactionConflict:
            .invalidInput
        case .notFound, .ioFailure, .injectedInterruption:
            .internalError
        case .integrityViolation:
            .integrityViolation
        case .blockedEnvironment:
            .blockedEnvironment
        }
    }
}

public struct PersistenceFaultInjector: @unchecked Sendable {
    private let handler: @Sendable (PersistenceMutationPoint) throws -> Void

    public init(_ handler: @escaping @Sendable (PersistenceMutationPoint) throws -> Void) {
        self.handler = handler
    }

    public static var none: PersistenceFaultInjector {
        PersistenceFaultInjector { _ in }
    }

    func hit(_ point: PersistenceMutationPoint) throws {
        try handler(point)
    }
}

public struct TransactionID: Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) throws {
        guard isValidatedPersistenceIdentifier(rawValue) else {
            throw PersistenceError.invalidPathComponent
        }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        try self.init(rawValue: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct ReceiptKind: Codable, Hashable, Comparable, Sendable {
    public let rawValue: String

    public init(validating rawValue: String) throws {
        guard isValidatedPersistenceIdentifier(rawValue),
              rawValue == rawValue.lowercased()
        else {
            throw PersistenceError.invalidPathComponent
        }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: ReceiptKind, rhs: ReceiptKind) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct ReceiptID: Codable, Hashable, Comparable, Sendable {
    public let rawValue: String

    public init(validating rawValue: String) throws {
        guard isValidatedPersistenceIdentifier(rawValue),
              rawValue == rawValue.lowercased(),
              isValidatedPersistenceComponent("\(rawValue).json")
        else {
            throw PersistenceError.invalidPathComponent
        }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: ReceiptID, rhs: ReceiptID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct ReceiptTableWrite: Hashable, Sendable {
    public let kind: ReceiptKind
    public let id: ReceiptID
    public let payloadBytes: Data
    public let payloadDigest: HashDigest

    public init(
        kind: ReceiptKind,
        id: ReceiptID,
        value: some Encodable
    ) throws {
        let bytes = try CanonicalJSON.encode(value)
        try validateCanonicalReceiptPayload(bytes)
        self.kind = kind
        self.id = id
        payloadBytes = bytes
        payloadDigest = CanonicalTreeDigest.sha256(bytes)
    }

    init(kind: ReceiptKind, id: ReceiptID, canonicalPayloadBytes: Data) throws {
        try validateCanonicalReceiptPayload(canonicalPayloadBytes)
        self.kind = kind
        self.id = id
        payloadBytes = canonicalPayloadBytes
        payloadDigest = CanonicalTreeDigest.sha256(canonicalPayloadBytes)
    }
}

public struct StateTransaction: Hashable, Sendable {
    public let id: TransactionID
    public let runRoot: URL
    public let expectedStateDigest: HashDigest?
    public let expectedEventHead: HashDigest?
    public let state: RunState
    public let event: WorkflowEvent
    public let receiptWrites: [ReceiptTableWrite]
    public let stateBytes: Data
    public let eventBytes: Data
    public let digest: HashDigest

    var stateTemporaryFilename: String {
        ".state-\(digest.rawValue).tmp"
    }

    var eventTemporaryFilename: String {
        ".events-\(digest.rawValue).tmp"
    }

    public init(
        id: TransactionID,
        runRoot: URL,
        expectedStateDigest: HashDigest?,
        expectedEventHead: HashDigest?,
        state: RunState,
        event: WorkflowEvent,
        receiptWrites: [ReceiptTableWrite]
    ) throws {
        guard runRoot.isFileURL,
              runRoot.standardizedFileURL.lastPathComponent == state.runID.filesystemComponent,
              Set(receiptWrites.map { "\($0.kind.rawValue)/\($0.id.rawValue)" }).count
                == receiptWrites.count
        else { throw PersistenceError.integrityViolation }
        let stateBytes = try CanonicalJSON.encode(state)
        let eventBytes = try CanonicalJSON.encode(event)
        let receiptDigests = receiptWrites
            .map {
                TransactionReceiptDigest(
                    kind: $0.kind,
                    id: $0.id,
                    payloadDigest: $0.payloadDigest
                )
            }
            .sorted {
                ($0.kind.rawValue, $0.id.rawValue) < ($1.kind.rawValue, $1.id.rawValue)
            }
        let preimage = StateTransactionPreimage(
            schemaVersion: 1,
            id: id,
            runID: state.runID,
            expectedStateDigest: expectedStateDigest,
            expectedEventHead: expectedEventHead,
            stateDigest: CanonicalTreeDigest.sha256(stateBytes),
            eventDigest: CanonicalTreeDigest.sha256(eventBytes),
            receipts: receiptDigests
        )
        self.id = id
        self.runRoot = runRoot.standardizedFileURL
        self.expectedStateDigest = expectedStateDigest
        self.expectedEventHead = expectedEventHead
        self.state = state
        self.event = event
        self.receiptWrites = receiptWrites
        self.stateBytes = stateBytes
        self.eventBytes = eventBytes
        digest = CanonicalTreeDigest.sha256(try CanonicalJSON.encode(preimage))
    }
}

struct ReceiptEnvelope: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let kind: ReceiptKind
    let id: ReceiptID
    let transactionID: TransactionID
    let transactionDigest: HashDigest
    let payloadDigest: HashDigest
    let payloadBytes: Data

    init(write: ReceiptTableWrite, transaction: StateTransaction) {
        schemaVersion = 1
        kind = write.kind
        id = write.id
        transactionID = transaction.id
        transactionDigest = transaction.digest
        payloadDigest = write.payloadDigest
        payloadBytes = write.payloadBytes
    }

    func validate() throws {
        guard schemaVersion == 1,
              CanonicalTreeDigest.sha256(payloadBytes) == payloadDigest,
              try isCanonicalJSONObject(payloadBytes)
        else { throw PersistenceError.integrityViolation }
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case kind
        case id
        case transactionID = "transaction_id"
        case transactionDigest = "transaction_digest"
        case payloadDigest = "payload_digest"
        case payloadBytes = "payload_bytes"
    }
}

private struct TransactionReceiptDigest: Codable {
    let kind: ReceiptKind
    let id: ReceiptID
    let payloadDigest: HashDigest

    enum CodingKeys: String, CodingKey {
        case kind
        case id
        case payloadDigest = "payload_digest"
    }
}

private struct StateTransactionPreimage: Codable {
    let schemaVersion: Int
    let id: TransactionID
    let runID: RunID
    let expectedStateDigest: HashDigest?
    let expectedEventHead: HashDigest?
    let stateDigest: HashDigest
    let eventDigest: HashDigest
    let receipts: [TransactionReceiptDigest]

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

func isValidatedPersistenceComponent(_ value: String) -> Bool {
    guard (1...128).contains(value.utf8.count), value != ".", value != ".." else {
        return false
    }
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
    return !value.contains("/") && value.unicodeScalars.allSatisfy(allowed.contains)
}

func isValidatedPersistenceIdentifier(_ value: String) -> Bool {
    guard isValidatedPersistenceComponent(value), let first = value.first else { return false }
    return first.isLetter || first.isNumber
}

private func isCanonicalJSONObject(_ bytes: Data) throws -> Bool {
    let object = try JSONSerialization.jsonObject(with: bytes, options: [.fragmentsAllowed])
    let canonical = try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]
    )
    return canonical == bytes
}

private func validateCanonicalReceiptPayload(_ bytes: Data) throws {
    let object: Any
    do {
        object = try JSONSerialization.jsonObject(with: bytes)
    } catch {
        throw PersistenceError.invalidReceiptPayload
    }
    guard object is [String: Any], try isCanonicalJSONObject(bytes), isIntegerJSONValue(object) else {
        throw PersistenceError.invalidReceiptPayload
    }
}

private func isIntegerJSONValue(_ value: Any) -> Bool {
    switch value {
    case is NSNull, is String:
        return true
    case let number as NSNumber:
        if CFGetTypeID(number) == CFBooleanGetTypeID() { return true }
        return !CFNumberIsFloatType(number)
    case let array as [Any]:
        return array.allSatisfy(isIntegerJSONValue)
    case let object as [String: Any]:
        return object.values.allSatisfy(isIntegerJSONValue)
    default:
        return false
    }
}
