import Foundation
import IFLContracts

public struct ReviewCycleID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(validating rawValue: String) throws {
        self.rawValue = try HashDigest(validating: rawValue).rawValue
    }

    public init?(rawValue: String) {
        guard let digest = try? HashDigest(validating: rawValue) else { return nil }
        self.rawValue = digest.rawValue
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func derive(
        runID: RunID,
        gate: ReviewGateKind,
        cycleOrdinal: UInt64,
        preFreezeEventHead: HashDigest
    ) throws -> ReviewCycleID {
        let preimage = ReviewCycleIDPreimage(
            schemaVersion: 1,
            runID: runID,
            gate: gate,
            cycleOrdinal: cycleOrdinal,
            preFreezeEventHead: preFreezeEventHead
        )
        return try ReviewCycleID(
            validating: CanonicalTreeDigest.sha256(CanonicalJSON.encode(preimage)).rawValue
        )
    }
}

public struct ReviewRoundID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(validating rawValue: String) throws {
        self.rawValue = try HashDigest(validating: rawValue).rawValue
    }

    public init?(rawValue: String) {
        guard let digest = try? HashDigest(validating: rawValue) else { return nil }
        self.rawValue = digest.rawValue
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func derive(
        runID: RunID,
        gate: ReviewGateKind,
        cycleID: ReviewCycleID,
        kind: ReviewRoundKind,
        semanticOrdinal: UInt64,
        roundAnchorEventHead: HashDigest,
        predecessorBaselineDigest: HashDigest?
    ) throws -> ReviewRoundID {
        switch kind {
        case .initial:
            guard semanticOrdinal == 0, predecessorBaselineDigest == nil else {
                throw WorkflowError.invalidReviewRound
            }
        case .normalConfirmation:
            guard semanticOrdinal == 1, predecessorBaselineDigest != nil else {
                throw WorkflowError.invalidReviewRound
            }
        case .exception:
            guard semanticOrdinal >= 2, predecessorBaselineDigest != nil else {
                throw WorkflowError.invalidReviewRound
            }
        }

        let preimage = ReviewRoundIDPreimage(
            schemaVersion: 1,
            runID: runID,
            gate: gate,
            cycleID: cycleID,
            kind: kind,
            semanticOrdinal: semanticOrdinal,
            roundAnchorEventHead: roundAnchorEventHead,
            predecessorBaseline: predecessorBaselineDigest?.rawValue ?? "none"
        )
        return try ReviewRoundID(
            validating: CanonicalTreeDigest.sha256(CanonicalJSON.encode(preimage)).rawValue
        )
    }
}

private struct ReviewCycleIDPreimage: Codable {
    let schemaVersion: Int
    let runID: RunID
    let gate: ReviewGateKind
    let cycleOrdinal: UInt64
    let preFreezeEventHead: HashDigest

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case runID = "run_id"
        case gate
        case cycleOrdinal = "cycle_ordinal"
        case preFreezeEventHead = "pre_freeze_event_head"
    }
}

private struct ReviewRoundIDPreimage: Codable {
    let schemaVersion: Int
    let runID: RunID
    let gate: ReviewGateKind
    let cycleID: ReviewCycleID
    let kind: ReviewRoundKind
    let semanticOrdinal: UInt64
    let roundAnchorEventHead: HashDigest
    let predecessorBaseline: String

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case runID = "run_id"
        case gate
        case cycleID = "cycle_id"
        case kind
        case semanticOrdinal = "semantic_ordinal"
        case roundAnchorEventHead = "round_anchor_event_head"
        case predecessorBaseline = "predecessor_baseline"
    }
}
