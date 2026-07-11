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

public enum KernelReviewHistoryEventKind: String, Hashable, Sendable {
    case registerJoined = "register_joined"
    case remediationRecorded = "remediation_recorded"
    case confirmationRecorded = "confirmation_recorded"
}

public struct KernelReviewHistoryEntry: Hashable, Sendable {
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
}

public struct KernelReviewHistory: Hashable, Sendable {
    public let entries: [KernelReviewHistoryEntry]
    public let priorExceptionRoundIDs: [ReviewRoundID]

    init(
        entries: [KernelReviewHistoryEntry],
        priorExceptionRoundIDs: [ReviewRoundID]
    ) {
        self.entries = entries
        self.priorExceptionRoundIDs = priorExceptionRoundIDs
    }
}

public enum ReviewFindingState: String, Codable, CaseIterable, Hashable, Sendable {
    case active
    case resolved
    case failedRemediation = "failed_remediation"
}

public struct ReviewFindingSummary: Hashable, Sendable {
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
}

public struct ReviewExceptionContext: Hashable, Sendable {
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

public struct ReviewConvergencePolicy: Sendable {
    public init() {}

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

    public func evaluateException(
        _ context: ReviewExceptionContext,
        budget: AttemptBudget
    ) -> ReviewExceptionDecision {
        guard hasUniqueFingerprints(context.immediatelyPreceding),
              hasUniqueFingerprints(context.current),
              hasValidConfirmedHistory(context),
              Set(context.history.priorExceptionRoundIDs).count ==
                context.history.priorExceptionRoundIDs.count
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
        guard let usedOrdinal = UInt64(exactly: used) else {
            return .escalation(.failed)
        }
        let (nextOrdinal, overflow) = usedOrdinal.addingReportingOverflow(2)
        guard !overflow,
              let nextRoundID = try? ReviewRoundID.derive(
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
              isBound(entries[0], kind: .registerJoined, context: context),
              isBound(entries[1], kind: .remediationRecorded, context: context),
              isBound(entries[2], kind: .confirmationRecorded, context: context),
              Set(entries.map(\.eventHead)).count == entries.count
        else { return false }
        return true
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
