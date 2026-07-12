import Foundation
import IFLContracts

public enum ReviewPathDecision: Hashable, Sendable {
    case directConvergenceNoAcceptedCurrentScope
    case requiresRemediation
    case requiresNormalConfirmation
    case exception(ReviewExceptionEligibility)
    case escalation(PolicyStatus)
}

public struct ReviewDispositionSummary: Hashable, Sendable {
    public let initialJoinCompleted: Bool
    public let acceptedCurrentScopeCount: Int
    public let hasResolvedTransitions: Bool
    public let hasAmbiguity: Bool

    public init(
        initialJoinCompleted: Bool,
        acceptedCurrentScopeCount: Int,
        hasResolvedTransitions: Bool,
        hasAmbiguity: Bool
    ) {
        self.initialJoinCompleted = initialJoinCompleted
        self.acceptedCurrentScopeCount = acceptedCurrentScopeCount
        self.hasResolvedTransitions = hasResolvedTransitions
        self.hasAmbiguity = hasAmbiguity
    }
}

public enum KernelReviewHistoryEventKind: String, Codable, CaseIterable, Hashable, Sendable {
    case registerJoined = "register_joined"
    case remediationRecorded = "remediation_recorded"
    case confirmationRecorded = "confirmation_recorded"
}

public struct KernelReviewHistoryEntry: Codable, Hashable, Sendable {
    public let kind: KernelReviewHistoryEventKind
    public let roundID: ReviewRoundID
    public let registerDigest: HashDigest
    public let baselineDigest: HashDigest
    public let eventHead: HashDigest

    init(
        kind: KernelReviewHistoryEventKind,
        roundID: ReviewRoundID,
        registerDigest: HashDigest,
        baselineDigest: HashDigest,
        eventHead: HashDigest
    ) {
        self.kind = kind
        self.roundID = roundID
        self.registerDigest = registerDigest
        self.baselineDigest = baselineDigest
        self.eventHead = eventHead
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            kind: try values.decode(KernelReviewHistoryEventKind.self, forKey: .kind),
            roundID: try values.decode(ReviewRoundID.self, forKey: .roundID),
            registerDigest: try values.decode(HashDigest.self, forKey: .registerDigest),
            baselineDigest: try values.decode(HashDigest.self, forKey: .baselineDigest),
            eventHead: try values.decode(HashDigest.self, forKey: .eventHead)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case roundID = "round_id"
        case registerDigest = "register_digest"
        case baselineDigest = "baseline_digest"
        case eventHead = "event_head"
    }
}

public struct KernelReviewHistory: Codable, Hashable, Sendable {
    public let entries: [KernelReviewHistoryEntry]
    public let priorExceptionRoundIDs: [ReviewRoundID]

    init(
        entries: [KernelReviewHistoryEntry],
        priorExceptionRoundIDs: [ReviewRoundID]
    ) {
        self.entries = entries
        self.priorExceptionRoundIDs = priorExceptionRoundIDs
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 1 else {
            throw WorkflowPolicyError.invalidPolicy
        }
        self.init(
            entries: try values.decode([KernelReviewHistoryEntry].self, forKey: .entries),
            priorExceptionRoundIDs: try values.decode(
                [ReviewRoundID].self,
                forKey: .priorExceptionRoundIDs
            )
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(1, forKey: .schemaVersion)
        try values.encode(entries, forKey: .entries)
        try values.encode(priorExceptionRoundIDs, forKey: .priorExceptionRoundIDs)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case entries
        case priorExceptionRoundIDs = "prior_exception_round_ids"
    }
}

public enum ReviewFindingState: String, Codable, CaseIterable, Hashable, Sendable {
    case active
    case resolved
    case failedRemediation = "failed_remediation"
}

public struct ReviewFindingSummary: Codable, Hashable, Sendable {
    public let fingerprint: FailureFingerprint
    public let severity: RiskClass
    public let mustFix: Bool
    public let state: ReviewFindingState

    public init(
        fingerprint: FailureFingerprint,
        severity: RiskClass,
        mustFix: Bool,
        state: ReviewFindingState
    ) {
        self.fingerprint = fingerprint
        self.severity = severity
        self.mustFix = mustFix
        self.state = state
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            fingerprint: try values.decode(FailureFingerprint.self, forKey: .fingerprint),
            severity: try values.decode(RiskClass.self, forKey: .severity),
            mustFix: try values.decode(Bool.self, forKey: .mustFix),
            state: try values.decode(ReviewFindingState.self, forKey: .state)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case fingerprint
        case severity
        case mustFix = "must_fix"
        case state
    }
}

public struct ReviewExceptionContext: Codable, Hashable, Sendable {
    public let runID: RunID
    public let cycleID: ReviewCycleID
    public let gate: ReviewGateKind
    public let precedingRoundID: ReviewRoundID
    public let precedingRegisterDigest: HashDigest
    public let precedingBaselineDigest: HashDigest
    public let roundAnchorEventHead: HashDigest
    public let immediatelyPreceding: [ReviewFindingSummary]
    public let current: [ReviewFindingSummary]
    public let history: KernelReviewHistory
    public let exhaustionCause: RetryExhaustionCause

    public init(
        runID: RunID,
        cycleID: ReviewCycleID,
        gate: ReviewGateKind,
        precedingRoundID: ReviewRoundID,
        precedingRegisterDigest: HashDigest,
        precedingBaselineDigest: HashDigest,
        roundAnchorEventHead: HashDigest,
        immediatelyPreceding: [ReviewFindingSummary],
        current: [ReviewFindingSummary],
        history: KernelReviewHistory,
        exhaustionCause: RetryExhaustionCause
    ) {
        self.runID = runID
        self.cycleID = cycleID
        self.gate = gate
        self.precedingRoundID = precedingRoundID
        self.precedingRegisterDigest = precedingRegisterDigest
        self.precedingBaselineDigest = precedingBaselineDigest
        self.roundAnchorEventHead = roundAnchorEventHead
        self.immediatelyPreceding = immediatelyPreceding
        self.current = current
        self.history = history
        self.exhaustionCause = exhaustionCause
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 1,
              let exhaustionCause = RetryExhaustionCause(
                rawValue: try values.decode(String.self, forKey: .exhaustionCause)
              )
        else { throw WorkflowPolicyError.invalidPolicy }
        self.init(
            runID: try values.decode(RunID.self, forKey: .runID),
            cycleID: try values.decode(ReviewCycleID.self, forKey: .cycleID),
            gate: try values.decode(ReviewGateKind.self, forKey: .gate),
            precedingRoundID: try values.decode(ReviewRoundID.self, forKey: .precedingRoundID),
            precedingRegisterDigest: try values.decode(
                HashDigest.self,
                forKey: .precedingRegisterDigest
            ),
            precedingBaselineDigest: try values.decode(
                HashDigest.self,
                forKey: .precedingBaselineDigest
            ),
            roundAnchorEventHead: try values.decode(
                HashDigest.self,
                forKey: .roundAnchorEventHead
            ),
            immediatelyPreceding: try values.decode(
                [ReviewFindingSummary].self,
                forKey: .immediatelyPreceding
            ),
            current: try values.decode([ReviewFindingSummary].self, forKey: .current),
            history: try values.decode(KernelReviewHistory.self, forKey: .history),
            exhaustionCause: exhaustionCause
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(1, forKey: .schemaVersion)
        try values.encode(runID, forKey: .runID)
        try values.encode(cycleID, forKey: .cycleID)
        try values.encode(gate, forKey: .gate)
        try values.encode(precedingRoundID, forKey: .precedingRoundID)
        try values.encode(precedingRegisterDigest, forKey: .precedingRegisterDigest)
        try values.encode(precedingBaselineDigest, forKey: .precedingBaselineDigest)
        try values.encode(roundAnchorEventHead, forKey: .roundAnchorEventHead)
        try values.encode(immediatelyPreceding, forKey: .immediatelyPreceding)
        try values.encode(current, forKey: .current)
        try values.encode(history, forKey: .history)
        try values.encode(exhaustionCause.rawValue, forKey: .exhaustionCause)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case runID = "run_id"
        case cycleID = "cycle_id"
        case gate
        case precedingRoundID = "preceding_round_id"
        case precedingRegisterDigest = "preceding_register_digest"
        case precedingBaselineDigest = "preceding_baseline_digest"
        case roundAnchorEventHead = "round_anchor_event_head"
        case immediatelyPreceding = "immediately_preceding"
        case current
        case history
        case exhaustionCause = "exhaustion_cause"
    }
}

/// Exact committed event/receipt history needed to admit one exception round. Wire DTOs never mint
/// this capability; every production path starts from committed receipt authority.
struct VerifiedActiveReviewCycleHistory: Hashable, Sendable {
    let predecessorRegisterDigest: HashDigest
    let currentRegisterDigest: HashDigest
    let remediationBatchDigest: HashDigest
    let confirmationReceiptDigest: HashDigest
    let registerJoinedEventHead: HashDigest
    let remediationEventHead: HashDigest
    let confirmationEventHead: HashDigest
    let confirmationRoundID: ReviewRoundID
    let confirmationRegisterDigest: HashDigest
    let confirmationBaselineDigest: HashDigest

    private init(
        predecessorRegisterDigest: HashDigest,
        currentRegisterDigest: HashDigest,
        remediationBatchDigest: HashDigest,
        confirmationReceiptDigest: HashDigest,
        registerJoinedEventHead: HashDigest,
        remediationEventHead: HashDigest,
        confirmationEventHead: HashDigest,
        confirmationRoundID: ReviewRoundID,
        confirmationRegisterDigest: HashDigest,
        confirmationBaselineDigest: HashDigest
    ) {
        self.predecessorRegisterDigest = predecessorRegisterDigest
        self.currentRegisterDigest = currentRegisterDigest
        self.remediationBatchDigest = remediationBatchDigest
        self.confirmationReceiptDigest = confirmationReceiptDigest
        self.registerJoinedEventHead = registerJoinedEventHead
        self.remediationEventHead = remediationEventHead
        self.confirmationEventHead = confirmationEventHead
        self.confirmationRoundID = confirmationRoundID
        self.confirmationRegisterDigest = confirmationRegisterDigest
        self.confirmationBaselineDigest = confirmationBaselineDigest
    }

    static func verify(
        predecessorRegister: VerifiedIssueRegister,
        currentRegister: VerifiedIssueRegister,
        remediation: VerifiedCommittedRemediationSuccessor,
        predecessorRegisterReceipt: VerifiedPublishedReviewReceipt,
        currentRegisterReceipt: VerifiedPublishedReviewReceipt,
        confirmationReceipt: VerifiedPublishedReviewReceipt,
        persistedRun: PersistedRun
    ) throws -> VerifiedActiveReviewCycleHistory {
        try ReviewCommittedReceiptVerifier.validateActiveChain(persistedRun)
        let committedHistoryReceipts = [
            predecessorRegisterReceipt,
            currentRegisterReceipt,
            confirmationReceipt,
        ] + remediation.receipts
        for receipt in committedHistoryReceipts {
            guard try ReviewCommittedReceiptVerifier.verify(
                id: receipt.id,
                kind: receipt.kind,
                digest: receipt.payloadDigest,
                in: persistedRun
            ) == receipt else { throw PersistenceError.integrityViolation }
        }
        let runID = currentRegister.baseline.runID
        let cycleID = currentRegister.baseline.cycleID
        let gate = currentRegister.baseline.gate
        let predecessorBytes = try CanonicalJSON.encode(predecessorRegister.register)
        let currentBytes = try CanonicalJSON.encode(currentRegister.register)
        let remediationBytes = try CanonicalJSON.encode(remediation.batch)
        let confirmation = try ConfirmationReceipt.decodeCanonical(
            from: confirmationReceipt.payloadBytes
        )
        guard let cycle = persistedRun.state.reviewCycle,
              currentRegister.register.digest == remediation.sourceRegister.register.digest,
              currentRegister.baseline.digest == remediation.sourceRegister.baseline.digest,
              cycle.id == currentRegister.baseline.cycleID,
              cycle.gate == currentRegister.baseline.gate,
              cycle.currentRoundID == currentRegister.baseline.roundID,
              cycle.phase == .awaitingRemediation,
              cycle.closedRoundID == currentRegister.baseline.roundID,
              cycle.closedBaselineDigest == currentRegister.baseline.digest,
              cycle.closedRegisterDigest == currentRegister.register.digest,
              cycle.closedPathDecision == .requiresRemediation,
              cycle.lastRemediatedRoundID == currentRegister.baseline.roundID,
              cycle.confirmationReceiptID == confirmationReceipt.id,
              cycle.didRecordConfirmation,
              persistedRun.eventHead == remediation.producedEventHead,
              predecessorRegisterReceipt.kind == (try ReceiptKind(validating: "issue-register")),
              predecessorRegisterReceipt.eventKind == .reviewInventoryClosed,
              predecessorRegisterReceipt.runID == runID,
              predecessorRegisterReceipt.payloadBytes == predecessorBytes,
              currentRegisterReceipt.kind == (try ReceiptKind(validating: "issue-register")),
              currentRegisterReceipt.eventKind == .reviewInventoryClosed,
              currentRegisterReceipt.runID == runID,
              currentRegisterReceipt.payloadBytes == currentBytes,
              remediation.receipts.contains(where: {
                  $0.kind.rawValue == "review-remediation-batch" &&
                      $0.eventKind == .reviewRemediationRecorded &&
                      $0.runID == runID &&
                      $0.payloadBytes == remediationBytes
              }),
              confirmationReceipt.kind == (try ReceiptKind(validating: "review-confirmation")),
              confirmationReceipt.eventKind == .reviewConfirmationRecorded,
              confirmationReceipt.runID == runID,
              persistedRun.state.runID == runID,
              try confirmation.hasValidIdentity(runID: runID, cycleID: cycleID, gate: gate),
              Set([
                  currentRegisterReceipt.producedEventHead,
                  remediation.producedEventHead,
                  confirmationReceipt.producedEventHead,
              ]).count == 3
        else { throw WorkflowPolicyError.invalidExceptionProof }
        return VerifiedActiveReviewCycleHistory(
            predecessorRegisterDigest: predecessorRegister.register.digest,
            currentRegisterDigest: currentRegister.register.digest,
            remediationBatchDigest: remediation.batch.digest,
            confirmationReceiptDigest: confirmation.digest,
            registerJoinedEventHead: currentRegisterReceipt.producedEventHead,
            remediationEventHead: remediation.producedEventHead,
            confirmationEventHead: confirmationReceipt.producedEventHead,
            confirmationRoundID: confirmation.roundID,
            confirmationRegisterDigest: confirmation.confirmationRegisterDigest,
            confirmationBaselineDigest: confirmation.successorBaselineDigest
        )
    }

    #if DEBUG
    static func testing(
        predecessorRegister: VerifiedIssueRegister,
        currentRegister: VerifiedIssueRegister,
        remediation: VerifiedCommittedRemediationSuccessor,
        registerJoinedEventHead: HashDigest,
        remediationEventHead: HashDigest,
        confirmationEventHead: HashDigest,
        confirmationRoundID: ReviewRoundID? = nil,
        confirmationRegisterDigest: HashDigest? = nil,
        confirmationBaselineDigest: HashDigest? = nil
    ) -> VerifiedActiveReviewCycleHistory {
        VerifiedActiveReviewCycleHistory(
            predecessorRegisterDigest: predecessorRegister.register.digest,
            currentRegisterDigest: currentRegister.register.digest,
            remediationBatchDigest: remediation.batch.digest,
            confirmationReceiptDigest: CanonicalTreeDigest.sha256(
                Data("verified-confirmation-test-history".utf8)
            ),
            registerJoinedEventHead: registerJoinedEventHead,
            remediationEventHead: remediationEventHead,
            confirmationEventHead: confirmationEventHead,
            confirmationRoundID: confirmationRoundID ?? currentRegister.baseline.roundID,
            confirmationRegisterDigest: confirmationRegisterDigest ??
                currentRegister.register.digest,
            confirmationBaselineDigest: confirmationBaselineDigest ??
                currentRegister.baseline.digest
        )
    }
    #endif
}

public struct ReviewExceptionEligibility: Hashable, Sendable {
    public let runID: RunID
    public let cycleID: ReviewCycleID
    public let gate: ReviewGateKind
    public let precedingRoundID: ReviewRoundID
    public let precedingRegisterDigest: HashDigest
    public let precedingBaselineDigest: HashDigest
    public let roundAnchorEventHead: HashDigest
    public let remediationEventHead: HashDigest
    public let confirmationEventHead: HashDigest
    public let qualifyingFingerprints: [FailureFingerprint]
    public let nextSemanticOrdinal: UInt64
    public let remainingExceptionRounds: Int
    public let policyVersion: Int
    public let budgetDigest: HashDigest
    public let historyDigest: HashDigest
    public let nextRoundID: ReviewRoundID
    public let proofDigest: HashDigest

    private init(
        context: ReviewExceptionContext,
        qualifyingFingerprints: [FailureFingerprint],
        nextSemanticOrdinal: UInt64,
        remainingExceptionRounds: Int,
        budget: AttemptBudget,
        remediationEventHead: HashDigest,
        confirmationEventHead: HashDigest,
        historyDigest: HashDigest,
        nextRoundID: ReviewRoundID,
        proofDigest: HashDigest
    ) {
        runID = context.runID
        cycleID = context.cycleID
        gate = context.gate
        precedingRoundID = context.precedingRoundID
        precedingRegisterDigest = context.precedingRegisterDigest
        precedingBaselineDigest = context.precedingBaselineDigest
        roundAnchorEventHead = context.roundAnchorEventHead
        self.remediationEventHead = remediationEventHead
        self.confirmationEventHead = confirmationEventHead
        self.qualifyingFingerprints = qualifyingFingerprints
        self.nextSemanticOrdinal = nextSemanticOrdinal
        self.remainingExceptionRounds = remainingExceptionRounds
        policyVersion = budget.policyVersion
        budgetDigest = budget.policyDigest
        self.historyDigest = historyDigest
        self.nextRoundID = nextRoundID
        self.proofDigest = proofDigest
    }

    var hasValidDigest: Bool {
        guard let expected = try? Self.makeProofDigest(
            runID: runID,
            cycleID: cycleID,
            gate: gate,
            precedingRoundID: precedingRoundID,
            precedingRegisterDigest: precedingRegisterDigest,
            precedingBaselineDigest: precedingBaselineDigest,
            roundAnchorEventHead: roundAnchorEventHead,
            remediationEventHead: remediationEventHead,
            confirmationEventHead: confirmationEventHead,
            qualifyingFingerprints: qualifyingFingerprints,
            nextSemanticOrdinal: nextSemanticOrdinal,
            remainingExceptionRounds: remainingExceptionRounds,
            policyVersion: policyVersion,
            budgetDigest: budgetDigest,
            historyDigest: historyDigest,
            nextRoundID: nextRoundID
        ) else { return false }
        return expected == proofDigest
    }

    private static func makeProofDigest(
        runID: RunID,
        cycleID: ReviewCycleID,
        gate: ReviewGateKind,
        precedingRoundID: ReviewRoundID,
        precedingRegisterDigest: HashDigest,
        precedingBaselineDigest: HashDigest,
        roundAnchorEventHead: HashDigest,
        remediationEventHead: HashDigest,
        confirmationEventHead: HashDigest,
        qualifyingFingerprints: [FailureFingerprint],
        nextSemanticOrdinal: UInt64,
        remainingExceptionRounds: Int,
        policyVersion: Int,
        budgetDigest: HashDigest,
        historyDigest: HashDigest,
        nextRoundID: ReviewRoundID
    ) throws -> HashDigest {
        CanonicalTreeDigest.sha256(
            try CanonicalJSON.encode(
                ReviewExceptionProofPreimage(
                    schemaVersion: 1,
                    runID: runID,
                    cycleID: cycleID,
                    gate: gate,
                    precedingRoundID: precedingRoundID,
                    precedingRegisterDigest: precedingRegisterDigest,
                    precedingBaselineDigest: precedingBaselineDigest,
                    roundAnchorEventHead: roundAnchorEventHead,
                    remediationEventHead: remediationEventHead,
                    confirmationEventHead: confirmationEventHead,
                    qualifyingFingerprints: qualifyingFingerprints.map(\.rawValue),
                    nextSemanticOrdinal: nextSemanticOrdinal,
                    remainingExceptionRounds: remainingExceptionRounds,
                    policyVersion: policyVersion,
                    budgetDigest: budgetDigest,
                    historyDigest: historyDigest,
                    nextRoundID: nextRoundID
                )
            )
        )
    }

    fileprivate static func make(
        context: ReviewExceptionContext,
        qualifyingFingerprints: [FailureFingerprint],
        nextSemanticOrdinal: UInt64,
        remainingExceptionRounds: Int,
        budget: AttemptBudget,
        remediationEventHead: HashDigest,
        confirmationEventHead: HashDigest,
        historyDigest: HashDigest,
        nextRoundID: ReviewRoundID
    ) throws -> ReviewExceptionEligibility {
        let proofDigest = try makeProofDigest(
            runID: context.runID,
            cycleID: context.cycleID,
            gate: context.gate,
            precedingRoundID: context.precedingRoundID,
            precedingRegisterDigest: context.precedingRegisterDigest,
            precedingBaselineDigest: context.precedingBaselineDigest,
            roundAnchorEventHead: context.roundAnchorEventHead,
            remediationEventHead: remediationEventHead,
            confirmationEventHead: confirmationEventHead,
            qualifyingFingerprints: qualifyingFingerprints,
            nextSemanticOrdinal: nextSemanticOrdinal,
            remainingExceptionRounds: remainingExceptionRounds,
            policyVersion: budget.policyVersion,
            budgetDigest: budget.policyDigest,
            historyDigest: historyDigest,
            nextRoundID: nextRoundID
        )
        return ReviewExceptionEligibility(
            context: context,
            qualifyingFingerprints: qualifyingFingerprints,
            nextSemanticOrdinal: nextSemanticOrdinal,
            remainingExceptionRounds: remainingExceptionRounds,
            budget: budget,
            remediationEventHead: remediationEventHead,
            confirmationEventHead: confirmationEventHead,
            historyDigest: historyDigest,
            nextRoundID: nextRoundID,
            proofDigest: proofDigest
        )
    }
}

public enum ReviewExceptionDecision: Hashable, Sendable {
    case eligible(ReviewExceptionEligibility)
    case notEligible
    case exhausted(PolicyStatus)
    case escalation(PolicyStatus)
}

/// Non-Codable authority for exactly one bounded exception successor. Publication consumes this
/// capability as a unit; a raw eligibility DTO or caller-created baseline is never sufficient.
public struct VerifiedReviewExceptionAdmission: Sendable {
    public let eligibility: ReviewExceptionEligibility
    public let successorBaseline: ReviewBaseline
    let remediation: VerifiedCommittedRemediationSuccessor
    let frozenBudget: VerifiedFrozenBudgetFact
    let activeHistory: VerifiedActiveReviewCycleHistory

    fileprivate init(
        eligibility: ReviewExceptionEligibility,
        remediation: VerifiedCommittedRemediationSuccessor,
        frozenBudget: VerifiedFrozenBudgetFact,
        activeHistory: VerifiedActiveReviewCycleHistory
    ) {
        self.eligibility = eligibility
        successorBaseline = remediation.successorBaseline
        self.remediation = remediation
        self.frozenBudget = frozenBudget
        self.activeHistory = activeHistory
    }

}

public enum VerifiedReviewExceptionDecision: Sendable {
    case eligible(VerifiedReviewExceptionAdmission)
    case notEligible
    case exhausted(PolicyStatus)
    case escalation(PolicyStatus)
}

struct VerifiedReviewExceptionFacts: Sendable {
    let context: ReviewExceptionContext
    let predecessorRegister: VerifiedIssueRegister
    let remediation: VerifiedCommittedRemediationSuccessor
    let activeHistory: VerifiedActiveReviewCycleHistory
    let priorAdmissions: [VerifiedReviewExceptionAdmission]
    let budget: AttemptBudget

    private init(
        context: ReviewExceptionContext,
        predecessorRegister: VerifiedIssueRegister,
        remediation: VerifiedCommittedRemediationSuccessor,
        activeHistory: VerifiedActiveReviewCycleHistory,
        priorAdmissions: [VerifiedReviewExceptionAdmission],
        budget: AttemptBudget
    ) {
        self.context = context
        self.predecessorRegister = predecessorRegister
        self.remediation = remediation
        self.activeHistory = activeHistory
        self.priorAdmissions = priorAdmissions
        self.budget = budget
    }

    static func verify(
        claim: ReviewExceptionContext,
        predecessorRegister: VerifiedIssueRegister,
        remediation: VerifiedCommittedRemediationSuccessor,
        activeHistory: VerifiedActiveReviewCycleHistory,
        priorAdmissions: [VerifiedReviewExceptionAdmission],
        budget: AttemptBudget
    ) throws -> VerifiedReviewExceptionFacts {
        let currentRegister = remediation.sourceRegister
        let predecessor = predecessorRegister.baseline
        let current = currentRegister.baseline
        let successor = remediation.successorBaseline
        let normalConfirmationRegister = current.kind == .normalConfirmation
            ? currentRegister
            : priorAdmissions.first?.remediation.sourceRegister
        let expectedCurrentOrdinal = try incrementChecked(predecessor.semanticOrdinal)
        let expectedSuccessorOrdinal = try incrementChecked(current.semanticOrdinal)
        guard let normalConfirmationRegister,
              current.semanticOrdinal >= 1,
              let expectedPriorCount = Int(exactly: current.semanticOrdinal - 1),
              current.kind == .normalConfirmation || current.kind == .exception,
              hasExpectedPredecessorKind(predecessor, current: current),
              current.predecessorBaselineDigest == predecessor.digest,
              current.semanticOrdinal == expectedCurrentOrdinal,
              successor.kind == .exception,
              successor.predecessorBaselineDigest == current.digest,
              successor.semanticOrdinal == expectedSuccessorOrdinal,
              successor.preCreationEventHead == remediation.publicationAnchorEventHead,
              currentRegister.register.pathDecision == .requiresRemediation,
              !currentRegister.register.acceptedCurrentScopeAssignments.isEmpty,
              activeHistory.predecessorRegisterDigest == predecessorRegister.register.digest,
              activeHistory.currentRegisterDigest == currentRegister.register.digest,
              activeHistory.remediationBatchDigest == remediation.batch.digest,
              budget.policyVersion == 1,
              budget.policyDigest == current.convergencePolicyDigest,
              priorAdmissions.count == expectedPriorCount,
              hasExactPriorAdmissionLineage(
                  priorAdmissions,
                  currentBaseline: current
              ),
              activeHistory.confirmationRoundID == normalConfirmationRegister.baseline.roundID,
              activeHistory.confirmationRegisterDigest ==
                normalConfirmationRegister.register.digest,
              activeHistory.confirmationBaselineDigest ==
                normalConfirmationRegister.baseline.digest,
              hasImmutableReviewFacts(predecessor, current, successor)
        else { throw WorkflowPolicyError.invalidExceptionProof }

        let priorRoundIDs = priorAdmissions.map { $0.successorBaseline.roundID }
        let derived = ReviewExceptionContext(
            runID: current.runID,
            cycleID: current.cycleID,
            gate: current.gate,
            precedingRoundID: current.roundID,
            precedingRegisterDigest: currentRegister.register.digest,
            precedingBaselineDigest: current.digest,
            roundAnchorEventHead: successor.preCreationEventHead,
            immediatelyPreceding: summaries(
                predecessorRegister.register,
                acceptedState: .failedRemediation
            ),
            current: summaries(currentRegister.register, acceptedState: .active),
            history: KernelReviewHistory(
                entries: [
                    KernelReviewHistoryEntry(
                        kind: .registerJoined,
                        roundID: current.roundID,
                        registerDigest: currentRegister.register.digest,
                        baselineDigest: current.digest,
                        eventHead: activeHistory.registerJoinedEventHead
                    ),
                    KernelReviewHistoryEntry(
                        kind: .remediationRecorded,
                        roundID: current.roundID,
                        registerDigest: currentRegister.register.digest,
                        baselineDigest: current.digest,
                        eventHead: activeHistory.remediationEventHead
                    ),
                    KernelReviewHistoryEntry(
                        kind: .confirmationRecorded,
                        roundID: activeHistory.confirmationRoundID,
                        registerDigest: activeHistory.confirmationRegisterDigest,
                        baselineDigest: activeHistory.confirmationBaselineDigest,
                        eventHead: activeHistory.confirmationEventHead
                    ),
                ],
                priorExceptionRoundIDs: priorRoundIDs
            ),
            exhaustionCause: .authorityOrDecisionRequired
        )
        guard claim == derived else { throw WorkflowPolicyError.invalidExceptionProof }
        return VerifiedReviewExceptionFacts(
            context: derived,
            predecessorRegister: predecessorRegister,
            remediation: remediation,
            activeHistory: activeHistory,
            priorAdmissions: priorAdmissions,
            budget: budget
        )
    }
}

public struct ReviewConvergencePolicy: Sendable {
    public init() {}

    func nextExceptionSemanticOrdinal(after predecessor: UInt64) throws -> UInt64 {
        let next = try incrementChecked(predecessor)
        guard next >= 2 else { throw WorkflowError.invalidReviewRound }
        return next
    }

    public func selectInitialPath(
        _ summary: ReviewDispositionSummary
    ) -> ReviewPathDecision {
        guard summary.initialJoinCompleted,
              summary.acceptedCurrentScopeCount >= 0,
              !summary.hasResolvedTransitions,
              !summary.hasAmbiguity
        else { return .escalation(.waitingForUser) }
        return summary.acceptedCurrentScopeCount == 0
            ? .directConvergenceNoAcceptedCurrentScope
            : .requiresRemediation
    }

    public func admitNormalConfirmation(
        _ history: KernelReviewHistory
    ) throws -> ReviewPathDecision {
        guard history.entries.contains(where: { $0.kind == .registerJoined }) else {
            throw WorkflowPolicyError.initialReviewRequired
        }
        guard history.entries.count >= 2,
              isBound(history.entries[0], kind: .registerJoined, to: history.entries[0]),
              isBound(history.entries[1], kind: .remediationRecorded, to: history.entries[0]),
              history.entries[0].eventHead != history.entries[1].eventHead
        else { throw WorkflowPolicyError.remediationRequired }
        if history.entries.count == 3,
           isBound(history.entries[2], kind: .confirmationRecorded, to: history.entries[0]),
           Set(history.entries.map(\.eventHead)).count == 3 {
            throw WorkflowPolicyError.normalConfirmationAlreadyRecorded
        }
        guard history.entries.count == 2 else {
            throw WorkflowPolicyError.remediationRequired
        }
        return .requiresNormalConfirmation
    }

    #if DEBUG
    func evaluateException(
        _ context: ReviewExceptionContext,
        budget: AttemptBudget
    ) -> ReviewExceptionDecision {
        evaluateContext(context, budget: budget)
    }
    #endif

    func evaluateException(
        _ facts: VerifiedReviewExceptionFacts
    ) -> VerifiedReviewExceptionDecision {
        switch evaluateContext(facts.context, budget: facts.budget) {
        case .eligible(let eligibility):
            let successor = facts.remediation.successorBaseline
            guard eligibility.nextRoundID == successor.roundID,
                  eligibility.nextSemanticOrdinal == successor.semanticOrdinal,
                  eligibility.roundAnchorEventHead == successor.preCreationEventHead,
                  eligibility.precedingBaselineDigest == successor.predecessorBaselineDigest,
                  eligibility.remediationEventHead == facts.activeHistory.remediationEventHead,
                  eligibility.confirmationEventHead == facts.activeHistory.confirmationEventHead,
                  let frozenBudget = try? VerifiedFrozenBudgetFact.freeze(
                      budget: facts.budget,
                      runID: eligibility.runID,
                      cycleID: eligibility.cycleID,
                      convergencePolicyDigest: facts.remediation.sourceRegister.baseline
                        .convergencePolicyDigest,
                      boundEventHead: successor.preCreationEventHead
                  )
            else { return .escalation(.failed) }
            return .eligible(
                VerifiedReviewExceptionAdmission(
                    eligibility: eligibility,
                    remediation: facts.remediation,
                    frozenBudget: frozenBudget,
                    activeHistory: facts.activeHistory
                )
            )
        case .notEligible:
            return .notEligible
        case .exhausted(let status):
            return .exhausted(status)
        case .escalation(let status):
            return .escalation(status)
        }
    }

    private func evaluateContext(
        _ context: ReviewExceptionContext,
        budget: AttemptBudget
    ) -> ReviewExceptionDecision {
        guard hasUniqueFingerprints(context.immediatelyPreceding),
              hasUniqueFingerprints(context.current),
              hasValidConfirmedHistory(context),
              Set(context.history.priorExceptionRoundIDs).count ==
                context.history.priorExceptionRoundIDs.count,
              hasContinuousExceptionHistory(context)
        else { return .escalation(.failed) }

        let previous = Dictionary(
            uniqueKeysWithValues: context.immediatelyPreceding.map { ($0.fingerprint, $0) }
        )
        let qualifying = context.current.filter { current in
            guard current.state == .active else { return false }
            if current.mustFix { return true }
            guard current.severity == .high || current.severity == .critical else {
                return false
            }
            guard let predecessor = previous[current.fingerprint] else { return true }
            return current.severity.policyRank > predecessor.severity.policyRank ||
                predecessor.state == .resolved ||
                predecessor.state == .failedRemediation
        }

        guard !qualifying.isEmpty else { return .notEligible }
        let used = context.history.priorExceptionRoundIDs.count
        guard used <= budget.exceptionRounds else {
            return .escalation(.failed)
        }
        guard used < budget.exceptionRounds else {
            return .exhausted(Self.exhaustionStatus(for: context.exhaustionCause))
        }
        guard let usedOrdinal = UInt64(exactly: used),
              let predecessorOrdinal = try? incrementChecked(usedOrdinal),
              let nextOrdinal = try? nextExceptionSemanticOrdinal(after: predecessorOrdinal)
        else {
            return .escalation(.failed)
        }
        guard let nextRoundID = try? ReviewRoundID.derive(
                runID: context.runID,
                gate: context.gate,
                cycleID: context.cycleID,
                kind: .exception,
                semanticOrdinal: nextOrdinal,
                roundAnchorEventHead: context.roundAnchorEventHead,
                predecessorBaselineDigest: context.precedingBaselineDigest
              ),
              let historyDigest = try? makeHistoryDigest(context.history),
              let remediationHead = context.history.entries
                .first(where: { $0.kind == .remediationRecorded })?.eventHead,
              let confirmationHead = context.history.entries
                .first(where: { $0.kind == .confirmationRecorded })?.eventHead
        else { return .escalation(.failed) }
        let fingerprints = qualifying
            .map(\.fingerprint)
            .sorted(by: { $0.rawValue < $1.rawValue })
        guard let proof = try? ReviewExceptionEligibility.make(
            context: context,
            qualifyingFingerprints: fingerprints,
            nextSemanticOrdinal: nextOrdinal,
            remainingExceptionRounds: budget.exceptionRounds - used - 1,
            budget: budget,
            remediationEventHead: remediationHead,
            confirmationEventHead: confirmationHead,
            historyDigest: historyDigest,
            nextRoundID: nextRoundID
        ) else { return .escalation(.failed) }
        return .eligible(proof)
    }

    private func hasValidConfirmedHistory(_ context: ReviewExceptionContext) -> Bool {
        let entries = context.history.entries
        guard entries.count == 3,
              let register = entries.first(where: { $0.kind == .registerJoined }),
              let remediation = entries.first(where: { $0.kind == .remediationRecorded }),
              let confirmation = entries.first(where: { $0.kind == .confirmationRecorded }),
              entries.filter({ $0.kind == .registerJoined }).count == 1,
              entries.filter({ $0.kind == .remediationRecorded }).count == 1,
              entries.filter({ $0.kind == .confirmationRecorded }).count == 1,
              isBound(register, kind: .registerJoined, context: context),
              isBound(remediation, kind: .remediationRecorded, context: context),
              confirmation.kind == .confirmationRecorded,
              Set(entries.map(\.eventHead)).count == entries.count
        else { return false }
        return true
    }

    private func hasContinuousExceptionHistory(_ context: ReviewExceptionContext) -> Bool {
        guard let latestExceptionRound = context.history.priorExceptionRoundIDs.last else {
            return true
        }
        return latestExceptionRound == context.precedingRoundID
    }

    private func isBound(
        _ entry: KernelReviewHistoryEntry,
        kind: KernelReviewHistoryEventKind,
        to reference: KernelReviewHistoryEntry
    ) -> Bool {
        entry.kind == kind &&
            entry.roundID == reference.roundID &&
            entry.registerDigest == reference.registerDigest &&
            entry.baselineDigest == reference.baselineDigest
    }

    private func isBound(
        _ entry: KernelReviewHistoryEntry,
        kind: KernelReviewHistoryEventKind,
        context: ReviewExceptionContext
    ) -> Bool {
        entry.kind == kind &&
            entry.roundID == context.precedingRoundID &&
            entry.registerDigest == context.precedingRegisterDigest &&
            entry.baselineDigest == context.precedingBaselineDigest
    }

    private func hasUniqueFingerprints(_ findings: [ReviewFindingSummary]) -> Bool {
        Set(findings.map(\.fingerprint)).count == findings.count
    }

    private func makeHistoryDigest(_ history: KernelReviewHistory) throws -> HashDigest {
        CanonicalTreeDigest.sha256(
            try CanonicalJSON.encode(
                KernelReviewHistoryPreimage(
                    schemaVersion: 1,
                    entries: history.entries.map {
                        KernelReviewHistoryEntryPreimage(
                            kind: $0.kind.rawValue,
                            roundID: $0.roundID,
                            registerDigest: $0.registerDigest,
                            baselineDigest: $0.baselineDigest,
                            eventHead: $0.eventHead
                        )
                    },
                    priorExceptionRoundIDs: history.priorExceptionRoundIDs
                )
            )
        )
    }

    private static func exhaustionStatus(for cause: RetryExhaustionCause) -> PolicyStatus {
        switch RetryPolicy.exhaustionResolution(for: cause) {
        case .waitForUser: .waitingForUser
        case .block: .blocked
        case .fail: .failed
        case .continueWorkflow, .rollback: .failed
        }
    }
}

private func summaries(
    _ register: IssueRegister,
    acceptedState: ReviewFindingState
) -> [ReviewFindingSummary] {
    let dispositions = Dictionary(
        uniqueKeysWithValues: register.dispositions.map { ($0.fingerprint, $0) }
    )
    return register.entries.map { entry in
        let state: ReviewFindingState = dispositions[
            entry.fingerprint.failureFingerprint
        ]?.entersRemediation == true ? acceptedState : .resolved
        return ReviewFindingSummary(
            fingerprint: entry.fingerprint.failureFingerprint,
            severity: entry.severity,
            mustFix: entry.mustFix,
            state: state
        )
    }.sorted { $0.fingerprint.rawValue < $1.fingerprint.rawValue }
}

private func hasImmutableReviewFacts(
    _ predecessor: ReviewBaseline,
    _ current: ReviewBaseline,
    _ successor: ReviewBaseline
) -> Bool {
    [current, successor].allSatisfy { baseline in
        baseline.runID == predecessor.runID &&
            baseline.cycleID == predecessor.cycleID &&
            baseline.gate == predecessor.gate &&
            baseline.rosterDigest == predecessor.rosterDigest &&
            baseline.roster == predecessor.roster &&
            baseline.redactionPolicy == predecessor.redactionPolicy &&
            baseline.activeProfileDigest == predecessor.activeProfileDigest &&
            baseline.riskPolicyDigest == predecessor.riskPolicyDigest &&
            baseline.assurancePolicyDigest == predecessor.assurancePolicyDigest &&
            baseline.convergencePolicyDigest == predecessor.convergencePolicyDigest
    }
}

private func hasExpectedPredecessorKind(
    _ predecessor: ReviewBaseline,
    current: ReviewBaseline
) -> Bool {
    switch (current.kind, current.semanticOrdinal) {
    case (.normalConfirmation, 1):
        predecessor.kind == .initial && predecessor.semanticOrdinal == 0
    case (.exception, 2):
        predecessor.kind == .normalConfirmation && predecessor.semanticOrdinal == 1
    case (.exception, let ordinal) where ordinal > 2:
        predecessor.kind == .exception && predecessor.semanticOrdinal == ordinal - 1
    default:
        false
    }
}

private func hasExactPriorAdmissionLineage(
    _ admissions: [VerifiedReviewExceptionAdmission],
    currentBaseline: ReviewBaseline
) -> Bool {
    if currentBaseline.kind == .normalConfirmation {
        return admissions.isEmpty && currentBaseline.semanticOrdinal == 1
    }
    guard currentBaseline.kind == .exception,
          !admissions.isEmpty,
          admissions.last?.successorBaseline.digest == currentBaseline.digest
    else { return false }
    for (offset, admission) in admissions.enumerated() {
        guard let expectedOrdinal = UInt64(exactly: offset + 2),
              admission.eligibility.hasValidDigest,
              admission.successorBaseline.kind == .exception,
              admission.successorBaseline.semanticOrdinal == expectedOrdinal,
              admission.eligibility.nextSemanticOrdinal == expectedOrdinal,
              admission.eligibility.nextRoundID == admission.successorBaseline.roundID,
              admission.eligibility.budgetDigest == currentBaseline.convergencePolicyDigest
        else { return false }
        if offset == 0 {
            guard admission.remediation.sourceRegister.baseline.kind == .normalConfirmation,
                  admission.remediation.sourceRegister.baseline.semanticOrdinal == 1
            else { return false }
        } else {
            let prior = admissions[offset - 1]
            guard admission.remediation.sourceRegister.baseline.digest ==
                    prior.successorBaseline.digest,
                  admission.eligibility.remainingExceptionRounds ==
                    prior.eligibility.remainingExceptionRounds - 1
            else { return false }
        }
    }
    return true
}

private extension RiskClass {
    var policyRank: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        case .critical: 3
        }
    }
}

private struct KernelReviewHistoryEntryPreimage: Codable {
    let kind: String
    let roundID: ReviewRoundID
    let registerDigest: HashDigest
    let baselineDigest: HashDigest
    let eventHead: HashDigest

    enum CodingKeys: String, CodingKey {
        case kind
        case roundID = "round_id"
        case registerDigest = "register_digest"
        case baselineDigest = "baseline_digest"
        case eventHead = "event_head"
    }
}

private struct KernelReviewHistoryPreimage: Codable {
    let schemaVersion: Int
    let entries: [KernelReviewHistoryEntryPreimage]
    let priorExceptionRoundIDs: [ReviewRoundID]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case entries
        case priorExceptionRoundIDs = "prior_exception_round_ids"
    }
}

private struct ReviewExceptionProofPreimage: Codable {
    let schemaVersion: Int
    let runID: RunID
    let cycleID: ReviewCycleID
    let gate: ReviewGateKind
    let precedingRoundID: ReviewRoundID
    let precedingRegisterDigest: HashDigest
    let precedingBaselineDigest: HashDigest
    let roundAnchorEventHead: HashDigest
    let remediationEventHead: HashDigest
    let confirmationEventHead: HashDigest
    let qualifyingFingerprints: [String]
    let nextSemanticOrdinal: UInt64
    let remainingExceptionRounds: Int
    let policyVersion: Int
    let budgetDigest: HashDigest
    let historyDigest: HashDigest
    let nextRoundID: ReviewRoundID

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case runID = "run_id"
        case cycleID = "cycle_id"
        case gate
        case precedingRoundID = "preceding_round_id"
        case precedingRegisterDigest = "preceding_register_digest"
        case precedingBaselineDigest = "preceding_baseline_digest"
        case roundAnchorEventHead = "round_anchor_event_head"
        case remediationEventHead = "remediation_event_head"
        case confirmationEventHead = "confirmation_event_head"
        case qualifyingFingerprints = "qualifying_fingerprints"
        case nextSemanticOrdinal = "next_semantic_ordinal"
        case remainingExceptionRounds = "remaining_exception_rounds"
        case policyVersion = "policy_version"
        case budgetDigest = "budget_digest"
        case historyDigest = "history_digest"
        case nextRoundID = "next_round_id"
    }
}
