import Foundation
import IFLContracts

public enum ConvergencePathKind: String, Codable, Hashable, Sendable {
    case directConvergenceNoAcceptedCurrentScope = "direct_convergence_no_accepted_current_scope"
    case confirmedRemediation = "confirmed_remediation"
}

public struct ConfirmationReceipt: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let receiptID: String
    public let successorBaselineDigest: HashDigest
    public let roundID: ReviewRoundID
    public let rosterDigest: HashDigest
    public let confirmationRegisterDigest: HashDigest
    public let remediationBatchDigest: HashDigest
    public let currentArtifactSetDigest: HashDigest
    public let currentApprovalSetDigest: HashDigest
    public let authorityPolicyDigest: HashDigest
    public let publicationAnchorEventHead: HashDigest
    public let digest: HashDigest

    fileprivate init(payload: ConfirmationReceiptPayload, digest: HashDigest) {
        schemaVersion = payload.schemaVersion
        receiptID = payload.receiptID
        successorBaselineDigest = payload.successorBaselineDigest
        roundID = payload.roundID
        rosterDigest = payload.rosterDigest
        confirmationRegisterDigest = payload.confirmationRegisterDigest
        remediationBatchDigest = payload.remediationBatchDigest
        currentArtifactSetDigest = payload.currentArtifactSetDigest
        currentApprovalSetDigest = payload.currentApprovalSetDigest
        authorityPolicyDigest = payload.authorityPolicyDigest
        publicationAnchorEventHead = payload.publicationAnchorEventHead
        self.digest = digest
    }

    static func issue(
        successorBaseline: ReviewBaseline,
        confirmationRegister: IssueRegister,
        remediationBatch: RemediationBatch,
        currentArtifactSetDigest: HashDigest,
        approvalSetDigest: HashDigest,
        authorityPolicyDigest: HashDigest,
        publicationAnchorEventHead: HashDigest
    ) throws -> ConfirmationReceipt {
        let lineageIdentityDigest = try confirmationLineageIdentityDigest(
            successorBaselineDigest: successorBaseline.digest,
            roundID: successorBaseline.roundID,
            rosterDigest: successorBaseline.rosterDigest,
            confirmationRegisterDigest: confirmationRegister.digest,
            remediationBatchDigest: remediationBatch.digest,
            currentArtifactSetDigest: currentArtifactSetDigest,
            currentApprovalSetDigest: approvalSetDigest,
            authorityPolicyDigest: authorityPolicyDigest
        )
        let payload = ConfirmationReceiptPayload(
            schemaVersion: 2,
            receiptID: try ReviewReceiptIdentity.receiptID(
                prefix: "review-confirmation-",
                receiptSchemaIdentity: "urn:ifl:standards:schema:review-confirmation-receipt:v2",
                receiptKind: "review-confirmation",
                logicalPathKind: "normal_confirmation",
                runID: successorBaseline.runID,
                cycleID: successorBaseline.cycleID,
                gate: successorBaseline.gate,
                lineageIdentityDigest: lineageIdentityDigest,
                publicationAnchorEventHead: publicationAnchorEventHead
            ),
            successorBaselineDigest: successorBaseline.digest,
            roundID: successorBaseline.roundID,
            rosterDigest: successorBaseline.rosterDigest,
            confirmationRegisterDigest: confirmationRegister.digest,
            remediationBatchDigest: remediationBatch.digest,
            currentArtifactSetDigest: currentArtifactSetDigest,
            currentApprovalSetDigest: approvalSetDigest,
            authorityPolicyDigest: authorityPolicyDigest,
            publicationAnchorEventHead: publicationAnchorEventHead
        )
        try validate(payload)
        return ConfirmationReceipt(
            payload: payload,
            digest: CanonicalTreeDigest.sha256(try CanonicalJSON.encode(payload))
        )
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 2 else {
            throw WorkflowPolicyError.invalidPolicy
        }
        let payload = try ConfirmationReceiptPayload(
            schemaVersion: 2,
            receiptID: values.decode(String.self, forKey: .receiptID),
            successorBaselineDigest: values.decode(HashDigest.self, forKey: .successorBaselineDigest),
            roundID: values.decode(ReviewRoundID.self, forKey: .roundID),
            rosterDigest: values.decode(HashDigest.self, forKey: .rosterDigest),
            confirmationRegisterDigest: values.decode(HashDigest.self, forKey: .confirmationRegisterDigest),
            remediationBatchDigest: values.decode(HashDigest.self, forKey: .remediationBatchDigest),
            currentArtifactSetDigest: values.decode(HashDigest.self, forKey: .currentArtifactSetDigest),
            currentApprovalSetDigest: values.decode(HashDigest.self, forKey: .currentApprovalSetDigest),
            authorityPolicyDigest: values.decode(HashDigest.self, forKey: .authorityPolicyDigest),
            publicationAnchorEventHead: values.decode(
                HashDigest.self,
                forKey: .publicationAnchorEventHead
            )
        )
        try Self.validate(payload)
        let decodedDigest = try values.decode(HashDigest.self, forKey: .digest)
        guard decodedDigest == CanonicalTreeDigest.sha256(try CanonicalJSON.encode(payload)) else {
            throw WorkflowPolicyError.invalidPolicy
        }
        self.init(payload: payload, digest: decodedDigest)
    }

    public static func decodeCanonical(from bytes: Data) throws -> ConfirmationReceipt {
        try artifactDecodeCanonical(Self.self, from: bytes)
    }

    private static func validate(_ payload: ConfirmationReceiptPayload) throws {
        _ = try ReceiptID(validating: payload.receiptID)
        guard payload.schemaVersion == 2 else {
            throw WorkflowPolicyError.invalidPolicy
        }
    }

    func hasValidIdentity(runID: RunID, cycleID: ReviewCycleID, gate: ReviewGateKind) throws -> Bool {
        receiptID == (try ReviewReceiptIdentity.receiptID(
            prefix: "review-confirmation-",
            receiptSchemaIdentity: "urn:ifl:standards:schema:review-confirmation-receipt:v2",
            receiptKind: "review-confirmation",
            logicalPathKind: "normal_confirmation",
            runID: runID,
            cycleID: cycleID,
            gate: gate,
            lineageIdentityDigest: confirmationLineageIdentityDigest(
                successorBaselineDigest: successorBaselineDigest,
                roundID: roundID,
                rosterDigest: rosterDigest,
                confirmationRegisterDigest: confirmationRegisterDigest,
                remediationBatchDigest: remediationBatchDigest,
                currentArtifactSetDigest: currentArtifactSetDigest,
                currentApprovalSetDigest: currentApprovalSetDigest,
                authorityPolicyDigest: authorityPolicyDigest
            ),
            publicationAnchorEventHead: publicationAnchorEventHead
        ))
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case receiptID = "receipt_id"
        case successorBaselineDigest = "successor_baseline_digest"
        case roundID = "round_id"
        case rosterDigest = "roster_digest"
        case confirmationRegisterDigest = "confirmation_register_digest"
        case remediationBatchDigest = "remediation_batch_digest"
        case currentArtifactSetDigest = "current_artifact_set_digest"
        case currentApprovalSetDigest = "current_approval_set_digest"
        case authorityPolicyDigest = "authority_policy_digest"
        case publicationAnchorEventHead = "publication_anchor_event_head"
        case digest = "confirmation_digest"
    }
}

private struct ConfirmationReceiptPayload: Codable {
    let schemaVersion: Int
    let receiptID: String
    let successorBaselineDigest: HashDigest
    let roundID: ReviewRoundID
    let rosterDigest: HashDigest
    let confirmationRegisterDigest: HashDigest
    let remediationBatchDigest: HashDigest
    let currentArtifactSetDigest: HashDigest
    let currentApprovalSetDigest: HashDigest
    let authorityPolicyDigest: HashDigest
    let publicationAnchorEventHead: HashDigest

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case receiptID = "receipt_id"
        case successorBaselineDigest = "successor_baseline_digest"
        case roundID = "round_id"
        case rosterDigest = "roster_digest"
        case confirmationRegisterDigest = "confirmation_register_digest"
        case remediationBatchDigest = "remediation_batch_digest"
        case currentArtifactSetDigest = "current_artifact_set_digest"
        case currentApprovalSetDigest = "current_approval_set_digest"
        case authorityPolicyDigest = "authority_policy_digest"
        case publicationAnchorEventHead = "publication_anchor_event_head"
    }
}

public struct ConvergenceReceipt: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let receiptID: String
    public let path: ConvergencePathKind
    public let baselineLineage: [HashDigest]
    public let registerDigests: [HashDigest]
    public let remediationBatchDigests: [HashDigest]
    public let confirmationReceiptDigest: HashDigest?
    public let exceptionProofDigests: [HashDigest]
    public let currentArtifactSetDigest: HashDigest
    public let currentApprovalSetDigest: HashDigest
    public let authorityPolicyDigest: HashDigest
    public let publicationAnchorEventHead: HashDigest
    public let digest: HashDigest

    init(payload: ConvergenceReceiptPayload, digest: HashDigest) {
        schemaVersion = payload.schemaVersion
        receiptID = payload.receiptID
        path = payload.path
        baselineLineage = payload.baselineLineage
        registerDigests = payload.registerDigests
        remediationBatchDigests = payload.remediationBatchDigests
        confirmationReceiptDigest = payload.confirmationReceiptDigest
        exceptionProofDigests = payload.exceptionProofDigests
        currentArtifactSetDigest = payload.currentArtifactSetDigest
        currentApprovalSetDigest = payload.currentApprovalSetDigest
        authorityPolicyDigest = payload.authorityPolicyDigest
        publicationAnchorEventHead = payload.publicationAnchorEventHead
        self.digest = digest
    }

    static func issue(payload: ConvergenceReceiptPayload) throws -> ConvergenceReceipt {
        try validate(payload)
        return ConvergenceReceipt(
            payload: payload,
            digest: CanonicalTreeDigest.sha256(try CanonicalJSON.encode(payload))
        )
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 2 else {
            throw WorkflowPolicyError.invalidPolicy
        }
        let payload = try ConvergenceReceiptPayload(
            schemaVersion: 2,
            receiptID: values.decode(String.self, forKey: .receiptID),
            path: values.decode(ConvergencePathKind.self, forKey: .path),
            baselineLineage: values.decode([HashDigest].self, forKey: .baselineLineage),
            registerDigests: values.decode([HashDigest].self, forKey: .registerDigests),
            remediationBatchDigests: values.decode(
                [HashDigest].self,
                forKey: .remediationBatchDigests
            ),
            confirmationReceiptDigest: values.decodeIfPresent(HashDigest.self, forKey: .confirmationReceiptDigest),
            exceptionProofDigests: values.decode([HashDigest].self, forKey: .exceptionProofDigests),
            currentArtifactSetDigest: values.decode(HashDigest.self, forKey: .currentArtifactSetDigest),
            currentApprovalSetDigest: values.decode(HashDigest.self, forKey: .currentApprovalSetDigest),
            authorityPolicyDigest: values.decode(HashDigest.self, forKey: .authorityPolicyDigest),
            publicationAnchorEventHead: values.decode(
                HashDigest.self,
                forKey: .publicationAnchorEventHead
            )
        )
        try Self.validate(payload)
        self.init(
            payload: payload,
            digest: CanonicalTreeDigest.sha256(try CanonicalJSON.encode(payload))
        )
    }

    public func encode(to encoder: any Encoder) throws {
        try payload.encode(to: encoder)
    }

    public static func decodeCanonical(from bytes: Data) throws -> ConvergenceReceipt {
        try artifactDecodeCanonical(Self.self, from: bytes)
    }

    private var payload: ConvergenceReceiptPayload {
        ConvergenceReceiptPayload(
            schemaVersion: schemaVersion,
            receiptID: receiptID,
            path: path,
            baselineLineage: baselineLineage,
            registerDigests: registerDigests,
            remediationBatchDigests: remediationBatchDigests,
            confirmationReceiptDigest: confirmationReceiptDigest,
            exceptionProofDigests: exceptionProofDigests,
            currentArtifactSetDigest: currentArtifactSetDigest,
            currentApprovalSetDigest: currentApprovalSetDigest,
            authorityPolicyDigest: authorityPolicyDigest,
            publicationAnchorEventHead: publicationAnchorEventHead
        )
    }

    private static func validate(_ payload: ConvergenceReceiptPayload) throws {
        _ = try ReceiptID(validating: payload.receiptID)
        guard payload.schemaVersion == 2,
              !payload.baselineLineage.isEmpty,
              !payload.registerDigests.isEmpty,
              Set(payload.baselineLineage).count == payload.baselineLineage.count,
              Set(payload.registerDigests).count == payload.registerDigests.count,
              Set(payload.exceptionProofDigests).count == payload.exceptionProofDigests.count
        else { throw WorkflowPolicyError.invalidPolicy }
        switch payload.path {
        case .directConvergenceNoAcceptedCurrentScope:
            guard payload.baselineLineage.count == 1,
                  payload.registerDigests.count == 1,
                  payload.remediationBatchDigests.isEmpty,
                  payload.confirmationReceiptDigest == nil,
                  payload.exceptionProofDigests.isEmpty
            else { throw WorkflowPolicyError.invalidPolicy }
        case .confirmedRemediation:
            guard payload.baselineLineage.count >= 2,
                  payload.registerDigests.count == payload.baselineLineage.count,
                  payload.exceptionProofDigests.count == payload.baselineLineage.count - 2,
                  !payload.remediationBatchDigests.isEmpty,
                  Set(payload.remediationBatchDigests).count == payload.remediationBatchDigests.count,
                  payload.confirmationReceiptDigest != nil
            else { throw WorkflowPolicyError.invalidPolicy }
        }
    }

    static func deterministicReceiptID(
        payload: ConvergenceReceiptPayload,
        runID: RunID,
        cycleID: ReviewCycleID,
        gate: ReviewGateKind
    ) throws -> String {
        try ReviewReceiptIdentity.receiptID(
            prefix: "review-convergence-",
            receiptSchemaIdentity: "urn:ifl:standards:schema:review-convergence-receipt:v2",
            receiptKind: "review-convergence",
            logicalPathKind: payload.path.rawValue,
            runID: runID,
            cycleID: cycleID,
            gate: gate,
            lineageIdentityDigest: convergenceLineageIdentityDigest(payload),
            publicationAnchorEventHead: payload.publicationAnchorEventHead
        )
    }

    func hasValidIdentity(runID: RunID, cycleID: ReviewCycleID, gate: ReviewGateKind) throws -> Bool {
        receiptID == (try Self.deterministicReceiptID(
            payload: payload,
            runID: runID,
            cycleID: cycleID,
            gate: gate
        ))
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case receiptID = "receipt_id"
        case path = "path_kind"
        case baselineLineage = "baseline_lineage"
        case registerDigests = "register_digests"
        case remediationBatchDigests = "remediation_batch_digests"
        case confirmationReceiptDigest = "confirmation_receipt_digest"
        case exceptionProofDigests = "exception_proof_digests"
        case currentArtifactSetDigest = "current_artifact_set_digest"
        case currentApprovalSetDigest = "current_approval_set_digest"
        case authorityPolicyDigest = "authority_policy_digest"
        case publicationAnchorEventHead = "publication_anchor_event_head"
    }
}

struct ConvergenceReceiptPayload: Codable {
    let schemaVersion: Int
    let receiptID: String
    let path: ConvergencePathKind
    let baselineLineage: [HashDigest]
    let registerDigests: [HashDigest]
    let remediationBatchDigests: [HashDigest]
    let confirmationReceiptDigest: HashDigest?
    let exceptionProofDigests: [HashDigest]
    let currentArtifactSetDigest: HashDigest
    let currentApprovalSetDigest: HashDigest
    let authorityPolicyDigest: HashDigest
    let publicationAnchorEventHead: HashDigest

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case receiptID = "receipt_id"
        case path = "path_kind"
        case baselineLineage = "baseline_lineage"
        case registerDigests = "register_digests"
        case remediationBatchDigests = "remediation_batch_digests"
        case confirmationReceiptDigest = "confirmation_receipt_digest"
        case exceptionProofDigests = "exception_proof_digests"
        case currentArtifactSetDigest = "current_artifact_set_digest"
        case currentApprovalSetDigest = "current_approval_set_digest"
        case authorityPolicyDigest = "authority_policy_digest"
        case publicationAnchorEventHead = "publication_anchor_event_head"
    }
}

private enum ReviewReceiptIdentity {
    static func receiptID(
        prefix: String,
        receiptSchemaIdentity: String,
        receiptKind: String,
        logicalPathKind: String,
        runID: RunID,
        cycleID: ReviewCycleID,
        gate: ReviewGateKind,
        lineageIdentityDigest: HashDigest,
        publicationAnchorEventHead: HashDigest
    ) throws -> String {
        let preimage = ReviewReceiptIdentityPreimage(
            identitySchema: "urn:ifl:workflow:review-receipt-identity:v1",
            lineageIdentityDigest: lineageIdentityDigest,
            logicalPathKind: logicalPathKind,
            publicationAnchorEventHead: publicationAnchorEventHead,
            receiptKind: receiptKind,
            receiptSchemaIdentity: receiptSchemaIdentity,
            reviewCycleID: cycleID,
            reviewGate: gate,
            runID: runID
        )
        return prefix + CanonicalTreeDigest.sha256(try CanonicalJSON.encode(preimage)).rawValue
    }
}

private struct ReviewReceiptIdentityPreimage: Codable {
    let identitySchema: String
    let lineageIdentityDigest: HashDigest
    let logicalPathKind: String
    let publicationAnchorEventHead: HashDigest
    let receiptKind: String
    let receiptSchemaIdentity: String
    let reviewCycleID: ReviewCycleID
    let reviewGate: ReviewGateKind
    let runID: RunID

    enum CodingKeys: String, CodingKey {
        case identitySchema = "identity_schema"
        case lineageIdentityDigest = "lineage_identity_digest"
        case logicalPathKind = "logical_path_kind"
        case publicationAnchorEventHead = "publication_anchor_event_head"
        case receiptKind = "receipt_kind"
        case receiptSchemaIdentity = "receipt_schema_identity"
        case reviewCycleID = "review_cycle_id"
        case reviewGate = "review_gate"
        case runID = "run_id"
    }
}

private struct ConfirmationLineageIdentity: Codable {
    let authorityPolicyDigest: HashDigest
    let confirmationRegisterDigest: HashDigest
    let currentApprovalSetDigest: HashDigest
    let currentArtifactSetDigest: HashDigest
    let remediationBatchDigest: HashDigest
    let rosterDigest: HashDigest
    let roundID: ReviewRoundID
    let successorBaselineDigest: HashDigest

    enum CodingKeys: String, CodingKey {
        case authorityPolicyDigest = "authority_policy_digest"
        case confirmationRegisterDigest = "confirmation_register_digest"
        case currentApprovalSetDigest = "current_approval_set_digest"
        case currentArtifactSetDigest = "current_artifact_set_digest"
        case remediationBatchDigest = "remediation_batch_digest"
        case rosterDigest = "roster_digest"
        case roundID = "round_id"
        case successorBaselineDigest = "successor_baseline_digest"
    }
}

private func confirmationLineageIdentityDigest(
    successorBaselineDigest: HashDigest,
    roundID: ReviewRoundID,
    rosterDigest: HashDigest,
    confirmationRegisterDigest: HashDigest,
    remediationBatchDigest: HashDigest,
    currentArtifactSetDigest: HashDigest,
    currentApprovalSetDigest: HashDigest,
    authorityPolicyDigest: HashDigest
) throws -> HashDigest {
    CanonicalTreeDigest.sha256(try CanonicalJSON.encode(ConfirmationLineageIdentity(
        authorityPolicyDigest: authorityPolicyDigest,
        confirmationRegisterDigest: confirmationRegisterDigest,
        currentApprovalSetDigest: currentApprovalSetDigest,
        currentArtifactSetDigest: currentArtifactSetDigest,
        remediationBatchDigest: remediationBatchDigest,
        rosterDigest: rosterDigest,
        roundID: roundID,
        successorBaselineDigest: successorBaselineDigest
    )))
}

private struct ConvergenceLineageIdentity: Codable {
    let authorityPolicyDigest: HashDigest
    let baselineLineage: [HashDigest]
    let confirmationReceiptDigest: HashDigest?
    let currentApprovalSetDigest: HashDigest
    let currentArtifactSetDigest: HashDigest
    let exceptionProofDigests: [HashDigest]
    let path: ConvergencePathKind
    let registerDigests: [HashDigest]
    let remediationBatchDigests: [HashDigest]

    enum CodingKeys: String, CodingKey {
        case authorityPolicyDigest = "authority_policy_digest"
        case baselineLineage = "baseline_lineage"
        case confirmationReceiptDigest = "confirmation_receipt_digest"
        case currentApprovalSetDigest = "current_approval_set_digest"
        case currentArtifactSetDigest = "current_artifact_set_digest"
        case exceptionProofDigests = "exception_proof_digests"
        case path = "path_kind"
        case registerDigests = "register_digests"
        case remediationBatchDigests = "remediation_batch_digests"
    }
}

private func convergenceLineageIdentityDigest(
    _ payload: ConvergenceReceiptPayload
) throws -> HashDigest {
    CanonicalTreeDigest.sha256(try CanonicalJSON.encode(ConvergenceLineageIdentity(
        authorityPolicyDigest: payload.authorityPolicyDigest,
        baselineLineage: payload.baselineLineage,
        confirmationReceiptDigest: payload.confirmationReceiptDigest,
        currentApprovalSetDigest: payload.currentApprovalSetDigest,
        currentArtifactSetDigest: payload.currentArtifactSetDigest,
        exceptionProofDigests: payload.exceptionProofDigests,
        path: payload.path,
        registerDigests: payload.registerDigests,
        remediationBatchDigests: payload.remediationBatchDigests
    )))
}
