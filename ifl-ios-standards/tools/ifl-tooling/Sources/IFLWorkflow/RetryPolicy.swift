import IFLContracts

public struct AttemptBudget: Hashable, Sendable {
    public let policyVersion: Int
    public let policyDigest: HashDigest
    public let basePolicyDigest: HashDigest?
    public let authoringSameFingerprintCycles: Int
    public let executionCheckpointRetries: Int
    public let exceptionRounds: Int
    public let transientToolAttempts: Int

    private init(
        policyVersion: Int,
        policyDigest: HashDigest,
        basePolicyDigest: HashDigest?,
        authoringSameFingerprintCycles: Int,
        executionCheckpointRetries: Int,
        exceptionRounds: Int,
        transientToolAttempts: Int
    ) throws {
        guard policyVersion == 1,
              authoringSameFingerprintCycles > 0,
              executionCheckpointRetries > 0,
              exceptionRounds > 0,
              transientToolAttempts > 0
        else { throw WorkflowPolicyError.invalidAttemptBudget }
        self.policyVersion = policyVersion
        self.policyDigest = policyDigest
        self.basePolicyDigest = basePolicyDigest
        self.authoringSameFingerprintCycles = authoringSameFingerprintCycles
        self.executionCheckpointRetries = executionCheckpointRetries
        self.exceptionRounds = exceptionRounds
        self.transientToolAttempts = transientToolAttempts
    }

    public static func standardV1(policyDigest: HashDigest) throws -> AttemptBudget {
        try AttemptBudget(
            policyVersion: 1,
            policyDigest: policyDigest,
            basePolicyDigest: nil,
            authoringSameFingerprintCycles: 2,
            executionCheckpointRetries: 2,
            exceptionRounds: 2,
            transientToolAttempts: 3
        )
    }

    public static func tightenedOverlay(
        base: AttemptBudget,
        overlayDigest: HashDigest,
        authoringSameFingerprintCycles: Int,
        executionCheckpointRetries: Int,
        exceptionRounds: Int,
        transientToolAttempts: Int
    ) throws -> AttemptBudget {
        guard overlayDigest != base.policyDigest,
              authoringSameFingerprintCycles <= base.authoringSameFingerprintCycles,
              executionCheckpointRetries <= base.executionCheckpointRetries,
              exceptionRounds <= base.exceptionRounds,
              transientToolAttempts <= base.transientToolAttempts
        else { throw WorkflowPolicyError.invalidAttemptBudget }
        return try AttemptBudget(
            policyVersion: base.policyVersion,
            policyDigest: overlayDigest,
            basePolicyDigest: base.policyDigest,
            authoringSameFingerprintCycles: authoringSameFingerprintCycles,
            executionCheckpointRetries: executionCheckpointRetries,
            exceptionRounds: exceptionRounds,
            transientToolAttempts: transientToolAttempts
        )
    }
}

public enum AttemptFamily: String, Hashable, Sendable {
    case authoringRevision = "authoring_revision"
    case executionCheckpoint = "execution_checkpoint"
    case exceptionRound = "exception_round"
    case transientTool = "transient_tool"
    case reviewerDelivery = "reviewer_delivery"
}

public struct AttemptScope: Hashable, Sendable {
    public let policyDigest: HashDigest
    public let family: AttemptFamily
    public let failureFingerprint: FailureFingerprint?
    public let reviewRoundID: ReviewRoundID?
    public let deliveryIdentity: ReviewerDeliveryIdentity?
    public let anchorEventHead: HashDigest

    private init(
        policyDigest: HashDigest,
        family: AttemptFamily,
        failureFingerprint: FailureFingerprint?,
        reviewRoundID: ReviewRoundID?,
        deliveryIdentity: ReviewerDeliveryIdentity?,
        anchorEventHead: HashDigest
    ) {
        self.policyDigest = policyDigest
        self.family = family
        self.failureFingerprint = failureFingerprint
        self.reviewRoundID = reviewRoundID
        self.deliveryIdentity = deliveryIdentity
        self.anchorEventHead = anchorEventHead
    }

    public static func authoring(
        policyDigest: HashDigest,
        failure: FailureFingerprint,
        anchorEventHead: HashDigest
    ) throws -> AttemptScope {
        AttemptScope(
            policyDigest: policyDigest,
            family: .authoringRevision,
            failureFingerprint: failure,
            reviewRoundID: nil,
            deliveryIdentity: nil,
            anchorEventHead: anchorEventHead
        )
    }

    public static func execution(
        policyDigest: HashDigest,
        failure: FailureFingerprint,
        anchorEventHead: HashDigest
    ) throws -> AttemptScope {
        AttemptScope(
            policyDigest: policyDigest,
            family: .executionCheckpoint,
            failureFingerprint: failure,
            reviewRoundID: nil,
            deliveryIdentity: nil,
            anchorEventHead: anchorEventHead
        )
    }

    public static func transientTool(
        policyDigest: HashDigest,
        failure: FailureFingerprint,
        anchorEventHead: HashDigest
    ) throws -> AttemptScope {
        AttemptScope(
            policyDigest: policyDigest,
            family: .transientTool,
            failureFingerprint: failure,
            reviewRoundID: nil,
            deliveryIdentity: nil,
            anchorEventHead: anchorEventHead
        )
    }

    public static func exceptionRound(
        policyDigest: HashDigest,
        roundID: ReviewRoundID,
        anchorEventHead: HashDigest
    ) throws -> AttemptScope {
        AttemptScope(
            policyDigest: policyDigest,
            family: .exceptionRound,
            failureFingerprint: nil,
            reviewRoundID: roundID,
            deliveryIdentity: nil,
            anchorEventHead: anchorEventHead
        )
    }

    static func reviewerDelivery(
        policyDigest: HashDigest,
        attempt: ReviewerDeliveryAttempt
    ) -> AttemptScope {
        AttemptScope(
            policyDigest: policyDigest,
            family: .reviewerDelivery,
            failureFingerprint: nil,
            reviewRoundID: attempt.roundID,
            deliveryIdentity: attempt.identity,
            anchorEventHead: attempt.baselineDigest
        )
    }

    var hasValidShape: Bool {
        switch family {
        case .authoringRevision, .executionCheckpoint, .transientTool:
            failureFingerprint != nil && reviewRoundID == nil && deliveryIdentity == nil
        case .exceptionRound:
            failureFingerprint == nil && reviewRoundID != nil && deliveryIdentity == nil
        case .reviewerDelivery:
            failureFingerprint == nil && reviewRoundID != nil && deliveryIdentity != nil
        }
    }
}

public struct AttemptRecord: Hashable, Sendable {
    public let scope: AttemptScope
    public let ordinal: Int
    public let completionEventHead: HashDigest
    public let delayMilliseconds: Int

    init(
        scope: AttemptScope,
        ordinal: Int,
        completionEventHead: HashDigest,
        delayMilliseconds: Int
    ) {
        self.scope = scope
        self.ordinal = ordinal
        self.completionEventHead = completionEventHead
        self.delayMilliseconds = delayMilliseconds
    }
}

public struct AttemptHistory: Hashable, Sendable {
    public let records: [AttemptRecord]

    init(records: [AttemptRecord]) {
        self.records = records
    }
}

public enum RetryOutcome: String, Hashable, Sendable {
    case retry
    case exhausted
    case integrityFailure = "integrity_failure"
}

public struct RetryDecision: Hashable, Sendable {
    public let outcome: RetryOutcome
    public let nextAttempt: Int?
    public let attemptsRemainingAfterDecision: Int
    public let delayMilliseconds: Int
    public let resolution: ResolutionKind

    init(
        outcome: RetryOutcome,
        nextAttempt: Int?,
        attemptsRemainingAfterDecision: Int,
        delayMilliseconds: Int,
        resolution: ResolutionKind
    ) {
        self.outcome = outcome
        self.nextAttempt = nextAttempt
        self.attemptsRemainingAfterDecision = attemptsRemainingAfterDecision
        self.delayMilliseconds = delayMilliseconds
        self.resolution = resolution
    }
}

public enum RetryExhaustionCause: String, Hashable, Sendable {
    case authorityOrDecisionRequired = "authority_or_decision_required"
    case externalPrerequisite = "external_prerequisite"
    case integrityViolation = "integrity_violation"
}

public struct ReviewerDeliveryRetryDecision: Hashable, Sendable {
    public let outcome: RetryOutcome
    public let attempt: ReviewerDeliveryAttempt
    public let nextAttempt: Int?
    public let delayMilliseconds: Int
    public let semanticRoundsConsumed: Int

    init(
        outcome: RetryOutcome,
        attempt: ReviewerDeliveryAttempt,
        nextAttempt: Int?,
        delayMilliseconds: Int,
        semanticRoundsConsumed: Int
    ) {
        self.outcome = outcome
        self.attempt = attempt
        self.nextAttempt = nextAttempt
        self.delayMilliseconds = delayMilliseconds
        self.semanticRoundsConsumed = semanticRoundsConsumed
    }
}

public struct RetryPolicy: Sendable {
    public let budget: AttemptBudget

    public init(budget: AttemptBudget) {
        self.budget = budget
    }

    public func decide(
        scope: AttemptScope,
        history: AttemptHistory,
        exhaustionCause: RetryExhaustionCause
    ) -> RetryDecision {
        guard scope.policyDigest == budget.policyDigest,
              scope.hasValidShape,
              let normalized = normalizedHistory(history)
        else { return integrityFailure() }
        let completed = normalized[scope]?.count ?? 0
        let maximum = maximumAttempts(for: scope.family)
        guard completed <= maximum else { return integrityFailure() }
        guard completed < maximum else {
            return RetryDecision(
                outcome: .exhausted,
                nextAttempt: nil,
                attemptsRemainingAfterDecision: 0,
                delayMilliseconds: 0,
                resolution: Self.exhaustionResolution(for: exhaustionCause)
            )
        }
        let next = completed + 1
        return RetryDecision(
            outcome: .retry,
            nextAttempt: next,
            attemptsRemainingAfterDecision: maximum - next,
            delayMilliseconds: Self.expectedDelayMilliseconds(
                family: scope.family,
                ordinal: next
            ),
            resolution: .continueWorkflow
        )
    }

    public func reviewerDelivery(
        anchor: ReviewerDeliveryAttempt,
        retry: ReviewerDeliveryAttempt,
        history: AttemptHistory
    ) -> ReviewerDeliveryRetryDecision {
        guard anchor.hasCanonicalIdentity,
              retry.hasCanonicalIdentity,
              anchor == retry
        else {
            return ReviewerDeliveryRetryDecision(
                outcome: .integrityFailure,
                attempt: retry,
                nextAttempt: nil,
                delayMilliseconds: 0,
                semanticRoundsConsumed: 0
            )
        }
        let decision = decide(
            scope: .reviewerDelivery(policyDigest: budget.policyDigest, attempt: anchor),
            history: history,
            exhaustionCause: .externalPrerequisite
        )
        return ReviewerDeliveryRetryDecision(
            outcome: decision.outcome,
            attempt: retry,
            nextAttempt: decision.nextAttempt,
            delayMilliseconds: decision.delayMilliseconds,
            semanticRoundsConsumed: 0
        )
    }

    public static func expectedDelayMilliseconds(
        family: AttemptFamily,
        ordinal: Int
    ) -> Int {
        guard ordinal > 0,
              family == .transientTool || family == .reviewerDelivery
        else { return 0 }
        var delay = 100
        if ordinal > 1 {
            for _ in 2 ... ordinal {
                delay = min(delay * 2, 1_000)
            }
        }
        return delay
    }

    public static func exhaustionResolution(
        for cause: RetryExhaustionCause
    ) -> ResolutionKind {
        switch cause {
        case .authorityOrDecisionRequired: .waitForUser
        case .externalPrerequisite: .block
        case .integrityViolation: .fail
        }
    }

    private func normalizedHistory(
        _ history: AttemptHistory
    ) -> [AttemptScope: [Int: AttemptRecord]]? {
        var result: [AttemptScope: [Int: AttemptRecord]] = [:]
        for record in history.records {
            guard record.scope.policyDigest == budget.policyDigest,
                  record.scope.hasValidShape,
                  record.ordinal > 0,
                  record.delayMilliseconds == Self.expectedDelayMilliseconds(
                      family: record.scope.family,
                      ordinal: record.ordinal
                  )
            else { return nil }
            if let prior = result[record.scope]?[record.ordinal] {
                guard prior == record else { return nil }
            } else {
                result[record.scope, default: [:]][record.ordinal] = record
            }
        }
        for records in result.values {
            guard records.keys.sorted() == Array(1 ... records.count) else { return nil }
        }
        return result
    }

    private func maximumAttempts(for family: AttemptFamily) -> Int {
        switch family {
        case .authoringRevision: budget.authoringSameFingerprintCycles
        case .executionCheckpoint: budget.executionCheckpointRetries
        case .exceptionRound: budget.exceptionRounds
        case .transientTool, .reviewerDelivery: budget.transientToolAttempts
        }
    }

    private func integrityFailure() -> RetryDecision {
        RetryDecision(
            outcome: .integrityFailure,
            nextAttempt: nil,
            attemptsRemainingAfterDecision: 0,
            delayMilliseconds: 0,
            resolution: .fail
        )
    }
}
