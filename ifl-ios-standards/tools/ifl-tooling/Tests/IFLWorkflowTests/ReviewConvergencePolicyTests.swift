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

    @Test("RC-09 cross-bound history is integrity escalation not eligibility")
    func corruptExceptionHistory() throws {
        let fixture = try confirmedStateFixture()
        let valid = try exceptionContext(
            fixture: fixture,
            current: [reviewFinding("high", severity: .critical)],
            priorExceptionRoundIDs: []
        )
        let entries = valid.history.entries
        let foreignRemediation = KernelReviewHistoryEntry(
            kind: .remediationRecorded,
            roundID: valid.precedingRoundID,
            registerDigest: try workflowTestDigest("f"),
            baselineDigest: valid.precedingBaselineDigest,
            eventHead: try workflowTestDigest("d")
        )
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
                entries: [entries[0], entries[1], foreignRemediation],
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
            priorExceptionRoundIDs: rounds,
            precedingRoundID: rounds.last
        )
        #expect(
            ReviewConvergencePolicy().evaluateException(context, budget: budget)
                == .exhausted(.waitingForUser)
        )

        let duplicateHistory = try exceptionContext(
            fixture: fixture,
            current: [reviewFinding("high", severity: .high)],
            priorExceptionRoundIDs: [rounds[0], rounds[0]],
            precedingRoundID: rounds[0]
        )
        #expect(
            ReviewConvergencePolicy().evaluateException(duplicateHistory, budget: budget)
                == .escalation(.failed)
        )

        let overLimitRounds = rounds + [
            try ReviewRoundID(validating: String(repeating: "d", count: 64)),
        ]
        let overLimit = try exceptionContext(
            fixture: fixture,
            current: [reviewFinding("high", severity: .high)],
            priorExceptionRoundIDs: overLimitRounds,
            precedingRoundID: overLimitRounds.last
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

    @Test("RRC-06 exception semantic ordinal uses checked predecessor advancement")
    func checkedExceptionSemanticOrdinal() throws {
        let policy = ReviewConvergencePolicy()
        #expect(
            try policy.nextExceptionSemanticOrdinal(after: UInt64.max - 1) == UInt64.max
        )
        #expect(throws: WorkflowError.ordinalOverflow) {
            try policy.nextExceptionSemanticOrdinal(after: UInt64.max)
        }
    }

    @Test("RRC-03 confirmed convergence requires the latest register to be terminal")
    func confirmedConvergenceRequiresTerminalLatestRegister() throws {
        let source = try LaneBReviewScenario.make(acceptedCurrentScope: true)
        let successor = try source.makeSuccessorBaseline()
        let unresolved = try successor.makeConfirmationRegister(acceptedCurrentScope: true)
        let terminal = try successor.makeConfirmationRegister(acceptedCurrentScope: false)

        #expect(throws: WorkflowPolicyError.remediationRequired) {
            try ReviewConvergenceValidator.validateConfirmedTerminal(unresolved.verifiedRegister)
        }
        try ReviewConvergenceValidator.validateConfirmedTerminal(terminal.verifiedRegister)
    }

    @Test("RC-09 reducer consumes an exact proof and persists valid exception state")
    func reducerConsumesProof() throws {
        let fixture = try confirmedStateFixture()
        let admission = try eligibleAdmission(fixture)
        let proof = admission.eligibility
        let predecessor = try #require(fixture.state.reviewCycle)
        #expect(predecessor.closedRoundID == predecessor.currentRoundID)
        #expect(predecessor.closedBaselineDigest == fixture.baselineDigest)
        #expect(predecessor.closedRegisterDigest == fixture.registerDigest)
        #expect(predecessor.closedPathDecision == .requiresRemediation)
        #expect(predecessor.lastRemediatedRoundID == predecessor.currentRoundID)
        #expect(predecessor.confirmationReceiptID != nil)
        let event = try WorkflowEvent(id: "open-exception", kind: .reviewExceptionOpened)
        let context = try exceptionTransitionContext(fixture, admission: admission)
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
        #expect(next.reviewCycle?.predecessorBaselineDigest == fixture.baselineDigest)
        #expect(next.reviewCycle?.closedRoundID == nil)
        #expect(next.reviewCycle?.closedBaselineDigest == nil)
        #expect(next.reviewCycle?.closedRegisterDigest == nil)
        #expect(next.reviewCycle?.closedPathDecision == nil)
        #expect(next.reviewCycle?.lastRemediatedRoundID == proof.precedingRoundID)
        #expect(next.reviewCycle?.confirmationReceiptID == predecessor.confirmationReceiptID)
        let decoded = try CanonicalJSON.decode(
            RunState.self,
            from: CanonicalJSON.encode(next)
        )
        #expect(decoded == next)
    }

    @Test("RC-09 reducer rejects absent or replayed admission without binding later CAS head")
    func reducerRejectsInvalidProof() throws {
        let fixture = try confirmedStateFixture()
        let admission = try eligibleAdmission(fixture)
        let event = try WorkflowEvent(id: "exception-without-proof", kind: .reviewExceptionOpened)
        #expect(throws: WorkflowError.exceptionPolicyRequired) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: fixture.state,
                event: event,
                context: exceptionTransitionContext(fixture, admission: nil)
            )
        }

        let laterPublicationHead = try workflowTestDigest("0")
        let advanced = try WorkflowReducer().decide(
            definition: EngineeringWorkflow.definition,
            state: fixture.state,
            event: WorkflowEvent(id: "later-publication-head", kind: .reviewExceptionOpened),
            context: exceptionTransitionContext(
                fixture,
                admission: admission,
                currentEventHead: laterPublicationHead
            )
        ).proposedState
        #expect(advanced.reviewCycle?.currentRoundID == admission.successorBaseline.roundID)

        let accepted = try WorkflowReducer().decide(
            definition: EngineeringWorkflow.definition,
            state: fixture.state,
            event: WorkflowEvent(id: "consume-proof", kind: .reviewExceptionOpened),
            context: exceptionTransitionContext(fixture, admission: admission)
        ).proposedState
        #expect(throws: WorkflowError.invalidExceptionProof) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: accepted,
                event: WorkflowEvent(id: "replay-proof-new-event", kind: .reviewExceptionOpened),
                context: exceptionTransitionContext(fixture, admission: admission)
            )
        }
    }

    @Test("Residual D-006 exception admission requires exact Kernel-frozen budget binding")
    func reducerRequiresFrozenBudgetFact() throws {
        let fixture = try confirmedStateFixture()
        let admission = try eligibleAdmission(fixture)
        let proof = admission.eligibility
        let wrongBudget = try AttemptBudget.standardV1(
            policyDigest: workflowTestDigest("b")
        )
        #expect(throws: WorkflowPolicyError.invalidExceptionProof) {
            try VerifiedFrozenBudgetFact.freeze(
                budget: wrongBudget,
                runID: proof.runID,
                cycleID: proof.cycleID,
                convergencePolicyDigest: fixture.confirmation.baseline.convergencePolicyDigest,
                boundEventHead: proof.roundAnchorEventHead
            )
        }
        let accepted = try WorkflowReducer().decide(
            definition: EngineeringWorkflow.definition,
            state: fixture.state,
            event: WorkflowEvent(id: "budget-bound-exception", kind: .reviewExceptionOpened),
            context: exceptionTransitionContext(fixture, admission: admission)
        ).proposedState
        #expect(accepted.reviewCycle?.currentRoundID == admission.successorBaseline.roundID)
    }

    @Test("RC-05 exception lineage is continuous and exhausts the frozen budget")
    func continuousBoundedExceptionLineage() throws {
        let fixture = try confirmedStateFixture()
        let budget = try AttemptBudget.standardV1(policyDigest: workflowTestDigest("a"))
        let first = try eligibleProof(fixture)
        let secondContext = try exceptionContext(
            fixture: fixture,
            current: [reviewFinding("second-high", severity: .high)],
            priorExceptionRoundIDs: [first.nextRoundID],
            precedingRoundID: first.nextRoundID
        )
        guard case let .eligible(second) = ReviewConvergencePolicy().evaluateException(
            secondContext,
            budget: budget
        ) else {
            Issue.record("expected the continuous second exception round")
            return
        }
        #expect(second.nextSemanticOrdinal == 3)
        #expect(second.remainingExceptionRounds == 0)

        let unrelatedPrior = try ReviewRoundID(
            validating: String(repeating: "f", count: 64)
        )
        let discontinuous = try exceptionContext(
            fixture: fixture,
            current: [reviewFinding("discontinuous-high", severity: .high)],
            priorExceptionRoundIDs: [unrelatedPrior],
            precedingRoundID: first.nextRoundID
        )
        #expect(
            ReviewConvergencePolicy().evaluateException(discontinuous, budget: budget)
                == .escalation(.failed)
        )

        let exhausted = try exceptionContext(
            fixture: fixture,
            current: [reviewFinding("third-high", severity: .high)],
            priorExceptionRoundIDs: [first.nextRoundID, second.nextRoundID],
            precedingRoundID: second.nextRoundID
        )
        #expect(
            ReviewConvergencePolicy().evaluateException(exhausted, budget: budget)
                == .exhausted(.waitingForUser)
        )
    }
}

private struct HistoryFixture {
    let joined: KernelReviewHistoryEntry
    let remediation: KernelReviewHistoryEntry
    let confirmation: KernelReviewHistoryEntry
}

struct ConfirmedStateFixture {
    let state: RunState
    let source: LaneBReviewScenario
    let successor: LaneBSuccessorScenario
    let confirmation: LaneBReviewScenario
    let firstExceptionRemediation: VerifiedCommittedRemediationSuccessor
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

func confirmedStateFixture() throws -> ConfirmedStateFixture {
    let initialHead = try workflowTestDigest("1")
    let source = try LaneBReviewScenario.make(
        acceptedCurrentScope: true,
        runID: workflowTestRunID,
        gate: .requirements,
        preFreezeEventHead: initialHead,
        activeProfileDigest: workflowTestDigest("a")
    )
    let sourceClosure = try verifiedReviewClosure(source)
    var state = try reviewGateState(runID: source.runID, gate: source.baseline.gate)
    state = try reduceReview(
        state,
        event: WorkflowEvent(
            id: "policy-initial-freeze",
            kind: .reviewBaselineFrozen,
            reviewRound: try reviewRoundInput(for: source.baseline)
        ),
        head: initialHead
    )
    state = try reduceReview(
        state,
        event: WorkflowEvent(id: "policy-initial-close", kind: .reviewInventoryClosed),
        head: source.currentness.currentEventHead,
        baseline: source.baseline.digest,
        closureFact: sourceClosure
    )
    let remediationHead = try workflowTestDigest("3")
    state = try reduceReview(
        state,
        event: WorkflowEvent(id: "policy-remediation", kind: .reviewRemediationRecorded),
        head: remediationHead
    )
    let successor = try source.makeSuccessorBaseline(anchor: remediationHead)
    _ = try laneBVerifiedRemediation(
        source: source,
        successorBaseline: successor.baseline
    )
    let confirmation = try successor.makeConfirmationRegister(acceptedCurrentScope: true)
    let confirmationClosure = try verifiedReviewClosure(confirmation)
    state = try reduceReview(
        state,
        event: WorkflowEvent(
            id: "policy-confirmation-freeze",
            kind: .reviewBaselineFrozen,
            reviewRound: try reviewRoundInput(for: confirmation.baseline)
        ),
        head: confirmation.baseline.preCreationEventHead,
        baseline: source.baseline.digest
    )
    state = try reduceReview(
        state,
        event: WorkflowEvent(
            id: "policy-confirmation-inventory",
            kind: .reviewInventoryRecorded
        ),
        head: try workflowTestDigest("9"),
        baseline: confirmation.baseline.digest
    )
    state = try reduceReview(
        state,
        event: WorkflowEvent(
            id: "policy-confirmation-close",
            kind: .reviewInventoryClosed
        ),
        head: confirmation.currentness.currentEventHead,
        baseline: confirmation.baseline.digest,
        closureFact: confirmationClosure
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
    let currentRoundRemediationHead = try workflowTestDigest("7")
    state = try reduceReview(
        state,
        event: WorkflowEvent(
            id: "policy-confirmation-remediation",
            kind: .reviewRemediationRecorded
        ),
        head: currentRoundRemediationHead
    )
    let exceptionTemplate = try laneBRemediationSuccessorBaseline(
        source: confirmation,
        kind: .exception,
        semanticOrdinal: 2,
        anchor: try workflowTestDigest("8"),
        artifactHash: "c"
    )
    let firstExceptionRemediation = try laneBCommittedRemediation(
        source: confirmation,
        successorTemplate: exceptionTemplate
    ).successor
    return ConfirmedStateFixture(
        state: state,
        source: source,
        successor: successor,
        confirmation: confirmation,
        firstExceptionRemediation: firstExceptionRemediation,
        baselineDigest: confirmation.baseline.digest,
        registerDigest: confirmation.register.digest,
        remediationEventHead: firstExceptionRemediation.producedEventHead,
        confirmationEventHead: confirmationHead,
        exceptionEventHead: firstExceptionRemediation.publicationAnchorEventHead
    )
}

func exceptionContext(
    fixture: ConfirmedStateFixture,
    immediatelyPreceding: [ReviewFindingSummary] = [],
    current: [ReviewFindingSummary],
    priorExceptionRoundIDs: [ReviewRoundID],
    precedingRoundID: ReviewRoundID? = nil,
    precedingRegisterDigest: HashDigest? = nil,
    precedingBaselineDigest: HashDigest? = nil,
    remediationEventHead: HashDigest? = nil,
    confirmationEventHead: HashDigest? = nil,
    roundAnchorEventHead: HashDigest? = nil
) throws -> ReviewExceptionContext {
    let roundID: ReviewRoundID
    if let precedingRoundID {
        roundID = precedingRoundID
    } else {
        roundID = try #require(fixture.state.reviewCycle?.currentRoundID)
    }
    let registerDigest = precedingRegisterDigest ?? fixture.registerDigest
    let baselineDigest = precedingBaselineDigest ?? fixture.baselineDigest
    let remediationHead = remediationEventHead ?? fixture.remediationEventHead
    let confirmationHead = confirmationEventHead ?? fixture.confirmationEventHead
    let anchorHead = roundAnchorEventHead ?? fixture.exceptionEventHead
    let history = KernelReviewHistory(
        entries: [
            KernelReviewHistoryEntry(
                kind: .registerJoined,
                roundID: roundID,
                registerDigest: registerDigest,
                baselineDigest: baselineDigest,
                eventHead: try workflowTestDigest("2")
            ),
            KernelReviewHistoryEntry(
                kind: .confirmationRecorded,
                roundID: roundID,
                registerDigest: registerDigest,
                baselineDigest: baselineDigest,
                eventHead: confirmationHead
            ),
            KernelReviewHistoryEntry(
                kind: .remediationRecorded,
                roundID: roundID,
                registerDigest: registerDigest,
                baselineDigest: baselineDigest,
                eventHead: remediationHead
            ),
        ],
        priorExceptionRoundIDs: priorExceptionRoundIDs
    )
    return ReviewExceptionContext(
        runID: fixture.state.runID,
        cycleID: try #require(fixture.state.reviewCycle?.id),
        gate: try #require(fixture.state.reviewCycle?.gate),
        precedingRoundID: roundID,
        precedingRegisterDigest: registerDigest,
        precedingBaselineDigest: baselineDigest,
        roundAnchorEventHead: anchorHead,
        immediatelyPreceding: immediatelyPreceding,
        current: current,
        history: history,
        exhaustionCause: .authorityOrDecisionRequired
    )
}

func eligibleProof(
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

func eligibleAdmission(
    _ fixture: ConfirmedStateFixture
) throws -> VerifiedReviewExceptionAdmission {
    try sealedAdmission(
        fixture: fixture,
        predecessor: fixture.source,
        remediation: fixture.firstExceptionRemediation,
        priorAdmissions: []
    )
}

func sealedAdmission(
    fixture: ConfirmedStateFixture,
    predecessor: LaneBReviewScenario,
    remediation: VerifiedCommittedRemediationSuccessor,
    priorAdmissions: [VerifiedReviewExceptionAdmission]
) throws -> VerifiedReviewExceptionAdmission {
    let current = remediation.sourceRegister
    let registerJoinedHead = try workflowTestDigest("2")
    let context = ReviewExceptionContext(
        runID: current.baseline.runID,
        cycleID: current.baseline.cycleID,
        gate: current.baseline.gate,
        precedingRoundID: current.baseline.roundID,
        precedingRegisterDigest: current.register.digest,
        precedingBaselineDigest: current.baseline.digest,
        roundAnchorEventHead: remediation.successorBaseline.preCreationEventHead,
        immediatelyPreceding: reviewSummaries(
            predecessor.register,
            acceptedState: .failedRemediation
        ),
        current: reviewSummaries(current.register, acceptedState: .active),
        history: KernelReviewHistory(
            entries: [
                KernelReviewHistoryEntry(
                    kind: .registerJoined,
                    roundID: current.baseline.roundID,
                    registerDigest: current.register.digest,
                    baselineDigest: current.baseline.digest,
                    eventHead: registerJoinedHead
                ),
                KernelReviewHistoryEntry(
                    kind: .remediationRecorded,
                    roundID: current.baseline.roundID,
                    registerDigest: current.register.digest,
                    baselineDigest: current.baseline.digest,
                    eventHead: remediation.producedEventHead
                ),
                KernelReviewHistoryEntry(
                    kind: .confirmationRecorded,
                    roundID: fixture.confirmation.baseline.roundID,
                    registerDigest: fixture.confirmation.register.digest,
                    baselineDigest: fixture.confirmation.baseline.digest,
                    eventHead: fixture.confirmationEventHead
                ),
            ],
            priorExceptionRoundIDs: priorAdmissions.map(\.successorBaseline.roundID)
        ),
        exhaustionCause: .authorityOrDecisionRequired
    )
    let budget = try AttemptBudget.standardV1(
        policyDigest: current.baseline.convergencePolicyDigest
    )
    guard case let .eligible(admission) = ReviewConvergenceValidator
        .evaluateExceptionForTesting(
            context,
            predecessorRegister: predecessor.verifiedRegister,
            remediation: remediation,
            priorAdmissions: priorAdmissions,
            budget: budget,
            registerJoinedEventHead: registerJoinedHead,
            remediationEventHead: remediation.producedEventHead,
            confirmationEventHead: fixture.confirmationEventHead,
            confirmationRoundID: fixture.confirmation.baseline.roundID,
            confirmationRegisterDigest: fixture.confirmation.register.digest,
            confirmationBaselineDigest: fixture.confirmation.baseline.digest
        )
    else { throw WorkflowPolicyError.invalidExceptionProof }
    return admission
}

func exceptionTransitionContext(
    _ fixture: ConfirmedStateFixture,
    admission: VerifiedReviewExceptionAdmission?,
    currentEventHead: HashDigest? = nil
) throws -> TransitionContext {
    guard let admission else {
        return try TransitionContext(
            actorID: ActorID(validating: "exception-author"),
            principalID: PrincipalID(validating: "exception-principal"),
            currentEventHead: currentEventHead ?? fixture.exceptionEventHead,
            currentReviewBaselineDigest: fixture.baselineDigest,
            satisfiedGuards: []
        )
    }
    return try TransitionContext.openingException(
        actorID: ActorID(validating: "exception-author"),
        principalID: PrincipalID(validating: "exception-principal"),
        currentEventHead: currentEventHead ?? fixture.exceptionEventHead,
        admission: admission
    )
}

private func reviewSummaries(
    _ register: IssueRegister,
    acceptedState: ReviewFindingState
) -> [ReviewFindingSummary] {
    let dispositions = Dictionary(
        uniqueKeysWithValues: register.dispositions.map { ($0.fingerprint, $0) }
    )
    return register.entries.map { entry in
        ReviewFindingSummary(
            fingerprint: entry.fingerprint.failureFingerprint,
            severity: entry.severity,
            mustFix: entry.mustFix,
            state: dispositions[entry.fingerprint.failureFingerprint]?.entersRemediation == true
                ? acceptedState
                : .resolved
        )
    }.sorted { $0.fingerprint.rawValue < $1.fingerprint.rawValue }
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
