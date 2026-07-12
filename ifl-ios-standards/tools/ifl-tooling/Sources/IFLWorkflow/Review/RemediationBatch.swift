import Foundation
import IFLContracts

public enum RemediationEvidenceKind: String, Codable, CaseIterable, Hashable, Sendable {
    case command
    case staticAnalysis = "static_analysis"
    case review

    fileprivate var order: Int {
        switch self {
        case .command: 0
        case .staticAnalysis: 1
        case .review: 2
        }
    }
}

public struct RemediationEvidence: Codable, Hashable, Sendable {
    public let kind: RemediationEvidenceKind
    public let receipt: ImmutableReceiptReference
    public let publicationAnchorEventHead: HashDigest

    public init(
        kind: RemediationEvidenceKind,
        receipt: ImmutableReceiptReference,
        publicationAnchorEventHead: HashDigest
    ) throws {
        self.kind = kind
        self.receipt = receipt
        self.publicationAnchorEventHead = publicationAnchorEventHead
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            kind: values.decode(RemediationEvidenceKind.self, forKey: .kind),
            receipt: values.decode(ImmutableReceiptReference.self, forKey: .receipt),
            publicationAnchorEventHead: values.decode(
                HashDigest.self,
                forKey: .publicationAnchorEventHead
            )
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case receipt
        case publicationAnchorEventHead = "publication_anchor_event_head"
    }
}

/// Canonical planned evidence projection for one remediation proof.
/// The anchor is H_before consumed by the single atomic remediation publication, never H_after.
public struct ReviewRemediationEvidencePayload: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let receiptID: ReceiptID
    public let receiptKind: ReceiptKind
    public let runID: RunID
    public let sourceBaselineDigest: HashDigest
    public let sourceRegisterDigest: HashDigest
    public let fingerprint: IssueFingerprint
    public let preChangeArtifact: ArtifactReference
    public let postChangeArtifact: ArtifactReference
    public let evidenceKind: RemediationEvidenceKind
    public let implementingActorID: ActorID
    public let implementingPrincipalID: PrincipalID
    public let implementingContextDigest: HashDigest
    public let implementationAuthorityDigest: HashDigest
    public let publicationAnchorEventHead: HashDigest
    public let proofDigest: HashDigest

    public init(
        receiptID: ReceiptID,
        receiptKind: ReceiptKind,
        runID: RunID,
        sourceBaselineDigest: HashDigest,
        sourceRegisterDigest: HashDigest,
        fingerprint: IssueFingerprint,
        preChangeArtifact: ArtifactReference,
        postChangeArtifact: ArtifactReference,
        evidenceKind: RemediationEvidenceKind,
        implementingActorID: ActorID,
        implementingPrincipalID: PrincipalID,
        implementingContextDigest: HashDigest,
        implementationAuthorityDigest: HashDigest,
        publicationAnchorEventHead: HashDigest
    ) throws {
        guard receiptKind == (try remediationReceiptKind(evidenceKind)),
              preChangeArtifact.id == postChangeArtifact.id,
              preChangeArtifact.type == postChangeArtifact.type,
              preChangeArtifact.scope == postChangeArtifact.scope,
              preChangeArtifact.contentHash != postChangeArtifact.contentHash
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
        schemaVersion = 1
        self.receiptID = receiptID
        self.receiptKind = receiptKind
        self.runID = runID
        self.sourceBaselineDigest = sourceBaselineDigest
        self.sourceRegisterDigest = sourceRegisterDigest
        self.fingerprint = fingerprint
        self.preChangeArtifact = preChangeArtifact
        self.postChangeArtifact = postChangeArtifact
        self.evidenceKind = evidenceKind
        self.implementingActorID = implementingActorID
        self.implementingPrincipalID = implementingPrincipalID
        self.implementingContextDigest = implementingContextDigest
        self.implementationAuthorityDigest = implementationAuthorityDigest
        self.publicationAnchorEventHead = publicationAnchorEventHead
        proofDigest = try Self.deriveProofDigest(
            runID: runID,
            sourceBaselineDigest: sourceBaselineDigest,
            sourceRegisterDigest: sourceRegisterDigest,
            fingerprint: fingerprint,
            preChangeArtifact: preChangeArtifact,
            postChangeArtifact: postChangeArtifact,
            evidenceKind: evidenceKind,
            implementingActorID: implementingActorID,
            implementingPrincipalID: implementingPrincipalID,
            implementingContextDigest: implementingContextDigest,
            implementationAuthorityDigest: implementationAuthorityDigest,
            publicationAnchorEventHead: publicationAnchorEventHead
        )
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 1 else {
            throw WorkflowPolicyError.invalidDispositionEvidence
        }
        let claimedProofDigest = try values.decode(HashDigest.self, forKey: .proofDigest)
        let candidate = try Self(
            receiptID: values.decode(ReceiptID.self, forKey: .receiptID),
            receiptKind: values.decode(ReceiptKind.self, forKey: .receiptKind),
            runID: values.decode(RunID.self, forKey: .runID),
            sourceBaselineDigest: values.decode(
                HashDigest.self,
                forKey: .sourceBaselineDigest
            ),
            sourceRegisterDigest: values.decode(
                HashDigest.self,
                forKey: .sourceRegisterDigest
            ),
            fingerprint: values.decode(IssueFingerprint.self, forKey: .fingerprint),
            preChangeArtifact: values.decode(
                ArtifactReference.self,
                forKey: .preChangeArtifact
            ),
            postChangeArtifact: values.decode(
                ArtifactReference.self,
                forKey: .postChangeArtifact
            ),
            evidenceKind: values.decode(RemediationEvidenceKind.self, forKey: .evidenceKind),
            implementingActorID: values.decode(ActorID.self, forKey: .implementingActorID),
            implementingPrincipalID: values.decode(
                PrincipalID.self,
                forKey: .implementingPrincipalID
            ),
            implementingContextDigest: values.decode(
                HashDigest.self,
                forKey: .implementingContextDigest
            ),
            implementationAuthorityDigest: values.decode(
                HashDigest.self,
                forKey: .implementationAuthorityDigest
            ),
            publicationAnchorEventHead: values.decode(
                HashDigest.self,
                forKey: .publicationAnchorEventHead
            )
        )
        guard claimedProofDigest == candidate.proofDigest else {
            throw WorkflowPolicyError.invalidDispositionEvidence
        }
        self = candidate
    }

    public static func decodeCanonical(
        from bytes: Data
    ) throws -> ReviewRemediationEvidencePayload {
        try artifactDecodeCanonical(Self.self, from: bytes)
    }

    private static func deriveProofDigest(
        runID: RunID,
        sourceBaselineDigest: HashDigest,
        sourceRegisterDigest: HashDigest,
        fingerprint: IssueFingerprint,
        preChangeArtifact: ArtifactReference,
        postChangeArtifact: ArtifactReference,
        evidenceKind: RemediationEvidenceKind,
        implementingActorID: ActorID,
        implementingPrincipalID: PrincipalID,
        implementingContextDigest: HashDigest,
        implementationAuthorityDigest: HashDigest,
        publicationAnchorEventHead: HashDigest
    ) throws -> HashDigest {
        CanonicalTreeDigest.sha256(try CanonicalJSON.encode(
            ReviewRemediationEvidenceProofPreimage(
                domain: "ReviewRemediationEvidenceProof/v1",
                schemaVersion: 1,
                runID: runID,
                sourceBaselineDigest: sourceBaselineDigest,
                sourceRegisterDigest: sourceRegisterDigest,
                fingerprint: fingerprint,
                preChangeArtifact: preChangeArtifact,
                postChangeArtifact: postChangeArtifact,
                evidenceKind: evidenceKind,
                implementingActorID: implementingActorID,
                implementingPrincipalID: implementingPrincipalID,
                implementingContextDigest: implementingContextDigest,
                implementationAuthorityDigest: implementationAuthorityDigest,
                publicationAnchorEventHead: publicationAnchorEventHead
            )
        ))
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case receiptID = "receipt_id"
        case receiptKind = "receipt_kind"
        case runID = "run_id"
        case sourceBaselineDigest = "source_baseline_digest"
        case sourceRegisterDigest = "source_register_digest"
        case fingerprint
        case preChangeArtifact = "pre_change_artifact"
        case postChangeArtifact = "post_change_artifact"
        case evidenceKind = "evidence_kind"
        case implementingActorID = "implementing_actor_id"
        case implementingPrincipalID = "implementing_principal_id"
        case implementingContextDigest = "implementing_context_digest"
        case implementationAuthorityDigest = "implementation_authority_digest"
        case publicationAnchorEventHead = "publication_anchor_event_head"
        case proofDigest = "proof_digest"
    }
}

private struct ReviewRemediationEvidenceProofPreimage: Codable {
    let domain: String
    let schemaVersion: Int
    let runID: RunID
    let sourceBaselineDigest: HashDigest
    let sourceRegisterDigest: HashDigest
    let fingerprint: IssueFingerprint
    let preChangeArtifact: ArtifactReference
    let postChangeArtifact: ArtifactReference
    let evidenceKind: RemediationEvidenceKind
    let implementingActorID: ActorID
    let implementingPrincipalID: PrincipalID
    let implementingContextDigest: HashDigest
    let implementationAuthorityDigest: HashDigest
    let publicationAnchorEventHead: HashDigest

    enum CodingKeys: String, CodingKey {
        case domain
        case schemaVersion = "schema_version"
        case runID = "run_id"
        case sourceBaselineDigest = "source_baseline_digest"
        case sourceRegisterDigest = "source_register_digest"
        case fingerprint
        case preChangeArtifact = "pre_change_artifact"
        case postChangeArtifact = "post_change_artifact"
        case evidenceKind = "evidence_kind"
        case implementingActorID = "implementing_actor_id"
        case implementingPrincipalID = "implementing_principal_id"
        case implementingContextDigest = "implementing_context_digest"
        case implementationAuthorityDigest = "implementation_authority_digest"
        case publicationAnchorEventHead = "publication_anchor_event_head"
    }
}

public struct RemediationArtifactTransitionBinding: Codable, Hashable, Sendable {
    public let preChangeArtifact: ArtifactReference
    public let postChangeArtifact: ArtifactReference

    init(preChangeArtifact: ArtifactReference, postChangeArtifact: ArtifactReference) throws {
        guard preChangeArtifact.id == postChangeArtifact.id,
              preChangeArtifact.type == postChangeArtifact.type,
              preChangeArtifact.scope == postChangeArtifact.scope,
              preChangeArtifact.contentHash != postChangeArtifact.contentHash
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
        self.preChangeArtifact = preChangeArtifact
        self.postChangeArtifact = postChangeArtifact
    }

    enum CodingKeys: String, CodingKey {
        case preChangeArtifact = "pre_change_artifact"
        case postChangeArtifact = "post_change_artifact"
    }
}

/// H_before-bound scope for planning one remediation publication while the source round is active.
public struct VerifiedReviewRemediationPlanningContext: Hashable, Sendable {
    public let runID: RunID
    public let cycleID: ReviewCycleID
    public let gate: ReviewGateKind
    public let sourceRoundID: ReviewRoundID
    public let sourceRoundKind: ReviewRoundKind
    public let sourceSemanticOrdinal: UInt64
    public let sourceBaselineDigest: HashDigest
    public let sourceRegisterDigest: HashDigest
    public let successorRoundID: ReviewRoundID
    public let successorRoundKind: ReviewRoundKind
    public let successorSemanticOrdinal: UInt64
    public let successorBaselineDigest: HashDigest
    public let publicationAnchorEventHead: HashDigest
    public let sourceArtifactSetDigest: HashDigest
    public let currentArtifactSetDigest: HashDigest
    public let planningProvenanceDigest: HashDigest
    let sourceArtifacts: [ArtifactReference]
    let currentArtifacts: [ArtifactReference]

    init(
        sourceRegister: VerifiedIssueRegister,
        successorBaseline: ReviewBaseline,
        publicationAnchorEventHead: HashDigest
    ) throws {
        let source = sourceRegister.baseline
        let sourceArtifacts = canonicalReviewArtifacts(source.artifactScopes)
        let currentArtifacts = canonicalReviewArtifacts(successorBaseline.artifactScopes)
        let preimage = ReviewRemediationPlanningPreimage(
            domain: "ReviewRemediationPlanning/v1",
            runID: source.runID,
            cycleID: source.cycleID,
            gate: source.gate,
            sourceRoundID: source.roundID,
            sourceRoundKind: source.kind,
            sourceSemanticOrdinal: source.semanticOrdinal,
            sourceBaselineDigest: source.digest,
            sourceRegisterDigest: sourceRegister.register.digest,
            successorRoundID: successorBaseline.roundID,
            successorRoundKind: successorBaseline.kind,
            successorSemanticOrdinal: successorBaseline.semanticOrdinal,
            successorBaselineDigest: successorBaseline.digest,
            publicationAnchorEventHead: publicationAnchorEventHead,
            sourceArtifacts: sourceArtifacts,
            currentArtifacts: currentArtifacts
        )
        runID = source.runID
        cycleID = source.cycleID
        gate = source.gate
        sourceRoundID = source.roundID
        sourceRoundKind = source.kind
        sourceSemanticOrdinal = source.semanticOrdinal
        sourceBaselineDigest = source.digest
        sourceRegisterDigest = sourceRegister.register.digest
        successorRoundID = successorBaseline.roundID
        successorRoundKind = successorBaseline.kind
        successorSemanticOrdinal = successorBaseline.semanticOrdinal
        successorBaselineDigest = successorBaseline.digest
        self.publicationAnchorEventHead = publicationAnchorEventHead
        sourceArtifactSetDigest = CanonicalTreeDigest.sha256(
            try CanonicalJSON.encode(sourceArtifacts)
        )
        currentArtifactSetDigest = CanonicalTreeDigest.sha256(
            try CanonicalJSON.encode(currentArtifacts)
        )
        planningProvenanceDigest = CanonicalTreeDigest.sha256(try CanonicalJSON.encode(preimage))
        self.sourceArtifacts = sourceArtifacts
        self.currentArtifacts = currentArtifacts
    }
}

private struct ReviewRemediationPlanningPreimage: Codable {
    let domain: String
    let runID: RunID
    let cycleID: ReviewCycleID
    let gate: ReviewGateKind
    let sourceRoundID: ReviewRoundID
    let sourceRoundKind: ReviewRoundKind
    let sourceSemanticOrdinal: UInt64
    let sourceBaselineDigest: HashDigest
    let sourceRegisterDigest: HashDigest
    let successorRoundID: ReviewRoundID
    let successorRoundKind: ReviewRoundKind
    let successorSemanticOrdinal: UInt64
    let successorBaselineDigest: HashDigest
    let publicationAnchorEventHead: HashDigest
    let sourceArtifacts: [ArtifactReference]
    let currentArtifacts: [ArtifactReference]

    enum CodingKeys: String, CodingKey {
        case domain
        case runID = "run_id"
        case cycleID = "cycle_id"
        case gate
        case sourceRoundID = "source_round_id"
        case sourceRoundKind = "source_round_kind"
        case sourceSemanticOrdinal = "source_semantic_ordinal"
        case sourceBaselineDigest = "source_baseline_digest"
        case sourceRegisterDigest = "source_register_digest"
        case successorRoundID = "successor_round_id"
        case successorRoundKind = "successor_round_kind"
        case successorSemanticOrdinal = "successor_semantic_ordinal"
        case successorBaselineDigest = "successor_baseline_digest"
        case publicationAnchorEventHead = "publication_anchor_event_head"
        case sourceArtifacts = "source_artifacts"
        case currentArtifacts = "current_artifacts"
    }
}

public enum ReviewRemediationPlanningVerifier {
    public static func verify(
        sourceRegister: VerifiedIssueRegister,
        successorBaseline: ReviewBaseline,
        currentGraph: ArtifactGraph,
        persistedRun: PersistedRun
    ) throws -> VerifiedReviewRemediationPlanningContext {
        try ReviewCommittedReceiptVerifier.validateActiveChain(persistedRun)
        let source = sourceRegister.baseline
        let cycle = persistedRun.state.reviewCycle
        let stateBytes = try CanonicalJSON.encode(persistedRun.state)
        guard try hasValidRemediationSuccessor(
            source: source,
            successor: successorBaseline,
            publicationAnchorEventHead: persistedRun.eventHead
        ),
            sourceRegister.register.pathDecision == .requiresRemediation,
            !sourceRegister.register.acceptedCurrentScopeAssignments.isEmpty,
            canonicalReviewArtifacts(currentGraph.artifacts) == successorBaseline.artifactScopes,
            persistedRun.state.runID == source.runID,
            persistedRun.state.canonSnapshotDigest == source.activeProfileDigest,
            persistedRun.stateBytes == stateBytes,
            persistedRun.stateDigest == CanonicalTreeDigest.sha256(stateBytes),
            persistedRun.events.last?.recordDigest == persistedRun.eventHead,
            cycle?.id == source.cycleID,
            cycle?.gate == source.gate,
            cycle?.currentRoundID == source.roundID,
            cycle?.currentRoundKind == source.kind,
            cycle?.currentSemanticOrdinal == source.semanticOrdinal,
            cycle?.currentRoundAnchorEventHead == source.preCreationEventHead,
            cycle?.predecessorBaselineDigest == source.predecessorBaselineDigest,
            cycle?.phase == .awaitingRemediation,
            cycle?.hasVerifiedCurrentRoundClosure == true,
            cycle?.closedBaselineDigest == source.digest,
            cycle?.closedRegisterDigest == sourceRegister.register.digest,
            cycle?.closedPathDecision == .requiresRemediation,
            cycle?.lastRemediatedRoundID != source.roundID
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
        return try VerifiedReviewRemediationPlanningContext(
            sourceRegister: sourceRegister,
            successorBaseline: successorBaseline,
            publicationAnchorEventHead: persistedRun.eventHead
        )
    }
}

/// Authenticated implementation authority sealed to the exact before/after artifact set.
public struct VerifiedReviewImplementationAuthority: Hashable, Sendable {
    public let runID: RunID
    public let sourceBaselineDigest: HashDigest
    public let sourceRegisterDigest: HashDigest
    public let successorBaselineDigest: HashDigest
    public let publicationAnchorEventHead: HashDigest
    public let implementingActorID: ActorID
    public let implementingPrincipalID: PrincipalID
    public let implementingContextDigest: HashDigest
    public let artifactTransitions: [RemediationArtifactTransitionBinding]
    public let provenanceDigest: HashDigest
    let identity: ScopedReviewAuthorityIdentity

    init(
        authority: VerifiedAuthorityFact,
        planning: VerifiedReviewRemediationPlanningContext,
        artifactTransitions: [RemediationArtifactTransitionBinding],
        provenanceDigest: HashDigest
    ) {
        runID = planning.runID
        sourceBaselineDigest = planning.sourceBaselineDigest
        sourceRegisterDigest = planning.sourceRegisterDigest
        successorBaselineDigest = planning.successorBaselineDigest
        publicationAnchorEventHead = planning.publicationAnchorEventHead
        implementingActorID = authority.actorID
        implementingPrincipalID = authority.principalID
        implementingContextDigest = authority.independentContextDigest
        self.artifactTransitions = artifactTransitions
        self.provenanceDigest = provenanceDigest
        identity = ScopedReviewAuthorityIdentity(authority)
    }
}

private struct ReviewImplementationAuthorityPreimage: Codable {
    let domain: String
    let planningProvenanceDigest: HashDigest
    let authority: ScopedReviewAuthorityIdentity
    let artifactTransitions: [RemediationArtifactTransitionBinding]

    enum CodingKeys: String, CodingKey {
        case domain
        case planningProvenanceDigest = "planning_provenance_digest"
        case authority
        case artifactTransitions = "artifact_transitions"
    }
}

public enum ReviewImplementationAuthorityVerifier {
    public static func verify(
        authority: VerifiedAuthorityFact,
        planning: VerifiedReviewRemediationPlanningContext
    ) throws -> VerifiedReviewImplementationAuthority {
        let before = Dictionary(uniqueKeysWithValues: planning.sourceArtifacts.map { ($0.id, $0) })
        let after = Dictionary(uniqueKeysWithValues: planning.currentArtifacts.map { ($0.id, $0) })
        guard Set(before.keys) == Set(after.keys),
              authority.principalKind == .agent || authority.principalKind == .kernel,
              authority.roles.contains(.author),
              authority.hasAuthorshipEdge,
              authority.hasSourceWriteCapability
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
        let transitions = try before.keys.sorted().compactMap { id -> RemediationArtifactTransitionBinding? in
            guard let pre = before[id], let post = after[id] else {
                throw WorkflowPolicyError.invalidDispositionEvidence
            }
            guard pre != post else { return nil }
            return try RemediationArtifactTransitionBinding(
                preChangeArtifact: pre,
                postChangeArtifact: post
            )
        }
        guard !transitions.isEmpty else { throw WorkflowPolicyError.invalidDispositionEvidence }
        let identity = ScopedReviewAuthorityIdentity(authority)
        let provenanceDigest = CanonicalTreeDigest.sha256(try CanonicalJSON.encode(
            ReviewImplementationAuthorityPreimage(
                domain: "ReviewImplementationAuthority/v1",
                planningProvenanceDigest: planning.planningProvenanceDigest,
                authority: identity,
                artifactTransitions: transitions
            )
        ))
        return VerifiedReviewImplementationAuthority(
            authority: authority,
            planning: planning,
            artifactTransitions: transitions,
            provenanceDigest: provenanceDigest
        )
    }
}

public struct VerifiedPlannedRemediationEvidence: Hashable, Sendable {
    public let fingerprint: IssueFingerprint
    public let evidence: RemediationEvidence
    public let payload: ReviewRemediationEvidencePayload
    public let payloadBytes: Data
    public let payloadDigest: HashDigest

    init(
        fingerprint: IssueFingerprint,
        evidence: RemediationEvidence,
        payload: ReviewRemediationEvidencePayload,
        payloadBytes: Data
    ) {
        self.fingerprint = fingerprint
        self.evidence = evidence
        self.payload = payload
        self.payloadBytes = payloadBytes
        payloadDigest = CanonicalTreeDigest.sha256(payloadBytes)
    }
}

public enum ReviewRemediationEvidencePlanner {
    public static func plan(
        receiptID: ReceiptID,
        kind: RemediationEvidenceKind,
        fingerprint: IssueFingerprint,
        preChangeArtifact: ArtifactReference,
        postChangeArtifact: ArtifactReference,
        sourceRegister: VerifiedIssueRegister,
        implementationAuthority: VerifiedReviewImplementationAuthority
    ) throws -> VerifiedPlannedRemediationEvidence {
        let components = try sourceRegister.components(for: fingerprint.failureFingerprint)
        let transition = try RemediationArtifactTransitionBinding(
            preChangeArtifact: preChangeArtifact,
            postChangeArtifact: postChangeArtifact
        )
        guard implementationAuthority.sourceBaselineDigest == sourceRegister.baseline.digest,
              implementationAuthority.sourceRegisterDigest == sourceRegister.register.digest,
              sourceRegister.register.acceptedCurrentScopeAssignments.contains(
                  fingerprint.failureFingerprint
              ),
              components.artifactID == preChangeArtifact.id,
              components.scopeSelector == preChangeArtifact.scope,
              implementationAuthority.artifactTransitions.contains(transition)
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
        let payload = try ReviewRemediationEvidencePayload(
            receiptID: receiptID,
            receiptKind: remediationReceiptKind(kind),
            runID: implementationAuthority.runID,
            sourceBaselineDigest: implementationAuthority.sourceBaselineDigest,
            sourceRegisterDigest: implementationAuthority.sourceRegisterDigest,
            fingerprint: fingerprint,
            preChangeArtifact: preChangeArtifact,
            postChangeArtifact: postChangeArtifact,
            evidenceKind: kind,
            implementingActorID: implementationAuthority.implementingActorID,
            implementingPrincipalID: implementationAuthority.implementingPrincipalID,
            implementingContextDigest: implementationAuthority.implementingContextDigest,
            implementationAuthorityDigest: implementationAuthority.provenanceDigest,
            publicationAnchorEventHead: implementationAuthority.publicationAnchorEventHead
        )
        let bytes = try CanonicalJSON.encode(payload)
        let reference = ImmutableReceiptReference(
            id: receiptID,
            digest: CanonicalTreeDigest.sha256(bytes)
        )
        return VerifiedPlannedRemediationEvidence(
            fingerprint: fingerprint,
            evidence: try RemediationEvidence(
                kind: kind,
                receipt: reference,
                publicationAnchorEventHead: implementationAuthority.publicationAnchorEventHead
            ),
            payload: payload,
            payloadBytes: bytes
        )
    }
}

public struct RemediationChange: Codable, Hashable, Sendable {
    public let fingerprint: IssueFingerprint
    public let preChangeArtifact: ArtifactReference
    public let postChangeArtifact: ArtifactReference
    public let evidence: [RemediationEvidence]

    public init(
        fingerprint: IssueFingerprint,
        preChangeArtifact: ArtifactReference,
        postChangeArtifact: ArtifactReference,
        evidence: [RemediationEvidence]
    ) throws {
        let sorted = evidence.sorted { $0.kind.order < $1.kind.order }
        guard preChangeArtifact.id == postChangeArtifact.id,
              preChangeArtifact.type == postChangeArtifact.type,
              preChangeArtifact.scope == postChangeArtifact.scope,
              preChangeArtifact.contentHash != postChangeArtifact.contentHash,
              Set(sorted.map(\.kind)).count == sorted.count
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
        self.fingerprint = fingerprint
        self.preChangeArtifact = preChangeArtifact
        self.postChangeArtifact = postChangeArtifact
        self.evidence = sorted
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let decodedEvidence = try values.decode([RemediationEvidence].self, forKey: .evidence)
        try self.init(
            fingerprint: values.decode(IssueFingerprint.self, forKey: .fingerprint),
            preChangeArtifact: values.decode(ArtifactReference.self, forKey: .preChangeArtifact),
            postChangeArtifact: values.decode(ArtifactReference.self, forKey: .postChangeArtifact),
            evidence: decodedEvidence
        )
        guard decodedEvidence == evidence else {
            throw WorkflowPolicyError.invalidDispositionEvidence
        }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case fingerprint
        case preChangeArtifact = "pre_change_artifact"
        case postChangeArtifact = "post_change_artifact"
        case evidence
    }
}

public struct RemediationResolvedTransition: Codable, Hashable, Sendable {
    public let fingerprint: FailureFingerprint
    public let previous: IssueDispositionKind
    public let current: IssueDispositionKind
    public let implementingActorID: ActorID
    public let evidenceDigests: [HashDigest]
    public let publicationAnchorEventHead: HashDigest

    init(
        fingerprint: FailureFingerprint,
        implementingActorID: ActorID,
        evidenceDigests: [HashDigest],
        publicationAnchorEventHead: HashDigest
    ) {
        self.fingerprint = fingerprint
        previous = .acceptedCurrentScope
        current = .resolved
        self.implementingActorID = implementingActorID
        self.evidenceDigests = evidenceDigests.sorted { $0.rawValue < $1.rawValue }
        self.publicationAnchorEventHead = publicationAnchorEventHead
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        fingerprint = try values.decode(FailureFingerprint.self, forKey: .fingerprint)
        previous = try values.decode(IssueDispositionKind.self, forKey: .previous)
        current = try values.decode(IssueDispositionKind.self, forKey: .current)
        implementingActorID = try values.decode(ActorID.self, forKey: .implementingActorID)
        evidenceDigests = try values.decode([HashDigest].self, forKey: .evidenceDigests)
        publicationAnchorEventHead = try values.decode(
            HashDigest.self,
            forKey: .publicationAnchorEventHead
        )
        guard previous == .acceptedCurrentScope,
              current == .resolved,
              !evidenceDigests.isEmpty,
              evidenceDigests == evidenceDigests.sorted(by: remediationDigestOrder),
              Set(evidenceDigests).count == evidenceDigests.count
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case fingerprint
        case previous
        case current
        case implementingActorID = "implementing_actor_id"
        case evidenceDigests = "evidence_digests"
        case publicationAnchorEventHead = "publication_anchor_event_head"
    }
}

public struct RemediationBatch: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let sourceRegisterDigest: HashDigest
    public let sourceBaselineDigest: HashDigest
    public let assignedFingerprints: [FailureFingerprint]
    public let changes: [RemediationChange]
    public let implementingActorID: ActorID
    public let resolvedTransitions: [RemediationResolvedTransition]
    public let successorBaselineDigest: HashDigest
    public let digest: HashDigest

    private init(payload: RemediationBatchPayload, digest: HashDigest) {
        schemaVersion = payload.schemaVersion
        sourceRegisterDigest = payload.sourceRegisterDigest
        sourceBaselineDigest = payload.sourceBaselineDigest
        assignedFingerprints = payload.assignedFingerprints
        changes = payload.changes
        implementingActorID = payload.implementingActorID
        resolvedTransitions = payload.resolvedTransitions
        successorBaselineDigest = payload.successorBaselineDigest
        self.digest = digest
    }

    static func issue(
        sourceRegister: IssueRegister,
        sourceBaseline: ReviewBaseline,
        changes: [RemediationChange],
        implementingActorID: ActorID,
        successorBaseline: ReviewBaseline,
        publicationAnchorEventHead: HashDigest
    ) throws -> RemediationBatch {
        let sortedChanges = changes.sorted { $0.fingerprint < $1.fingerprint }
        let assigned = sourceRegister.acceptedCurrentScopeAssignments.sorted {
            $0.rawValue < $1.rawValue
        }
        let changedFingerprints = sortedChanges.map { $0.fingerprint.failureFingerprint }
        let requiredEvidence = Set(RemediationEvidenceKind.allCases)
        let evidenceIDs = sortedChanges.flatMap { $0.evidence.map(\.receipt.id) }
        let expectedSuccessorArtifacts = try applying(
            sortedChanges,
            to: sourceBaseline.artifactScopes
        )
        guard sourceRegister.baselineDigest == sourceBaseline.digest,
              sourceRegister.roundID == sourceBaseline.roundID,
              sourceRegister.rosterDigest == sourceBaseline.rosterDigest,
              sourceRegister.pathDecision == .requiresRemediation,
              !assigned.isEmpty,
              changedFingerprints == assigned,
              Set(changedFingerprints).count == changedFingerprints.count,
              Set(evidenceIDs).count == evidenceIDs.count,
              sortedChanges.allSatisfy({ change in
                  Set(change.evidence.map(\.kind)) == requiredEvidence &&
                      change.evidence.allSatisfy({
                          $0.publicationAnchorEventHead == publicationAnchorEventHead
                      }) &&
                      sourceBaseline.artifactScopes.contains(change.preChangeArtifact) &&
                      successorBaseline.artifactScopes.contains(change.postChangeArtifact)
              }),
              try hasValidRemediationSuccessor(
                  source: sourceBaseline,
                  successor: successorBaseline,
                  publicationAnchorEventHead: publicationAnchorEventHead
              ),
              successorBaseline.artifactScopes == expectedSuccessorArtifacts
        else { throw WorkflowPolicyError.invalidDispositionEvidence }

        let transitions = sortedChanges.map { change in
            RemediationResolvedTransition(
                fingerprint: change.fingerprint.failureFingerprint,
                implementingActorID: implementingActorID,
                evidenceDigests: change.evidence.map(\.receipt.digest),
                publicationAnchorEventHead: publicationAnchorEventHead
            )
        }
        let payload = RemediationBatchPayload(
            schemaVersion: 1,
            sourceRegisterDigest: sourceRegister.digest,
            sourceBaselineDigest: sourceBaseline.digest,
            assignedFingerprints: assigned,
            changes: sortedChanges,
            implementingActorID: implementingActorID,
            resolvedTransitions: transitions,
            successorBaselineDigest: successorBaseline.digest
        )
        return RemediationBatch(
            payload: payload,
            digest: CanonicalTreeDigest.sha256(try CanonicalJSON.encode(payload))
        )
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 1 else {
            throw WorkflowPolicyError.invalidDispositionEvidence
        }
        let payload = try RemediationBatchPayload(
            schemaVersion: 1,
            sourceRegisterDigest: values.decode(HashDigest.self, forKey: .sourceRegisterDigest),
            sourceBaselineDigest: values.decode(HashDigest.self, forKey: .sourceBaselineDigest),
            assignedFingerprints: values.decode([FailureFingerprint].self, forKey: .assignedFingerprints),
            changes: values.decode([RemediationChange].self, forKey: .changes),
            implementingActorID: values.decode(ActorID.self, forKey: .implementingActorID),
            resolvedTransitions: values.decode(
                [RemediationResolvedTransition].self,
                forKey: .resolvedTransitions
            ),
            successorBaselineDigest: values.decode(HashDigest.self, forKey: .successorBaselineDigest)
        )
        let decodedDigest = try values.decode(HashDigest.self, forKey: .digest)
        let changeFingerprints = payload.changes.map { $0.fingerprint.failureFingerprint }
        let transitionFingerprints = payload.resolvedTransitions.map(\.fingerprint)
        let requiredEvidence = Set(RemediationEvidenceKind.allCases)
        let evidence = payload.changes.flatMap(\.evidence)
        let anchors = Set(evidence.map(\.publicationAnchorEventHead))
        let evidenceIDs = evidence.map(\.receipt.id)
        guard !payload.assignedFingerprints.isEmpty,
              payload.assignedFingerprints == payload.assignedFingerprints.sorted(by: {
                  $0.rawValue < $1.rawValue
              }),
              Set(payload.assignedFingerprints).count == payload.assignedFingerprints.count,
              changeFingerprints == payload.assignedFingerprints,
              transitionFingerprints == payload.assignedFingerprints,
              anchors.count == 1,
              Set(evidenceIDs).count == evidenceIDs.count,
              payload.changes.allSatisfy({
                  Set($0.evidence.map(\.kind)) == requiredEvidence
              }),
              payload.resolvedTransitions.allSatisfy({
                  $0.previous == .acceptedCurrentScope &&
                      $0.current == .resolved &&
                      $0.implementingActorID == payload.implementingActorID &&
                      anchors.contains($0.publicationAnchorEventHead)
              }),
              zip(payload.changes, payload.resolvedTransitions).allSatisfy({ change, transition in
                  transition.evidenceDigests == change.evidence.map(\.receipt.digest).sorted(
                      by: remediationDigestOrder
                  )
              }),
              decodedDigest == CanonicalTreeDigest.sha256(try CanonicalJSON.encode(payload))
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
        self.init(payload: payload, digest: decodedDigest)
    }

    public static func decodeCanonical(from bytes: Data) throws -> RemediationBatch {
        try artifactDecodeCanonical(Self.self, from: bytes)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case sourceRegisterDigest = "source_register_digest"
        case sourceBaselineDigest = "source_baseline_digest"
        case assignedFingerprints = "assigned_fingerprints"
        case changes
        case implementingActorID = "implementing_actor_id"
        case resolvedTransitions = "resolved_transitions"
        case successorBaselineDigest = "successor_baseline_digest"
        case digest = "batch_digest"
    }
}

public struct VerifiedRemediationSuccessor: Sendable {
    public let batch: RemediationBatch
    public let sourceBaseline: ReviewBaseline
    public let sourceRegister: VerifiedIssueRegister
    public let successorBaseline: ReviewBaseline
    public let planning: VerifiedReviewRemediationPlanningContext
    public let implementationAuthority: VerifiedReviewImplementationAuthority
    public let plannedEvidence: [VerifiedPlannedRemediationEvidence]

    init(
        batch: RemediationBatch,
        sourceRegister: VerifiedIssueRegister,
        successorBaseline: ReviewBaseline,
        planning: VerifiedReviewRemediationPlanningContext,
        implementationAuthority: VerifiedReviewImplementationAuthority,
        plannedEvidence: [VerifiedPlannedRemediationEvidence]
    ) {
        self.batch = batch
        sourceBaseline = sourceRegister.baseline
        self.sourceRegister = sourceRegister
        self.successorBaseline = successorBaseline
        self.planning = planning
        self.implementationAuthority = implementationAuthority
        self.plannedEvidence = plannedEvidence
    }
}

/// Restart-safe authority for a remediation successor recovered from one exact durable
/// `reviewRemediationRecorded` transaction. Unlike `VerifiedRemediationSuccessor`, this
/// capability carries no in-memory planning or authority fact and cannot be minted pre-commit.
public struct VerifiedCommittedRemediationSuccessor: Sendable {
    public let batch: RemediationBatch
    public let sourceBaseline: ReviewBaseline
    public let sourceRegister: VerifiedIssueRegister
    public let successorBaseline: ReviewBaseline
    public let publicationAnchorEventHead: HashDigest
    public let producedEventHead: HashDigest
    public let implementingPrincipalID: PrincipalID
    public let implementingContextDigest: HashDigest
    public let implementationAuthorityDigest: HashDigest
    public let receipts: [VerifiedPublishedReviewReceipt]

    init(
        batch: RemediationBatch,
        sourceRegister: VerifiedIssueRegister,
        successorBaseline: ReviewBaseline,
        publicationAnchorEventHead: HashDigest,
        producedEventHead: HashDigest,
        implementingPrincipalID: PrincipalID,
        implementingContextDigest: HashDigest,
        implementationAuthorityDigest: HashDigest,
        receipts: [VerifiedPublishedReviewReceipt]
    ) {
        self.batch = batch
        sourceBaseline = sourceRegister.baseline
        self.sourceRegister = sourceRegister
        self.successorBaseline = successorBaseline
        self.publicationAnchorEventHead = publicationAnchorEventHead
        self.producedEventHead = producedEventHead
        self.implementingPrincipalID = implementingPrincipalID
        self.implementingContextDigest = implementingContextDigest
        self.implementationAuthorityDigest = implementationAuthorityDigest
        self.receipts = receipts.sorted {
            ($0.kind.rawValue, $0.id.rawValue) < ($1.kind.rawValue, $1.id.rawValue)
        }
    }
}

public enum ReviewRemediationVerifier {
    public static func verifySuccessor(
        sourceRegister: VerifiedIssueRegister,
        changes: [RemediationChange],
        plannedEvidence: [VerifiedPlannedRemediationEvidence],
        implementationAuthority: VerifiedReviewImplementationAuthority,
        successorBaseline: ReviewBaseline,
        planning: VerifiedReviewRemediationPlanningContext
    ) throws -> VerifiedRemediationSuccessor {
        let baseline = sourceRegister.baseline
        let assigned = sourceRegister.register.acceptedCurrentScopeAssignments
        let sortedChanges = changes.sorted { $0.fingerprint < $1.fingerprint }
        let sortedEvidence = plannedEvidence.sorted {
            ($0.fingerprint.rawValue, $0.evidence.kind.order, $0.evidence.receipt.id.rawValue) <
                ($1.fingerprint.rawValue, $1.evidence.kind.order, $1.evidence.receipt.id.rawValue)
        }
        let evidenceKeys = sortedEvidence.map {
            "\($0.fingerprint.rawValue)/\($0.evidence.kind.rawValue)"
        }
        guard sourceRegister.register.pathDecision == .requiresRemediation,
              !assigned.isEmpty,
              sortedChanges.map({ $0.fingerprint.failureFingerprint }) == assigned,
              planning.runID == baseline.runID,
              planning.sourceBaselineDigest == baseline.digest,
              planning.sourceRegisterDigest == sourceRegister.register.digest,
              planning.successorBaselineDigest == successorBaseline.digest,
              planning.currentArtifacts == successorBaseline.artifactScopes,
              implementationAuthority.runID == planning.runID,
              implementationAuthority.sourceBaselineDigest == planning.sourceBaselineDigest,
              implementationAuthority.sourceRegisterDigest == planning.sourceRegisterDigest,
              implementationAuthority.successorBaselineDigest == planning.successorBaselineDigest,
              implementationAuthority.publicationAnchorEventHead ==
                planning.publicationAnchorEventHead,
              sortedEvidence.count == sortedChanges.count * RemediationEvidenceKind.allCases.count,
              Set(evidenceKeys).count == evidenceKeys.count,
              Set(sortedEvidence.map { $0.evidence.receipt.id }).count == sortedEvidence.count,
              try hasValidRemediationSuccessor(
                  source: baseline,
                  successor: successorBaseline,
                  publicationAnchorEventHead: planning.publicationAnchorEventHead
              )
        else { throw WorkflowPolicyError.invalidDispositionEvidence }

        for change in sortedChanges {
            let components = try sourceRegister.components(
                for: change.fingerprint.failureFingerprint
            )
            guard change.preChangeArtifact.id == components.artifactID,
                  change.preChangeArtifact.scope == components.scopeSelector,
                  baseline.artifactScopes.contains(change.preChangeArtifact),
                  change.evidence.count == RemediationEvidenceKind.allCases.count,
                  change.evidence.allSatisfy({
                      $0.publicationAnchorEventHead == planning.publicationAnchorEventHead
                  }),
                  implementationAuthority.artifactTransitions.contains(
                      try RemediationArtifactTransitionBinding(
                          preChangeArtifact: change.preChangeArtifact,
                          postChangeArtifact: change.postChangeArtifact
                      )
                  )
            else { throw WorkflowPolicyError.invalidDispositionEvidence }
            for evidence in change.evidence {
                let matches = sortedEvidence.filter {
                    $0.fingerprint == change.fingerprint && $0.evidence.kind == evidence.kind
                }
                guard matches.count == 1, let planned = matches.first,
                      planned.evidence == evidence,
                      planned.payload.receiptID == evidence.receipt.id,
                      planned.payload.receiptKind == (try remediationReceiptKind(evidence.kind)),
                      planned.payload.runID == planning.runID,
                      planned.payload.sourceBaselineDigest == baseline.digest,
                      planned.payload.sourceRegisterDigest == sourceRegister.register.digest,
                      planned.payload.fingerprint == change.fingerprint,
                      planned.payload.preChangeArtifact == change.preChangeArtifact,
                      planned.payload.postChangeArtifact == change.postChangeArtifact,
                      planned.payload.implementingActorID ==
                        implementationAuthority.implementingActorID,
                      planned.payload.implementingPrincipalID ==
                        implementationAuthority.implementingPrincipalID,
                      planned.payload.implementingContextDigest ==
                        implementationAuthority.implementingContextDigest,
                      planned.payload.implementationAuthorityDigest ==
                        implementationAuthority.provenanceDigest,
                      planned.payload.publicationAnchorEventHead ==
                        planning.publicationAnchorEventHead,
                      planned.payloadDigest == evidence.receipt.digest,
                      planned.payloadBytes == (try CanonicalJSON.encode(planned.payload)),
                      try ReviewRemediationEvidencePayload.decodeCanonical(
                          from: planned.payloadBytes
                      ) == planned.payload
                else { throw WorkflowPolicyError.invalidDispositionEvidence }
            }
        }

        let batch = try RemediationBatch.issue(
            sourceRegister: sourceRegister.register,
            sourceBaseline: baseline,
            changes: sortedChanges,
            implementingActorID: implementationAuthority.implementingActorID,
            successorBaseline: successorBaseline,
            publicationAnchorEventHead: planning.publicationAnchorEventHead
        )
        return VerifiedRemediationSuccessor(
            batch: batch,
            sourceRegister: sourceRegister,
            successorBaseline: successorBaseline,
            planning: planning,
            implementationAuthority: implementationAuthority,
            plannedEvidence: sortedEvidence
        )
    }
}

/// Reconstructs remediation lineage solely from durable state. The verifier requires the
/// successor baseline, batch, transitions, and every typed evidence receipt to be the complete
/// receipt closure of one owning event; split-event, missing, additional, or replayed evidence
/// cannot mint a committed successor.
public enum ReviewCommittedRemediationVerifier {
    public static func verify(
        sourceRegister: VerifiedIssueRegister,
        batch: RemediationBatch,
        successorBaseline: ReviewBaseline,
        persistedRun: PersistedRun
    ) throws -> VerifiedCommittedRemediationSuccessor {
        try ReviewCommittedReceiptVerifier.validateActiveChain(persistedRun)
        let sourceBaseline = sourceRegister.baseline
        let batchBytes = try CanonicalJSON.encode(batch)
        let batchKind = try ReceiptKind(validating: "review-remediation-batch")
        let batchCandidates = persistedRun.receipts.filter {
            $0.kind == batchKind &&
                $0.payloadBytes == batchBytes &&
                $0.payloadDigest == CanonicalTreeDigest.sha256(batchBytes)
        }
        guard batchCandidates.count == 1, let batchCandidate = batchCandidates.first else {
            throw PersistenceError.integrityViolation
        }
        let committedBatch = try ReviewCommittedReceiptVerifier.verify(
            id: batchCandidate.id,
            kind: batchKind,
            digest: batchCandidate.payloadDigest,
            in: persistedRun
        )
        guard let publicationAnchorEventHead = committedBatch.publicationAnchorEventHead else {
            throw PersistenceError.integrityViolation
        }
        let suffix = String(publicationAnchorEventHead.rawValue.prefix(16))
        let expectedBatchID = try ReceiptID(
            validating: "review-remediation-batch-\(suffix)"
        )
        let expectedEventID = expectedBatchID.rawValue

        guard committedBatch.id == expectedBatchID,
              committedBatch.eventID == expectedEventID,
              committedBatch.eventKind == .reviewRemediationRecorded,
              committedBatch.runID == sourceBaseline.runID,
              committedBatch.owningRecord.previousDigest == publicationAnchorEventHead,
              committedBatch.owningRecord.recordDigest == committedBatch.producedEventHead,
              batch.sourceRegisterDigest == sourceRegister.register.digest,
              batch.sourceBaselineDigest == sourceBaseline.digest,
              batch.successorBaselineDigest == successorBaseline.digest,
              persistedRun.state.runID == sourceBaseline.runID,
              try RemediationBatch.decodeCanonical(from: committedBatch.payloadBytes) == batch,
              try hasValidRemediationSuccessor(
                  source: sourceBaseline,
                  successor: successorBaseline,
                  publicationAnchorEventHead: publicationAnchorEventHead
              ),
              try RemediationBatch.issue(
                  sourceRegister: sourceRegister.register,
                  sourceBaseline: sourceBaseline,
                  changes: batch.changes,
                  implementingActorID: batch.implementingActorID,
                  successorBaseline: successorBaseline,
                  publicationAnchorEventHead: publicationAnchorEventHead
              ) == batch
        else { throw PersistenceError.integrityViolation }

        let baselineReceipt = try committedReceipt(
            kind: "review-baseline",
            id: "review-baseline-\(suffix)",
            expectedPayloadBytes: CanonicalJSON.encode(successorBaseline),
            persistedRun: persistedRun
        )
        let transitionPayload = ReviewResolvedTransitionsReceiptPayload(batch: batch)
        let transitionReceipt = try committedReceipt(
            kind: "review-resolved-transitions",
            id: "review-resolved-transitions-\(suffix)",
            expectedPayloadBytes: CanonicalJSON.encode(transitionPayload),
            persistedRun: persistedRun
        )
        guard try ReviewBaseline.decodeCanonical(from: baselineReceipt.payloadBytes) ==
                successorBaseline,
              let decodedTransitions = try? CanonicalJSON.decode(
                  ReviewResolvedTransitionsReceiptPayload.self,
                  from: transitionReceipt.payloadBytes
              ),
              decodedTransitions == transitionPayload,
              try CanonicalJSON.encode(decodedTransitions) == transitionReceipt.payloadBytes
        else { throw PersistenceError.integrityViolation }

        var committedEvidence: [VerifiedPublishedReviewReceipt] = []
        var implementingPrincipalID: PrincipalID?
        var implementingContextDigest: HashDigest?
        var implementationAuthorityDigest: HashDigest?
        for change in batch.changes {
            let components = try sourceRegister.components(
                for: change.fingerprint.failureFingerprint
            )
            guard components.artifactID == change.preChangeArtifact.id,
                  components.scopeSelector == change.preChangeArtifact.scope
            else { throw PersistenceError.integrityViolation }
            for evidence in change.evidence {
                let kind = try remediationReceiptKind(evidence.kind)
                let receipt = try ReviewCommittedReceiptVerifier.verify(
                    id: evidence.receipt.id,
                    kind: kind,
                    digest: evidence.receipt.digest,
                    in: persistedRun
                )
                let payload = try ReviewRemediationEvidencePayload.decodeCanonical(
                    from: receipt.payloadBytes
                )
                guard evidence.publicationAnchorEventHead == publicationAnchorEventHead,
                      payload.receiptID == receipt.id,
                      payload.receiptKind == receipt.kind,
                      payload.runID == sourceBaseline.runID,
                      payload.sourceBaselineDigest == sourceBaseline.digest,
                      payload.sourceRegisterDigest == sourceRegister.register.digest,
                      payload.fingerprint == change.fingerprint,
                      payload.preChangeArtifact == change.preChangeArtifact,
                      payload.postChangeArtifact == change.postChangeArtifact,
                      payload.evidenceKind == evidence.kind,
                      payload.implementingActorID == batch.implementingActorID,
                      payload.publicationAnchorEventHead == publicationAnchorEventHead,
                      receipt.payloadDigest == evidence.receipt.digest,
                      receipt.payloadDigest == CanonicalTreeDigest.sha256(receipt.payloadBytes),
                      receipt.payloadBytes == (try CanonicalJSON.encode(payload))
                else { throw PersistenceError.integrityViolation }
                if let sealedPrincipal = implementingPrincipalID {
                    guard sealedPrincipal == payload.implementingPrincipalID,
                          implementingContextDigest == payload.implementingContextDigest,
                          implementationAuthorityDigest == payload.implementationAuthorityDigest
                    else { throw PersistenceError.integrityViolation }
                } else {
                    implementingPrincipalID = payload.implementingPrincipalID
                    implementingContextDigest = payload.implementingContextDigest
                    implementationAuthorityDigest = payload.implementationAuthorityDigest
                }
                committedEvidence.append(receipt)
            }
        }

        guard let implementingPrincipalID,
              let implementingContextDigest,
              let implementationAuthorityDigest
        else { throw PersistenceError.integrityViolation }
        let receipts = [committedBatch, baselineReceipt, transitionReceipt] + committedEvidence
        try verifyAtomicReceiptClosure(
            receipts,
            owning: committedBatch,
            persistedRun: persistedRun
        )
        return VerifiedCommittedRemediationSuccessor(
            batch: batch,
            sourceRegister: sourceRegister,
            successorBaseline: successorBaseline,
            publicationAnchorEventHead: publicationAnchorEventHead,
            producedEventHead: committedBatch.producedEventHead,
            implementingPrincipalID: implementingPrincipalID,
            implementingContextDigest: implementingContextDigest,
            implementationAuthorityDigest: implementationAuthorityDigest,
            receipts: receipts
        )
    }

    private static func committedReceipt(
        kind: String,
        id: String,
        expectedPayloadBytes: Data,
        persistedRun: PersistedRun
    ) throws -> VerifiedPublishedReviewReceipt {
        let kind = try ReceiptKind(validating: kind)
        let id = try ReceiptID(validating: id)
        let digest = CanonicalTreeDigest.sha256(expectedPayloadBytes)
        let receipt = try ReviewCommittedReceiptVerifier.verify(
            id: id,
            kind: kind,
            digest: digest,
            in: persistedRun
        )
        guard receipt.payloadBytes == expectedPayloadBytes else {
            throw PersistenceError.integrityViolation
        }
        return receipt
    }

    private static func verifyAtomicReceiptClosure(
        _ receipts: [VerifiedPublishedReviewReceipt],
        owning committedBatch: VerifiedPublishedReviewReceipt,
        persistedRun: PersistedRun
    ) throws {
        let addresses = receipts.map { "\($0.kind.rawValue)/\($0.id.rawValue)" }
        let manifestAddresses = committedBatch.owningRecord.receiptManifest.map {
            "\($0.kind.rawValue)/\($0.id.rawValue)"
        }
        let transactionReceipts = persistedRun.receipts.filter {
            $0.transactionID == committedBatch.transactionID &&
                $0.transactionDigest == committedBatch.transactionDigest
        }
        let transactionAddresses = transactionReceipts.map {
            "\($0.kind.rawValue)/\($0.id.rawValue)"
        }
        guard Set(addresses).count == addresses.count,
              Set(addresses) == Set(manifestAddresses),
              addresses.count == manifestAddresses.count,
              Set(addresses) == Set(transactionAddresses),
              addresses.count == transactionAddresses.count,
              receipts.allSatisfy({ receipt in
                  receipt.transactionID == committedBatch.transactionID &&
                      receipt.transactionDigest == committedBatch.transactionDigest &&
                      receipt.eventID == committedBatch.eventID &&
                      receipt.eventKind == .reviewRemediationRecorded &&
                      receipt.publicationAnchorEventHead ==
                        committedBatch.publicationAnchorEventHead &&
                      receipt.producedEventHead == committedBatch.producedEventHead &&
                      receipt.owningRecord == committedBatch.owningRecord
              })
        else { throw PersistenceError.integrityViolation }
    }
}

private struct RemediationBatchPayload: Codable {
    let schemaVersion: Int
    let sourceRegisterDigest: HashDigest
    let sourceBaselineDigest: HashDigest
    let assignedFingerprints: [FailureFingerprint]
    let changes: [RemediationChange]
    let implementingActorID: ActorID
    let resolvedTransitions: [RemediationResolvedTransition]
    let successorBaselineDigest: HashDigest

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case sourceRegisterDigest = "source_register_digest"
        case sourceBaselineDigest = "source_baseline_digest"
        case assignedFingerprints = "assigned_fingerprints"
        case changes
        case implementingActorID = "implementing_actor_id"
        case resolvedTransitions = "resolved_transitions"
        case successorBaselineDigest = "successor_baseline_digest"
    }
}

private func applying(
    _ changes: [RemediationChange],
    to artifacts: [ArtifactReference]
) throws -> [ArtifactReference] {
    guard Set(artifacts.map(\.id)).count == artifacts.count,
          Set(changes.map { $0.preChangeArtifact.id }).count == changes.count
    else { throw WorkflowPolicyError.invalidDispositionEvidence }
    let replacements = Dictionary(
        uniqueKeysWithValues: changes.map { ($0.preChangeArtifact.id, $0) }
    )
    var result: [ArtifactReference] = []
    for artifact in artifacts {
        if let change = replacements[artifact.id] {
            guard change.preChangeArtifact == artifact else {
                throw WorkflowPolicyError.invalidDispositionEvidence
            }
            result.append(change.postChangeArtifact)
        } else {
            result.append(artifact)
        }
    }
    return canonicalReviewArtifacts(result)
}

private func hasValidRemediationSuccessor(
    source: ReviewBaseline,
    successor: ReviewBaseline,
    publicationAnchorEventHead: HashDigest
) throws -> Bool {
    let expectedKind: ReviewRoundKind
    let expectedOrdinal: UInt64
    switch source.kind {
    case .initial:
        expectedKind = .normalConfirmation
        expectedOrdinal = 1
    case .normalConfirmation:
        guard source.semanticOrdinal == 1 else { return false }
        expectedKind = .exception
        expectedOrdinal = 2
    case .exception:
        expectedKind = .exception
        expectedOrdinal = try incrementChecked(source.semanticOrdinal)
    }
    return successor.runID == source.runID &&
        successor.cycleID == source.cycleID &&
        successor.gate == source.gate &&
        successor.kind == expectedKind &&
        successor.semanticOrdinal == expectedOrdinal &&
        successor.cycleOrdinal == nil &&
        successor.preCreationEventHead == publicationAnchorEventHead &&
        successor.predecessorBaselineDigest == source.digest &&
        successor.rosterDigest == source.rosterDigest &&
        successor.roster == source.roster &&
        successor.redactionPolicy == source.redactionPolicy &&
        successor.activeProfileDigest == source.activeProfileDigest &&
        successor.riskPolicyDigest == source.riskPolicyDigest &&
        successor.assurancePolicyDigest == source.assurancePolicyDigest &&
        successor.convergencePolicyDigest == source.convergencePolicyDigest
}

private func remediationReceiptKind(_ kind: RemediationEvidenceKind) throws -> ReceiptKind {
    switch kind {
    case .command:
        try ReceiptKind(validating: "review-remediation-command")
    case .staticAnalysis:
        try ReceiptKind(validating: "review-remediation-static-analysis")
    case .review:
        try ReceiptKind(validating: "review-remediation-review")
    }
}

private func remediationDigestOrder(_ lhs: HashDigest, _ rhs: HashDigest) -> Bool {
    lhs.rawValue < rhs.rawValue
}

#if DEBUG
extension ReviewCapabilityTestFactory {
    static func verifyRemediationPlanningContext(
        sourceRegister: VerifiedIssueRegister,
        successorBaseline: ReviewBaseline,
        publicationAnchorEventHead: HashDigest
    ) throws -> VerifiedReviewRemediationPlanningContext {
        guard sourceRegister.register.pathDecision == .requiresRemediation,
              !sourceRegister.register.acceptedCurrentScopeAssignments.isEmpty,
              try hasValidRemediationSuccessor(
                  source: sourceRegister.baseline,
                  successor: successorBaseline,
                  publicationAnchorEventHead: publicationAnchorEventHead
              )
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
        return try VerifiedReviewRemediationPlanningContext(
            sourceRegister: sourceRegister,
            successorBaseline: successorBaseline,
            publicationAnchorEventHead: publicationAnchorEventHead
        )
    }
}
#endif
