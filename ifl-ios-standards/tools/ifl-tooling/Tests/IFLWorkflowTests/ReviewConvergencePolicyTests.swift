import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("ReviewConvergencePolicyTests")
struct ReviewConvergencePolicyTests {
    @Test("initial direct convergence remains joined-initial only")
    func initialPathIsClosed() {
        let policy = ReviewConvergencePolicy()
        #expect(
            policy.selectInitialPath(
                ReviewDispositionSummary(
                    initialJoinCompleted: false,
                    acceptedCurrentScopeCount: 0,
                    hasResolvedTransitions: false,
                    hasAmbiguity: false
                )
            ) == .escalation(.waitingForUser)
        )
        #expect(
            policy.selectInitialPath(
                ReviewDispositionSummary(
                    initialJoinCompleted: true,
                    acceptedCurrentScopeCount: 0,
                    hasResolvedTransitions: false,
                    hasAmbiguity: false
                )
            ) == .directConvergenceNoAcceptedCurrentScope
        )
        #expect(
            policy.selectInitialPath(
                ReviewDispositionSummary(
                    initialJoinCompleted: true,
                    acceptedCurrentScopeCount: 1,
                    hasResolvedTransitions: false,
                    hasAmbiguity: false
                )
            ) == .requiresRemediation
        )
        #expect(
            policy.selectInitialPath(
                ReviewDispositionSummary(
                    initialJoinCompleted: true,
                    acceptedCurrentScopeCount: 0,
                    hasResolvedTransitions: true,
                    hasAmbiguity: false
                )
            ) == .escalation(.waitingForUser)
        )
    }

    @Test("RC-09 normal confirmation admission is derived from ordered history")
    func orderedNormalConfirmationHistory() throws {
        let fixture = try reviewHistoryFixture()
        let policy = ReviewConvergencePolicy()
        #expect(
            try policy.admitNormalConfirmation(
                KernelReviewHistory(
                    entries: [fixture.joined, fixture.remediation],
                    priorExceptionRoundIDs: []
                )
            ) == .requiresNormalConfirmation
        )
        #expect(throws: WorkflowPolicyError.remediationRequired) {
            try policy.admitNormalConfirmation(
                KernelReviewHistory(
                    entries: [fixture.remediation, fixture.joined],
                    priorExceptionRoundIDs: []
                )
            )
        }
        #expect(throws: WorkflowPolicyError.normalConfirmationAlreadyRecorded) {
            try policy.admitNormalConfirmation(
                KernelReviewHistory(
                    entries: [fixture.joined, fixture.remediation, fixture.confirmation],
                    priorExceptionRoundIDs: []
                )
            )
        }
    }

    @Test("RC-09 exception proof binds complete predecessor and frozen budget")
    func exceptionProofBinding() throws {
        let fixture = try confirmedStateFixture()
        let budget = try AttemptBudget.standardV1(policyDigest: workflowTestDigest("a"))
        let high = try reviewFinding("new-high", severity: .high)
        let context = try exceptionContext(
            fixture: fixture,
            current: [high],
            priorExceptionRoundIDs: []
        )
        guard case let .eligible(proof) = ReviewConvergencePolicy().evaluateException(
            context,
            budget: budget
        ) else {
            Issue.record("expected eligible exception proof")
            return
        }

        #expect(proof.runID == fixture.state.runID)
        #expect(proof.cycleID == fixture.state.reviewCycle?.id)
        #expect(proof.gate == fixture.state.reviewCycle?.gate)
        #expect(proof.precedingRoundID == fixture.state.reviewCycle?.currentRoundID)
        #expect(proof.precedingRegisterDigest == fixture.registerDigest)
        #expect(proof.precedingBaselineDigest == fixture.baselineDigest)
        #expect(proof.roundAnchorEventHead == fixture.exceptionEventHead)
        #expect(proof.remediationEventHead == fixture.remediationEventHead)
        #expect(proof.confirmationEventHead == fixture.confirmationEventHead)
        #expect(proof.nextSemanticOrdinal == 2)
        #expect(proof.budgetDigest == budget.policyDigest)
        #expect(proof.proofDigest.rawValue.count == 64)
    }

    @Test("RC-09 misordered history is integrity escalation not eligibility")
    func corruptExceptionHistory() throws {
        let fixture = try confirmedStateFixture()
        let valid = try exceptionContext(
            fixture: fixture,
            current: [reviewFinding("high", severity: .critical)],
            priorExceptionRoundIDs: []
        )
        let entries = valid.history.entries
        let corrupt = ReviewExceptionContext(
            runID: valid.runID,
            cycleID: valid.cycleID,
            gate: valid.gate,
            precedingRoundID: valid.precedingRoundID,
            precedingRegisterDigest: valid.precedingRegisterDigest,
            precedingBaselineDigest: valid.precedingBaselineDigest,
            roundAnchorEventHead: valid.roundAnchorEventHead,
            immediatelyPreceding: valid.immediatelyPreceding,
            current: valid.current,
            history: KernelReviewHistory(
                entries: [entries[0], entries[2], entries[1]],
                priorExceptionRoundIDs: []
            ),
            exhaustionCause: .integrityViolation
        )
        let budget = try AttemptBudget.standardV1(policyDigest: workflowTestDigest("a"))
        #expect(
            ReviewConvergencePolicy().evaluateException(corrupt, budget: budget)
                == .escalation(.failed)
        )
    }

    @Test("RC-09 exception budget is counted from unique prior round history")
    func historyBoundExceptionBudget() throws {
        let fixture = try confirmedStateFixture()
        let budget = try AttemptBudget.standardV1(policyDigest: workflowTestDigest("a"))
        let rounds = [
            try ReviewRoundID(validating: String(repeating: "b", count: 64)),
            try ReviewRoundID(validating: String(repeating: "c", count: 64)),
        ]
        let context = try exceptionContext(
            fixture: fixture,
            current: [reviewFinding("high", severity: .high)],
            priorExceptionRoundIDs: rounds
        )
        #expect(
            ReviewConvergencePolicy().evaluateException(context, budget: budget)
                == .exhausted(.waitingForUser)
        )

        let duplicateHistory = try exceptionContext(
            fixture: fixture,
            current: [reviewFinding("high", severity: .high)],
            priorExceptionRoundIDs: [rounds[0], rounds[0]]
        )
        #expect(
            ReviewConvergencePolicy().evaluateException(duplicateHistory, budget: budget)
                == .escalation(.failed)
        )

        let overLimit = try exceptionContext(
            fixture: fixture,
            current: [reviewFinding("high", severity: .high)],
            priorExceptionRoundIDs: rounds + [
                try ReviewRoundID(validating: String(repeating: "d", count: 64)),
            ]
        )
        #expect(
            ReviewConvergencePolicy().evaluateException(overLimit, budget: budget)
                == .escalation(.failed)
        )
    }

    @Test("only new regressed high or policy must-fix findings qualify")
    func findingQualification() throws {
        let fixture = try confirmedStateFixture()
        let budget = try AttemptBudget.standardV1(policyDigest: workflowTestDigest("a"))
        let low = try reviewFinding("low", severity: .low)
        let medium = try reviewFinding("medium", severity: .medium)
        let noException = try exceptionContext(
            fixture: fixture,
            immediatelyPreceding: [],
            current: [low, medium],
            priorExceptionRoundIDs: []
        )
        #expect(
            ReviewConvergencePolicy().evaluateException(noException, budget: budget)
                == .notEligible
        )

        let prior = try reviewFinding("regressed", severity: .medium)
        let regressed = ReviewFindingSummary(
            fingerprint: prior.fingerprint,
            severity: .high,
            mustFix: false,
            state: .active
        )
        let mustFix = try reviewFinding("must-fix", severity: .medium, mustFix: true)
        let eligible = try exceptionContext(
            fixture: fixture,
            immediatelyPreceding: [prior],
            current: [regressed, mustFix],
            priorExceptionRoundIDs: []
        )
        guard case let .eligible(proof) = ReviewConvergencePolicy().evaluateException(
            eligible,
            budget: budget
        ) else {
            Issue.record("expected regressed/must-fix eligibility")
            return
        }
        #expect(proof.qualifyingFingerprints.count == 2)
    }

    @Test("RC-09 reducer consumes an exact proof and persists valid exception state")
    func reducerConsumesProof() throws {
        let fixture = try confirmedStateFixture()
        let proof = try eligibleProof(fixture)
        let event = try WorkflowEvent(id: "open-exception", kind: .reviewExceptionOpened)
        let context = try exceptionTransitionContext(fixture, proof: proof)
        let next = try WorkflowReducer().decide(
            definition: EngineeringWorkflow.definition,
            state: fixture.state,
            event: event,
            context: context
        ).proposedState

        #expect(next.reviewCycle?.phase == .collectingException)
        #expect(next.reviewCycle?.currentRoundKind == .exception)
        #expect(next.reviewCycle?.currentSemanticOrdinal == 2)
        #expect(next.reviewCycle?.currentRoundID == proof.nextRoundID)
        let decoded = try CanonicalJSON.decode(
            RunState.self,
            from: CanonicalJSON.encode(next)
        )
        #expect(decoded == next)
    }

    @Test("RC-09 reducer rejects absent stale cross-cycle and replayed proof")
    func reducerRejectsInvalidProof() throws {
        let fixture = try confirmedStateFixture()
        let proof = try eligibleProof(fixture)
        let event = try WorkflowEvent(id: "exception-without-proof", kind: .reviewExceptionOpened)
        #expect(throws: WorkflowError.exceptionPolicyRequired) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: fixture.state,
                event: event,
                context: exceptionTransitionContext(fixture, proof: nil)
            )
        }

        let staleContext = try TransitionContext(
            actorID: ActorID(validating: "exception-author"),
            principalID: PrincipalID(validating: "exception-principal"),
            currentEventHead: workflowTestDigest("0"),
            currentReviewBaselineDigest: fixture.baselineDigest,
            satisfiedGuards: [],
            reviewExceptionProof: proof,
            verifiedFrozenBudget: verifiedFrozenBudget(proof)
        )
        #expect(throws: WorkflowError.invalidExceptionProof) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: fixture.state,
                event: WorkflowEvent(id: "stale-proof", kind: .reviewExceptionOpened),
                context: staleContext
            )
        }

        let accepted = try WorkflowReducer().decide(
            definition: EngineeringWorkflow.definition,
            state: fixture.state,
            event: WorkflowEvent(id: "consume-proof", kind: .reviewExceptionOpened),
            context: exceptionTransitionContext(fixture, proof: proof)
        ).proposedState
        #expect(throws: WorkflowError.invalidExceptionProof) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: accepted,
                event: WorkflowEvent(id: "replay-proof-new-event", kind: .reviewExceptionOpened),
                context: exceptionTransitionContext(fixture, proof: proof)
            )
        }

        let crossCycle = try crossCycleProof(fixture)
        #expect(throws: WorkflowError.invalidExceptionProof) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: fixture.state,
                event: WorkflowEvent(id: "cross-cycle-proof", kind: .reviewExceptionOpened),
                context: exceptionTransitionContext(fixture, proof: crossCycle)
            )
        }
    }

    @Test("Residual D-006 exception admission requires exact Kernel-frozen budget binding")
    func reducerRequiresFrozenBudgetFact() throws {
        let fixture = try confirmedStateFixture()
        let proof = try eligibleProof(fixture)
        let event = try WorkflowEvent(id: "budget-bound-exception", kind: .reviewExceptionOpened)

        #expect(throws: WorkflowError.invalidExceptionProof) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: fixture.state,
                event: event,
                context: exceptionTransitionContext(
                    fixture,
                    proof: proof,
                    includeVerifiedBudget: false
                )
            )
        }

        let mismatchedDigest = VerifiedFrozenBudgetFact(
            runID: proof.runID,
            cycleID: proof.cycleID,
            policyVersion: proof.policyVersion,
            policyDigest: try workflowTestDigest("b"),
            boundEventHead: proof.roundAnchorEventHead
        )
        #expect(throws: WorkflowError.invalidExceptionProof) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: fixture.state,
                event: WorkflowEvent(id: "budget-digest-mismatch", kind: .reviewExceptionOpened),
                context: exceptionTransitionContext(
                    fixture,
                    proof: proof,
                    verifiedBudgetOverride: mismatchedDigest
                )
            )
        }

        let mismatchedVersion = VerifiedFrozenBudgetFact(
            runID: proof.runID,
            cycleID: proof.cycleID,
            policyVersion: proof.policyVersion + 1,
            policyDigest: proof.budgetDigest,
            boundEventHead: proof.roundAnchorEventHead
        )
        #expect(throws: WorkflowError.invalidExceptionProof) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: fixture.state,
                event: WorkflowEvent(id: "budget-version-mismatch", kind: .reviewExceptionOpened),
                context: exceptionTransitionContext(
                    fixture,
                    proof: proof,
                    verifiedBudgetOverride: mismatchedVersion
                )
            )
        }

        let stale = VerifiedFrozenBudgetFact(
            runID: proof.runID,
            cycleID: proof.cycleID,
            policyVersion: proof.policyVersion,
            policyDigest: proof.budgetDigest,
            boundEventHead: try workflowTestDigest("0")
        )
        #expect(throws: WorkflowError.invalidExceptionProof) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: fixture.state,
                event: WorkflowEvent(id: "budget-stale", kind: .reviewExceptionOpened),
                context: exceptionTransitionContext(
                    fixture,
                    proof: proof,
                    verifiedBudgetOverride: stale
                )
            )
        }
    }
}

private struct HistoryFixture {
    let joined: KernelReviewHistoryEntry
    let remediation: KernelReviewHistoryEntry
    let confirmation: KernelReviewHistoryEntry
}

private struct ConfirmedStateFixture {
    let state: RunState
    let baselineDigest: HashDigest
    let registerDigest: HashDigest
    let remediationEventHead: HashDigest
    let confirmationEventHead: HashDigest
    let exceptionEventHead: HashDigest
}

private func reviewHistoryFixture() throws -> HistoryFixture {
    let roundID = try ReviewRoundID(validating: String(repeating: "1", count: 64))
    let register = try workflowTestDigest("2")
    let baseline = try workflowTestDigest("3")
    return HistoryFixture(
        joined: KernelReviewHistoryEntry(
            kind: .registerJoined,
            roundID: roundID,
            registerDigest: register,
            baselineDigest: baseline,
            eventHead: try workflowTestDigest("4")
        ),
        remediation: KernelReviewHistoryEntry(
            kind: .remediationRecorded,
            roundID: roundID,
            registerDigest: register,
            baselineDigest: baseline,
            eventHead: try workflowTestDigest("5")
        ),
        confirmation: KernelReviewHistoryEntry(
            kind: .confirmationRecorded,
            roundID: roundID,
            registerDigest: register,
            baselineDigest: baseline,
            eventHead: try workflowTestDigest("6")
        )
    )
}

private func confirmedStateFixture() throws -> ConfirmedStateFixture {
    let initialHead = try workflowTestDigest("1")
    var state = try reviewGateState()
    state = try reduceReview(
        state,
        event: WorkflowEvent(
            id: "policy-initial-freeze",
            kind: .reviewBaselineFrozen,
            reviewRound: try .initial(
                gate: .requirements,
                cycleOrdinal: 0,
                preFreezeEventHead: initialHead,
                redactionPolicy: reviewRedactionPolicy
            )
        ),
        head: initialHead
    )
    state = try reduceReview(
        state,
        event: WorkflowEvent(id: "policy-initial-close", kind: .reviewInventoryClosed),
        head: try workflowTestDigest("2")
    )
    let remediationHead = try workflowTestDigest("3")
    state = try reduceReview(
        state,
        event: WorkflowEvent(id: "policy-remediation", kind: .reviewRemediationRecorded),
        head: remediationHead
    )
    let cycleID = try #require(state.reviewCycle?.id)
    let baseline = try workflowTestDigest("4")
    let confirmationAnchor = try workflowTestDigest("5")
    state = try reduceReview(
        state,
        event: WorkflowEvent(
            id: "policy-confirmation-freeze",
            kind: .reviewBaselineFrozen,
            reviewRound: try .later(
                cycleID: cycleID,
                gate: .requirements,
                kind: .normalConfirmation,
                semanticOrdinal: 1,
                roundAnchorEventHead: confirmationAnchor,
                predecessorBaselineDigest: baseline,
                redactionPolicy: reviewRedactionPolicy
            )
        ),
        head: confirmationAnchor,
        baseline: baseline
    )
    let confirmationHead = try workflowTestDigest("6")
    state = try reduceReview(
        state,
        event: WorkflowEvent(
            id: "policy-confirmation-recorded",
            kind: .reviewConfirmationRecorded
        ),
        head: confirmationHead
    )
    return ConfirmedStateFixture(
        state: state,
        baselineDigest: baseline,
        registerDigest: try workflowTestDigest("7"),
        remediationEventHead: remediationHead,
        confirmationEventHead: confirmationHead,
        exceptionEventHead: try workflowTestDigest("8")
    )
}

private func exceptionContext(
    fixture: ConfirmedStateFixture,
    immediatelyPreceding: [ReviewFindingSummary] = [],
    current: [ReviewFindingSummary],
    priorExceptionRoundIDs: [ReviewRoundID]
) throws -> ReviewExceptionContext {
    let roundID = try #require(fixture.state.reviewCycle?.currentRoundID)
    let history = KernelReviewHistory(
        entries: [
            KernelReviewHistoryEntry(
                kind: .registerJoined,
                roundID: roundID,
                registerDigest: fixture.registerDigest,
                baselineDigest: fixture.baselineDigest,
                eventHead: try workflowTestDigest("2")
            ),
            KernelReviewHistoryEntry(
                kind: .remediationRecorded,
                roundID: roundID,
                registerDigest: fixture.registerDigest,
                baselineDigest: fixture.baselineDigest,
                eventHead: fixture.remediationEventHead
            ),
            KernelReviewHistoryEntry(
                kind: .confirmationRecorded,
                roundID: roundID,
                registerDigest: fixture.registerDigest,
                baselineDigest: fixture.baselineDigest,
                eventHead: fixture.confirmationEventHead
            ),
        ],
        priorExceptionRoundIDs: priorExceptionRoundIDs
    )
    return ReviewExceptionContext(
        runID: fixture.state.runID,
        cycleID: try #require(fixture.state.reviewCycle?.id),
        gate: try #require(fixture.state.reviewCycle?.gate),
        precedingRoundID: roundID,
        precedingRegisterDigest: fixture.registerDigest,
        precedingBaselineDigest: fixture.baselineDigest,
        roundAnchorEventHead: fixture.exceptionEventHead,
        immediatelyPreceding: immediatelyPreceding,
        current: current,
        history: history,
        exhaustionCause: .authorityOrDecisionRequired
    )
}

private func eligibleProof(
    _ fixture: ConfirmedStateFixture
) throws -> ReviewExceptionEligibility {
    let context = try exceptionContext(
        fixture: fixture,
        current: [reviewFinding("eligible-high", severity: .high)],
        priorExceptionRoundIDs: []
    )
    let budget = try AttemptBudget.standardV1(policyDigest: workflowTestDigest("a"))
    guard case let .eligible(proof) = ReviewConvergencePolicy().evaluateException(
        context,
        budget: budget
    ) else {
        throw WorkflowPolicyError.invalidExceptionProof
    }
    return proof
}

private func crossCycleProof(
    _ fixture: ConfirmedStateFixture
) throws -> ReviewExceptionEligibility {
    let otherCycle = try ReviewCycleID.derive(
        runID: fixture.state.runID,
        gate: .requirements,
        cycleOrdinal: 9,
        preFreezeEventHead: workflowTestDigest("9")
    )
    let base = try exceptionContext(
        fixture: fixture,
        current: [reviewFinding("cross-high", severity: .high)],
        priorExceptionRoundIDs: []
    )
    let cross = ReviewExceptionContext(
        runID: base.runID,
        cycleID: otherCycle,
        gate: base.gate,
        precedingRoundID: base.precedingRoundID,
        precedingRegisterDigest: base.precedingRegisterDigest,
        precedingBaselineDigest: base.precedingBaselineDigest,
        roundAnchorEventHead: base.roundAnchorEventHead,
        immediatelyPreceding: base.immediatelyPreceding,
        current: base.current,
        history: base.history,
        exhaustionCause: base.exhaustionCause
    )
    let budget = try AttemptBudget.standardV1(policyDigest: workflowTestDigest("a"))
    guard case let .eligible(proof) = ReviewConvergencePolicy().evaluateException(
        cross,
        budget: budget
    ) else { throw WorkflowPolicyError.invalidExceptionProof }
    return proof
}

private func exceptionTransitionContext(
    _ fixture: ConfirmedStateFixture,
    proof: ReviewExceptionEligibility?,
    includeVerifiedBudget: Bool = true,
    verifiedBudgetOverride: VerifiedFrozenBudgetFact? = nil
) throws -> TransitionContext {
    let budget = verifiedBudgetOverride ?? (
        includeVerifiedBudget ? proof.map(verifiedFrozenBudget) : nil
    )
    return try TransitionContext(
        actorID: ActorID(validating: "exception-author"),
        principalID: PrincipalID(validating: "exception-principal"),
        currentEventHead: fixture.exceptionEventHead,
        currentReviewBaselineDigest: fixture.baselineDigest,
        satisfiedGuards: [],
        reviewExceptionProof: proof,
        verifiedFrozenBudget: budget
    )
}

private func verifiedFrozenBudget(
    _ proof: ReviewExceptionEligibility
) -> VerifiedFrozenBudgetFact {
    VerifiedFrozenBudgetFact(
        runID: proof.runID,
        cycleID: proof.cycleID,
        policyVersion: proof.policyVersion,
        policyDigest: proof.budgetDigest,
        boundEventHead: proof.roundAnchorEventHead
    )
}

private func reviewFinding(
    _ value: String,
    severity: RiskClass,
    mustFix: Bool = false
) throws -> ReviewFindingSummary {
    ReviewFindingSummary(
        fingerprint: try failure("review-\(value)"),
        severity: severity,
        mustFix: mustFix,
        state: .active
    )
}
