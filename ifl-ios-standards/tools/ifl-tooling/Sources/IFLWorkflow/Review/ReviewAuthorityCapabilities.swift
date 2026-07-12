import Foundation
import IFLContracts

/// A policy set whose behavior-bearing payloads have been frozen and bound to one baseline.
public struct VerifiedReviewPolicySet: Hashable, Sendable {
    public let baselineDigest: HashDigest
    public let runID: RunID
    public let gate: ReviewGateKind
    public let assurancePolicyDigest: HashDigest
    public let findingPolicy: FrozenReviewFindingPolicy
    public let dispositionPolicy: FrozenDispositionPolicy

    init(
        baselineDigest: HashDigest,
        runID: RunID,
        gate: ReviewGateKind,
        assurancePolicyDigest: HashDigest,
        findingPolicy: FrozenReviewFindingPolicy,
        dispositionPolicy: FrozenDispositionPolicy
    ) {
        self.baselineDigest = baselineDigest
        self.runID = runID
        self.gate = gate
        self.assurancePolicyDigest = assurancePolicyDigest
        self.findingPolicy = findingPolicy
        self.dispositionPolicy = dispositionPolicy
    }
}

public enum ReviewPolicyVerifier {
    public static func verify(
        findingPolicy: FrozenReviewFindingPolicy,
        dispositionPolicy: FrozenDispositionPolicy,
        baseline: ReviewBaseline
    ) throws -> VerifiedReviewPolicySet {
        guard !dispositionPolicy.authorizedPrincipalIDs.isEmpty,
              findingPolicy.hasCanonicalDigest,
              dispositionPolicy.hasCanonicalDigest
        else { throw WorkflowPolicyError.invalidPolicy }
        return VerifiedReviewPolicySet(
            baselineDigest: baseline.digest,
            runID: baseline.runID,
            gate: baseline.gate,
            assurancePolicyDigest: baseline.assurancePolicyDigest,
            findingPolicy: findingPolicy,
            dispositionPolicy: dispositionPolicy
        )
    }
}

/// Current persisted/artifact/approval authority for issuing review receipts.
public struct VerifiedReviewReceiptAuthority: Hashable, Sendable {
    public let runID: RunID
    public let currentness: VerifiedReviewScopeCurrentness
    public let policies: VerifiedReviewPolicySet
    public let approvals: [ApprovalRecord]
    public let approvalSetDigest: HashDigest
    public let persistedStateDigest: HashDigest
    public let eventHead: HashDigest
    let hasRecordedNormalConfirmation: Bool
    let approvalSet: VerifiedReviewApprovalSet

    init(
        runID: RunID,
        currentness: VerifiedReviewScopeCurrentness,
        policies: VerifiedReviewPolicySet,
        approvals: [ApprovalRecord],
        approvalSetDigest: HashDigest,
        persistedStateDigest: HashDigest,
        eventHead: HashDigest,
        hasRecordedNormalConfirmation: Bool,
        approvalSet: VerifiedReviewApprovalSet
    ) {
        self.runID = runID
        self.currentness = currentness
        self.policies = policies
        self.approvals = approvals
        self.approvalSetDigest = approvalSetDigest
        self.persistedStateDigest = persistedStateDigest
        self.eventHead = eventHead
        self.hasRecordedNormalConfirmation = hasRecordedNormalConfirmation
        self.approvalSet = approvalSet
    }
}

struct VerifiedReviewApprovalSet: Hashable, Sendable {
    let records: [ApprovalRecord]
    let attestations: [VerifiedApprovalAttestation]
    let digest: HashDigest
}

enum ReviewApprovalSetVerifier {
    static func verify(
        records: [ApprovalRecord],
        attestations: [VerifiedApprovalAttestation],
        currentness: VerifiedReviewScopeCurrentness,
        policies: VerifiedReviewPolicySet
    ) throws -> VerifiedReviewApprovalSet {
        let currentReviewed = Dictionary(
            uniqueKeysWithValues: currentness.currentArtifacts.map { ($0.id, $0.contentHash) }
        )
        let keyed = try records.map { record -> (Data, ApprovalRecord, VerifiedApprovalAttestation) in
            let bytes = try CanonicalJSON.encode(record)
            let recordDigest = CanonicalTreeDigest.sha256(bytes)
            let matching = attestations.filter { $0.recordDigest == recordDigest }
            let reviewed = Dictionary(
                uniqueKeysWithValues: record.reviewedArtifacts.map {
                    ($0.artifactID, $0.artifactHash)
                }
            )
            guard matching.count == 1,
                  matching[0].attestationReference == record.attestationReference,
                  reviewed == currentReviewed,
                  record.authorityPolicyDigest == policies.assurancePolicyDigest,
                  ReviewGateKind.findingProducingGate(for: record.gate) == policies.gate
            else { throw WorkflowPolicyError.invalidPolicy }
            return (bytes, record, matching[0])
        }.sorted { $0.0.lexicographicallyPrecedes($1.0) }
        guard keyed.count == attestations.count,
              Set(keyed.map { $0.2.capabilityDigest }).count == keyed.count
        else { throw WorkflowPolicyError.invalidPolicy }
        let canonicalRecords = keyed.map(\.1)
        let canonicalAttestations = keyed.map(\.2)
        return VerifiedReviewApprovalSet(
            records: canonicalRecords,
            attestations: canonicalAttestations,
            digest: CanonicalTreeDigest.sha256(try CanonicalJSON.encode(canonicalRecords))
        )
    }
}

enum ReviewReceiptAuthorityVerifier {
    static func verify(
        persistedRun: PersistedRun,
        currentness: VerifiedReviewScopeCurrentness,
        policies: VerifiedReviewPolicySet,
        approvalSet: VerifiedReviewApprovalSet
    ) throws -> VerifiedReviewReceiptAuthority {
        try ReviewCommittedReceiptVerifier.validateActiveChain(persistedRun)
        let canonicalStateBytes = try CanonicalJSON.encode(persistedRun.state)
        guard persistedRun.state.runID == policies.runID,
              persistedRun.state.runID == currentness.runID,
              policies.baselineDigest == currentness.baselineDigest,
              persistedRun.stateBytes == canonicalStateBytes,
              persistedRun.stateDigest == CanonicalTreeDigest.sha256(canonicalStateBytes),
              persistedRun.eventHead == currentness.currentEventHead,
              currentness.gate == policies.gate,
              currentness.matchesActiveCycle(persistedRun.state.reviewCycle),
              approvalSet == (try ReviewApprovalSetVerifier.verify(
                  records: approvalSet.records,
                  attestations: approvalSet.attestations,
                  currentness: currentness,
                  policies: policies
              ))
        else { throw PersistenceError.integrityViolation }
        let hasRecordedNormalConfirmation = try verifyActiveCycleConfirmation(
            persistedRun: persistedRun
        )
        return VerifiedReviewReceiptAuthority(
            runID: policies.runID,
            currentness: currentness,
            policies: policies,
            approvals: approvalSet.records,
            approvalSetDigest: approvalSet.digest,
            persistedStateDigest: persistedRun.stateDigest,
            eventHead: persistedRun.eventHead,
            hasRecordedNormalConfirmation: hasRecordedNormalConfirmation,
            approvalSet: approvalSet
        )
    }

    private static func verifyActiveCycleConfirmation(
        persistedRun: PersistedRun
    ) throws -> Bool {
        guard let cycle = persistedRun.state.reviewCycle else {
            throw PersistenceError.integrityViolation
        }
        guard let receiptID = cycle.confirmationReceiptID else {
            guard !cycle.didRecordConfirmation else {
                throw PersistenceError.integrityViolation
            }
            return false
        }
        guard cycle.didRecordConfirmation else {
            throw PersistenceError.integrityViolation
        }
        let kind = try ReceiptKind(validating: "review-confirmation")
        let committed = try ReviewCommittedReceiptVerifier.verify(
            id: receiptID,
            kind: kind,
            in: persistedRun
        )
        let receipt = try ConfirmationReceipt.decodeCanonical(from: committed.payloadBytes)
        guard receipt.receiptID == receiptID.rawValue,
              try receipt.hasValidIdentity(
                  runID: persistedRun.state.runID,
                  cycleID: cycle.id,
                  gate: cycle.gate
              ),
              committed.runID == persistedRun.state.runID,
              committed.eventID == receiptID.rawValue,
              committed.eventKind == .reviewConfirmationRecorded,
              committed.publicationAnchorEventHead == receipt.publicationAnchorEventHead,
              committed.receipt.transactionID == committed.transactionID,
              committed.receipt.transactionDigest == committed.transactionDigest,
              committed.manifestEntry.kind == committed.kind,
              committed.manifestEntry.id == committed.id,
              committed.manifestEntry.payloadDigest == committed.payloadDigest,
              committed.owningRecord.transactionID == committed.transactionID,
              committed.owningRecord.transactionDigest == committed.transactionDigest,
              committed.owningRecord.receiptManifest.contains(committed.manifestEntry),
              committed.owningRecord.recordDigest == committed.producedEventHead,
              persistedRun.events.contains(where: {
                  $0.recordDigest == committed.owningRecord.recordDigest
              })
        else { throw PersistenceError.integrityViolation }
        return true
    }
}

/// Exact artifact and event-head currentness for one frozen review baseline.
public struct VerifiedReviewScopeCurrentness: Hashable, Sendable {
    public let runID: RunID
    public let baselineDigest: HashDigest
    public let cycleID: ReviewCycleID
    public let gate: ReviewGateKind
    public let roundID: ReviewRoundID
    public let roundKind: ReviewRoundKind
    public let semanticOrdinal: UInt64
    public let roundAnchorEventHead: HashDigest
    public let predecessorBaselineDigest: HashDigest?
    public let currentArtifacts: [ArtifactReference]
    public let currentGraphDigest: HashDigest
    public let currentArtifactSetDigest: HashDigest
    public let currentEventHead: HashDigest

    init(
        runID: RunID,
        baselineDigest: HashDigest,
        cycleID: ReviewCycleID,
        gate: ReviewGateKind,
        roundID: ReviewRoundID,
        roundKind: ReviewRoundKind,
        semanticOrdinal: UInt64,
        roundAnchorEventHead: HashDigest,
        predecessorBaselineDigest: HashDigest?,
        currentArtifacts: [ArtifactReference],
        currentGraphDigest: HashDigest,
        currentArtifactSetDigest: HashDigest,
        currentEventHead: HashDigest
    ) {
        self.runID = runID
        self.baselineDigest = baselineDigest
        self.cycleID = cycleID
        self.gate = gate
        self.roundID = roundID
        self.roundKind = roundKind
        self.semanticOrdinal = semanticOrdinal
        self.roundAnchorEventHead = roundAnchorEventHead
        self.predecessorBaselineDigest = predecessorBaselineDigest
        self.currentArtifacts = currentArtifacts
        self.currentGraphDigest = currentGraphDigest
        self.currentArtifactSetDigest = currentArtifactSetDigest
        self.currentEventHead = currentEventHead
    }

    func matchesActiveCycle(_ cycle: ReviewCycleState?) -> Bool {
        guard let cycle else { return false }
        return cycle.id == cycleID &&
            cycle.gate == gate &&
            cycle.currentRoundID == roundID &&
            cycle.currentRoundKind == roundKind &&
            cycle.currentSemanticOrdinal == semanticOrdinal &&
            cycle.currentRoundAnchorEventHead == roundAnchorEventHead &&
            cycle.predecessorBaselineDigest == predecessorBaselineDigest
    }

    func matchesBaseline(_ baseline: ReviewBaseline) -> Bool {
        runID == baseline.runID &&
            baselineDigest == baseline.digest &&
            cycleID == baseline.cycleID &&
            gate == baseline.gate &&
            roundID == baseline.roundID &&
            roundKind == baseline.kind &&
            semanticOrdinal == baseline.semanticOrdinal &&
            roundAnchorEventHead == baseline.preCreationEventHead &&
            predecessorBaselineDigest == baseline.predecessorBaselineDigest &&
            currentArtifacts == baseline.artifactScopes
    }
}

public enum ReviewScopeCurrentnessVerifier {
    public static func verify(
        baseline: ReviewBaseline,
        currentGraph: ArtifactGraph,
        persistedRun: PersistedRun
    ) throws -> VerifiedReviewScopeCurrentness {
        try ReviewCommittedReceiptVerifier.validateActiveChain(persistedRun)
        let canonical = canonicalReviewArtifacts(currentGraph.artifacts)
        let stateBytes = try CanonicalJSON.encode(persistedRun.state)
        guard canonical == baseline.artifactScopes,
              persistedRun.state.runID == baseline.runID,
              persistedRun.state.canonSnapshotDigest == baseline.activeProfileDigest,
              persistedRun.eventHead == persistedRun.events.last?.recordDigest,
              persistedRun.state.reviewCycle.map({ cycle in
                  cycle.id == baseline.cycleID &&
                      cycle.gate == baseline.gate &&
                      cycle.currentRoundID == baseline.roundID &&
                      cycle.currentRoundKind == baseline.kind &&
                      cycle.currentSemanticOrdinal == baseline.semanticOrdinal &&
                      cycle.currentRoundAnchorEventHead == baseline.preCreationEventHead &&
                      cycle.predecessorBaselineDigest == baseline.predecessorBaselineDigest
              }) == true,
              persistedRun.stateBytes == stateBytes,
              persistedRun.stateDigest == CanonicalTreeDigest.sha256(stateBytes)
        else { throw PersistenceError.integrityViolation }
        return VerifiedReviewScopeCurrentness(
            runID: baseline.runID,
            baselineDigest: baseline.digest,
            cycleID: baseline.cycleID,
            gate: baseline.gate,
            roundID: baseline.roundID,
            roundKind: baseline.kind,
            semanticOrdinal: baseline.semanticOrdinal,
            roundAnchorEventHead: baseline.preCreationEventHead,
            predecessorBaselineDigest: baseline.predecessorBaselineDigest,
            currentArtifacts: canonical,
            currentGraphDigest: try currentGraph.canonicalDigest(),
            currentArtifactSetDigest: CanonicalTreeDigest.sha256(
                try CanonicalJSON.encode(canonical)
            ),
            currentEventHead: persistedRun.eventHead
        )
    }
}

struct ScopedReviewAuthorityIdentity: Codable, Hashable, Sendable {
    let actorID: ActorID
    let principalID: PrincipalID
    let roles: [String]
    let principalKind: String
    let independentContextDigest: HashDigest
    let hasAuthorshipEdge: Bool
    let hasSourceWriteCapability: Bool

    init(_ authority: VerifiedAuthorityFact) {
        actorID = authority.actorID
        principalID = authority.principalID
        roles = authority.roles.map(\.rawValue).sorted()
        principalKind = authority.principalKind.rawValue
        independentContextDigest = authority.independentContextDigest
        hasAuthorshipEdge = authority.hasAuthorshipEdge
        hasSourceWriteCapability = authority.hasSourceWriteCapability
    }

    enum CodingKeys: String, CodingKey {
        case actorID = "actor_id"
        case principalID = "principal_id"
        case roles
        case principalKind = "principal_kind"
        case independentContextDigest = "independent_context_digest"
        case hasAuthorshipEdge = "has_authorship_edge"
        case hasSourceWriteCapability = "has_source_write_capability"
    }
}

private struct ReviewAuthorshipProvenancePreimage: Codable {
    let domain: String
    let runID: RunID
    let baselineDigest: HashDigest
    let roundID: ReviewRoundID
    let currentEventHead: HashDigest
    let authoredArtifacts: [ArtifactReference]
    let authors: [ScopedReviewAuthorityIdentity]

    enum CodingKeys: String, CodingKey {
        case domain
        case runID = "run_id"
        case baselineDigest = "baseline_digest"
        case roundID = "round_id"
        case currentEventHead = "current_event_head"
        case authoredArtifacts = "authored_artifacts"
        case authors
    }
}

/// Sealed authorship identity and execution context for one frozen review baseline.
///
/// This capability is intentionally non-Codable: only the verifier can mint it from current
/// baseline and artifact facts.
public struct VerifiedReviewAuthorshipContext: Hashable, Sendable {
    public let runID: RunID
    public let baselineDigest: HashDigest
    public let roundID: ReviewRoundID
    public let baselineEventHead: HashDigest
    public let currentEventHead: HashDigest
    public let currentArtifactSetDigest: HashDigest
    public let authorActorIDs: [ActorID]
    public let authorPrincipalIDs: [PrincipalID]
    public let authorIndependentContextDigests: [HashDigest]
    public let authoredArtifactSetDigest: HashDigest
    public let authorshipProvenanceDigest: HashDigest

    public var authorActorID: ActorID { authorActorIDs[0] }
    public var authorPrincipalID: PrincipalID { authorPrincipalIDs[0] }
    public var authorIndependentContextDigest: HashDigest {
        authorIndependentContextDigests[0]
    }

    init(
        runID: RunID,
        baselineDigest: HashDigest,
        roundID: ReviewRoundID,
        baselineEventHead: HashDigest,
        currentEventHead: HashDigest,
        currentArtifactSetDigest: HashDigest,
        authorActorIDs: [ActorID],
        authorPrincipalIDs: [PrincipalID],
        authorIndependentContextDigests: [HashDigest],
        authoredArtifactSetDigest: HashDigest,
        authorshipProvenanceDigest: HashDigest
    ) {
        self.runID = runID
        self.baselineDigest = baselineDigest
        self.roundID = roundID
        self.baselineEventHead = baselineEventHead
        self.currentEventHead = currentEventHead
        self.currentArtifactSetDigest = currentArtifactSetDigest
        self.authorActorIDs = authorActorIDs
        self.authorPrincipalIDs = authorPrincipalIDs
        self.authorIndependentContextDigests = authorIndependentContextDigests
        self.authoredArtifactSetDigest = authoredArtifactSetDigest
        self.authorshipProvenanceDigest = authorshipProvenanceDigest
    }
}

public enum ReviewAuthorshipContextVerifier {
    public static func verify(
        authorAuthority: VerifiedAuthorityFact,
        baseline: ReviewBaseline,
        currentness: VerifiedReviewScopeCurrentness
    ) throws -> VerifiedReviewAuthorshipContext {
        try verify(
            authorAuthorities: [authorAuthority],
            authoredArtifacts: baseline.artifactScopes,
            baseline: baseline,
            currentness: currentness
        )
    }

    public static func verify(
        authorAuthorities: [VerifiedAuthorityFact],
        authoredArtifacts: [ArtifactReference],
        baseline: ReviewBaseline,
        currentness: VerifiedReviewScopeCurrentness
    ) throws -> VerifiedReviewAuthorshipContext {
        let canonicalArtifacts = canonicalReviewArtifacts(authoredArtifacts)
        let artifactSetDigest = CanonicalTreeDigest.sha256(
            try CanonicalJSON.encode(baseline.artifactScopes)
        )
        let authors = authorAuthorities.map(ScopedReviewAuthorityIdentity.init).sorted {
            ($0.actorID.rawValue, $0.principalID.rawValue, $0.independentContextDigest.rawValue) <
                ($1.actorID.rawValue, $1.principalID.rawValue, $1.independentContextDigest.rawValue)
        }
        guard !authors.isEmpty,
              canonicalArtifacts == baseline.artifactScopes,
              Set(authors.map(\.actorID)).count == authors.count,
              Set(authors.map(\.principalID)).count == authors.count,
              Set(authors.map(\.independentContextDigest)).count == authors.count,
              authorAuthorities.allSatisfy({ authority in
                  authority.roles.contains(.author) &&
                      (authority.principalKind == .agent || authority.principalKind == .human) &&
                      authority.hasAuthorshipEdge &&
                      authority.hasSourceWriteCapability
              }),
              currentness.matchesBaseline(baseline),
              currentness.currentArtifactSetDigest == artifactSetDigest
        else { throw WorkflowPolicyError.invalidPolicy }
        let provenanceDigest = CanonicalTreeDigest.sha256(try CanonicalJSON.encode(
            ReviewAuthorshipProvenancePreimage(
                domain: "ReviewAuthorshipProvenance/v1",
                runID: baseline.runID,
                baselineDigest: baseline.digest,
                roundID: baseline.roundID,
                currentEventHead: currentness.currentEventHead,
                authoredArtifacts: canonicalArtifacts,
                authors: authors
            )
        ))
        return VerifiedReviewAuthorshipContext(
            runID: baseline.runID,
            baselineDigest: baseline.digest,
            roundID: baseline.roundID,
            baselineEventHead: baseline.preCreationEventHead,
            currentEventHead: currentness.currentEventHead,
            currentArtifactSetDigest: artifactSetDigest,
            authorActorIDs: authors.map(\.actorID),
            authorPrincipalIDs: authors.map(\.principalID),
            authorIndependentContextDigests: authors.map(\.independentContextDigest),
            authoredArtifactSetDigest: artifactSetDigest,
            authorshipProvenanceDigest: provenanceDigest
        )
    }
}

/// Receipt-backed authority for exactly one reviewer submission.
public struct VerifiedReviewerInventoryAuthority: Hashable, Sendable {
    let submissionDigest: HashDigest
    let baselineDigest: HashDigest
    let roundID: ReviewRoundID
    let assignmentID: ReviewAssignmentID
    let baselineEventHead: HashDigest
    let currentEventHead: HashDigest
    let currentArtifactSetDigest: HashDigest
    let envelopeReceiptDigests: [HashDigest]
    let authorityContextDigest: HashDigest
    let authorActorIDs: [ActorID]
    let authorPrincipalIDs: [PrincipalID]
    let authorContextDigests: [HashDigest]
    let authorshipProvenanceDigest: HashDigest

    init(
        submissionDigest: HashDigest,
        baselineDigest: HashDigest,
        roundID: ReviewRoundID,
        assignmentID: ReviewAssignmentID,
        baselineEventHead: HashDigest,
        currentEventHead: HashDigest,
        currentArtifactSetDigest: HashDigest,
        envelopeReceiptDigests: [HashDigest],
        authorityContextDigest: HashDigest,
        authorActorIDs: [ActorID],
        authorPrincipalIDs: [PrincipalID],
        authorContextDigests: [HashDigest],
        authorshipProvenanceDigest: HashDigest
    ) {
        self.submissionDigest = submissionDigest
        self.baselineDigest = baselineDigest
        self.roundID = roundID
        self.assignmentID = assignmentID
        self.baselineEventHead = baselineEventHead
        self.currentEventHead = currentEventHead
        self.currentArtifactSetDigest = currentArtifactSetDigest
        self.envelopeReceiptDigests = envelopeReceiptDigests
        self.authorityContextDigest = authorityContextDigest
        self.authorActorIDs = authorActorIDs
        self.authorPrincipalIDs = authorPrincipalIDs
        self.authorContextDigests = authorContextDigests
        self.authorshipProvenanceDigest = authorshipProvenanceDigest
    }
}

/// Canonical, non-self-referential projection committed by disposition-evidence receipts.
/// `rationaleDigest` is intentionally excluded because it is the digest of this payload.
public struct ReviewDispositionEvidenceReceiptPayload: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let receiptID: ReceiptID
    public let runID: RunID
    public let baselineDigest: HashDigest
    public let fingerprint: FailureFingerprint
    public let severity: RiskClass
    public let mustFix: Bool
    public let evidenceKind: DispositionEvidenceKind?
    public let remediationAssignmentID: String?
    public let scopeDigest: HashDigest?
    public let canonicalFingerprint: FailureFingerprint?
    public let equivalenceEvidenceReferences: [String]
    public let refutationEvidenceReferences: [String]
    public let governingClauseDigest: HashDigest?
    public let accountableOwner: String?
    public let deferredScope: String?
    public let revisitCondition: String?
    public let humanRiskAcceptance: Bool
    public let disputed: Bool
    public let authorityActorID: ActorID
    public let authorityPrincipalID: PrincipalID
    public let authorityKind: DispositionAuthorityKind
    public let claimedAuthenticated: Bool
    public let authorityPolicyDigest: HashDigest
    public let authorityContextDigest: HashDigest
    public let evidenceReferences: [String]

    public init(
        receiptID: ReceiptID,
        runID: RunID,
        baselineDigest: HashDigest,
        fingerprint: FailureFingerprint,
        severity: RiskClass,
        mustFix: Bool,
        evidenceKind: DispositionEvidenceKind?,
        remediationAssignmentID: String? = nil,
        scopeDigest: HashDigest? = nil,
        canonicalFingerprint: FailureFingerprint? = nil,
        equivalenceEvidenceReferences: [String] = [],
        refutationEvidenceReferences: [String] = [],
        governingClauseDigest: HashDigest? = nil,
        accountableOwner: String? = nil,
        deferredScope: String? = nil,
        revisitCondition: String? = nil,
        humanRiskAcceptance: Bool,
        disputed: Bool,
        authorityActorID: ActorID,
        authorityPrincipalID: PrincipalID,
        authorityKind: DispositionAuthorityKind,
        claimedAuthenticated: Bool,
        authorityPolicyDigest: HashDigest,
        authorityContextDigest: HashDigest,
        evidenceReferences: [String]
    ) throws {
        let equivalenceReferences = equivalenceEvidenceReferences.sorted()
        let refutationReferences = refutationEvidenceReferences.sorted()
        let authorityEvidenceReferences = evidenceReferences.sorted()
        let optionalIdentifiers = [
            remediationAssignmentID,
            accountableOwner,
            deferredScope,
            revisitCondition,
        ].compactMap { $0 }
        guard authorityKind != .agent,
              claimedAuthenticated,
              authorityEvidenceReferences.contains(receiptID.rawValue),
              !authorityEvidenceReferences.isEmpty,
              Set(authorityEvidenceReferences).count == authorityEvidenceReferences.count,
              authorityEvidenceReferences.allSatisfy(WorkflowIdentifier.isValid),
              Set(equivalenceReferences).count == equivalenceReferences.count,
              Set(refutationReferences).count == refutationReferences.count,
              (equivalenceReferences + refutationReferences)
                .allSatisfy(WorkflowIdentifier.isValid),
              optionalIdentifiers.allSatisfy(WorkflowIdentifier.isValid)
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
        schemaVersion = 1
        self.receiptID = receiptID
        self.runID = runID
        self.baselineDigest = baselineDigest
        self.fingerprint = fingerprint
        self.severity = severity
        self.mustFix = mustFix
        self.evidenceKind = evidenceKind
        self.remediationAssignmentID = remediationAssignmentID
        self.scopeDigest = scopeDigest
        self.canonicalFingerprint = canonicalFingerprint
        self.equivalenceEvidenceReferences = equivalenceReferences
        self.refutationEvidenceReferences = refutationReferences
        self.governingClauseDigest = governingClauseDigest
        self.accountableOwner = accountableOwner
        self.deferredScope = deferredScope
        self.revisitCondition = revisitCondition
        self.humanRiskAcceptance = humanRiskAcceptance
        self.disputed = disputed
        self.authorityActorID = authorityActorID
        self.authorityPrincipalID = authorityPrincipalID
        self.authorityKind = authorityKind
        self.claimedAuthenticated = claimedAuthenticated
        self.authorityPolicyDigest = authorityPolicyDigest
        self.authorityContextDigest = authorityContextDigest
        self.evidenceReferences = authorityEvidenceReferences
    }

    init(
        receiptID: ReceiptID,
        evidence: IssueDispositionEvidence,
        authority: VerifiedAuthorityFact,
        runID: RunID,
        baselineDigest: HashDigest
    ) throws {
        let envelope = evidence.envelope
        let claim = envelope.authority
        try self.init(
            receiptID: receiptID,
            runID: runID,
            baselineDigest: baselineDigest,
            fingerprint: evidence.fingerprint,
            severity: envelope.severity,
            mustFix: envelope.mustFix,
            evidenceKind: envelope.evidenceKind,
            remediationAssignmentID: envelope.remediationAssignmentID,
            scopeDigest: envelope.scopeDigest,
            canonicalFingerprint: envelope.canonicalFingerprint,
            equivalenceEvidenceReferences: envelope.equivalenceEvidenceReferences,
            refutationEvidenceReferences: envelope.refutationEvidenceReferences,
            governingClauseDigest: envelope.governingClauseDigest,
            accountableOwner: envelope.accountableOwner,
            deferredScope: envelope.deferredScope,
            revisitCondition: envelope.revisitCondition,
            humanRiskAcceptance: envelope.humanRiskAcceptance,
            disputed: envelope.disputed,
            authorityActorID: claim.actorID,
            authorityPrincipalID: claim.principalID,
            authorityKind: claim.claimedKind,
            claimedAuthenticated: claim.claimedAuthenticated,
            authorityPolicyDigest: claim.authorityPolicyDigest,
            authorityContextDigest: authority.independentContextDigest,
            evidenceReferences: claim.evidenceReferences
        )
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 1 else {
            throw WorkflowPolicyError.invalidDispositionEvidence
        }
        let equivalenceReferences = try values.decode(
            [String].self,
            forKey: .equivalenceEvidenceReferences
        )
        let refutationReferences = try values.decode(
            [String].self,
            forKey: .refutationEvidenceReferences
        )
        let authorityEvidenceReferences = try values.decode(
            [String].self,
            forKey: .evidenceReferences
        )
        try self.init(
            receiptID: values.decode(ReceiptID.self, forKey: .receiptID),
            runID: values.decode(RunID.self, forKey: .runID),
            baselineDigest: values.decode(HashDigest.self, forKey: .baselineDigest),
            fingerprint: values.decode(FailureFingerprint.self, forKey: .fingerprint),
            severity: values.decode(RiskClass.self, forKey: .severity),
            mustFix: values.decode(Bool.self, forKey: .mustFix),
            evidenceKind: values.decodeIfPresent(
                DispositionEvidenceKind.self,
                forKey: .evidenceKind
            ),
            remediationAssignmentID: values.decodeIfPresent(
                String.self,
                forKey: .remediationAssignmentID
            ),
            scopeDigest: values.decodeIfPresent(HashDigest.self, forKey: .scopeDigest),
            canonicalFingerprint: values.decodeIfPresent(
                FailureFingerprint.self,
                forKey: .canonicalFingerprint
            ),
            equivalenceEvidenceReferences: equivalenceReferences,
            refutationEvidenceReferences: refutationReferences,
            governingClauseDigest: values.decodeIfPresent(
                HashDigest.self,
                forKey: .governingClauseDigest
            ),
            accountableOwner: values.decodeIfPresent(String.self, forKey: .accountableOwner),
            deferredScope: values.decodeIfPresent(String.self, forKey: .deferredScope),
            revisitCondition: values.decodeIfPresent(String.self, forKey: .revisitCondition),
            humanRiskAcceptance: values.decode(Bool.self, forKey: .humanRiskAcceptance),
            disputed: values.decode(Bool.self, forKey: .disputed),
            authorityActorID: values.decode(ActorID.self, forKey: .authorityActorID),
            authorityPrincipalID: values.decode(
                PrincipalID.self,
                forKey: .authorityPrincipalID
            ),
            authorityKind: values.decode(DispositionAuthorityKind.self, forKey: .authorityKind),
            claimedAuthenticated: values.decode(Bool.self, forKey: .claimedAuthenticated),
            authorityPolicyDigest: values.decode(
                HashDigest.self,
                forKey: .authorityPolicyDigest
            ),
            authorityContextDigest: values.decode(
                HashDigest.self,
                forKey: .authorityContextDigest
            ),
            evidenceReferences: authorityEvidenceReferences
        )
        guard equivalenceReferences == equivalenceEvidenceReferences,
              refutationReferences == refutationEvidenceReferences,
              authorityEvidenceReferences == evidenceReferences
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
    }

    public static func decodeCanonical(
        from bytes: Data
    ) throws -> ReviewDispositionEvidenceReceiptPayload {
        try artifactDecodeCanonical(Self.self, from: bytes)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case receiptID = "receipt_id"
        case runID = "run_id"
        case baselineDigest = "baseline_digest"
        case fingerprint
        case severity
        case mustFix = "must_fix"
        case evidenceKind = "evidence_kind"
        case remediationAssignmentID = "remediation_assignment_id"
        case scopeDigest = "scope_digest"
        case canonicalFingerprint = "canonical_fingerprint"
        case equivalenceEvidenceReferences = "equivalence_evidence_references"
        case refutationEvidenceReferences = "refutation_evidence_references"
        case governingClauseDigest = "governing_clause_digest"
        case accountableOwner = "accountable_owner"
        case deferredScope = "deferred_scope"
        case revisitCondition = "revisit_condition"
        case humanRiskAcceptance = "human_risk_acceptance"
        case disputed
        case authorityActorID = "authority_actor_id"
        case authorityPrincipalID = "authority_principal_id"
        case authorityKind = "authority_kind"
        case claimedAuthenticated = "claimed_authenticated"
        case authorityPolicyDigest = "authority_policy_digest"
        case authorityContextDigest = "authority_context_digest"
        case evidenceReferences = "evidence_references"
    }
}

/// Receipt-backed disposition evidence. Raw wire claims never cross this boundary by themselves.
public struct VerifiedReviewDispositionEvidence: Sendable {
    public let fingerprint: FailureFingerprint
    let evidence: IssueDispositionEvidence
    let verifiedAuthority: VerifiedDispositionAuthorityFact
    let baselineDigest: HashDigest
    let persistedEvidenceDigests: [HashDigest]

    init(
        evidence: IssueDispositionEvidence,
        verifiedAuthority: VerifiedDispositionAuthorityFact,
        baselineDigest: HashDigest,
        persistedEvidenceDigests: [HashDigest]
    ) {
        fingerprint = evidence.fingerprint
        self.evidence = evidence
        self.verifiedAuthority = verifiedAuthority
        self.baselineDigest = baselineDigest
        self.persistedEvidenceDigests = persistedEvidenceDigests
    }
}

public enum ReviewAuthorityVerifier {
    public static func verifyInventoryAuthority(
        submission: ReviewerFindingSubmission,
        baseline: ReviewBaseline,
        assignment: ReviewerAssignment,
        authority: VerifiedAuthorityFact,
        authorshipContext: VerifiedReviewAuthorshipContext,
        persistedRun: PersistedRun,
        currentness: VerifiedReviewScopeCurrentness
    ) throws -> VerifiedReviewerInventoryAuthority {
        guard baseline.roster.assignments.contains(assignment),
              submission.baselineDigest == baseline.digest,
              submission.roundID == baseline.roundID,
              submission.rosterDigest == baseline.rosterDigest,
              submission.assignmentID == assignment.id,
              submission.checklistDigest == assignment.checklistDigest,
              submission.redactionPolicy == baseline.redactionPolicy,
              submission.redactionMetadata.policy == baseline.redactionPolicy,
              submission.redactionMetadata.sanitizedEnvelopeDigest ==
                submission.envelope.artifact.contentHash,
              !submission.redactionMetadata.containsRawSensitiveData,
              submission.actorID == assignment.expectedActorID,
              submission.principalID == assignment.expectedPrincipalID,
              submission.role == assignment.requiredRole,
              submission.complete,
              authority.actorID == assignment.expectedActorID,
              authority.principalID == assignment.expectedPrincipalID,
              authority.principalKind == .agent,
              authority.roles.contains(where: { $0.rawValue == assignment.requiredRole }),
              satisfiesIndependence(
                  assignment.independenceConstraints,
                  authority: authority,
                  authorshipContext: authorshipContext
              ),
              !authorshipContext.authorActorIDs.contains(authority.actorID),
              !authorshipContext.authorPrincipalIDs.contains(authority.principalID),
              !authorshipContext.authorIndependentContextDigests.contains(
                  authority.independentContextDigest
              ),
              authorshipContext.runID == baseline.runID,
              authorshipContext.baselineDigest == baseline.digest,
              authorshipContext.roundID == baseline.roundID,
              authorshipContext.baselineEventHead == baseline.preCreationEventHead,
              authorshipContext.currentEventHead == currentness.currentEventHead,
              authorshipContext.currentArtifactSetDigest ==
                currentness.currentArtifactSetDigest,
              authorshipContext.authoredArtifactSetDigest ==
                currentness.currentArtifactSetDigest,
              persistedRun.state.runID == baseline.runID,
              persistedRun.state.canonSnapshotDigest == baseline.activeProfileDigest,
              persistedRun.eventHead == currentness.currentEventHead,
              persistedRun.events.last?.recordDigest == persistedRun.eventHead,
              currentness.matchesBaseline(baseline),
              currentness.matchesActiveCycle(persistedRun.state.reviewCycle)
        else { throw WorkflowPolicyError.invalidPolicy }

        let receiptBindings: [(ReceiptKind, ImmutableReceiptReference)] = try [
            (ReceiptKind(validating: "review-envelope-effect"), submission.envelope.effectReceipt),
            (ReceiptKind(validating: "review-envelope-domain"), submission.envelope.domainReceipt),
            (ReceiptKind(validating: "review-envelope-record"), submission.envelope.recordReceipt),
        ]
        let receiptDigests = try receiptBindings.map { kind, reference in
            try verifyEnvelopeReceipt(
                reference,
                kind: kind,
                submission: submission,
                baseline: baseline,
                authority: authority,
                persistedRun: persistedRun
            ).payloadDigest
        }
        let submissionDigest = try submission.canonicalDigest()
        return VerifiedReviewerInventoryAuthority(
            submissionDigest: submissionDigest,
            baselineDigest: baseline.digest,
            roundID: baseline.roundID,
            assignmentID: assignment.id,
            baselineEventHead: baseline.preCreationEventHead,
            currentEventHead: currentness.currentEventHead,
            currentArtifactSetDigest: currentness.currentArtifactSetDigest,
            envelopeReceiptDigests: receiptDigests.sorted(by: digestOrder),
            authorityContextDigest: authority.independentContextDigest,
            authorActorIDs: authorshipContext.authorActorIDs,
            authorPrincipalIDs: authorshipContext.authorPrincipalIDs,
            authorContextDigests: authorshipContext.authorIndependentContextDigests,
            authorshipProvenanceDigest: authorshipContext.authorshipProvenanceDigest
        )
    }

    public static func verifyDispositionEvidence(
        evidence: IssueDispositionEvidence,
        authority: VerifiedAuthorityFact,
        persistedRun: PersistedRun,
        policies: VerifiedReviewPolicySet
    ) throws -> VerifiedReviewDispositionEvidence {
        let claim = evidence.envelope.authority
        let kind: VerifiedDispositionAuthorityKind
        let requiredRole: AuthorityRole
        switch claim.claimedKind {
        case .kernel:
            guard authority.principalKind == .kernel else {
                throw WorkflowPolicyError.invalidDispositionEvidence
            }
            kind = .kernel
            requiredRole = .kernel
        case .human:
            guard authority.principalKind == .human else {
                throw WorkflowPolicyError.invalidDispositionEvidence
            }
            kind = .human
            requiredRole = .authenticatedUser
        case .agent:
            throw WorkflowPolicyError.invalidDispositionEvidence
        }

        let derivedAuthority = VerifiedDispositionAuthorityFact(
            actorID: authority.actorID,
            principalID: authority.principalID,
            kind: kind,
            authorityPolicyDigest: claim.authorityPolicyDigest,
            rationaleDigest: claim.rationaleDigest,
            evidenceReferences: claim.evidenceReferences
        )
        guard claim.claimedAuthenticated,
              evidence.fingerprint == evidence.envelope.issueFingerprint,
              evidence.verifiedAuthority == derivedAuthority,
              authority.actorID == claim.actorID,
              authority.principalID == claim.principalID,
              authority.roles.contains(requiredRole),
              !authority.hasAuthorshipEdge,
              !authority.hasSourceWriteCapability,
              claim.authorityPolicyDigest == policies.dispositionPolicy.digest,
              policies.dispositionPolicy.authorizedPrincipalIDs.contains(authority.principalID),
              persistedRun.state.runID == policies.runID,
              !claim.evidenceReferences.isEmpty
        else { throw WorkflowPolicyError.invalidDispositionEvidence }

        let expectedKind = try ReceiptKind(validating: "review-disposition-evidence")
        let committed = try claim.evidenceReferences.map {
            reference -> VerifiedPublishedReviewReceipt in
            let id = try ReceiptID(validating: reference)
            let receipt = try ReviewCommittedReceiptVerifier.verify(
                id: id,
                kind: expectedKind,
                in: persistedRun
            )
            let payload = try ReviewDispositionEvidenceReceiptPayload.decodeCanonical(
                from: receipt.payloadBytes
            )
            let expected = try ReviewDispositionEvidenceReceiptPayload(
                receiptID: id,
                evidence: evidence,
                authority: authority,
                runID: policies.runID,
                baselineDigest: policies.baselineDigest
            )
            guard payload == expected,
                  receipt.runID == policies.runID,
                  receipt.eventKind == .reviewInventoryRecorded,
                  receipt.producedEventHead == persistedRun.eventHead
            else { throw PersistenceError.integrityViolation }
            return receipt
        }
        guard committed.filter({ $0.payloadDigest == claim.rationaleDigest }).count == 1 else {
            throw WorkflowPolicyError.invalidDispositionEvidence
        }
        return VerifiedReviewDispositionEvidence(
            evidence: evidence,
            verifiedAuthority: derivedAuthority,
            baselineDigest: policies.baselineDigest,
            persistedEvidenceDigests: committed.map(\.payloadDigest).sorted(by: digestOrder)
        )
    }

    private static func satisfiesIndependence(
        _ constraints: [ReviewerIndependenceConstraint],
        authority: VerifiedAuthorityFact,
        authorshipContext: VerifiedReviewAuthorshipContext
    ) -> Bool {
        constraints.allSatisfy { constraint in
            switch constraint {
            case .distinctPrincipal:
                authority.principalKind == .agent &&
                    !authorshipContext.authorActorIDs.contains(authority.actorID) &&
                    !authorshipContext.authorPrincipalIDs.contains(authority.principalID) &&
                    !authorshipContext.authorIndependentContextDigests.contains(
                        authority.independentContextDigest
                    )
            case .noAuthorshipEdge:
                !authority.hasAuthorshipEdge
            case .noSourceWriteCapability:
                !authority.hasSourceWriteCapability
            }
        }
    }

    private static func verifyEnvelopeReceipt(
        _ reference: ImmutableReceiptReference,
        kind: ReceiptKind,
        submission: ReviewerFindingSubmission,
        baseline: ReviewBaseline,
        authority: VerifiedAuthorityFact,
        persistedRun: PersistedRun
    ) throws -> VerifiedPublishedReviewReceipt {
        let committed = try ReviewCommittedReceiptVerifier.verify(
            id: reference.id,
            kind: kind,
            digest: reference.digest,
            in: persistedRun
        )
        let payload = try ReviewEnvelopeReceiptPayload.decodeCanonical(
            from: committed.payloadBytes
        )
        let expected = try ReviewEnvelopeReceiptPayload(
            submission: submission,
            baseline: baseline,
            receiptID: reference.id,
            receiptKind: kind,
            independentContextDigest: authority.independentContextDigest
        )
        guard payload == expected,
              committed.runID == baseline.runID,
              committed.eventKind == .reviewInventoryRecorded,
              committed.producedEventHead == persistedRun.eventHead,
              committed.receipt.payloadBytes == committed.payloadBytes,
              committed.receipt.payloadDigest == committed.payloadDigest,
              committed.receipt.transactionID == committed.transactionID,
              committed.receipt.transactionDigest == committed.transactionDigest,
              committed.manifestEntry.kind == committed.kind,
              committed.manifestEntry.id == committed.id,
              committed.manifestEntry.payloadDigest == committed.payloadDigest,
              committed.owningRecord.transactionID == committed.transactionID,
              committed.owningRecord.transactionDigest == committed.transactionDigest,
              committed.owningRecord.receiptManifest.contains(committed.manifestEntry),
              committed.owningRecord.recordDigest == committed.producedEventHead,
              persistedRun.events.contains(where: {
                  $0.recordDigest == committed.owningRecord.recordDigest
              })
        else { throw PersistenceError.integrityViolation }
        return committed
    }
}

func canonicalReviewArtifacts<S: Sequence>(
    _ artifacts: S
) -> [ArtifactReference] where S.Element == ArtifactReference {
    artifacts.sorted { lhs, rhs in
        (lhs.id.rawValue, lhs.scope.kind.rawValue, lhs.scope.value, lhs.contentHash.rawValue) <
            (rhs.id.rawValue, rhs.scope.kind.rawValue, rhs.scope.value, rhs.contentHash.rawValue)
    }
}

func requirePersistedReceipt(
    _ reference: ImmutableReceiptReference,
    kind: ReceiptKind,
    in persistedRun: PersistedRun
) throws -> PersistedReceipt {
    try requirePersistedReceipt(id: reference.id, kind: kind, digest: reference.digest, in: persistedRun)
}

func requirePersistedReceipt(
    id: ReceiptID,
    kind: ReceiptKind,
    digest: HashDigest? = nil,
    in persistedRun: PersistedRun
) throws -> PersistedReceipt {
    let matches = persistedRun.receipts.filter { $0.kind == kind && $0.id == id }
    guard matches.count == 1, let receipt = matches.first,
          receipt.payloadDigest == CanonicalTreeDigest.sha256(receipt.payloadBytes),
          digest == nil || receipt.payloadDigest == digest
    else { throw PersistenceError.integrityViolation }
    return receipt
}

private func digestOrder(_ lhs: HashDigest, _ rhs: HashDigest) -> Bool {
    lhs.rawValue < rhs.rawValue
}

#if DEBUG
enum ReviewCapabilityTestFactory {
    static func verifyCurrentness(
        baseline: ReviewBaseline,
        currentArtifacts: [ArtifactReference],
        currentEventHead: HashDigest
    ) throws -> VerifiedReviewScopeCurrentness {
        let canonical = canonicalReviewArtifacts(currentArtifacts)
        guard !canonical.isEmpty,
              Set(canonical.map(\.id)).count == canonical.count,
              canonical == baseline.artifactScopes
        else { throw WorkflowPolicyError.invalidPolicy }
        return VerifiedReviewScopeCurrentness(
            runID: baseline.runID,
            baselineDigest: baseline.digest,
            cycleID: baseline.cycleID,
            gate: baseline.gate,
            roundID: baseline.roundID,
            roundKind: baseline.kind,
            semanticOrdinal: baseline.semanticOrdinal,
            roundAnchorEventHead: baseline.preCreationEventHead,
            predecessorBaselineDigest: baseline.predecessorBaselineDigest,
            currentArtifacts: canonical,
            currentGraphDigest: CanonicalTreeDigest.sha256(
                try CanonicalJSON.encode(canonical)
            ),
            currentArtifactSetDigest: CanonicalTreeDigest.sha256(
                try CanonicalJSON.encode(canonical)
            ),
            currentEventHead: currentEventHead
        )
    }

    static func verifyReceiptAuthority(
        persistedRun: PersistedRun,
        currentness: VerifiedReviewScopeCurrentness,
        policies: VerifiedReviewPolicySet,
        approvalRecords: [ApprovalRecord]
    ) throws -> VerifiedReviewReceiptAuthority {
        let attestations = try approvalRecords.map { record -> VerifiedApprovalAttestation in
            let recordBytes = try CanonicalJSON.encode(record)
            let recordDigest = CanonicalTreeDigest.sha256(recordBytes)
            let authenticatedEventDigest = CanonicalTreeDigest.sha256(
                recordBytes + Data("/authenticated-event".utf8)
            )
            let signatureDigest = CanonicalTreeDigest.sha256(
                recordBytes + Data("/signature".utf8)
            )
            let trustPolicyDigest = CanonicalTreeDigest.sha256(
                Data("review-approval-test-trust-policy-v1".utf8)
            )
            let capabilities = try ApprovalAttestationTestCapabilities.make(
                recordDigest: recordDigest,
                authenticatedEventDigest: authenticatedEventDigest,
                signatureDigest: signatureDigest,
                trustPolicyDigest: trustPolicyDigest
            )
            return try ApprovalAttestationVerifier.verify(
                record: record,
                authenticatedEvent: capabilities.authenticatedEvent,
                signature: capabilities.signature,
                trustPolicy: capabilities.trustPolicy
            )
        }
        let set = try ReviewApprovalSetVerifier.verify(
            records: approvalRecords,
            attestations: attestations,
            currentness: currentness,
            policies: policies
        )
        return try ReviewReceiptAuthorityVerifier.verify(
            persistedRun: persistedRun,
            currentness: currentness,
            policies: policies,
            approvalSet: set
        )
    }
}
#endif
