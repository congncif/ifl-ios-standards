import Foundation
import IFLContracts

public struct ReviewInvalidationPlan: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let invalidationMutationDigest: HashDigest
    public let invalidatedBaselineDigests: [HashDigest]
    public let invalidatedInventoryDigests: [HashDigest]
    public let invalidatedRegisterDigests: [HashDigest]
    public let invalidatedRemediationBatchDigests: [HashDigest]
    public let invalidatedConfirmationReceiptDigests: [HashDigest]
    public let invalidatedExceptionProofDigests: [HashDigest]
    public let invalidatedConvergenceReceiptDigests: [HashDigest]
    public let invalidatedApprovalDigests: [HashDigest]
    public let requiresFreshInitialCycle: Bool
    public let remainsCurrent: Bool
    public let digest: HashDigest

    fileprivate init(payload: ReviewInvalidationPlanPayload, digest: HashDigest) {
        schemaVersion = payload.schemaVersion
        invalidationMutationDigest = payload.invalidationMutationDigest
        invalidatedBaselineDigests = payload.invalidatedBaselineDigests
        invalidatedInventoryDigests = payload.invalidatedInventoryDigests
        invalidatedRegisterDigests = payload.invalidatedRegisterDigests
        invalidatedRemediationBatchDigests = payload.invalidatedRemediationBatchDigests
        invalidatedConfirmationReceiptDigests = payload.invalidatedConfirmationReceiptDigests
        invalidatedExceptionProofDigests = payload.invalidatedExceptionProofDigests
        invalidatedConvergenceReceiptDigests = payload.invalidatedConvergenceReceiptDigests
        invalidatedApprovalDigests = payload.invalidatedApprovalDigests
        requiresFreshInitialCycle = payload.requiresFreshInitialCycle
        remainsCurrent = payload.remainsCurrent
        self.digest = digest
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 1 else {
            throw WorkflowPolicyError.invalidPolicy
        }
        let payload = try ReviewInvalidationPlanPayload(
            schemaVersion: 1,
            invalidationMutationDigest: values.decode(HashDigest.self, forKey: .invalidationMutationDigest),
            invalidatedBaselineDigests: values.decode(
                [HashDigest].self,
                forKey: .invalidatedBaselineDigests
            ),
            invalidatedInventoryDigests: values.decode([HashDigest].self, forKey: .invalidatedInventoryDigests),
            invalidatedRegisterDigests: values.decode(
                [HashDigest].self,
                forKey: .invalidatedRegisterDigests
            ),
            invalidatedRemediationBatchDigests: values.decode(
                [HashDigest].self,
                forKey: .invalidatedRemediationBatchDigests
            ),
            invalidatedConfirmationReceiptDigests: values.decode(
                [HashDigest].self,
                forKey: .invalidatedConfirmationReceiptDigests
            ),
            invalidatedExceptionProofDigests: values.decode(
                [HashDigest].self,
                forKey: .invalidatedExceptionProofDigests
            ),
            invalidatedConvergenceReceiptDigests: values.decode(
                [HashDigest].self,
                forKey: .invalidatedConvergenceReceiptDigests
            ),
            invalidatedApprovalDigests: values.decode([HashDigest].self, forKey: .invalidatedApprovalDigests),
            requiresFreshInitialCycle: values.decode(Bool.self, forKey: .requiresFreshInitialCycle),
            remainsCurrent: values.decode(Bool.self, forKey: .remainsCurrent)
        )
        let decodedDigest = try values.decode(HashDigest.self, forKey: .digest)
        let allDigestLists = [
            payload.invalidatedBaselineDigests,
            payload.invalidatedInventoryDigests,
            payload.invalidatedRegisterDigests,
            payload.invalidatedRemediationBatchDigests,
            payload.invalidatedConfirmationReceiptDigests,
            payload.invalidatedExceptionProofDigests,
            payload.invalidatedConvergenceReceiptDigests,
            payload.invalidatedApprovalDigests,
        ]
        let isEmpty = payload.invalidatedBaselineDigests.isEmpty &&
            payload.invalidatedInventoryDigests.isEmpty &&
            payload.invalidatedRegisterDigests.isEmpty &&
            payload.invalidatedRemediationBatchDigests.isEmpty &&
            payload.invalidatedConfirmationReceiptDigests.isEmpty &&
            payload.invalidatedExceptionProofDigests.isEmpty &&
            payload.invalidatedConvergenceReceiptDigests.isEmpty &&
            payload.invalidatedApprovalDigests.isEmpty
        guard allDigestLists.allSatisfy(isCanonicalDigestList),
            payload.remainsCurrent == isEmpty,
            payload.requiresFreshInitialCycle != payload.remainsCurrent,
            decodedDigest == CanonicalTreeDigest.sha256(try CanonicalJSON.encode(payload))
        else { throw WorkflowPolicyError.invalidPolicy }
        self.init(payload: payload, digest: decodedDigest)
    }

    public static func decodeCanonical(from bytes: Data) throws -> ReviewInvalidationPlan {
        try artifactDecodeCanonical(Self.self, from: bytes)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case invalidationMutationDigest = "invalidation_mutation_digest"
        case invalidatedBaselineDigests = "invalidated_baseline_digests"
        case invalidatedInventoryDigests = "invalidated_inventory_digests"
        case invalidatedRegisterDigests = "invalidated_register_digests"
        case invalidatedRemediationBatchDigests = "invalidated_remediation_batch_digests"
        case invalidatedConfirmationReceiptDigests = "invalidated_confirmation_receipt_digests"
        case invalidatedExceptionProofDigests = "invalidated_exception_proof_digests"
        case invalidatedConvergenceReceiptDigests = "invalidated_convergence_receipt_digests"
        case invalidatedApprovalDigests = "invalidated_approval_digests"
        case requiresFreshInitialCycle = "requires_fresh_initial_cycle"
        case remainsCurrent = "remains_current"
        case digest = "invalidation_plan_digest"
    }
}

private struct ReviewInvalidationPlanPayload: Codable {
    let schemaVersion: Int
    let invalidationMutationDigest: HashDigest
    let invalidatedBaselineDigests: [HashDigest]
    let invalidatedInventoryDigests: [HashDigest]
    let invalidatedRegisterDigests: [HashDigest]
    let invalidatedRemediationBatchDigests: [HashDigest]
    let invalidatedConfirmationReceiptDigests: [HashDigest]
    let invalidatedExceptionProofDigests: [HashDigest]
    let invalidatedConvergenceReceiptDigests: [HashDigest]
    let invalidatedApprovalDigests: [HashDigest]
    let requiresFreshInitialCycle: Bool
    let remainsCurrent: Bool

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case invalidationMutationDigest = "invalidation_mutation_digest"
        case invalidatedBaselineDigests = "invalidated_baseline_digests"
        case invalidatedInventoryDigests = "invalidated_inventory_digests"
        case invalidatedRegisterDigests = "invalidated_register_digests"
        case invalidatedRemediationBatchDigests = "invalidated_remediation_batch_digests"
        case invalidatedConfirmationReceiptDigests = "invalidated_confirmation_receipt_digests"
        case invalidatedExceptionProofDigests = "invalidated_exception_proof_digests"
        case invalidatedConvergenceReceiptDigests = "invalidated_convergence_receipt_digests"
        case invalidatedApprovalDigests = "invalidated_approval_digests"
        case requiresFreshInitialCycle = "requires_fresh_initial_cycle"
        case remainsCurrent = "remains_current"
    }
}

/// Authenticated, ordered review lineage. Persisted wire values remain inspectable, but only this
/// non-Codable capability may authorize convergence publication or invalidation.
public struct VerifiedConfirmationLineage: Sendable {
    public let baselines: [ReviewBaseline]
    public let inventories: [ReviewerFindingInventory]
    public let registers: [IssueRegister]
    public let remediationBatches: [RemediationBatch]
    public let confirmationReceipts: [ConfirmationReceipt]
    public let exceptionRounds: [ReviewExceptionEligibility]
    public let convergenceReceipts: [ConvergenceReceipt]
    public let downstreamApprovals: [ApprovalRecord]
    public let receipts: [VerifiedPublishedReviewReceipt]
    let verifiedRegisters: [VerifiedIssueRegister]
    let remediationSuccessors: [VerifiedCommittedRemediationSuccessor]
    let currentness: VerifiedReviewScopeCurrentness
    let policies: VerifiedReviewPolicySet

    public var confirmationReceipt: ConfirmationReceipt? { confirmationReceipts.first }
    public var convergenceReceipt: ConvergenceReceipt? { convergenceReceipts.first }

    fileprivate init(
        verifiedRegisters: [VerifiedIssueRegister],
        remediationSuccessors: [VerifiedCommittedRemediationSuccessor],
        confirmationReceipts: [ConfirmationReceipt],
        exceptionRounds: [ReviewExceptionEligibility],
        convergenceReceipts: [ConvergenceReceipt],
        receipts: [VerifiedPublishedReviewReceipt],
        authority: VerifiedReviewReceiptAuthority
    ) throws {
        let baselines = verifiedRegisters.map(\.baseline)
        let inventories = verifiedRegisters.flatMap { $0.inventories.inventories }
        let registers = verifiedRegisters.map(\.register)
        let remediationBatches = remediationSuccessors.map(\.batch)
        let currentness = authority.currentness
        let policies = authority.policies
        let downstreamApprovals = authority.approvals
        guard !baselines.isEmpty,
              !receipts.isEmpty,
              registers.count == baselines.count,
              convergenceReceipts.count <= 1,
              Set(receipts.map { "\($0.kind.rawValue)/\($0.id.rawValue)" }).count ==
                receipts.count,
              receipts.allSatisfy({ $0.runID == baselines[0].runID }),
              Set(baselines.map(\.digest)).count == baselines.count,
              Set(registers.map(\.digest)).count == registers.count,
              Set(inventories.map(\.digest)).count == inventories.count
        else { throw WorkflowPolicyError.invalidPolicy }

        let source = baselines[0]
        try requireCommittedReviewLineageCoverage(
            baselines: baselines,
            inventories: inventories,
            registers: registers,
            remediationBatches: remediationBatches,
            confirmationReceipts: confirmationReceipts,
            exceptionRounds: exceptionRounds,
            convergenceReceipts: convergenceReceipts,
            receipts: receipts
        )
        if baselines.count == 1 {
            let register = registers[0]
            let expectedInventoryDigests = Set(register.inventoryDigests)
            let approvalSetDigest = try reviewApprovalSetDigest(downstreamApprovals)
            guard source.kind == .initial,
                  source.semanticOrdinal == 0,
                  remediationBatches.isEmpty,
                  confirmationReceipts.isEmpty,
                  exceptionRounds.isEmpty,
                  register.baselineDigest == source.digest,
                  register.roundID == source.roundID,
                  register.rosterDigest == source.rosterDigest,
                  register.pathDecision == .directConvergenceNoAcceptedCurrentScope,
                  register.acceptedCurrentScopeAssignments.isEmpty,
                  expectedInventoryDigests == Set(inventories.map(\.digest)),
                  currentness.runID == source.runID,
                  currentness.baselineDigest == source.digest,
                  currentness.currentArtifacts == source.artifactScopes,
                  policies.runID == source.runID,
                  policies.baselineDigest == source.digest,
                  policies.assurancePolicyDigest == source.assurancePolicyDigest
            else { throw WorkflowPolicyError.invalidPolicy }
            if let convergence = convergenceReceipts.first {
                let bytes = try CanonicalJSON.encode(convergence)
                guard convergence.path == .directConvergenceNoAcceptedCurrentScope,
                      try convergence.hasValidIdentity(
                        runID: source.runID,
                        cycleID: source.cycleID,
                        gate: source.gate
                      ),
                      convergence.baselineLineage == [source.digest],
                      convergence.registerDigests == [register.digest],
                      convergence.remediationBatchDigests.isEmpty,
                      convergence.confirmationReceiptDigest == nil,
                      convergence.exceptionProofDigests.isEmpty,
                      convergence.currentArtifactSetDigest ==
                        currentness.currentArtifactSetDigest,
                      convergence.currentApprovalSetDigest == approvalSetDigest,
                      convergence.authorityPolicyDigest == source.assurancePolicyDigest,
                      receipts.contains(where: {
                        $0.kind.rawValue == "review-convergence" &&
                            $0.id.rawValue == convergence.receiptID &&
                            $0.payloadBytes == bytes &&
                            $0.payloadDigest == CanonicalTreeDigest.sha256(bytes)
                      })
                else { throw WorkflowPolicyError.invalidPolicy }
            }
            self.baselines = baselines
            self.inventories = inventories
            self.registers = registers
            self.remediationBatches = remediationBatches
            self.confirmationReceipts = confirmationReceipts
            self.exceptionRounds = exceptionRounds
            self.convergenceReceipts = convergenceReceipts
            self.downstreamApprovals = downstreamApprovals
            self.receipts = receipts
            self.verifiedRegisters = verifiedRegisters
            self.remediationSuccessors = remediationSuccessors
            self.currentness = currentness
            self.policies = policies
            return
        }

        guard let latestRegister = verifiedRegisters.last else {
            throw WorkflowPolicyError.invalidPolicy
        }
        try ReviewConvergenceValidator.validateConfirmedTerminal(latestRegister)
        guard remediationBatches.count == baselines.count - 1,
              confirmationReceipts.count == 1,
              exceptionRounds.count == baselines.count - 2
        else { throw WorkflowPolicyError.invalidPolicy }
        let confirmation = baselines[1]
        guard source.kind == .initial,
              confirmation.kind == .normalConfirmation,
              confirmation.semanticOrdinal == 1,
              confirmation.predecessorBaselineDigest == source.digest,
              baselines.allSatisfy({
                $0.runID == source.runID &&
                    $0.cycleID == source.cycleID &&
                    $0.gate == source.gate &&
                    $0.rosterDigest == source.rosterDigest
              }),
              baselines.dropFirst(2).allSatisfy({ $0.kind == .exception }),
              zip(baselines, registers).allSatisfy({ baseline, register in
                register.baselineDigest == baseline.digest &&
                    register.roundID == baseline.roundID &&
                    register.rosterDigest == baseline.rosterDigest
              })
        else { throw WorkflowPolicyError.invalidPolicy }

        let expectedInventoryDigests = Set(registers.flatMap(\.inventoryDigests))
        guard expectedInventoryDigests == Set(inventories.map(\.digest)) else {
            throw WorkflowPolicyError.invalidPolicy
        }

        for index in remediationSuccessors.indices {
            let successor = remediationSuccessors[index]
            let sourceBaseline = baselines[index]
            let successorBaseline = baselines[index + 1]
            let sourceRegister = registers[index]
            guard successor.sourceRegister.register.digest == sourceRegister.digest,
                  successor.sourceRegister.baseline.digest == sourceBaseline.digest,
                  successor.successorBaseline.digest == successorBaseline.digest,
                  successor.batch.sourceBaselineDigest == sourceBaseline.digest,
                  successor.batch.sourceRegisterDigest == sourceRegister.digest,
                  successor.batch.successorBaselineDigest == successorBaseline.digest
            else { throw WorkflowPolicyError.invalidPolicy }
        }

        for (offset, proof) in exceptionRounds.enumerated() {
            let predecessorIndex = offset + 1
            let exceptionIndex = offset + 2
            let predecessor = baselines[predecessorIndex]
            let exception = baselines[exceptionIndex]
            let remediation = remediationSuccessors[predecessorIndex]
            let priorProof = offset == 0 ? nil : exceptionRounds[offset - 1]
            guard proof.runID == source.runID,
                  proof.cycleID == source.cycleID,
                  proof.gate == source.gate,
                  proof.precedingRoundID == predecessor.roundID,
                  proof.precedingRegisterDigest == registers[predecessorIndex].digest,
                  proof.precedingBaselineDigest == predecessor.digest,
                  proof.nextRoundID == exception.roundID,
                  proof.nextSemanticOrdinal == exception.semanticOrdinal,
                  proof.nextSemanticOrdinal == UInt64(offset + 2),
                  proof.remainingExceptionRounds >= 0,
                  proof.policyVersion == 1,
                  proof.budgetDigest == source.convergencePolicyDigest,
                  priorProof == nil || (
                    priorProof?.nextRoundID == proof.precedingRoundID &&
                        priorProof?.policyVersion == proof.policyVersion &&
                        priorProof?.budgetDigest == proof.budgetDigest &&
                        priorProof?.remainingExceptionRounds ==
                            proof.remainingExceptionRounds + 1
                  ),
                  proof.hasValidDigest,
                  remediation.sourceRegister.baseline.digest == predecessor.digest,
                  remediation.sourceRegister.register.digest ==
                    registers[predecessorIndex].digest,
                  remediation.successorBaseline.digest == exception.digest,
                  proof.roundAnchorEventHead == exception.preCreationEventHead,
                  proof.roundAnchorEventHead == remediation.publicationAnchorEventHead,
                  proof.remediationEventHead == remediation.producedEventHead
            else { throw WorkflowPolicyError.invalidExceptionProof }
        }

        let initialRemediation = remediationBatches[0]
        let confirmationReceipt = confirmationReceipts[0]
        let confirmationBytes = try CanonicalJSON.encode(confirmationReceipt)
        let confirmationArtifactDigest = try reviewArtifactSetDigest(confirmation.artifactScopes)
        let approvalSetDigest = try reviewApprovalSetDigest(downstreamApprovals)
        guard confirmationReceipt.successorBaselineDigest == confirmation.digest,
              try confirmationReceipt.hasValidIdentity(
                runID: source.runID,
                cycleID: source.cycleID,
                gate: source.gate
              ),
              confirmationReceipt.roundID == confirmation.roundID,
              confirmationReceipt.rosterDigest == confirmation.rosterDigest,
              confirmationReceipt.confirmationRegisterDigest == registers[1].digest,
              confirmationReceipt.remediationBatchDigest == initialRemediation.digest,
              confirmationReceipt.currentArtifactSetDigest == confirmationArtifactDigest,
              confirmationReceipt.currentApprovalSetDigest == approvalSetDigest,
              confirmationReceipt.authorityPolicyDigest == confirmation.assurancePolicyDigest,
              currentness.runID == source.runID,
              currentness.baselineDigest == baselines.last?.digest,
              currentness.currentArtifacts == baselines.last?.artifactScopes,
              currentness.currentArtifactSetDigest == (try reviewArtifactSetDigest(
                baselines.last?.artifactScopes ?? []
              )),
              policies.runID == source.runID,
              baselines.map(\.digest).contains(policies.baselineDigest)
        else { throw WorkflowPolicyError.invalidPolicy }
        guard receipts.contains(where: {
            $0.kind.rawValue == "review-confirmation" &&
                $0.id.rawValue == confirmationReceipt.receiptID &&
                $0.payloadBytes == confirmationBytes &&
                $0.payloadDigest == CanonicalTreeDigest.sha256(confirmationBytes)
        }) else { throw PersistenceError.integrityViolation }
        guard let committedConfirmation = receipts.first(where: {
            $0.kind.rawValue == "review-confirmation" &&
                $0.id.rawValue == confirmationReceipt.receiptID
        }),
            exceptionRounds.allSatisfy({
                $0.confirmationEventHead == committedConfirmation.producedEventHead
            })
        else { throw WorkflowPolicyError.invalidExceptionProof }

        if let convergence = convergenceReceipts.first {
            let convergenceBytes = try CanonicalJSON.encode(convergence)
            guard convergence.path == .confirmedRemediation,
                  try convergence.hasValidIdentity(
                    runID: source.runID,
                    cycleID: source.cycleID,
                    gate: source.gate
                  ),
                  convergence.baselineLineage == baselines.map(\.digest),
                  convergence.registerDigests == registers.map(\.digest),
                  convergence.remediationBatchDigests == remediationBatches.map(\.digest),
                  convergence.confirmationReceiptDigest == confirmationReceipt.digest,
                  convergence.exceptionProofDigests == exceptionRounds.map(\.proofDigest),
                  convergence.currentArtifactSetDigest == currentness.currentArtifactSetDigest,
                  convergence.currentApprovalSetDigest == approvalSetDigest,
                  convergence.authorityPolicyDigest == baselines.last?.assurancePolicyDigest,
                  receipts.contains(where: {
                    $0.kind.rawValue == "review-convergence" &&
                        $0.id.rawValue == convergence.receiptID &&
                        $0.payloadBytes == convergenceBytes &&
                        $0.payloadDigest == CanonicalTreeDigest.sha256(convergenceBytes)
                  })
            else { throw WorkflowPolicyError.invalidPolicy }
        }

        self.baselines = baselines
        self.inventories = inventories
        self.registers = registers
        self.remediationBatches = remediationBatches
        self.confirmationReceipts = confirmationReceipts
        self.exceptionRounds = exceptionRounds
        self.convergenceReceipts = convergenceReceipts
        self.downstreamApprovals = downstreamApprovals
        self.receipts = receipts
        self.verifiedRegisters = verifiedRegisters
        self.remediationSuccessors = remediationSuccessors
        self.currentness = currentness
        self.policies = policies
    }
}

public enum ReviewConfirmationLineageVerifier {
    public static func verify(
        registers: [VerifiedIssueRegister],
        remediation: [VerifiedCommittedRemediationSuccessor],
        confirmationReceipts: [ConfirmationReceipt],
        exceptionRounds: [ReviewExceptionEligibility],
        convergenceReceipts: [ConvergenceReceipt],
        receipts: [VerifiedPublishedReviewReceipt],
        persistedRun: PersistedRun,
        authority: VerifiedReviewReceiptAuthority
    ) throws -> VerifiedConfirmationLineage {
        guard persistedRun.state.runID == authority.runID,
              persistedRun.stateDigest == authority.persistedStateDigest,
              persistedRun.eventHead == authority.eventHead
        else { throw PersistenceError.integrityViolation }
        guard !receipts.isEmpty else { throw PersistenceError.integrityViolation }
        let committedReceipts = try receipts.map { supplied in
            let committed = try ReviewCommittedReceiptVerifier.verify(
                id: supplied.id,
                kind: supplied.kind,
                digest: supplied.payloadDigest,
                in: persistedRun
            )
            guard committed == supplied else {
                throw PersistenceError.integrityViolation
            }
            return committed
        }.sorted {
            ($0.kind.rawValue, $0.id.rawValue, $0.payloadDigest.rawValue) <
                ($1.kind.rawValue, $1.id.rawValue, $1.payloadDigest.rawValue)
        }
        for capabilityReceipt in remediation.flatMap(\.receipts) {
            guard try ReviewCommittedReceiptVerifier.verify(
                id: capabilityReceipt.id,
                kind: capabilityReceipt.kind,
                digest: capabilityReceipt.payloadDigest,
                in: persistedRun
            ) == capabilityReceipt else { throw PersistenceError.integrityViolation }
        }
        return try VerifiedConfirmationLineage(
            verifiedRegisters: registers,
            remediationSuccessors: remediation,
            confirmationReceipts: confirmationReceipts,
            exceptionRounds: exceptionRounds,
            convergenceReceipts: convergenceReceipts,
            receipts: committedReceipts,
            authority: authority
        )
    }
}

public struct VerifiedReviewInvalidationAuthorization: Sendable {
    public let plan: ReviewInvalidationPlan
    public let latestBaseline: ReviewBaseline
    let invalidation: ValidatedArtifactInvalidation
    let currentness: VerifiedReviewScopeCurrentness
    let persistedStateDigest: HashDigest
    let eventHead: HashDigest

    fileprivate init(
        plan: ReviewInvalidationPlan,
        latestBaseline: ReviewBaseline,
        invalidation: ValidatedArtifactInvalidation,
        currentness: VerifiedReviewScopeCurrentness,
        persistedStateDigest: HashDigest,
        eventHead: HashDigest
    ) {
        self.plan = plan
        self.latestBaseline = latestBaseline
        self.invalidation = invalidation
        self.currentness = currentness
        self.persistedStateDigest = persistedStateDigest
        self.eventHead = eventHead
    }
}

public enum ReviewInvalidationDecision: Sendable {
    case authorization(VerifiedReviewInvalidationAuthorization)
    case remainsCurrent
}

public enum ReviewConvergenceValidator {
    static func validateConfirmedTerminal(
        _ register: VerifiedIssueRegister
    ) throws {
        guard register.baseline.kind == .normalConfirmation ||
                register.baseline.kind == .exception,
              register.register.pathDecision == .directConvergenceNoAcceptedCurrentScope,
              register.register.acceptedCurrentScopeAssignments.isEmpty
        else { throw WorkflowPolicyError.remediationRequired }
    }

    public static func issueDirectConvergence(
        register: VerifiedIssueRegister,
        authority: VerifiedReviewReceiptAuthority,
        publicationAnchorEventHead: HashDigest
    ) throws -> ConvergenceReceipt {
        let baseline = register.baseline
        let wire = register.register
        guard baseline.kind == .initial,
              baseline.semanticOrdinal == 0,
              wire.baselineDigest == baseline.digest,
              wire.roundID == baseline.roundID,
              wire.rosterDigest == baseline.rosterDigest,
              wire.pathDecision == .directConvergenceNoAcceptedCurrentScope,
              wire.acceptedCurrentScopeAssignments.isEmpty,
              authority.runID == baseline.runID,
              authority.currentness.baselineDigest == baseline.digest,
              authority.currentness.currentArtifacts == baseline.artifactScopes,
              authority.currentness.currentArtifactSetDigest ==
                (try artifactSetDigest(for: baseline)),
              authority.policies == register.policies,
              authority.policies.assurancePolicyDigest == baseline.assurancePolicyDigest,
              publicationAnchorEventHead == authority.eventHead
        else { throw WorkflowPolicyError.remediationRequired }
        let identityDraft = ConvergenceReceiptPayload(
            schemaVersion: 2,
            receiptID: "review-convergence-pending",
            path: .directConvergenceNoAcceptedCurrentScope,
            baselineLineage: [baseline.digest],
            registerDigests: [wire.digest],
            remediationBatchDigests: [],
            confirmationReceiptDigest: nil,
            exceptionProofDigests: [],
            currentArtifactSetDigest: authority.currentness.currentArtifactSetDigest,
            currentApprovalSetDigest: authority.approvalSetDigest,
            authorityPolicyDigest: authority.policies.assurancePolicyDigest,
            publicationAnchorEventHead: publicationAnchorEventHead
        )
        return try ConvergenceReceipt.issue(payload: ConvergenceReceiptPayload(
            schemaVersion: 2,
            receiptID: ConvergenceReceipt.deterministicReceiptID(
                payload: identityDraft,
                runID: baseline.runID,
                cycleID: baseline.cycleID,
                gate: baseline.gate
            ),
            path: identityDraft.path,
            baselineLineage: identityDraft.baselineLineage,
            registerDigests: identityDraft.registerDigests,
            remediationBatchDigests: identityDraft.remediationBatchDigests,
            confirmationReceiptDigest: identityDraft.confirmationReceiptDigest,
            exceptionProofDigests: identityDraft.exceptionProofDigests,
            currentArtifactSetDigest: identityDraft.currentArtifactSetDigest,
            currentApprovalSetDigest: identityDraft.currentApprovalSetDigest,
            authorityPolicyDigest: identityDraft.authorityPolicyDigest,
            publicationAnchorEventHead: identityDraft.publicationAnchorEventHead
        ))
    }

    public static func issueConfirmation(
        successor: VerifiedCommittedRemediationSuccessor,
        confirmationRegister: VerifiedIssueRegister,
        authority: VerifiedReviewReceiptAuthority,
        publicationAnchorEventHead: HashDigest
    ) throws -> ConfirmationReceipt {
        guard !authority.hasRecordedNormalConfirmation else {
            throw WorkflowPolicyError.normalConfirmationAlreadyRecorded
        }
        let baseline = successor.successorBaseline
        let wire = confirmationRegister.register
        guard baseline.kind == .normalConfirmation,
              baseline.digest == successor.batch.successorBaselineDigest,
              baseline.predecessorBaselineDigest == successor.batch.sourceBaselineDigest,
              confirmationRegister.baseline.digest == baseline.digest,
              wire.baselineDigest == baseline.digest,
              wire.roundID == baseline.roundID,
              wire.rosterDigest == baseline.rosterDigest,
              authority.runID == baseline.runID,
              authority.currentness.baselineDigest == baseline.digest,
              authority.currentness.currentArtifacts == baseline.artifactScopes,
              authority.policies == confirmationRegister.policies,
              authority.policies.assurancePolicyDigest == baseline.assurancePolicyDigest,
              publicationAnchorEventHead == authority.eventHead
        else { throw WorkflowPolicyError.remediationRequired }
        return try ConfirmationReceipt.issue(
            successorBaseline: baseline,
            confirmationRegister: wire,
            remediationBatch: successor.batch,
            currentArtifactSetDigest: authority.currentness.currentArtifactSetDigest,
            approvalSetDigest: authority.approvalSetDigest,
            authorityPolicyDigest: authority.policies.assurancePolicyDigest,
            publicationAnchorEventHead: publicationAnchorEventHead
        )
    }

    public static func issueConfirmedConvergence(
        lineage: VerifiedConfirmationLineage,
        authority: VerifiedReviewReceiptAuthority,
        publicationAnchorEventHead: HashDigest
    ) throws -> ConvergenceReceipt {
        guard let latestRegister = lineage.verifiedRegisters.last else {
            throw WorkflowPolicyError.remediationRequired
        }
        try validateConfirmedTerminal(latestRegister)
        guard let confirmation = lineage.confirmationReceipt,
              let latestBaseline = lineage.baselines.last,
              !lineage.remediationBatches.isEmpty,
              lineage.convergenceReceipts.isEmpty,
              authority.runID == latestBaseline.runID,
              authority.currentness == lineage.currentness,
              authority.policies == lineage.policies,
              authority.approvals == lineage.downstreamApprovals,
              publicationAnchorEventHead == authority.eventHead
        else { throw WorkflowPolicyError.remediationRequired }
        let identityDraft = ConvergenceReceiptPayload(
            schemaVersion: 2,
            receiptID: "review-convergence-pending",
            path: .confirmedRemediation,
            baselineLineage: lineage.baselines.map(\.digest),
            registerDigests: lineage.registers.map(\.digest),
            remediationBatchDigests: lineage.remediationBatches.map(\.digest),
            confirmationReceiptDigest: confirmation.digest,
            exceptionProofDigests: lineage.exceptionRounds.map(\.proofDigest),
            currentArtifactSetDigest: authority.currentness.currentArtifactSetDigest,
            currentApprovalSetDigest: authority.approvalSetDigest,
            authorityPolicyDigest: authority.policies.assurancePolicyDigest,
            publicationAnchorEventHead: publicationAnchorEventHead
        )
        return try ConvergenceReceipt.issue(payload: ConvergenceReceiptPayload(
            schemaVersion: 2,
            receiptID: ConvergenceReceipt.deterministicReceiptID(
                payload: identityDraft,
                runID: latestBaseline.runID,
                cycleID: latestBaseline.cycleID,
                gate: latestBaseline.gate
            ),
            path: identityDraft.path,
            baselineLineage: identityDraft.baselineLineage,
            registerDigests: identityDraft.registerDigests,
            remediationBatchDigests: identityDraft.remediationBatchDigests,
            confirmationReceiptDigest: identityDraft.confirmationReceiptDigest,
            exceptionProofDigests: identityDraft.exceptionProofDigests,
            currentArtifactSetDigest: identityDraft.currentArtifactSetDigest,
            currentApprovalSetDigest: identityDraft.currentApprovalSetDigest,
            authorityPolicyDigest: identityDraft.authorityPolicyDigest,
            publicationAnchorEventHead: identityDraft.publicationAnchorEventHead
        ))
    }

    public static func evaluateException(
        _ context: ReviewExceptionContext,
        predecessorRegister: VerifiedIssueRegister,
        remediation: VerifiedCommittedRemediationSuccessor,
        predecessorRegisterReceipt: VerifiedPublishedReviewReceipt,
        currentRegisterReceipt: VerifiedPublishedReviewReceipt,
        confirmationReceipt: VerifiedPublishedReviewReceipt,
        priorAdmissions: [VerifiedReviewExceptionAdmission],
        budget: AttemptBudget,
        persistedRun: PersistedRun
    ) -> VerifiedReviewExceptionDecision {
        do {
            let history = try VerifiedActiveReviewCycleHistory.verify(
                predecessorRegister: predecessorRegister,
                currentRegister: remediation.sourceRegister,
                remediation: remediation,
                predecessorRegisterReceipt: predecessorRegisterReceipt,
                currentRegisterReceipt: currentRegisterReceipt,
                confirmationReceipt: confirmationReceipt,
                persistedRun: persistedRun
            )
            let facts = try VerifiedReviewExceptionFacts.verify(
                claim: context,
                predecessorRegister: predecessorRegister,
                remediation: remediation,
                activeHistory: history,
                priorAdmissions: priorAdmissions,
                budget: budget
            )
            return ReviewConvergencePolicy().evaluateException(facts)
        } catch {
            return .escalation(.failed)
        }
    }

    #if DEBUG
    static func evaluateExceptionForTesting(
        _ context: ReviewExceptionContext,
        predecessorRegister: VerifiedIssueRegister,
        remediation: VerifiedCommittedRemediationSuccessor,
        priorAdmissions: [VerifiedReviewExceptionAdmission],
        budget: AttemptBudget,
        registerJoinedEventHead: HashDigest,
        remediationEventHead: HashDigest,
        confirmationEventHead: HashDigest,
        confirmationRoundID: ReviewRoundID? = nil,
        confirmationRegisterDigest: HashDigest? = nil,
        confirmationBaselineDigest: HashDigest? = nil
    ) -> VerifiedReviewExceptionDecision {
        let history = VerifiedActiveReviewCycleHistory.testing(
            predecessorRegister: predecessorRegister,
            currentRegister: remediation.sourceRegister,
            remediation: remediation,
            registerJoinedEventHead: registerJoinedEventHead,
            remediationEventHead: remediationEventHead,
            confirmationEventHead: confirmationEventHead,
            confirmationRoundID: confirmationRoundID,
            confirmationRegisterDigest: confirmationRegisterDigest,
            confirmationBaselineDigest: confirmationBaselineDigest
        )
        guard let facts = try? VerifiedReviewExceptionFacts.verify(
            claim: context,
            predecessorRegister: predecessorRegister,
            remediation: remediation,
            activeHistory: history,
            priorAdmissions: priorAdmissions,
            budget: budget
        ) else { return .escalation(.failed) }
        return ReviewConvergencePolicy().evaluateException(facts)
    }

    static func evaluateException(
        _ context: ReviewExceptionContext,
        budget: AttemptBudget
    ) -> ReviewExceptionDecision {
        ReviewConvergencePolicy().evaluateException(context, budget: budget)
    }
    #endif

    static func invalidate(
        lineage: VerifiedConfirmationLineage,
        persistedRun: PersistedRun,
        by invalidation: ValidatedArtifactInvalidation
    ) throws -> ReviewInvalidationDecision {
        try validatePersistedLineage(lineage, persistedRun: persistedRun)
        let affected = Set([invalidation.changedArtifactID] + invalidation.staleArtifactIDs)
        let intersects = lineage.baselines.contains { baseline in
            baseline.artifactScopes.contains { affected.contains($0.id) }
        }
        guard intersects else { return .remainsCurrent }

        let payload = ReviewInvalidationPlanPayload(
            schemaVersion: 1,
            invalidationMutationDigest: invalidation.mutationDigest,
            invalidatedBaselineDigests: canonicalDigestList(lineage.baselines.map(\.digest)),
            invalidatedInventoryDigests: canonicalDigestList(lineage.inventories.map(\.digest)),
            invalidatedRegisterDigests: canonicalDigestList(lineage.registers.map(\.digest)),
            invalidatedRemediationBatchDigests: canonicalDigestList(
                lineage.remediationBatches.map(\.digest)
            ),
            invalidatedConfirmationReceiptDigests: canonicalDigestList(
                lineage.confirmationReceipts.map(\.digest)
            ),
            invalidatedExceptionProofDigests: canonicalDigestList(
                lineage.exceptionRounds.map(\.proofDigest)
            ),
            invalidatedConvergenceReceiptDigests: canonicalDigestList(
                lineage.convergenceReceipts.map(\.digest)
            ),
            invalidatedApprovalDigests: try reviewApprovalDigests(lineage.downstreamApprovals),
            requiresFreshInitialCycle: true,
            remainsCurrent: false
        )
        let plan = ReviewInvalidationPlan(
            payload: payload,
            digest: CanonicalTreeDigest.sha256(try CanonicalJSON.encode(payload))
        )
        guard let latestBaseline = lineage.baselines.last else {
            throw WorkflowPolicyError.invalidPolicy
        }
        return .authorization(
            VerifiedReviewInvalidationAuthorization(
                plan: plan,
                latestBaseline: latestBaseline,
                invalidation: invalidation,
                currentness: lineage.currentness,
                persistedStateDigest: persistedRun.stateDigest,
                eventHead: persistedRun.eventHead
            )
        )
    }

    private static func validatePersistedLineage(
        _ lineage: VerifiedConfirmationLineage,
        persistedRun: PersistedRun
    ) throws {
        guard let latestBaseline = lineage.baselines.last,
              persistedRun.state.runID == latestBaseline.runID,
              persistedRun.eventHead == lineage.currentness.currentEventHead,
              persistedRun.state.reviewCycle?.id == latestBaseline.cycleID,
              persistedRun.state.reviewCycle?.gate == latestBaseline.gate
        else { throw PersistenceError.integrityViolation }

        try requireCommittedReviewLineageCoverage(
            baselines: lineage.baselines,
            inventories: lineage.inventories,
            registers: lineage.registers,
            remediationBatches: lineage.remediationBatches,
            confirmationReceipts: lineage.confirmationReceipts,
            exceptionRounds: lineage.exceptionRounds,
            convergenceReceipts: lineage.convergenceReceipts,
            receipts: lineage.receipts
        )

        guard !lineage.receipts.isEmpty else {
            throw PersistenceError.integrityViolation
        }
        for verified in lineage.receipts {
            guard verified.payloadDigest == CanonicalTreeDigest.sha256(verified.payloadBytes),
                  try ReviewCommittedReceiptVerifier.verify(
                    id: verified.id,
                    kind: verified.kind,
                    digest: verified.payloadDigest,
                    in: persistedRun
                  ) == verified
            else { throw PersistenceError.integrityViolation }
        }
        for verified in lineage.remediationSuccessors.flatMap(\.receipts) {
            guard verified.payloadDigest == CanonicalTreeDigest.sha256(verified.payloadBytes),
                  try ReviewCommittedReceiptVerifier.verify(
                    id: verified.id,
                    kind: verified.kind,
                    digest: verified.payloadDigest,
                    in: persistedRun
                  ) == verified
            else { throw PersistenceError.integrityViolation }
        }
    }

    private static func artifactSetDigest(for baseline: ReviewBaseline) throws -> HashDigest {
        CanonicalTreeDigest.sha256(try CanonicalJSON.encode(baseline.artifactScopes))
    }
}

private func requireCommittedReviewLineageCoverage(
    baselines: [ReviewBaseline],
    inventories: [ReviewerFindingInventory],
    registers: [IssueRegister],
    remediationBatches: [RemediationBatch],
    confirmationReceipts: [ConfirmationReceipt],
    exceptionRounds: [ReviewExceptionEligibility],
    convergenceReceipts: [ConvergenceReceipt],
    receipts: [VerifiedPublishedReviewReceipt]
) throws {
    let expectedReceiptCount = baselines.count + inventories.count + registers.count +
        remediationBatches.count + confirmationReceipts.count + exceptionRounds.count +
        convergenceReceipts.count
    guard receipts.count == expectedReceiptCount else {
        throw PersistenceError.integrityViolation
    }
    for baseline in baselines {
        try requireCommittedReviewReceiptPayload(
            kind: "review-baseline",
            bytes: CanonicalJSON.encode(baseline),
            in: receipts
        )
    }
    for inventory in inventories {
        try requireCommittedReviewReceiptPayload(
            kind: "review-inventory",
            bytes: CanonicalJSON.encode(inventory),
            in: receipts
        )
    }
    for register in registers {
        try requireCommittedReviewReceiptPayload(
            kind: "issue-register",
            bytes: CanonicalJSON.encode(register),
            in: receipts
        )
    }
    for remediation in remediationBatches {
        try requireCommittedReviewReceiptPayload(
            kind: "review-remediation-batch",
            bytes: CanonicalJSON.encode(remediation),
            in: receipts
        )
    }
    for confirmation in confirmationReceipts {
        try requireCommittedReviewReceiptPayload(
            kind: "review-confirmation",
            id: confirmation.receiptID,
            eventKind: .reviewConfirmationRecorded,
            publicationAnchorEventHead: confirmation.publicationAnchorEventHead,
            bytes: CanonicalJSON.encode(confirmation),
            in: receipts
        )
    }
    for (index, proof) in exceptionRounds.enumerated() {
        guard baselines.indices.contains(index + 2) else {
            throw PersistenceError.integrityViolation
        }
        try requireCommittedReviewReceiptPayload(
            kind: "review-exception",
            bytes: CanonicalJSON.encode(
                ReviewExceptionReceiptPayload(
                    proof: proof,
                    successorBaselineDigest: baselines[index + 2].digest
                )
            ),
            in: receipts
        )
    }
    for convergence in convergenceReceipts {
        try requireCommittedReviewReceiptPayload(
            kind: "review-convergence",
            id: convergence.receiptID,
            eventKind: .reviewConverged,
            publicationAnchorEventHead: convergence.publicationAnchorEventHead,
            bytes: CanonicalJSON.encode(convergence),
            in: receipts
        )
    }
}

private func requireCommittedReviewReceiptPayload(
    kind: String,
    id: String? = nil,
    eventKind: WorkflowEventKind? = nil,
    publicationAnchorEventHead: HashDigest? = nil,
    bytes: Data,
    in receipts: [VerifiedPublishedReviewReceipt]
) throws {
    guard receipts.contains(where: { receipt in
        receipt.kind.rawValue == kind &&
            (id.map { $0 == receipt.id.rawValue } ?? true) &&
            (id.map { $0 == receipt.eventID } ?? true) &&
            (eventKind.map { $0 == receipt.eventKind } ?? true) &&
            (publicationAnchorEventHead.map {
                Optional($0) == receipt.publicationAnchorEventHead
            } ?? true) &&
            receipt.payloadBytes == bytes &&
            receipt.payloadDigest == CanonicalTreeDigest.sha256(bytes)
    }) else { throw PersistenceError.integrityViolation }
}

private func reviewArtifactSetDigest(
    _ artifacts: [ArtifactReference]
) throws -> HashDigest {
    CanonicalTreeDigest.sha256(try CanonicalJSON.encode(canonicalReviewArtifacts(artifacts)))
}

private func reviewApprovalDigests(
    _ approvals: [ApprovalRecord]
) throws -> [HashDigest] {
    try canonicalApprovalRecords(approvals).map {
        CanonicalTreeDigest.sha256(try CanonicalJSON.encode($0))
    }.sorted(by: reviewDigestOrder)
}

private func reviewApprovalSetDigest(
    _ approvals: [ApprovalRecord]
) throws -> HashDigest {
    CanonicalTreeDigest.sha256(try CanonicalJSON.encode(canonicalApprovalRecords(approvals)))
}

private func canonicalApprovalRecords(
    _ approvals: [ApprovalRecord]
) throws -> [ApprovalRecord] {
    try approvals.map { (try CanonicalJSON.encode($0), $0) }
        .sorted { $0.0.lexicographicallyPrecedes($1.0) }
        .map(\.1)
}

private func canonicalDigestList(_ values: [HashDigest]) -> [HashDigest] {
    values.sorted(by: reviewDigestOrder)
}

private func isCanonicalDigestList(_ values: [HashDigest]) -> Bool {
    values == canonicalDigestList(values) && Set(values).count == values.count
}

private func reviewDigestOrder(_ lhs: HashDigest, _ rhs: HashDigest) -> Bool {
    lhs.rawValue < rhs.rawValue
}
