import Foundation
import IFLContracts

public struct ReviewBaseline: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let runID: RunID
    public let cycleID: ReviewCycleID
    public let roundID: ReviewRoundID
    public let kind: ReviewRoundKind
    public let gate: ReviewGateKind
    public let cycleOrdinal: UInt64?
    public let semanticOrdinal: UInt64
    public let preCreationEventHead: HashDigest
    public let predecessorBaselineDigest: HashDigest?
    public let artifactScopes: [ArtifactReference]
    public let activeProfileDigest: HashDigest
    public let riskPolicyDigest: HashDigest
    public let assurancePolicyDigest: HashDigest
    public let convergencePolicyDigest: HashDigest
    public let redactionPolicy: RedactionPolicyBinding
    public let roster: FrozenReviewerRoster
    public let rosterDigest: HashDigest
    public let digest: HashDigest

    private init(payload: ReviewBaselinePayload, digest: HashDigest) {
        schemaVersion = payload.schemaVersion
        runID = payload.runID
        cycleID = payload.cycleID
        roundID = payload.roundID
        kind = payload.kind
        gate = payload.gate
        cycleOrdinal = payload.cycleOrdinal
        semanticOrdinal = payload.semanticOrdinal
        preCreationEventHead = payload.preCreationEventHead
        predecessorBaselineDigest = payload.predecessorBaselineDigest
        artifactScopes = payload.artifactScopes
        activeProfileDigest = payload.activeProfileDigest
        riskPolicyDigest = payload.riskPolicyDigest
        assurancePolicyDigest = payload.assurancePolicyDigest
        convergencePolicyDigest = payload.convergencePolicyDigest
        redactionPolicy = payload.redactionPolicy
        roster = payload.roster
        rosterDigest = payload.rosterDigest
        self.digest = digest
    }

    public static func freeze<S: Sequence>(
        runID: RunID,
        roundInput: ReviewRoundInput,
        artifactScopes: S,
        activeProfileDigest: HashDigest,
        riskPolicyDigest: HashDigest,
        assurancePolicyDigest: HashDigest,
        convergencePolicyDigest: HashDigest,
        roster: FrozenReviewerRoster
    ) throws -> ReviewBaseline where S.Element == ArtifactReference {
        let artifacts = artifactScopes.sorted { lhs, rhs in
            (lhs.id.rawValue, lhs.scope.kind.rawValue, lhs.scope.value, lhs.contentHash.rawValue) <
                (rhs.id.rawValue, rhs.scope.kind.rawValue, rhs.scope.value, rhs.contentHash.rawValue)
        }
        guard !artifacts.isEmpty,
              Set(artifacts.map(\.id)).count == artifacts.count,
              roster.redactionPolicy == roundInput.redactionPolicy
        else { throw WorkflowPolicyError.invalidPolicy }

        let cycleID: ReviewCycleID
        switch roundInput.kind {
        case .initial:
            guard let ordinal = roundInput.cycleOrdinal else {
                throw WorkflowError.invalidReviewRound
            }
            cycleID = try ReviewCycleID.derive(
                runID: runID,
                gate: roundInput.gate,
                cycleOrdinal: ordinal,
                preFreezeEventHead: roundInput.roundAnchorEventHead
            )
        case .normalConfirmation, .exception:
            guard let existing = roundInput.cycleID else { throw WorkflowError.invalidReviewRound }
            cycleID = existing
        }
        let roundID = try ReviewRoundID.derive(
            runID: runID,
            gate: roundInput.gate,
            cycleID: cycleID,
            kind: roundInput.kind,
            semanticOrdinal: roundInput.semanticOrdinal,
            roundAnchorEventHead: roundInput.roundAnchorEventHead,
            predecessorBaselineDigest: roundInput.predecessorBaselineDigest
        )
        let payload = ReviewBaselinePayload(
            schemaVersion: 1,
            runID: runID,
            cycleID: cycleID,
            roundID: roundID,
            kind: roundInput.kind,
            gate: roundInput.gate,
            cycleOrdinal: roundInput.cycleOrdinal,
            semanticOrdinal: roundInput.semanticOrdinal,
            preCreationEventHead: roundInput.roundAnchorEventHead,
            predecessorBaselineDigest: roundInput.predecessorBaselineDigest,
            artifactScopes: artifacts,
            activeProfileDigest: activeProfileDigest,
            riskPolicyDigest: riskPolicyDigest,
            assurancePolicyDigest: assurancePolicyDigest,
            convergencePolicyDigest: convergencePolicyDigest,
            redactionPolicy: roundInput.redactionPolicy,
            roster: roster,
            rosterDigest: roster.digest
        )
        return ReviewBaseline(
            payload: payload,
            digest: CanonicalTreeDigest.sha256(try CanonicalJSON.encode(payload))
        )
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 1 else {
            throw WorkflowPolicyError.invalidPolicy
        }
        let runID = try values.decode(RunID.self, forKey: .runID)
        let decodedCycleID = try values.decode(ReviewCycleID.self, forKey: .cycleID)
        let decodedRoundID = try values.decode(ReviewRoundID.self, forKey: .roundID)
        let kind = try values.decode(ReviewRoundKind.self, forKey: .kind)
        let gate = try values.decode(ReviewGateKind.self, forKey: .gate)
        let cycleOrdinal = try values.decodeIfPresent(UInt64.self, forKey: .cycleOrdinal)
        let semanticOrdinal = try values.decode(UInt64.self, forKey: .semanticOrdinal)
        let head = try values.decode(HashDigest.self, forKey: .preCreationEventHead)
        let predecessor = try values.decodeIfPresent(HashDigest.self, forKey: .predecessorBaselineDigest)
        let redactionPolicy = try values.decode(RedactionPolicyBinding.self, forKey: .redactionPolicy)
        let input: ReviewRoundInput
        if kind == .initial {
            guard let cycleOrdinal else { throw WorkflowError.invalidReviewRound }
            input = try .initial(
                gate: gate,
                cycleOrdinal: cycleOrdinal,
                preFreezeEventHead: head,
                redactionPolicy: redactionPolicy
            )
        } else {
            guard let predecessor else { throw WorkflowError.invalidReviewRound }
            input = try .later(
                cycleID: decodedCycleID,
                gate: gate,
                kind: kind,
                semanticOrdinal: semanticOrdinal,
                roundAnchorEventHead: head,
                predecessorBaselineDigest: predecessor,
                redactionPolicy: redactionPolicy
            )
        }
        let decodedArtifacts = try values.decode([ArtifactReference].self, forKey: .artifactScopes)
        let decodedRoster = try values.decode(FrozenReviewerRoster.self, forKey: .roster)
        let decodedRosterDigest = try values.decode(HashDigest.self, forKey: .rosterDigest)
        let decodedDigest = try values.decode(HashDigest.self, forKey: .digest)
        let frozen = try Self.freeze(
            runID: runID,
            roundInput: input,
            artifactScopes: decodedArtifacts,
            activeProfileDigest: values.decode(HashDigest.self, forKey: .activeProfileDigest),
            riskPolicyDigest: values.decode(HashDigest.self, forKey: .riskPolicyDigest),
            assurancePolicyDigest: values.decode(HashDigest.self, forKey: .assurancePolicyDigest),
            convergencePolicyDigest: values.decode(HashDigest.self, forKey: .convergencePolicyDigest),
            roster: decodedRoster
        )
        guard decodedArtifacts == frozen.artifactScopes,
              decodedCycleID == frozen.cycleID,
              decodedRoundID == frozen.roundID,
              decodedRosterDigest == frozen.rosterDigest,
              decodedDigest == frozen.digest
        else { throw WorkflowPolicyError.invalidPolicy }
        self = frozen
    }

    public static func decodeCanonical(from bytes: Data) throws -> ReviewBaseline {
        try artifactDecodeCanonical(Self.self, from: bytes)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case runID = "run_id"
        case cycleID = "cycle_id"
        case roundID = "round_id"
        case kind = "round_kind"
        case gate
        case cycleOrdinal = "cycle_ordinal"
        case semanticOrdinal = "semantic_ordinal"
        case preCreationEventHead = "pre_creation_event_head"
        case predecessorBaselineDigest = "predecessor_baseline_digest"
        case artifactScopes = "artifact_scopes"
        case activeProfileDigest = "active_profile_digest"
        case riskPolicyDigest = "risk_policy_digest"
        case assurancePolicyDigest = "assurance_policy_digest"
        case convergencePolicyDigest = "convergence_policy_digest"
        case redactionPolicy = "redaction_policy"
        case roster
        case rosterDigest = "roster_digest"
        case digest = "baseline_digest"
    }
}

private struct ReviewBaselinePayload: Codable {
    let schemaVersion: Int
    let runID: RunID
    let cycleID: ReviewCycleID
    let roundID: ReviewRoundID
    let kind: ReviewRoundKind
    let gate: ReviewGateKind
    let cycleOrdinal: UInt64?
    let semanticOrdinal: UInt64
    let preCreationEventHead: HashDigest
    let predecessorBaselineDigest: HashDigest?
    let artifactScopes: [ArtifactReference]
    let activeProfileDigest: HashDigest
    let riskPolicyDigest: HashDigest
    let assurancePolicyDigest: HashDigest
    let convergencePolicyDigest: HashDigest
    let redactionPolicy: RedactionPolicyBinding
    let roster: FrozenReviewerRoster
    let rosterDigest: HashDigest

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case runID = "run_id"
        case cycleID = "cycle_id"
        case roundID = "round_id"
        case kind = "round_kind"
        case gate
        case cycleOrdinal = "cycle_ordinal"
        case semanticOrdinal = "semantic_ordinal"
        case preCreationEventHead = "pre_creation_event_head"
        case predecessorBaselineDigest = "predecessor_baseline_digest"
        case artifactScopes = "artifact_scopes"
        case activeProfileDigest = "active_profile_digest"
        case riskPolicyDigest = "risk_policy_digest"
        case assurancePolicyDigest = "assurance_policy_digest"
        case convergencePolicyDigest = "convergence_policy_digest"
        case redactionPolicy = "redaction_policy"
        case roster
        case rosterDigest = "roster_digest"
    }
}
