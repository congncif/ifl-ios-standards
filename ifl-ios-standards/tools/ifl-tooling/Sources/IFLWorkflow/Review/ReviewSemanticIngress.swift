import Foundation
import IFLContracts

/// Contextual ingress for review wire artifacts. Structural decode alone never grants trust.
public enum ReviewSemanticIngress {
    public static func verifyBaseline(
        bytes: Data,
        runID: RunID,
        roundInput: ReviewRoundInput,
        artifactScopes: [ArtifactReference],
        activeProfileDigest: HashDigest,
        riskPolicyDigest: HashDigest,
        assurancePolicyDigest: HashDigest,
        convergencePolicyDigest: HashDigest,
        roster: FrozenReviewerRoster
    ) throws -> ReviewBaseline {
        let decoded = try ReviewBaseline.decodeCanonical(from: bytes)
        let expected = try ReviewBaseline.freeze(
            runID: runID,
            roundInput: roundInput,
            artifactScopes: artifactScopes,
            activeProfileDigest: activeProfileDigest,
            riskPolicyDigest: riskPolicyDigest,
            assurancePolicyDigest: assurancePolicyDigest,
            convergencePolicyDigest: convergencePolicyDigest,
            roster: roster
        )
        guard decoded == expected, try CanonicalJSON.encode(expected) == bytes else {
            throw WorkflowPolicyError.invalidPolicy
        }
        return expected
    }

    public static func verifyInventory(
        bytes: Data,
        baseline: ReviewBaseline,
        authority: VerifiedReviewerInventoryAuthority
    ) throws -> ReviewerFindingInventory {
        let decoded = try ReviewerFindingInventory.decodeCanonical(from: bytes)
        let submission = try ReviewerFindingSubmission(
            baselineDigest: decoded.baselineDigest,
            roundID: decoded.roundID,
            rosterDigest: decoded.rosterDigest,
            assignmentID: decoded.assignmentID,
            checklistDigest: decoded.checklistDigest,
            redactionPolicy: decoded.redactionPolicy,
            redactionMetadata: decoded.redactionMetadata,
            actorID: decoded.actorID,
            principalID: decoded.principalID,
            role: decoded.role,
            envelope: decoded.envelope,
            complete: decoded.complete,
            findings: decoded.findings
        )
        let expected = try ReviewerFindingInventory.ingest(
            submission: submission,
            against: baseline,
            authority: authority
        )
        guard decoded == expected, try CanonicalJSON.encode(expected) == bytes else {
            throw WorkflowPolicyError.invalidPolicy
        }
        return expected
    }

    public static func verifyRegister(
        bytes: Data,
        baseline: ReviewBaseline,
        inventories: VerifiedCompleteInventorySet,
        policies: VerifiedReviewPolicySet,
        dispositionEvidence: [VerifiedReviewDispositionEvidence]
    ) throws -> VerifiedIssueRegister {
        let decoded = try IssueRegister.decodeCanonical(from: bytes)
        let expected = try IssueRegister.issue(
            baseline: baseline,
            inventories: inventories,
            policies: policies,
            dispositionEvidence: dispositionEvidence
        )
        guard decoded == expected, try CanonicalJSON.encode(expected) == bytes else {
            throw WorkflowPolicyError.invalidDispositionEvidence
        }
        return try VerifiedIssueRegister(
            register: expected,
            baseline: baseline,
            inventories: inventories,
            policies: policies
        )
    }

    public static func verifyRemediationBatch(
        bytes: Data,
        successor: VerifiedRemediationSuccessor
    ) throws -> VerifiedRemediationSuccessor {
        let decoded = try RemediationBatch.decodeCanonical(from: bytes)
        guard decoded == successor.batch,
              try CanonicalJSON.encode(successor.batch) == bytes
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
        return successor
    }

    public static func verifyConfirmationReceipt(
        bytes: Data,
        successor: VerifiedCommittedRemediationSuccessor,
        confirmationRegister: VerifiedIssueRegister,
        authority: VerifiedReviewReceiptAuthority
    ) throws -> VerifiedReviewReceipt {
        let expected = try ReviewConvergenceValidator.issueConfirmation(
            successor: successor,
            confirmationRegister: confirmationRegister,
            authority: authority,
            publicationAnchorEventHead: authority.eventHead
        )
        guard try ConfirmationReceipt.decodeCanonical(from: bytes) == expected,
              try CanonicalJSON.encode(expected) == bytes
        else { throw WorkflowPolicyError.invalidPolicy }
        let id = try ReceiptID(validating: expected.receiptID)
        return try ReviewReceiptVerifier.verify(
            kind: ReceiptKind(validating: "review-confirmation"),
            id: id,
            payloadBytes: bytes,
            runID: successor.successorBaseline.runID,
            eventID: expected.receiptID,
            eventKind: .reviewConfirmationRecorded,
            eventHead: expected.publicationAnchorEventHead
        )
    }

    public static func verifyConvergenceReceipt(
        bytes: Data,
        lineage: VerifiedConfirmationLineage,
        authority: VerifiedReviewReceiptAuthority
    ) throws -> VerifiedReviewReceipt {
        let expected = try ReviewConvergenceValidator.issueConfirmedConvergence(
            lineage: lineage,
            authority: authority,
            publicationAnchorEventHead: authority.eventHead
        )
        guard let baseline = lineage.baselines.first,
              try ConvergenceReceipt.decodeCanonical(from: bytes) == expected,
              try CanonicalJSON.encode(expected) == bytes
        else { throw WorkflowPolicyError.invalidPolicy }
        let id = try ReceiptID(validating: expected.receiptID)
        return try ReviewReceiptVerifier.verify(
            kind: ReceiptKind(validating: "review-convergence"),
            id: id,
            payloadBytes: bytes,
            runID: baseline.runID,
            eventID: expected.receiptID,
            eventKind: .reviewConverged,
            eventHead: expected.publicationAnchorEventHead
        )
    }

    public static func verifyConvergenceReceipt(
        bytes: Data,
        register: VerifiedIssueRegister,
        authority: VerifiedReviewReceiptAuthority
    ) throws -> VerifiedReviewReceipt {
        let decoded = try ConvergenceReceipt.decodeCanonical(from: bytes)
        let expected = try ReviewConvergenceValidator.issueDirectConvergence(
            register: register,
            authority: authority,
            publicationAnchorEventHead: authority.eventHead
        )
        guard decoded == expected, try CanonicalJSON.encode(expected) == bytes else {
            throw WorkflowPolicyError.invalidPolicy
        }
        let id = try ReceiptID(validating: expected.receiptID)
        return try ReviewReceiptVerifier.verify(
            kind: ReceiptKind(validating: "review-convergence"),
            id: id,
            payloadBytes: bytes,
            runID: register.baseline.runID,
            eventID: expected.receiptID,
            eventKind: .reviewConverged,
            eventHead: expected.publicationAnchorEventHead
        )
    }
}
