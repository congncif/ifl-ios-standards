import Foundation
import IFLContracts

public enum ReviewFindingIdentityKind: String, Codable, CaseIterable, Hashable, Sendable {
    case rule
    case check
    case finding
}

public struct ReviewFindingIdentity: Codable, Hashable, Sendable {
    public let kind: ReviewFindingIdentityKind
    public let value: String

    public init(kind: ReviewFindingIdentityKind, value: String) throws {
        guard isCanonicalReviewFindingIdentity(value) else {
            throw WorkflowPolicyError.invalidFingerprintInput
        }
        self.kind = kind
        self.value = value
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            kind: values.decode(ReviewFindingIdentityKind.self, forKey: .kind),
            value: values.decode(String.self, forKey: .value)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case value
    }
}

public struct IssueFingerprintComponents: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let identity: ReviewFindingIdentity
    public let artifactID: ArtifactID
    public let scopeSelector: ArtifactScope
    public let locationSelector: String
    public let invariantID: String
    public let expectedClass: String
    public let actualClass: String

    public init(
        identity: ReviewFindingIdentity,
        artifactID: ArtifactID,
        scopeSelector: ArtifactScope,
        locationSelector: String,
        invariantID: String,
        expectedClass: String,
        actualClass: String
    ) throws {
        guard WorkflowIdentifier.isValid(identity.value),
              WorkflowIdentifier.isValid(locationSelector),
              WorkflowIdentifier.isValid(invariantID),
              WorkflowIdentifier.isValid(expectedClass),
              WorkflowIdentifier.isValid(actualClass)
        else { throw WorkflowPolicyError.invalidFingerprintInput }
        schemaVersion = 1
        self.identity = identity
        self.artifactID = artifactID
        self.scopeSelector = scopeSelector
        self.locationSelector = locationSelector
        self.invariantID = invariantID
        self.expectedClass = expectedClass
        self.actualClass = actualClass
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 1 else {
            throw WorkflowPolicyError.invalidFingerprintInput
        }
        try self.init(
            identity: values.decode(ReviewFindingIdentity.self, forKey: .identity),
            artifactID: values.decode(ArtifactID.self, forKey: .artifactID),
            scopeSelector: values.decode(ArtifactScope.self, forKey: .scopeSelector),
            locationSelector: values.decode(String.self, forKey: .locationSelector),
            invariantID: values.decode(String.self, forKey: .invariantID),
            expectedClass: values.decode(String.self, forKey: .expectedClass),
            actualClass: values.decode(String.self, forKey: .actualClass)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case identity
        case artifactID = "artifact_id"
        case scopeSelector = "scope_selector"
        case locationSelector = "location_selector"
        case invariantID = "invariant_id"
        case expectedClass = "expected_class"
        case actualClass = "actual_class"
    }
}

public struct ReviewerFinding: Codable, Hashable, Sendable {
    public let findingID: String
    public let components: IssueFingerprintComponents
    public let severity: RiskClass
    public let mustFixClaim: Bool
    public let title: String
    public let message: String
    public let evidenceReferences: [String]
    public let confidenceBasis: String
    public let reportedAt: String

    public init(
        findingID: String,
        components: IssueFingerprintComponents,
        severity: RiskClass,
        mustFixClaim: Bool,
        title: String,
        message: String,
        evidenceReferences: [String],
        confidenceBasis: String,
        reportedAt: String
    ) throws {
        guard WorkflowIdentifier.isValid(findingID),
              WorkflowIdentifier.isValid(title),
              WorkflowIdentifier.isValid(message),
              WorkflowIdentifier.isValid(confidenceBasis),
              isCanonicalReviewTimestamp(reportedAt),
              !evidenceReferences.isEmpty,
              Set(evidenceReferences).count == evidenceReferences.count,
              evidenceReferences.allSatisfy(WorkflowIdentifier.isValid)
        else { throw WorkflowPolicyError.invalidFingerprintInput }
        self.findingID = findingID
        self.components = components
        self.severity = severity
        self.mustFixClaim = mustFixClaim
        self.title = title
        self.message = message
        self.evidenceReferences = evidenceReferences.sorted()
        self.confidenceBasis = confidenceBasis
        self.reportedAt = reportedAt
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let references = try values.decode([String].self, forKey: .evidenceReferences)
        try self.init(
            findingID: values.decode(String.self, forKey: .findingID),
            components: values.decode(IssueFingerprintComponents.self, forKey: .components),
            severity: values.decode(RiskClass.self, forKey: .severity),
            mustFixClaim: values.decode(Bool.self, forKey: .mustFixClaim),
            title: values.decode(String.self, forKey: .title),
            message: values.decode(String.self, forKey: .message),
            evidenceReferences: references,
            confidenceBasis: values.decode(String.self, forKey: .confidenceBasis),
            reportedAt: values.decode(String.self, forKey: .reportedAt)
        )
        guard references == evidenceReferences else {
            throw WorkflowPolicyError.invalidFingerprintInput
        }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case findingID = "finding_id"
        case components
        case severity
        case mustFixClaim = "must_fix_claim"
        case title
        case message
        case evidenceReferences = "evidence_references"
        case confidenceBasis = "confidence_basis"
        case reportedAt = "reported_at"
    }
}

public struct ReviewRedactionMetadata: Codable, Hashable, Sendable {
    public let policy: RedactionPolicyBinding
    public let sanitizedEnvelopeDigest: HashDigest
    public let replacementTokenCount: Int
    public let containsRawSensitiveData: Bool

    public init(
        policy: RedactionPolicyBinding,
        sanitizedEnvelopeDigest: HashDigest,
        replacementTokenCount: Int,
        containsRawSensitiveData: Bool
    ) throws {
        guard replacementTokenCount >= 0 else { throw WorkflowPolicyError.invalidPolicy }
        self.policy = policy
        self.sanitizedEnvelopeDigest = sanitizedEnvelopeDigest
        self.replacementTokenCount = replacementTokenCount
        self.containsRawSensitiveData = containsRawSensitiveData
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            policy: values.decode(RedactionPolicyBinding.self, forKey: .policy),
            sanitizedEnvelopeDigest: values.decode(
                HashDigest.self,
                forKey: .sanitizedEnvelopeDigest
            ),
            replacementTokenCount: values.decode(Int.self, forKey: .replacementTokenCount),
            containsRawSensitiveData: values.decode(Bool.self, forKey: .containsRawSensitiveData)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case policy
        case sanitizedEnvelopeDigest = "sanitized_envelope_digest"
        case replacementTokenCount = "replacement_token_count"
        case containsRawSensitiveData = "contains_raw_sensitive_data"
    }
}

/// Canonical wire payload committed by each reviewer-envelope effect receipt.
///
/// The payload never embeds its own receipt digest. The record receipt alone cross-links the
/// already-computed effect and domain receipts, closing bundle splicing without a hash cycle.
public struct ReviewEnvelopeReceiptPayload: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let receiptID: ReceiptID
    public let receiptKind: ReceiptKind
    public let runID: RunID
    public let baselineDigest: HashDigest
    public let roundID: ReviewRoundID
    public let rosterDigest: HashDigest
    public let assignmentID: ReviewAssignmentID
    public let checklistDigest: HashDigest
    public let actorID: ActorID
    public let principalID: PrincipalID
    public let independentContextDigest: HashDigest
    public let role: String
    public let envelopeArtifact: ArtifactReference
    public let redactionPolicy: RedactionPolicyBinding
    public let redactionMetadata: ReviewRedactionMetadata
    public let effectReceipt: ImmutableReceiptReference?
    public let domainReceipt: ImmutableReceiptReference?
    public let complete: Bool
    public let findings: [ReviewerFinding]

    public init(
        receiptID: ReceiptID,
        receiptKind: ReceiptKind,
        runID: RunID,
        baselineDigest: HashDigest,
        roundID: ReviewRoundID,
        rosterDigest: HashDigest,
        assignmentID: ReviewAssignmentID,
        checklistDigest: HashDigest,
        actorID: ActorID,
        principalID: PrincipalID,
        independentContextDigest: HashDigest,
        role: String,
        envelopeArtifact: ArtifactReference,
        redactionPolicy: RedactionPolicyBinding,
        redactionMetadata: ReviewRedactionMetadata,
        effectReceipt: ImmutableReceiptReference? = nil,
        domainReceipt: ImmutableReceiptReference? = nil,
        complete: Bool,
        findings: [ReviewerFinding]
    ) throws {
        let isRecordReceipt = receiptKind.rawValue == "review-envelope-record"
        let canonicalFindings = try findings.sorted {
            let lhs = try IssueFingerprint.derive(from: $0.components).rawValue
            let rhs = try IssueFingerprint.derive(from: $1.components).rawValue
            return (lhs, $0.findingID) < (rhs, $1.findingID)
        }
        guard Self.allowedReceiptKinds.contains(receiptKind.rawValue),
              WorkflowIdentifier.isValid(role),
              redactionPolicy == redactionMetadata.policy,
              envelopeArtifact.contentHash == redactionMetadata.sanitizedEnvelopeDigest,
              !redactionMetadata.containsRawSensitiveData,
              isRecordReceipt == (effectReceipt != nil && domainReceipt != nil),
              isRecordReceipt || (effectReceipt == nil && domainReceipt == nil),
              !isRecordReceipt || (
                  effectReceipt?.id != domainReceipt?.id &&
                      effectReceipt?.id != receiptID &&
                  domainReceipt?.id != receiptID
              ),
              complete,
              findings == canonicalFindings,
              Set(findings.map(\.findingID)).count == findings.count
        else { throw WorkflowPolicyError.invalidPolicy }
        schemaVersion = 1
        self.receiptID = receiptID
        self.receiptKind = receiptKind
        self.runID = runID
        self.baselineDigest = baselineDigest
        self.roundID = roundID
        self.rosterDigest = rosterDigest
        self.assignmentID = assignmentID
        self.checklistDigest = checklistDigest
        self.actorID = actorID
        self.principalID = principalID
        self.independentContextDigest = independentContextDigest
        self.role = role
        self.envelopeArtifact = envelopeArtifact
        self.redactionPolicy = redactionPolicy
        self.redactionMetadata = redactionMetadata
        self.effectReceipt = effectReceipt
        self.domainReceipt = domainReceipt
        self.complete = complete
        self.findings = findings
    }

    init(
        submission: ReviewerFindingSubmission,
        baseline: ReviewBaseline,
        receiptID: ReceiptID,
        receiptKind: ReceiptKind,
        independentContextDigest: HashDigest
    ) throws {
        let isRecordReceipt = receiptKind.rawValue == "review-envelope-record"
        try self.init(
            receiptID: receiptID,
            receiptKind: receiptKind,
            runID: baseline.runID,
            baselineDigest: submission.baselineDigest,
            roundID: submission.roundID,
            rosterDigest: submission.rosterDigest,
            assignmentID: submission.assignmentID,
            checklistDigest: submission.checklistDigest,
            actorID: submission.actorID,
            principalID: submission.principalID,
            independentContextDigest: independentContextDigest,
            role: submission.role,
            envelopeArtifact: submission.envelope.artifact,
            redactionPolicy: submission.redactionPolicy,
            redactionMetadata: submission.redactionMetadata,
            effectReceipt: isRecordReceipt ? submission.envelope.effectReceipt : nil,
            domainReceipt: isRecordReceipt ? submission.envelope.domainReceipt : nil,
            complete: submission.complete,
            findings: submission.findings
        )
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 1 else {
            throw WorkflowPolicyError.invalidPolicy
        }
        try self.init(
            receiptID: values.decode(ReceiptID.self, forKey: .receiptID),
            receiptKind: values.decode(ReceiptKind.self, forKey: .receiptKind),
            runID: values.decode(RunID.self, forKey: .runID),
            baselineDigest: values.decode(HashDigest.self, forKey: .baselineDigest),
            roundID: values.decode(ReviewRoundID.self, forKey: .roundID),
            rosterDigest: values.decode(HashDigest.self, forKey: .rosterDigest),
            assignmentID: values.decode(ReviewAssignmentID.self, forKey: .assignmentID),
            checklistDigest: values.decode(HashDigest.self, forKey: .checklistDigest),
            actorID: values.decode(ActorID.self, forKey: .actorID),
            principalID: values.decode(PrincipalID.self, forKey: .principalID),
            independentContextDigest: values.decode(
                HashDigest.self,
                forKey: .independentContextDigest
            ),
            role: values.decode(String.self, forKey: .role),
            envelopeArtifact: values.decode(ArtifactReference.self, forKey: .envelopeArtifact),
            redactionPolicy: values.decode(RedactionPolicyBinding.self, forKey: .redactionPolicy),
            redactionMetadata: values.decode(
                ReviewRedactionMetadata.self,
                forKey: .redactionMetadata
            ),
            effectReceipt: values.decodeIfPresent(
                ImmutableReceiptReference.self,
                forKey: .effectReceipt
            ),
            domainReceipt: values.decodeIfPresent(
                ImmutableReceiptReference.self,
                forKey: .domainReceipt
            ),
            complete: values.decode(Bool.self, forKey: .complete),
            findings: values.decode([ReviewerFinding].self, forKey: .findings)
        )
    }

    public static func decodeCanonical(from bytes: Data) throws -> ReviewEnvelopeReceiptPayload {
        try artifactDecodeCanonical(Self.self, from: bytes)
    }

    private static let allowedReceiptKinds: Set<String> = [
        "review-envelope-effect",
        "review-envelope-domain",
        "review-envelope-record",
    ]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case receiptID = "receipt_id"
        case receiptKind = "receipt_kind"
        case runID = "run_id"
        case baselineDigest = "baseline_digest"
        case roundID = "round_id"
        case rosterDigest = "roster_digest"
        case assignmentID = "assignment_id"
        case checklistDigest = "checklist_digest"
        case actorID = "actor_id"
        case principalID = "principal_id"
        case independentContextDigest = "independent_context_digest"
        case role
        case envelopeArtifact = "envelope_artifact"
        case redactionPolicy = "redaction_policy"
        case redactionMetadata = "redaction_metadata"
        case effectReceipt = "effect_receipt"
        case domainReceipt = "domain_receipt"
        case complete
        case findings
    }
}

public struct ImmutableReceiptReference: Codable, Hashable, Sendable {
    public let id: ReceiptID
    public let digest: HashDigest

    public init(id: ReceiptID, digest: HashDigest) {
        self.id = id
        self.digest = digest
    }

    public init(id: String, digest: HashDigest) throws {
        self.init(id: try ReceiptID(validating: id), digest: digest)
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decode(ReceiptID.self, forKey: .id),
            digest: try values.decode(HashDigest.self, forKey: .digest)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case digest
    }
}

public struct ReviewerEnvelopeBinding: Codable, Hashable, Sendable {
    public let artifact: ArtifactReference
    public let effectReceipt: ImmutableReceiptReference
    public let domainReceipt: ImmutableReceiptReference
    public let recordReceipt: ImmutableReceiptReference

    public init(
        artifact: ArtifactReference,
        effectReceipt: ImmutableReceiptReference,
        domainReceipt: ImmutableReceiptReference,
        recordReceipt: ImmutableReceiptReference
    ) throws {
        let receipts = [effectReceipt, domainReceipt, recordReceipt]
        guard Set(receipts.map(\.id)).count == receipts.count
        else { throw WorkflowPolicyError.invalidPolicy }
        self.artifact = artifact
        self.effectReceipt = effectReceipt
        self.domainReceipt = domainReceipt
        self.recordReceipt = recordReceipt
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            artifact: values.decode(ArtifactReference.self, forKey: .artifact),
            effectReceipt: values.decode(ImmutableReceiptReference.self, forKey: .effectReceipt),
            domainReceipt: values.decode(ImmutableReceiptReference.self, forKey: .domainReceipt),
            recordReceipt: values.decode(ImmutableReceiptReference.self, forKey: .recordReceipt)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case artifact
        case effectReceipt = "effect_receipt"
        case domainReceipt = "domain_receipt"
        case recordReceipt = "record_receipt"
    }
}

public struct ReviewerFindingSubmission: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let baselineDigest: HashDigest
    public let roundID: ReviewRoundID
    public let rosterDigest: HashDigest
    public let assignmentID: ReviewAssignmentID
    public let checklistDigest: HashDigest
    public let redactionPolicy: RedactionPolicyBinding
    public let redactionMetadata: ReviewRedactionMetadata
    public let actorID: ActorID
    public let principalID: PrincipalID
    public let role: String
    public let envelope: ReviewerEnvelopeBinding
    public let complete: Bool
    public let findings: [ReviewerFinding]

    public init(
        baselineDigest: HashDigest,
        roundID: ReviewRoundID,
        rosterDigest: HashDigest,
        assignmentID: ReviewAssignmentID,
        checklistDigest: HashDigest,
        redactionPolicy: RedactionPolicyBinding,
        redactionMetadata: ReviewRedactionMetadata,
        actorID: ActorID,
        principalID: PrincipalID,
        role: String,
        envelope: ReviewerEnvelopeBinding,
        complete: Bool,
        findings: [ReviewerFinding]
    ) throws {
        let sorted = try findings.sorted {
            let lhs = try IssueFingerprint.derive(from: $0.components).rawValue
            let rhs = try IssueFingerprint.derive(from: $1.components).rawValue
            return (lhs, $0.findingID) < (rhs, $1.findingID)
        }
        guard WorkflowIdentifier.isValid(role),
              Set(sorted.map(\.findingID)).count == sorted.count
        else { throw WorkflowPolicyError.invalidPolicy }
        schemaVersion = 1
        self.baselineDigest = baselineDigest
        self.roundID = roundID
        self.rosterDigest = rosterDigest
        self.assignmentID = assignmentID
        self.checklistDigest = checklistDigest
        self.redactionPolicy = redactionPolicy
        self.redactionMetadata = redactionMetadata
        self.actorID = actorID
        self.principalID = principalID
        self.role = role
        self.envelope = envelope
        self.complete = complete
        self.findings = sorted
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 1 else {
            throw WorkflowPolicyError.invalidPolicy
        }
        let decodedFindings = try values.decode([ReviewerFinding].self, forKey: .findings)
        try self.init(
            baselineDigest: values.decode(HashDigest.self, forKey: .baselineDigest),
            roundID: values.decode(ReviewRoundID.self, forKey: .roundID),
            rosterDigest: values.decode(HashDigest.self, forKey: .rosterDigest),
            assignmentID: values.decode(ReviewAssignmentID.self, forKey: .assignmentID),
            checklistDigest: values.decode(HashDigest.self, forKey: .checklistDigest),
            redactionPolicy: values.decode(RedactionPolicyBinding.self, forKey: .redactionPolicy),
            redactionMetadata: values.decode(ReviewRedactionMetadata.self, forKey: .redactionMetadata),
            actorID: values.decode(ActorID.self, forKey: .actorID),
            principalID: values.decode(PrincipalID.self, forKey: .principalID),
            role: values.decode(String.self, forKey: .role),
            envelope: values.decode(ReviewerEnvelopeBinding.self, forKey: .envelope),
            complete: values.decode(Bool.self, forKey: .complete),
            findings: decodedFindings
        )
        guard decodedFindings == findings else { throw WorkflowPolicyError.invalidPolicy }
    }

    public func canonicalDigest() throws -> HashDigest {
        CanonicalTreeDigest.sha256(try CanonicalJSON.encode(self))
    }

    public static func decodeCanonical(from bytes: Data) throws -> ReviewerFindingSubmission {
        try artifactDecodeCanonical(Self.self, from: bytes)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case baselineDigest = "baseline_digest"
        case roundID = "round_id"
        case rosterDigest = "roster_digest"
        case assignmentID = "assignment_id"
        case checklistDigest = "checklist_digest"
        case redactionPolicy = "redaction_policy"
        case redactionMetadata = "redaction_metadata"
        case actorID = "actor_id"
        case principalID = "principal_id"
        case role
        case envelope
        case complete
        case findings
    }
}

public struct ReviewerFindingInventory: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let baselineDigest: HashDigest
    public let roundID: ReviewRoundID
    public let rosterDigest: HashDigest
    public let assignmentID: ReviewAssignmentID
    public let checklistDigest: HashDigest
    public let redactionPolicy: RedactionPolicyBinding
    public let redactionMetadata: ReviewRedactionMetadata
    public let actorID: ActorID
    public let principalID: PrincipalID
    public let role: String
    public let envelope: ReviewerEnvelopeBinding
    public let complete: Bool
    public let findings: [ReviewerFinding]
    public let submissionDigest: HashDigest
    public let digest: HashDigest

    private init(payload: ReviewerFindingInventoryPayload, digest: HashDigest) {
        schemaVersion = payload.schemaVersion
        baselineDigest = payload.baselineDigest
        roundID = payload.roundID
        rosterDigest = payload.rosterDigest
        assignmentID = payload.assignmentID
        checklistDigest = payload.checklistDigest
        redactionPolicy = payload.redactionPolicy
        redactionMetadata = payload.redactionMetadata
        actorID = payload.actorID
        principalID = payload.principalID
        role = payload.role
        envelope = payload.envelope
        complete = payload.complete
        findings = payload.findings
        submissionDigest = payload.submissionDigest
        self.digest = digest
    }

    public static func ingest(
        submission: ReviewerFindingSubmission,
        against baseline: ReviewBaseline,
        authority: VerifiedReviewerInventoryAuthority
    ) throws -> ReviewerFindingInventory {
        guard let assignment = baseline.roster.assignments.first(where: {
            $0.id == submission.assignmentID
        }),
            submission.baselineDigest == baseline.digest,
            submission.roundID == baseline.roundID,
            submission.rosterDigest == baseline.rosterDigest,
            submission.checklistDigest == assignment.checklistDigest,
            submission.redactionPolicy == baseline.redactionPolicy,
            submission.redactionMetadata.policy == baseline.redactionPolicy,
            !submission.redactionMetadata.containsRawSensitiveData,
            submission.actorID == assignment.expectedActorID,
            submission.principalID == assignment.expectedPrincipalID,
            submission.role == assignment.requiredRole,
            submission.complete,
            authority.submissionDigest == (try submission.canonicalDigest()),
            authority.baselineDigest == baseline.digest,
            authority.roundID == baseline.roundID,
            authority.assignmentID == assignment.id,
            authority.baselineEventHead == baseline.preCreationEventHead,
            authority.currentArtifactSetDigest == CanonicalTreeDigest.sha256(
                try CanonicalJSON.encode(baseline.artifactScopes)
            ),
            authority.envelopeReceiptDigests == [
                submission.envelope.effectReceipt.digest,
                submission.envelope.domainReceipt.digest,
                submission.envelope.recordReceipt.digest,
            ].sorted(by: { $0.rawValue < $1.rawValue })
        else { throw WorkflowPolicyError.invalidPolicy }
        let payload = try ReviewerFindingInventoryPayload(submission: submission)
        return ReviewerFindingInventory(
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
        let decodedFindings = try values.decode([ReviewerFinding].self, forKey: .findings)
        let submission = try ReviewerFindingSubmission(
            baselineDigest: values.decode(HashDigest.self, forKey: .baselineDigest),
            roundID: values.decode(ReviewRoundID.self, forKey: .roundID),
            rosterDigest: values.decode(HashDigest.self, forKey: .rosterDigest),
            assignmentID: values.decode(ReviewAssignmentID.self, forKey: .assignmentID),
            checklistDigest: values.decode(HashDigest.self, forKey: .checklistDigest),
            redactionPolicy: values.decode(RedactionPolicyBinding.self, forKey: .redactionPolicy),
            redactionMetadata: values.decode(ReviewRedactionMetadata.self, forKey: .redactionMetadata),
            actorID: values.decode(ActorID.self, forKey: .actorID),
            principalID: values.decode(PrincipalID.self, forKey: .principalID),
            role: values.decode(String.self, forKey: .role),
            envelope: values.decode(ReviewerEnvelopeBinding.self, forKey: .envelope),
            complete: values.decode(Bool.self, forKey: .complete),
            findings: decodedFindings
        )
        let payload = try ReviewerFindingInventoryPayload(submission: submission)
        let decodedSubmissionDigest = try values.decode(HashDigest.self, forKey: .submissionDigest)
        let decodedDigest = try values.decode(HashDigest.self, forKey: .digest)
        let candidate = ReviewerFindingInventory(
            payload: payload,
            digest: CanonicalTreeDigest.sha256(try CanonicalJSON.encode(payload))
        )
        guard decodedFindings == submission.findings,
              submission.complete,
              !submission.redactionMetadata.containsRawSensitiveData,
              decodedSubmissionDigest == payload.submissionDigest,
              decodedDigest == candidate.digest
        else { throw WorkflowPolicyError.invalidPolicy }
        self = candidate
    }

    public static func decodeCanonical(from bytes: Data) throws -> ReviewerFindingInventory {
        try artifactDecodeCanonical(Self.self, from: bytes)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case baselineDigest = "baseline_digest"
        case roundID = "round_id"
        case rosterDigest = "roster_digest"
        case assignmentID = "assignment_id"
        case checklistDigest = "checklist_digest"
        case redactionPolicy = "redaction_policy"
        case redactionMetadata = "redaction_metadata"
        case actorID = "actor_id"
        case principalID = "principal_id"
        case role
        case envelope
        case complete
        case findings
        case submissionDigest = "submission_digest"
        case digest = "inventory_digest"
    }
}

private struct ReviewerFindingInventoryPayload: Codable {
    let schemaVersion: Int
    let baselineDigest: HashDigest
    let roundID: ReviewRoundID
    let rosterDigest: HashDigest
    let assignmentID: ReviewAssignmentID
    let checklistDigest: HashDigest
    let redactionPolicy: RedactionPolicyBinding
    let redactionMetadata: ReviewRedactionMetadata
    let actorID: ActorID
    let principalID: PrincipalID
    let role: String
    let envelope: ReviewerEnvelopeBinding
    let complete: Bool
    let findings: [ReviewerFinding]
    let submissionDigest: HashDigest

    init(submission: ReviewerFindingSubmission) throws {
        schemaVersion = 1
        baselineDigest = submission.baselineDigest
        roundID = submission.roundID
        rosterDigest = submission.rosterDigest
        assignmentID = submission.assignmentID
        checklistDigest = submission.checklistDigest
        redactionPolicy = submission.redactionPolicy
        redactionMetadata = submission.redactionMetadata
        actorID = submission.actorID
        principalID = submission.principalID
        role = submission.role
        envelope = submission.envelope
        complete = submission.complete
        findings = submission.findings
        submissionDigest = try submission.canonicalDigest()
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case baselineDigest = "baseline_digest"
        case roundID = "round_id"
        case rosterDigest = "roster_digest"
        case assignmentID = "assignment_id"
        case checklistDigest = "checklist_digest"
        case redactionPolicy = "redaction_policy"
        case redactionMetadata = "redaction_metadata"
        case actorID = "actor_id"
        case principalID = "principal_id"
        case role
        case envelope
        case complete
        case findings
        case submissionDigest = "submission_digest"
    }
}

public struct VerifiedCompleteInventorySet: Sendable {
    public let inventories: [ReviewerFindingInventory]
    let baselineDigest: HashDigest
    let roundID: ReviewRoundID
    let rosterDigest: HashDigest
    let currentArtifactSetDigest: HashDigest
    let currentEventHead: HashDigest
    let authorities: [VerifiedReviewerInventoryAuthority]

    init(
        inventories: [ReviewerFindingInventory],
        baseline: ReviewBaseline,
        currentness: VerifiedReviewScopeCurrentness,
        authorities: [VerifiedReviewerInventoryAuthority]
    ) {
        self.inventories = inventories
        baselineDigest = baseline.digest
        roundID = baseline.roundID
        rosterDigest = baseline.rosterDigest
        currentArtifactSetDigest = currentness.currentArtifactSetDigest
        currentEventHead = currentness.currentEventHead
        self.authorities = authorities
    }
}

public enum ReviewInventoryCollectionResult: Sendable {
    case pending([ReviewAssignmentID])
    case complete(VerifiedCompleteInventorySet)
}

public struct ReviewInventoryCollector: Sendable {
    public let baseline: ReviewBaseline
    private var inventoriesByAssignment: [ReviewAssignmentID: ReviewerFindingInventory] = [:]
    private var authoritiesByAssignment: [ReviewAssignmentID: VerifiedReviewerInventoryAuthority] = [:]
    private var frozenCurrentness: VerifiedReviewScopeCurrentness?

    public init(baseline: ReviewBaseline) { self.baseline = baseline }

    public mutating func accept(
        _ inventory: ReviewerFindingInventory,
        authority: VerifiedReviewerInventoryAuthority,
        currentness: VerifiedReviewScopeCurrentness
    ) throws -> ReviewInventoryCollectionResult {
        guard let assignment = baseline.roster.assignments.first(where: {
            $0.id == inventory.assignmentID
        }),
              inventory.baselineDigest == baseline.digest,
              inventory.roundID == baseline.roundID,
              inventory.rosterDigest == baseline.rosterDigest,
              inventory.checklistDigest == assignment.checklistDigest,
              inventory.redactionPolicy == baseline.redactionPolicy,
              inventory.redactionMetadata.policy == baseline.redactionPolicy,
              !inventory.redactionMetadata.containsRawSensitiveData,
              inventory.actorID == assignment.expectedActorID,
              inventory.principalID == assignment.expectedPrincipalID,
              inventory.role == assignment.requiredRole,
              inventory.complete,
              authority.submissionDigest == inventory.submissionDigest,
              authority.baselineDigest == baseline.digest,
              authority.roundID == baseline.roundID,
              authority.assignmentID == inventory.assignmentID,
              authority.baselineEventHead == baseline.preCreationEventHead,
              authority.currentEventHead == currentness.currentEventHead,
              authority.currentArtifactSetDigest == currentness.currentArtifactSetDigest,
              currentness.runID == baseline.runID,
              currentness.baselineDigest == baseline.digest,
              currentness.currentArtifacts == baseline.artifactScopes
        else { throw WorkflowPolicyError.invalidPolicy }
        if let frozenCurrentness {
            guard frozenCurrentness == currentness else {
                throw WorkflowPolicyError.invalidPolicy
            }
        } else {
            frozenCurrentness = currentness
        }
        if let existing = inventoriesByAssignment[inventory.assignmentID] {
            guard try CanonicalJSON.encode(existing) == CanonicalJSON.encode(inventory),
                  authoritiesByAssignment[inventory.assignmentID] == authority
            else {
                throw WorkflowPolicyError.invalidPolicy
            }
            return try collectionResult()
        }
        inventoriesByAssignment[inventory.assignmentID] = inventory
        authoritiesByAssignment[inventory.assignmentID] = authority
        return try collectionResult()
    }

    private func collectionResult() throws -> ReviewInventoryCollectionResult {
        let required = baseline.roster.assignments.map(\.id)
        let missing = required.filter { inventoriesByAssignment[$0] == nil }
        guard missing.isEmpty else { return .pending(missing) }
        guard inventoriesByAssignment.count == required.count,
              authoritiesByAssignment.count == required.count,
              let currentness = frozenCurrentness
        else { throw WorkflowPolicyError.invalidPolicy }
        let inventories = try required.map { id -> ReviewerFindingInventory in
            guard let inventory = inventoriesByAssignment[id],
                  let authority = authoritiesByAssignment[id],
                  authority.submissionDigest == inventory.submissionDigest,
                  authority.assignmentID == id,
                  authority.baselineDigest == baseline.digest,
                  authority.roundID == baseline.roundID,
                  authority.currentEventHead == currentness.currentEventHead,
                  authority.currentArtifactSetDigest == currentness.currentArtifactSetDigest
            else { throw WorkflowPolicyError.invalidPolicy }
            return inventory
        }
        return .complete(
            VerifiedCompleteInventorySet(
                inventories: inventories,
                baseline: baseline,
                currentness: currentness,
                authorities: required.compactMap { authoritiesByAssignment[$0] }
            )
        )
    }
}

private func isCanonicalReviewFindingIdentity(_ value: String) -> Bool {
    let bytes = Array(value.utf8)
    guard let first = bytes.first,
          (65 ... 90).contains(first),
          bytes.last != 45
    else { return false }
    var sawSeparator = false
    var previousWasSeparator = false
    for byte in bytes {
        if byte == 45 {
            guard !previousWasSeparator else { return false }
            sawSeparator = true
            previousWasSeparator = true
        } else {
            guard (65 ... 90).contains(byte) || (48 ... 57).contains(byte) else {
                return false
            }
            previousWasSeparator = false
        }
    }
    return sawSeparator
}

private func isCanonicalReviewTimestamp(_ value: String) -> Bool {
    let bytes = Array(value.utf8)
    let digitPositions = Set([0, 1, 2, 3, 5, 6, 8, 9, 11, 12, 14, 15, 17, 18, 20, 21, 22])
    guard bytes.count == 24,
          bytes.enumerated().allSatisfy({ index, byte in
              digitPositions.contains(index) ? (48 ... 57).contains(byte) : true
          }),
          bytes[4] == 45,
          bytes[7] == 45,
          bytes[10] == 84,
          bytes[13] == 58,
          bytes[16] == 58,
          bytes[19] == 46,
          bytes[23] == 90
    else { return false }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = formatter.date(from: value) else { return false }
    return formatter.string(from: date) == value
}
