import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("RetryPolicyTests")
struct RetryPolicyTests {
    @Test("RC-05 standard v1 is closed and overlays may only tighten with a new digest")
    func closedBudgetPolicy() throws {
        let base = try AttemptBudget.standardV1(policyDigest: workflowTestDigest("1"))
        #expect(base.policyVersion == 1)
        #expect(base.authoringSameFingerprintCycles == 2)
        #expect(base.executionCheckpointRetries == 2)
        #expect(base.exceptionRounds == 2)
        #expect(base.transientToolAttempts == 3)

        let tightened = try AttemptBudget.tightenedOverlay(
            base: base,
            overlayDigest: workflowTestDigest("2"),
            authoringSameFingerprintCycles: 1,
            executionCheckpointRetries: 1,
            exceptionRounds: 1,
            transientToolAttempts: 2
        )
        #expect(tightened.basePolicyDigest == base.policyDigest)
        #expect(tightened.policyDigest != base.policyDigest)

        #expect(throws: WorkflowPolicyError.invalidAttemptBudget) {
            try AttemptBudget.tightenedOverlay(
                base: base,
                overlayDigest: base.policyDigest,
                authoringSameFingerprintCycles: 2,
                executionCheckpointRetries: 2,
                exceptionRounds: 2,
                transientToolAttempts: 3
            )
        }
        #expect(throws: WorkflowPolicyError.invalidAttemptBudget) {
            try AttemptBudget.tightenedOverlay(
                base: base,
                overlayDigest: workflowTestDigest("3"),
                authoringSameFingerprintCycles: 3,
                executionCheckpointRetries: 2,
                exceptionRounds: 2,
                transientToolAttempts: 3
            )
        }
    }

    @Test("RC-05 A B A history does not reset the A budget and exact replay is idempotent")
    func historyBoundAuthoringBudget() throws {
        let budget = try AttemptBudget.standardV1(policyDigest: workflowTestDigest("1"))
        let policy = RetryPolicy(budget: budget)
        let a = try AttemptScope.authoring(
            policyDigest: budget.policyDigest,
            failure: failure("A"),
            anchorEventHead: workflowTestDigest("a")
        )
        let b = try AttemptScope.authoring(
            policyDigest: budget.policyDigest,
            failure: failure("B"),
            anchorEventHead: workflowTestDigest("a")
        )
        let a1 = try attemptRecord(a, ordinal: 1, event: "b")
        let b1 = try attemptRecord(b, ordinal: 1, event: "c")
        let history = AttemptHistory(records: [a1, b1, a1])

        let nextA = policy.decide(
            scope: a,
            history: history,
            exhaustionCause: .authorityOrDecisionRequired
        )
        #expect(nextA.outcome == .retry)
        #expect(nextA.nextAttempt == 2)
        #expect(nextA.attemptsRemainingAfterDecision == 0)
    }

    @Test("RC-05 execution retry is fingerprinted and corrupt history is integrity failure")
    func executionIdentityAndCorruptHistory() throws {
        let budget = try AttemptBudget.standardV1(policyDigest: workflowTestDigest("1"))
        let policy = RetryPolicy(budget: budget)
        let scope = try AttemptScope.execution(
            policyDigest: budget.policyDigest,
            failure: failure("execution"),
            anchorEventHead: workflowTestDigest("d")
        )
        let valid = try attemptRecord(scope, ordinal: 1, event: "e")
        let collision = AttemptRecord(
            scope: scope,
            ordinal: 1,
            completionEventHead: try workflowTestDigest("f"),
            delayMilliseconds: valid.delayMilliseconds
        )
        let decision = policy.decide(
            scope: scope,
            history: AttemptHistory(records: [valid, collision]),
            exhaustionCause: .integrityViolation
        )
        #expect(decision.outcome == .integrityFailure)
        #expect(decision.resolution == .fail)
        #expect(decision.nextAttempt == nil)
    }

    @Test("RC-05 transient backoff is deterministic capped and exhausts at three")
    func deterministicBackoff() throws {
        let budget = try AttemptBudget.standardV1(policyDigest: workflowTestDigest("1"))
        let policy = RetryPolicy(budget: budget)
        let scope = try AttemptScope.transientTool(
            policyDigest: budget.policyDigest,
            failure: failure("tool"),
            anchorEventHead: workflowTestDigest("4")
        )
        let first = policy.decide(
            scope: scope,
            history: AttemptHistory(records: []),
            exhaustionCause: .externalPrerequisite
        )
        #expect(first.nextAttempt == 1)
        #expect(first.delayMilliseconds == 100)

        let records = [
            try attemptRecord(scope, ordinal: 1, event: "5"),
            try attemptRecord(scope, ordinal: 2, event: "6"),
            try attemptRecord(scope, ordinal: 3, event: "7"),
        ]
        #expect(records.map(\.delayMilliseconds) == [100, 200, 400])
        let exhausted = policy.decide(
            scope: scope,
            history: AttemptHistory(records: records),
            exhaustionCause: .externalPrerequisite
        )
        #expect(exhausted.outcome == .exhausted)
        #expect(exhausted.resolution == .block)
    }

    @Test("Residual R-007 exact limit exhausts while over-limit history fails integrity")
    func overLimitHistoryIsIntegrityFailure() throws {
        let budget = try AttemptBudget.standardV1(policyDigest: workflowTestDigest("1"))
        let policy = RetryPolicy(budget: budget)
        let scope = try AttemptScope.execution(
            policyDigest: budget.policyDigest,
            failure: failure("over-limit"),
            anchorEventHead: workflowTestDigest("8")
        )
        let exact = [
            try attemptRecord(scope, ordinal: 1, event: "9"),
            try attemptRecord(scope, ordinal: 2, event: "a"),
        ]
        let exhausted = policy.decide(
            scope: scope,
            history: AttemptHistory(records: exact),
            exhaustionCause: .authorityOrDecisionRequired
        )
        #expect(exhausted.outcome == .exhausted)
        #expect(exhausted.resolution == .waitForUser)

        let corrupt = policy.decide(
            scope: scope,
            history: AttemptHistory(
                records: exact + [try attemptRecord(scope, ordinal: 3, event: "b")]
            ),
            exhaustionCause: .authorityOrDecisionRequired
        )
        #expect(corrupt.outcome == .integrityFailure)
        #expect(corrupt.resolution == .fail)
    }

    @Test("RC-06 typed failure identity canonicalizes set inputs")
    func typedFailureIdentity() throws {
        let first = try failure("identity", relatedRuleIDs: ["R-2", "R-1", "R-1"])
        let reordered = try failure("identity", relatedRuleIDs: ["R-1", "R-2"])
        let changedCheck = try failure("identity-changed", relatedRuleIDs: ["R-1", "R-2"])
        #expect(first == reordered)
        #expect(first != changedCheck)
    }

    @Test("RC-06 delivery identity binds round baseline assignment and canonical inventory")
    func deliveryIdentityAndCollision() throws {
        let budget = try AttemptBudget.standardV1(policyDigest: workflowTestDigest("1"))
        let policy = RetryPolicy(budget: budget)
        let roundID = try ReviewRoundID(validating: String(repeating: "a", count: 64))
        let reviewer = try PrincipalID(validating: "reviewer-principal")
        let baseline = try workflowTestDigest("8")
        let assignment = try workflowTestDigest("9")
        let inventory = try ReviewerInventoryFingerprint.derive(
            roundID: roundID,
            reviewerPrincipalID: reviewer,
            baselineDigest: baseline,
            assignmentDigest: assignment,
            findings: [failure("A"), failure("B")]
        )
        let reordered = try ReviewerInventoryFingerprint.derive(
            roundID: roundID,
            reviewerPrincipalID: reviewer,
            baselineDigest: baseline,
            assignmentDigest: assignment,
            findings: [failure("B"), failure("A"), failure("A")]
        )
        #expect(inventory == reordered)
        #expect(
            inventory != (try ReviewerInventoryFingerprint.derive(
                roundID: roundID,
                reviewerPrincipalID: reviewer,
                baselineDigest: workflowTestDigest("0"),
                assignmentDigest: assignment,
                findings: [failure("A"), failure("B")]
            ))
        )

        let anchor = try ReviewerDeliveryAttempt.derive(
            roundID: roundID,
            baselineDigest: baseline,
            assignmentDigest: assignment,
            inventoryFingerprint: inventory
        )
        let retry = policy.reviewerDelivery(
            anchor: anchor,
            retry: anchor,
            history: AttemptHistory(records: [])
        )
        #expect(retry.outcome == .retry)
        #expect(retry.semanticRoundsConsumed == 0)
        #expect(retry.attempt == anchor)

        let collision = ReviewerDeliveryAttempt(
            identity: anchor.identity,
            roundID: roundID,
            baselineDigest: try workflowTestDigest("0"),
            assignmentDigest: assignment,
            inventoryFingerprint: inventory
        )
        let rejected = policy.reviewerDelivery(
            anchor: anchor,
            retry: collision,
            history: AttemptHistory(records: [])
        )
        #expect(rejected.outcome == .integrityFailure)
        #expect(rejected.semanticRoundsConsumed == 0)
    }
}

func failure(
    _ checkID: String,
    relatedRuleIDs: [String] = ["R-1"]
) throws -> FailureFingerprint {
    try FailureFingerprint.derive(
        from: FailureSemanticInput(
            schemaVersion: 1,
            failingStage: .executePhase,
            checkID: checkID,
            invariantDigest: workflowTestDigest("a"),
            expectedDigest: workflowTestDigest("b"),
            actualDigest: workflowTestDigest("c"),
            policyDigest: workflowTestDigest("d"),
            relatedRuleIDs: relatedRuleIDs
        )
    )
}

private func attemptRecord(
    _ scope: AttemptScope,
    ordinal: Int,
    event: Character
) throws -> AttemptRecord {
    AttemptRecord(
        scope: scope,
        ordinal: ordinal,
        completionEventHead: try workflowTestDigest(event),
        delayMilliseconds: RetryPolicy.expectedDelayMilliseconds(
            family: scope.family,
            ordinal: ordinal
        )
    )
}
