import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("ReviewConvergenceTransitionTests")
struct ReviewConvergenceTransitionTests {
    @Test("review round kinds use exact stable wire values")
    func reviewRoundKindWireValues() throws {
        let expectations: [(ReviewRoundKind, String)] = [
            (.initial, "initial"),
            (.normalConfirmation, "normal_confirmation"),
            (.exception, "exception"),
        ]

        for (kind, wireValue) in expectations {
            let bytes = try CanonicalJSON.encode(kind)
            #expect(String(decoding: bytes, as: UTF8.self) == "\"\(wireValue)\"")
            #expect(try CanonicalJSON.decode(ReviewRoundKind.self, from: bytes) == kind)
        }
    }

    @Test("only finding-producing engineering gates admit convergence review")
    func reviewGateAdmissionIsClosed() throws {
        let admitted: [(WorkflowStage, ReviewGateKind)] = [
            (.requirementGate, .requirements),
            (.designGate, .design),
            (.architectureGate, .architecture),
            (.planGate, .plan),
            (.checkpoint, .checkpoint),
            (.review, .review),
            (.finalGate, .final),
        ]

        for (stage, gate) in admitted {
            #expect(
                try ReviewGateKind.admit(
                    stage: stage,
                    workType: .engineeringRun,
                    evidenceKind: .findingProducingReview
                ) == gate
            )
        }

        #expect(throws: WorkflowError.reviewCycleNotAllowed) {
            try ReviewGateKind.admit(
                stage: .productReleaseGate,
                workType: .pluginRelease,
                evidenceKind: .findingProducingReview
            )
        }
        #expect(throws: WorkflowError.reviewCycleNotAllowed) {
            try ReviewGateKind.admit(
                stage: .finalGate,
                workType: .engineeringRun,
                evidenceKind: .pureScriptCheck
            )
        }
        #expect(throws: WorkflowError.reviewCycleNotAllowed) {
            try ReviewGateKind.admit(
                stage: .finalGate,
                workType: .engineeringRun,
                evidenceKind: .approvalOnly
            )
        }
    }

    @Test("round identity binds only predecessor inputs and enforces semantic ordinals")
    func deterministicRoundIdentity() throws {
        let preFreezeHead = try workflowTestDigest("1")
        let priorCommittedHead = try workflowTestDigest("2")
        let predecessorBaseline = try workflowTestDigest("3")
        let cycleID = try ReviewCycleID.derive(
            runID: workflowTestRunID,
            gate: .requirements,
            cycleOrdinal: 7,
            preFreezeEventHead: preFreezeHead
        )
        let sameCycleID = try ReviewCycleID.derive(
            runID: workflowTestRunID,
            gate: .requirements,
            cycleOrdinal: 7,
            preFreezeEventHead: preFreezeHead
        )
        #expect(cycleID == sameCycleID)

        let initial = try ReviewRoundID.derive(
            runID: workflowTestRunID,
            gate: .requirements,
            cycleID: cycleID,
            kind: .initial,
            semanticOrdinal: 0,
            roundAnchorEventHead: preFreezeHead,
            predecessorBaselineDigest: nil
        )
        let confirmation = try ReviewRoundID.derive(
            runID: workflowTestRunID,
            gate: .requirements,
            cycleID: cycleID,
            kind: .normalConfirmation,
            semanticOrdinal: 1,
            roundAnchorEventHead: priorCommittedHead,
            predecessorBaselineDigest: predecessorBaseline
        )
        #expect(initial != confirmation)
        #expect(initial.rawValue.count == 64)
        #expect(confirmation.rawValue.count == 64)

        #expect(throws: WorkflowError.invalidReviewRound) {
            try ReviewRoundID.derive(
                runID: workflowTestRunID,
                gate: .requirements,
                cycleID: cycleID,
                kind: .initial,
                semanticOrdinal: 0,
                roundAnchorEventHead: preFreezeHead,
                predecessorBaselineDigest: predecessorBaseline
            )
        }
        #expect(throws: WorkflowError.invalidReviewRound) {
            try ReviewRoundID.derive(
                runID: workflowTestRunID,
                gate: .requirements,
                cycleID: cycleID,
                kind: .normalConfirmation,
                semanticOrdinal: 2,
                roundAnchorEventHead: priorCommittedHead,
                predecessorBaselineDigest: predecessorBaseline
            )
        }
        #expect(throws: WorkflowError.invalidReviewRound) {
            try ReviewRoundID.derive(
                runID: workflowTestRunID,
                gate: .requirements,
                cycleID: cycleID,
                kind: .exception,
                semanticOrdinal: 1,
                roundAnchorEventHead: priorCommittedHead,
                predecessorBaselineDigest: predecessorBaseline
            )
        }
    }

    @Test("joined initial review may converge structurally without confirmation")
    func directConvergencePath() throws {
        let head = try workflowTestDigest("4")
        var state = try reviewGateState()
        state = try reduceReview(
            state,
            event: WorkflowEvent(
                id: "review-initial-freeze",
                kind: .reviewBaselineFrozen,
                reviewRound: try .initial(
                    gate: .requirements,
                    cycleOrdinal: 0,
                    preFreezeEventHead: head,
                    redactionPolicy: reviewRedactionPolicy
                )
            ),
            head: head
        )
        #expect(state.reviewCycle?.phase == .collectingInitial)
        #expect(state.reviewCycle?.currentRoundKind == .initial)

        state = try reduceReview(
            state,
            event: WorkflowEvent(id: "review-inventory", kind: .reviewInventoryRecorded),
            head: try workflowTestDigest("5")
        )
        state = try reduceReview(
            state,
            event: WorkflowEvent(id: "review-inventory-closed", kind: .reviewInventoryClosed),
            head: try workflowTestDigest("6")
        )
        state = try reduceReview(
            state,
            event: WorkflowEvent(id: "review-direct-converged", kind: .reviewConverged),
            head: try workflowTestDigest("7")
        )

        #expect(state.reviewCycle?.phase == .converged)
        #expect(state.reviewCycle?.didRecordRemediation == false)
        #expect(state.reviewCycle?.currentSemanticOrdinal == 0)
    }

    @Test("normal confirmation requires one recorded remediation and the current predecessor")
    func confirmationRequiresRemediation() throws {
        let initialHead = try workflowTestDigest("8")
        var state = try reviewGateState()
        state = try reduceReview(
            state,
            event: WorkflowEvent(
                id: "normal-initial-freeze",
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
            event: WorkflowEvent(id: "normal-inventory-closed", kind: .reviewInventoryClosed),
            head: try workflowTestDigest("9")
        )

        let cycleID = try #require(state.reviewCycle?.id)
        let predecessor = try workflowTestDigest("a")
        let laterHead = try workflowTestDigest("b")
        let confirmationRound = try ReviewRoundInput.later(
            cycleID: cycleID,
            gate: .requirements,
            kind: .normalConfirmation,
            semanticOrdinal: 1,
            roundAnchorEventHead: laterHead,
            predecessorBaselineDigest: predecessor,
            redactionPolicy: reviewRedactionPolicy
        )

        #expect(throws: WorkflowError.missingRemediation) {
            try reduceReview(
                state,
                event: WorkflowEvent(
                    id: "normal-too-early",
                    kind: .reviewBaselineFrozen,
                    reviewRound: confirmationRound
                ),
                head: laterHead,
                baseline: predecessor
            )
        }

        state = try reduceReview(
            state,
            event: WorkflowEvent(id: "normal-remediation", kind: .reviewRemediationRecorded),
            head: try workflowTestDigest("c")
        )
        state = try reduceReview(
            state,
            event: WorkflowEvent(
                id: "normal-freeze",
                kind: .reviewBaselineFrozen,
                reviewRound: confirmationRound
            ),
            head: laterHead,
            baseline: predecessor
        )
        #expect(state.reviewCycle?.phase == .collectingNormalConfirmation)
        #expect(state.reviewCycle?.currentRoundKind == .normalConfirmation)
        #expect(state.reviewCycle?.currentSemanticOrdinal == 1)

        state = try reduceReview(
            state,
            event: WorkflowEvent(id: "normal-confirmed", kind: .reviewConfirmationRecorded),
            head: try workflowTestDigest("d")
        )
        state = try reduceReview(
            state,
            event: WorkflowEvent(id: "normal-converged", kind: .reviewConverged),
            head: try workflowTestDigest("e")
        )
        #expect(state.reviewCycle?.phase == .converged)
    }

    @Test("checkpoint 02.1 rejects every policy-free exception round")
    func exceptionAdmissionIsUnavailable() throws {
        let head = try workflowTestDigest("f")
        let predecessor = try workflowTestDigest("0")
        let cycleID = try ReviewCycleID.derive(
            runID: workflowTestRunID,
            gate: .requirements,
            cycleOrdinal: 0,
            preFreezeEventHead: head
        )
        let input = try ReviewRoundInput.later(
            cycleID: cycleID,
            gate: .requirements,
            kind: .exception,
            semanticOrdinal: 2,
            roundAnchorEventHead: head,
            predecessorBaselineDigest: predecessor,
            redactionPolicy: reviewRedactionPolicy
        )
        let state = try reviewGateState()

        #expect(throws: WorkflowError.exceptionPolicyRequired) {
            try reduceReview(
                state,
                event: WorkflowEvent(
                    id: "exception-freeze",
                    kind: .reviewBaselineFrozen,
                    reviewRound: input
                ),
                head: head,
                baseline: predecessor
            )
        }
        #expect(throws: WorkflowError.exceptionPolicyRequired) {
            try reduceReview(
                state,
                event: WorkflowEvent(id: "exception-open", kind: .reviewExceptionOpened),
                head: head
            )
        }
    }

    @Test("an event ID replay with a different review payload is an integrity collision")
    func reviewEventIDCollisionIncludesRoundPayload() throws {
        let originalHead = try workflowTestDigest("1")
        let changedHead = try workflowTestDigest("2")
        var state = try reviewGateState()
        let original = try WorkflowEvent(
            id: "same-review-event",
            kind: .reviewBaselineFrozen,
            reviewRound: .initial(
                gate: .requirements,
                cycleOrdinal: 0,
                preFreezeEventHead: originalHead,
                redactionPolicy: reviewRedactionPolicy
            )
        )
        state = try reduceReview(state, event: original, head: originalHead)

        let changed = try WorkflowEvent(
            id: original.id,
            kind: .reviewBaselineFrozen,
            reviewRound: .initial(
                gate: .requirements,
                cycleOrdinal: 0,
                preFreezeEventHead: changedHead,
                redactionPolicy: reviewRedactionPolicy
            )
        )
        #expect(throws: WorkflowError.eventIDCollision) {
            try reduceReview(state, event: changed, head: changedHead)
        }
    }

    @Test("R-02.1-003 requires convergence and resets the cycle for the next gate")
    func gateConvergenceAndCycleReset() throws {
        let bareGate = try reviewGateState()
        #expect(throws: WorkflowError.illegalTransition) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: bareGate,
                event: WorkflowEvent(id: "gate-bypass", kind: .requirementApproved),
                context: exactContext(for: .requirementApproved)
            )
        }

        var state = try directlyConvergedReview(
            bareGate,
            gate: .requirements,
            cycleOrdinal: 0,
            prefix: "requirements"
        )
        state = try WorkflowReducer().decide(
            definition: EngineeringWorkflow.definition,
            state: state,
            event: WorkflowEvent(id: "requirements-approved", kind: .requirementApproved),
            context: exactContext(for: .requirementApproved)
        ).proposedState
        #expect(state.stage == .design)
        #expect(state.reviewCycle == nil)

        state = try WorkflowReducer().decide(
            definition: EngineeringWorkflow.definition,
            state: state,
            event: WorkflowEvent(id: "design-submitted-after-cycle", kind: .designSubmitted),
            context: exactContext(for: .designSubmitted)
        ).proposedState
        let designHead = try workflowTestDigest("4")
        state = try reduceReview(
            state,
            event: WorkflowEvent(
                id: "design-cycle",
                kind: .reviewBaselineFrozen,
                reviewRound: .initial(
                    gate: .design,
                    cycleOrdinal: 1,
                    preFreezeEventHead: designHead,
                    redactionPolicy: reviewRedactionPolicy
                )
            ),
            head: designHead
        )
        #expect(state.reviewCycle?.gate == .design)
        #expect(state.reviewCycle?.cycleOrdinal == 1)
    }

    @Test("R-02.1-003 invalidation admits only the next same-gate cycle ordinal")
    func invalidatedCycleReplacementIsMonotonic() throws {
        let head = try workflowTestDigest("5")
        var state = try reviewGateState()
        state = try reduceReview(
            state,
            event: WorkflowEvent(
                id: "invalidated-initial",
                kind: .reviewBaselineFrozen,
                reviewRound: .initial(
                    gate: .requirements,
                    cycleOrdinal: 0,
                    preFreezeEventHead: head,
                    redactionPolicy: reviewRedactionPolicy
                )
            ),
            head: head
        )
        state = try reduceReview(
            state,
            event: WorkflowEvent(id: "invalidate-cycle", kind: .reviewInvalidated),
            head: try workflowTestDigest("6")
        )

        let replacementHead = try workflowTestDigest("7")
        state = try reduceReview(
            state,
            event: WorkflowEvent(
                id: "replacement-initial",
                kind: .reviewBaselineFrozen,
                reviewRound: .initial(
                    gate: .requirements,
                    cycleOrdinal: 1,
                    preFreezeEventHead: replacementHead,
                    redactionPolicy: reviewRedactionPolicy
                )
            ),
            head: replacementHead
        )
        #expect(state.reviewCycle?.phase == .collectingInitial)
        #expect(state.reviewCycle?.cycleOrdinal == 1)

        let wrongHead = try workflowTestDigest("8")
        #expect(throws: WorkflowError.invalidReviewRound) {
            try reduceReview(
                try reviewGateState(),
                event: WorkflowEvent(
                    id: "wrong-first-ordinal",
                    kind: .reviewBaselineFrozen,
                    reviewRound: .initial(
                        gate: .requirements,
                        cycleOrdinal: 1,
                        preFreezeEventHead: wrongHead,
                        redactionPolicy: reviewRedactionPolicy
                    )
                ),
                head: wrongHead
            )
        }
        #expect(throws: WorkflowError.invalidReviewRound) {
            try reduceReview(
                try reviewGateState(),
                event: WorkflowEvent(
                    id: "wrong-gate-cycle",
                    kind: .reviewBaselineFrozen,
                    reviewRound: .initial(
                        gate: .design,
                        cycleOrdinal: 0,
                        preFreezeEventHead: wrongHead,
                        redactionPolicy: reviewRedactionPolicy
                    )
                ),
                head: wrongHead
            )
        }
    }

    @Test("R-02.1-006 review identities have golden preimages and bind every predecessor input")
    func reviewIdentityGoldenAndPerturbations() throws {
        let head = try workflowTestDigest("1")
        let cycle = try ReviewCycleID.derive(
            runID: workflowTestRunID,
            gate: .requirements,
            cycleOrdinal: 7,
            preFreezeEventHead: head
        )
        #expect(cycle.rawValue == "3daa22c0000d21675d23a855d0b5b0d9952589fd482f21bd6527550ab3808092")

        let round = try ReviewRoundID.derive(
            runID: workflowTestRunID,
            gate: .requirements,
            cycleID: cycle,
            kind: .initial,
            semanticOrdinal: 0,
            roundAnchorEventHead: head,
            predecessorBaselineDigest: nil
        )
        #expect(round.rawValue == "4a5197a2a452fa04b7e3957934fa9535fa9004a75b843133044393bf3b0900c6")

        let otherRun = RunID(rawValue: UUID(uuidString: "28b71a1e-d066-42ff-b324-a3295db301d2")!)
        let cyclePerturbations = [
            try ReviewCycleID.derive(
                runID: otherRun,
                gate: .requirements,
                cycleOrdinal: 7,
                preFreezeEventHead: head
            ),
            try ReviewCycleID.derive(
                runID: workflowTestRunID,
                gate: .design,
                cycleOrdinal: 7,
                preFreezeEventHead: head
            ),
            try ReviewCycleID.derive(
                runID: workflowTestRunID,
                gate: .requirements,
                cycleOrdinal: 8,
                preFreezeEventHead: head
            ),
            try ReviewCycleID.derive(
                runID: workflowTestRunID,
                gate: .requirements,
                cycleOrdinal: 7,
                preFreezeEventHead: workflowTestDigest("2")
            ),
        ]
        #expect(cyclePerturbations.allSatisfy { $0 != cycle })

        let predecessor = try workflowTestDigest("3")
        let laterHead = try workflowTestDigest("4")
        let confirmation = try ReviewRoundID.derive(
            runID: workflowTestRunID,
            gate: .requirements,
            cycleID: cycle,
            kind: .normalConfirmation,
            semanticOrdinal: 1,
            roundAnchorEventHead: laterHead,
            predecessorBaselineDigest: predecessor
        )
        let roundPerturbations = [
            try ReviewRoundID.derive(
                runID: otherRun,
                gate: .requirements,
                cycleID: cycle,
                kind: .normalConfirmation,
                semanticOrdinal: 1,
                roundAnchorEventHead: laterHead,
                predecessorBaselineDigest: predecessor
            ),
            try ReviewRoundID.derive(
                runID: workflowTestRunID,
                gate: .design,
                cycleID: cycle,
                kind: .normalConfirmation,
                semanticOrdinal: 1,
                roundAnchorEventHead: laterHead,
                predecessorBaselineDigest: predecessor
            ),
            try ReviewRoundID.derive(
                runID: workflowTestRunID,
                gate: .requirements,
                cycleID: try ReviewCycleID.derive(
                    runID: workflowTestRunID,
                    gate: .requirements,
                    cycleOrdinal: 8,
                    preFreezeEventHead: head
                ),
                kind: .normalConfirmation,
                semanticOrdinal: 1,
                roundAnchorEventHead: laterHead,
                predecessorBaselineDigest: predecessor
            ),
            try ReviewRoundID.derive(
                runID: workflowTestRunID,
                gate: .requirements,
                cycleID: cycle,
                kind: .normalConfirmation,
                semanticOrdinal: 1,
                roundAnchorEventHead: workflowTestDigest("5"),
                predecessorBaselineDigest: predecessor
            ),
            try ReviewRoundID.derive(
                runID: workflowTestRunID,
                gate: .requirements,
                cycleID: cycle,
                kind: .normalConfirmation,
                semanticOrdinal: 1,
                roundAnchorEventHead: laterHead,
                predecessorBaselineDigest: workflowTestDigest("6")
            ),
            try ReviewRoundID.derive(
                runID: workflowTestRunID,
                gate: .requirements,
                cycleID: cycle,
                kind: .exception,
                semanticOrdinal: 2,
                roundAnchorEventHead: laterHead,
                predecessorBaselineDigest: predecessor
            ),
            try ReviewRoundID.derive(
                runID: workflowTestRunID,
                gate: .requirements,
                cycleID: cycle,
                kind: .exception,
                semanticOrdinal: 3,
                roundAnchorEventHead: laterHead,
                predecessorBaselineDigest: predecessor
            ),
        ]
        #expect(roundPerturbations.allSatisfy { $0 != confirmation })

        var state = try reviewGateState()
        state = try reduceReview(
            state,
            event: WorkflowEvent(
                id: "identity-state-freeze",
                kind: .reviewBaselineFrozen,
                reviewRound: .initial(
                    gate: .requirements,
                    cycleOrdinal: 0,
                    preFreezeEventHead: head,
                    redactionPolicy: reviewRedactionPolicy
                )
            ),
            head: head
        )
        let stateObject = try workflowJSONObject(state)
        let cycleObject = try #require(stateObject["review_cycle"] as? [String: Any])
        #expect(cycleObject["current_round_anchor_event_head"] as? String == head.rawValue)
        #expect(cycleObject["predecessor_baseline_digest"] == nil)

        let alternatePolicy = try RedactionPolicyBinding(
            identity: "urn:ifl:redaction-policy:alternate:v1",
            digest: workflowTestDigest("8")
        )
        var alternateState = try reviewGateState()
        alternateState = try reduceReview(
            alternateState,
            event: WorkflowEvent(
                id: "identity-alternate-baseline",
                kind: .reviewBaselineFrozen,
                reviewRound: .initial(
                    gate: .requirements,
                    cycleOrdinal: 0,
                    preFreezeEventHead: head,
                    redactionPolicy: alternatePolicy
                )
            ),
            head: head
        )
        #expect(alternateState.reviewCycle?.currentRoundID == state.reviewCycle?.currentRoundID)
    }

    @Test("R-02.1-005 maximum review ordinal fails with a typed error instead of trapping")
    func maximumReviewOrdinalFailsSafely() throws {
        let head = try workflowTestDigest("a")
        var state = try reviewGateState()
        state.nextReviewCycleOrdinal = UInt64.max
        state = try reduceReview(
            state,
            event: WorkflowEvent(
                id: "maximum-cycle-freeze",
                kind: .reviewBaselineFrozen,
                reviewRound: .initial(
                    gate: .requirements,
                    cycleOrdinal: UInt64.max,
                    preFreezeEventHead: head,
                    redactionPolicy: reviewRedactionPolicy
                )
            ),
            head: head
        )

        #expect(throws: WorkflowError.ordinalOverflow) {
            try reduceReview(
                state,
                event: WorkflowEvent(id: "maximum-cycle-invalidated", kind: .reviewInvalidated),
                head: try workflowTestDigest("b")
            )
        }
    }
}

let reviewRedactionPolicy = try! RedactionPolicyBinding(
    identity: "urn:ifl:redaction-policy:enterprise:v1",
    digest: workflowTestDigest("9")
)

func reviewGateState() throws -> RunState {
    var state = try RunState.startEngineering(
        runID: workflowTestRunID,
        workItemID: "IIS-0002",
        mode: .auto,
        canonSnapshotDigest: workflowTestDigest("a")
    )
    state.stage = .requirementGate
    return state
}

func reduceReview(
    _ state: RunState,
    event: WorkflowEvent,
    head: HashDigest,
    baseline: HashDigest? = nil
) throws -> RunState {
    try WorkflowReducer().decide(
        definition: EngineeringWorkflow.definition,
        state: state,
        event: event,
        context: engineeringContext(
            currentEventHead: head,
            currentReviewBaselineDigest: baseline
        )
    ).proposedState
}

func directlyConvergedReview(
    _ state: RunState,
    gate: ReviewGateKind,
    cycleOrdinal: UInt64,
    prefix: String
) throws -> RunState {
    let head = try workflowTestDigest("1")
    var state = try reduceReview(
        state,
        event: WorkflowEvent(
            id: "\(prefix)-freeze",
            kind: .reviewBaselineFrozen,
            reviewRound: .initial(
                gate: gate,
                cycleOrdinal: cycleOrdinal,
                preFreezeEventHead: head,
                redactionPolicy: reviewRedactionPolicy
            )
        ),
        head: head
    )
    state = try reduceReview(
        state,
        event: WorkflowEvent(id: "\(prefix)-inventory-closed", kind: .reviewInventoryClosed),
        head: try workflowTestDigest("2")
    )
    return try reduceReview(
        state,
        event: WorkflowEvent(id: "\(prefix)-converged", kind: .reviewConverged),
        head: try workflowTestDigest("3")
    )
}
