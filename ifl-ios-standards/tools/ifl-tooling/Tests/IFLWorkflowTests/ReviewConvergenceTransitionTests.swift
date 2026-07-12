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
        let scenario = try LaneBReviewScenario.make(
            acceptedCurrentScope: false,
            runID: workflowTestRunID,
            gate: .requirements,
            preFreezeEventHead: head,
            activeProfileDigest: workflowTestDigest("a")
        )
        let closure = try verifiedReviewClosure(scenario)
        var state = try reviewGateState(runID: scenario.runID, gate: scenario.baseline.gate)
        state = try reduceReview(
            state,
            event: WorkflowEvent(
                id: "review-initial-freeze",
                kind: .reviewBaselineFrozen,
                reviewRound: try reviewRoundInput(for: scenario.baseline)
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
        let beforeRawClose = state
        #expect(throws: WorkflowError.invalidReviewRound) {
            try reduceReview(
                state,
                event: WorkflowEvent(id: "review-raw-close", kind: .reviewInventoryClosed),
                head: scenario.currentness.currentEventHead,
                baseline: scenario.baseline.digest
            )
        }
        #expect(state == beforeRawClose)
        let foreignClosure = try verifiedReviewClosure(
            LaneBReviewScenario.make(acceptedCurrentScope: false)
        )
        #expect(throws: WorkflowError.invalidReviewRound) {
            try reduceReview(
                state,
                event: WorkflowEvent(id: "review-foreign-close", kind: .reviewInventoryClosed),
                head: scenario.currentness.currentEventHead,
                baseline: scenario.baseline.digest,
                closureFact: foreignClosure
            )
        }
        state = try reduceReview(
            state,
            event: WorkflowEvent(id: "review-inventory-closed", kind: .reviewInventoryClosed),
            head: scenario.currentness.currentEventHead,
            baseline: scenario.baseline.digest,
            closureFact: closure
        )
        let closed = try #require(state.reviewCycle)
        #expect(closed.closedRoundID == scenario.baseline.roundID)
        #expect(closed.closedBaselineDigest == scenario.baseline.digest)
        #expect(closed.closedRegisterDigest == scenario.register.digest)
        #expect(closed.closedPathDecision == .directConvergenceNoAcceptedCurrentScope)
        #expect(closed.lastRemediatedRoundID == nil)
        #expect(closed.confirmationReceiptID == nil)
        let stateObject = try workflowJSONObject(state)
        let cycleObject = try #require(stateObject["review_cycle"] as? [String: Any])
        #expect(cycleObject["closed_round_id"] as? String == scenario.baseline.roundID.rawValue)
        #expect(cycleObject["closed_baseline_digest"] as? String == scenario.baseline.digest.rawValue)
        #expect(cycleObject["closed_register_digest"] as? String == scenario.register.digest.rawValue)
        #expect(
            cycleObject["closed_path_decision"] as? String ==
                IssueRegisterPathDecision.directConvergenceNoAcceptedCurrentScope.rawValue
        )
        var partialStateObject = stateObject
        var partialCycleObject = cycleObject
        partialCycleObject.removeValue(forKey: "closed_register_digest")
        partialStateObject["review_cycle"] = partialCycleObject
        #expect(throws: WorkflowError.invalidState) {
            try decodeWorkflowState(partialStateObject)
        }

        var legacyStateObject = stateObject
        var legacyCycleObject = cycleObject
        for key in [
            "closed_round_id",
            "closed_baseline_digest",
            "closed_register_digest",
            "closed_path_decision",
        ] {
            legacyCycleObject.removeValue(forKey: key)
        }
        legacyStateObject["review_cycle"] = legacyCycleObject
        let legacyState = try decodeWorkflowState(legacyStateObject)
        #expect(legacyState.reviewCycle?.closedRoundID == nil)
        #expect(throws: WorkflowError.illegalTransition) {
            try reduceReview(
                legacyState,
                event: WorkflowEvent(
                    id: "legacy-unsealed-convergence",
                    kind: .reviewConverged
                ),
                head: try workflowTestDigest("6")
            )
        }
        let directReceiptID = try ReceiptID(validating: "review-convergence-review-direct")
        state = try reduceReview(
            state,
            event: WorkflowEvent(id: directReceiptID.rawValue, kind: .reviewConverged),
            head: try workflowTestDigest("7")
        )

        #expect(state.reviewCycle?.phase == .converged)
        #expect(state.reviewCycle?.didRecordRemediation == false)
        #expect(state.reviewCycle?.currentSemanticOrdinal == 0)
        #expect(state.reviewCycle?.convergenceReceiptID == directReceiptID)
        #expect(state.reviewCycle?.closedRoundID == scenario.baseline.roundID)

        var legacyConvergedObject = try workflowJSONObject(state)
        var legacyConvergedCycle = try #require(
            legacyConvergedObject["review_cycle"] as? [String: Any]
        )
        for key in [
            "closed_round_id",
            "closed_baseline_digest",
            "closed_register_digest",
            "closed_path_decision",
        ] {
            legacyConvergedCycle.removeValue(forKey: key)
        }
        legacyConvergedObject["review_cycle"] = legacyConvergedCycle
        #expect(throws: WorkflowError.invalidState) {
            try decodeWorkflowState(legacyConvergedObject)
        }
    }

    @Test("normal confirmation requires one recorded remediation and the current predecessor")
    func confirmationRequiresRemediation() throws {
        let initialHead = try workflowTestDigest("8")
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
                id: "normal-initial-freeze",
                kind: .reviewBaselineFrozen,
                reviewRound: try reviewRoundInput(for: source.baseline)
            ),
            head: initialHead
        )
        state = try reduceReview(
            state,
            event: WorkflowEvent(id: "normal-inventory-closed", kind: .reviewInventoryClosed),
            head: source.currentness.currentEventHead,
            baseline: source.baseline.digest,
            closureFact: sourceClosure
        )
        #expect(state.reviewCycle?.closedRoundID == source.baseline.roundID)
        #expect(state.reviewCycle?.closedBaselineDigest == source.baseline.digest)
        #expect(state.reviewCycle?.closedRegisterDigest == source.register.digest)
        #expect(state.reviewCycle?.closedPathDecision == .requiresRemediation)

        let successor = try source.makeSuccessorBaseline()
        let remediation = try laneBVerifiedRemediation(
            source: source,
            successorBaseline: successor.baseline
        )
        #expect(remediation.successorBaseline.digest == successor.baseline.digest)
        let confirmation = try successor.makeConfirmationRegister()
        let confirmationClosure = try verifiedReviewClosure(confirmation)
        let confirmationRound = try reviewRoundInput(for: confirmation.baseline)

        #expect(throws: WorkflowError.missingRemediation) {
            try reduceReview(
                state,
                event: WorkflowEvent(
                    id: "normal-too-early",
                    kind: .reviewBaselineFrozen,
                    reviewRound: confirmationRound
                ),
                head: confirmation.baseline.preCreationEventHead,
                baseline: source.baseline.digest
            )
        }

        state = try reduceReview(
            state,
            event: WorkflowEvent(id: "normal-remediation", kind: .reviewRemediationRecorded),
            head: try workflowTestDigest("c")
        )
        #expect(state.reviewCycle?.lastRemediatedRoundID == source.baseline.roundID)
        state = try reduceReview(
            state,
            event: WorkflowEvent(
                id: "normal-freeze",
                kind: .reviewBaselineFrozen,
                reviewRound: confirmationRound
            ),
            head: confirmation.baseline.preCreationEventHead,
            baseline: source.baseline.digest
        )
        #expect(state.reviewCycle?.phase == .collectingNormalConfirmation)
        #expect(state.reviewCycle?.currentRoundKind == .normalConfirmation)
        #expect(state.reviewCycle?.currentSemanticOrdinal == 1)
        #expect(state.reviewCycle?.closedRoundID == nil)
        #expect(state.reviewCycle?.closedBaselineDigest == nil)
        #expect(state.reviewCycle?.closedRegisterDigest == nil)
        #expect(state.reviewCycle?.closedPathDecision == nil)
        #expect(state.reviewCycle?.lastRemediatedRoundID == source.baseline.roundID)
        #expect(state.reviewCycle?.confirmationReceiptID == nil)

        state = try reduceReview(
            state,
            event: WorkflowEvent(id: "normal-confirmation-inventory", kind: .reviewInventoryRecorded),
            head: try workflowTestDigest("c"),
            baseline: confirmation.baseline.digest
        )
        state = try reduceReview(
            state,
            event: WorkflowEvent(id: "normal-confirmation-close", kind: .reviewInventoryClosed),
            head: confirmation.currentness.currentEventHead,
            baseline: confirmation.baseline.digest,
            closureFact: confirmationClosure
        )
        #expect(state.reviewCycle?.phase == .collectingNormalConfirmation)
        #expect(state.reviewCycle?.closedRoundID == confirmation.baseline.roundID)
        #expect(state.reviewCycle?.closedBaselineDigest == confirmation.baseline.digest)
        #expect(state.reviewCycle?.closedRegisterDigest == confirmation.register.digest)
        #expect(
            state.reviewCycle?.closedPathDecision ==
                .directConvergenceNoAcceptedCurrentScope
        )

        let confirmationReceiptID = try ReceiptID(validating: "normal-confirmed")
        state = try reduceReview(
            state,
            event: WorkflowEvent(
                id: confirmationReceiptID.rawValue,
                kind: .reviewConfirmationRecorded
            ),
            head: try workflowTestDigest("e")
        )
        #expect(state.reviewCycle?.confirmationReceiptID == confirmationReceiptID)
        let persisted = try CanonicalJSON.decode(
            RunState.self,
            from: CanonicalJSON.encode(state)
        )
        #expect(throws: WorkflowError.illegalTransition) {
            try reduceReview(
                persisted,
                event: WorkflowEvent(
                    id: "normal-confirmed-again",
                    kind: .reviewConfirmationRecorded
                ),
                head: try workflowTestDigest("f")
            )
        }

        let receiptID = try ReceiptID(validating: "review-convergence-normal-confirmation")
        state = try reduceReview(
            persisted,
            event: WorkflowEvent(id: receiptID.rawValue, kind: .reviewConverged),
            head: try workflowTestDigest("0")
        )
        #expect(state.reviewCycle?.phase == .converged)
        #expect(state.reviewCycle?.convergenceReceiptID == receiptID)

        var legacyConfirmedObject = try workflowJSONObject(state)
        var legacyConfirmedCycle = try #require(
            legacyConfirmedObject["review_cycle"] as? [String: Any]
        )
        legacyConfirmedCycle.removeValue(forKey: "confirmation_receipt_id")
        legacyConfirmedObject["review_cycle"] = legacyConfirmedCycle
        #expect(throws: WorkflowError.invalidState) {
            try decodeWorkflowState(legacyConfirmedObject)
        }
    }

    @Test("RRC-03 exception closure requiring remediation cannot converge")
    func exceptionRoundIsOperational() throws {
        let fixture = try confirmedStateFixture()
        let admission = try eligibleAdmission(fixture)
        let proof = admission.eligibility
        let exception = try laneBScenario(
            replacing: fixture.confirmation,
            baseline: admission.successorBaseline,
            acceptedCurrentScope: true
        )
        let exceptionClosure = try verifiedReviewClosure(exception)
        var state = try WorkflowReducer().decide(
            definition: EngineeringWorkflow.definition,
            state: fixture.state,
            event: WorkflowEvent(id: "operational-exception-open", kind: .reviewExceptionOpened),
            context: exceptionTransitionContext(fixture, admission: admission)
        ).proposedState
        #expect(state.reviewCycle?.phase == .collectingException)
        #expect(state.reviewCycle?.currentRoundKind == .exception)
        #expect(state.reviewCycle?.currentRoundID == proof.nextRoundID)
        #expect(state.reviewCycle?.predecessorBaselineDigest == fixture.baselineDigest)
        #expect(state.reviewCycle?.closedRoundID == nil)
        #expect(state.reviewCycle?.closedBaselineDigest == nil)
        #expect(state.reviewCycle?.closedRegisterDigest == nil)
        #expect(state.reviewCycle?.closedPathDecision == nil)
        #expect(state.reviewCycle?.lastRemediatedRoundID == proof.precedingRoundID)
        let cycleConfirmation = try #require(state.reviewCycle?.confirmationReceiptID)

        state = try reduceReview(
            state,
            event: WorkflowEvent(
                id: "operational-exception-inventory",
                kind: .reviewInventoryRecorded
            ),
            head: try workflowTestDigest("9"),
            baseline: exception.baseline.digest
        )
        state = try reduceReview(
            state,
            event: WorkflowEvent(
                id: "operational-exception-close",
                kind: .reviewInventoryClosed
            ),
            head: exception.currentness.currentEventHead,
            baseline: exception.baseline.digest,
            closureFact: exceptionClosure
        )
        #expect(state.reviewCycle?.phase == .awaitingRemediation)
        #expect(state.reviewCycle?.closedRoundID == exception.baseline.roundID)
        #expect(state.reviewCycle?.closedBaselineDigest == exception.baseline.digest)
        #expect(state.reviewCycle?.closedRegisterDigest == exception.register.digest)
        #expect(state.reviewCycle?.closedPathDecision == .requiresRemediation)
        #expect(state.reviewCycle?.confirmationReceiptID == cycleConfirmation)

        let receiptID = try ReceiptID(validating: "review-convergence-exception")
        let beforeConvergence = state
        #expect(throws: WorkflowError.missingRemediation) {
            try reduceReview(
                state,
                event: WorkflowEvent(id: receiptID.rawValue, kind: .reviewConverged),
                head: try workflowTestDigest("b"),
                baseline: exception.baseline.digest
            )
        }
        #expect(state == beforeConvergence)

        let secondAnchor = try workflowTestDigest("d")
        let secondTemplate = try laneBRemediationSuccessorBaseline(
            source: exception,
            kind: .exception,
            semanticOrdinal: 3,
            anchor: secondAnchor,
            artifactHash: "d"
        )
        let secondRemediation = try laneBCommittedRemediation(
            source: exception,
            successorTemplate: secondTemplate
        ).successor
        let firstExceptionRemediationHead = secondRemediation.producedEventHead
        state = try reduceReview(
            state,
            event: WorkflowEvent(
                id: "operational-exception-remediation",
                kind: .reviewRemediationRecorded
            ),
            head: firstExceptionRemediationHead,
            baseline: exception.baseline.digest
        )
        let firstExceptionRoundID = exception.baseline.roundID
        #expect(state.reviewCycle?.lastRemediatedRoundID == firstExceptionRoundID)

        #expect(throws: WorkflowError.invalidExceptionProof) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: state,
                event: WorkflowEvent(
                    id: "operational-stale-predecessor",
                    kind: .reviewExceptionOpened
                ),
                context: exceptionTransitionContext(fixture, admission: admission)
            )
        }

        let secondAdmission = try sealedAdmission(
            fixture: fixture,
            predecessor: fixture.confirmation,
            remediation: secondRemediation,
            priorAdmissions: [admission]
        )
        let secondProof = secondAdmission.eligibility
        #expect(secondProof.precedingRoundID == firstExceptionRoundID)
        #expect(secondProof.precedingBaselineDigest == exception.baseline.digest)
        #expect(secondProof.precedingRegisterDigest == exception.register.digest)
        #expect(secondProof.nextSemanticOrdinal == 3)

        let secondContext = try TransitionContext.openingException(
            actorID: ActorID(validating: "exception-author"),
            principalID: PrincipalID(validating: "exception-principal"),
            currentEventHead: secondAnchor,
            admission: secondAdmission
        )
        state = try WorkflowReducer().decide(
            definition: EngineeringWorkflow.definition,
            state: state,
            event: WorkflowEvent(
                id: "operational-second-exception-open",
                kind: .reviewExceptionOpened
            ),
            context: secondContext
        ).proposedState
        #expect(state.reviewCycle?.phase == .collectingException)
        #expect(state.reviewCycle?.currentSemanticOrdinal == 3)
        #expect(state.reviewCycle?.currentRoundID == secondProof.nextRoundID)
        #expect(state.reviewCycle?.predecessorBaselineDigest == exception.baseline.digest)
        #expect(state.reviewCycle?.closedRoundID == nil)
        #expect(state.reviewCycle?.closedBaselineDigest == nil)
        #expect(state.reviewCycle?.closedRegisterDigest == nil)
        #expect(state.reviewCycle?.closedPathDecision == nil)
        #expect(state.reviewCycle?.lastRemediatedRoundID == firstExceptionRoundID)
        #expect(state.reviewCycle?.confirmationReceiptID == cycleConfirmation)
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
        var unsealed = state
        var unsealedCycle = try #require(unsealed.reviewCycle)
        unsealedCycle.clearCurrentRoundClosure()
        unsealed.reviewCycle = unsealedCycle
        #expect(throws: WorkflowError.illegalTransition) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: unsealed,
                event: WorkflowEvent(
                    id: "requirements-unsealed-exit",
                    kind: .requirementApproved
                ),
                context: exactContext(for: .requirementApproved)
            )
        }
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

    @Test("RRC-04 invalidation clears cycle markers and replacement starts fresh")
    func invalidationClearsLifecycleMarkers() throws {
        let fixture = try confirmedStateFixture()
        var state = fixture.state
        let active = try #require(state.reviewCycle)
        #expect(active.closedRoundID == active.currentRoundID)
        #expect(active.closedBaselineDigest == fixture.baselineDigest)
        #expect(active.closedRegisterDigest == fixture.registerDigest)
        #expect(active.closedPathDecision == .requiresRemediation)
        #expect(active.lastRemediatedRoundID == active.currentRoundID)
        #expect(active.confirmationReceiptID != nil)

        state = try reduceReview(
            state,
            event: WorkflowEvent(id: "marker-cycle-invalidated", kind: .reviewInvalidated),
            head: try workflowTestDigest("d")
        )
        #expect(state.reviewCycle?.phase == .invalidated)
        #expect(state.reviewCycle?.closedRoundID == nil)
        #expect(state.reviewCycle?.closedBaselineDigest == nil)
        #expect(state.reviewCycle?.closedRegisterDigest == nil)
        #expect(state.reviewCycle?.closedPathDecision == nil)
        #expect(state.reviewCycle?.lastRemediatedRoundID == nil)
        #expect(state.reviewCycle?.confirmationReceiptID == nil)

        let replacementHead = try workflowTestDigest("e")
        state = try reduceReview(
            state,
            event: WorkflowEvent(
                id: "marker-cycle-replacement",
                kind: .reviewBaselineFrozen,
                reviewRound: .initial(
                    gate: .requirements,
                    cycleOrdinal: 1,
                    preFreezeEventHead: replacementHead,
                    redactionPolicy: fixture.successor.baseline.redactionPolicy
                )
            ),
            head: replacementHead
        )
        #expect(state.reviewCycle?.phase == .collectingInitial)
        #expect(state.reviewCycle?.cycleOrdinal == 1)
        #expect(state.reviewCycle?.didRecordRemediation == false)
        #expect(state.reviewCycle?.didRecordConfirmation == false)
        #expect(state.reviewCycle?.closedRoundID == nil)
        #expect(state.reviewCycle?.closedBaselineDigest == nil)
        #expect(state.reviewCycle?.closedRegisterDigest == nil)
        #expect(state.reviewCycle?.closedPathDecision == nil)
        #expect(state.reviewCycle?.lastRemediatedRoundID == nil)
        #expect(state.reviewCycle?.confirmationReceiptID == nil)
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

func reviewGateState(
    runID: RunID = workflowTestRunID,
    gate: ReviewGateKind = .requirements
) throws -> RunState {
    var state = try RunState.startEngineering(
        runID: runID,
        workItemID: "IIS-0002",
        mode: .auto,
        canonSnapshotDigest: workflowTestDigest("a")
    )
    state.stage = switch gate {
    case .requirements: .requirementGate
    case .design: .designGate
    case .architecture: .architectureGate
    case .plan: .planGate
    case .checkpoint: .checkpoint
    case .review: .review
    case .final: .finalGate
    }
    return state
}

func reviewRoundInput(for baseline: ReviewBaseline) throws -> ReviewRoundInput {
    switch baseline.kind {
    case .initial:
        return try .initial(
            gate: baseline.gate,
            cycleOrdinal: #require(baseline.cycleOrdinal),
            preFreezeEventHead: baseline.preCreationEventHead,
            redactionPolicy: baseline.redactionPolicy
        )
    case .normalConfirmation, .exception:
        return try .later(
            cycleID: baseline.cycleID,
            gate: baseline.gate,
            kind: baseline.kind,
            semanticOrdinal: baseline.semanticOrdinal,
            roundAnchorEventHead: baseline.preCreationEventHead,
            predecessorBaselineDigest: #require(baseline.predecessorBaselineDigest),
            redactionPolicy: baseline.redactionPolicy
        )
    }
}

func verifiedReviewClosure(
    _ scenario: LaneBReviewScenario
) throws -> VerifiedReviewRoundClosureFact {
    try ReviewRoundClosureVerifier.verify(
        register: scenario.verifiedRegister,
        currentness: scenario.currentness
    )
}

func reduceReview(
    _ state: RunState,
    event: WorkflowEvent,
    head: HashDigest,
    baseline: HashDigest? = nil,
    closureFact: VerifiedReviewRoundClosureFact? = nil
) throws -> RunState {
    let context: TransitionContext
    if let closureFact {
        context = try TransitionContext(
            actorID: ActorID(validating: "author"),
            principalID: PrincipalID(validating: "principal"),
            currentEventHead: head,
            currentReviewBaselineDigest: baseline,
            satisfiedGuards: [],
            verifiedReviewRoundClosure: closureFact
        )
    } else {
        context = try engineeringContext(
            currentEventHead: head,
            currentReviewBaselineDigest: baseline
        )
    }
    return try WorkflowReducer().decide(
        definition: EngineeringWorkflow.definition,
        state: state,
        event: event,
        context: context
    ).proposedState
}

func directlyConvergedReview(
    _ state: RunState,
    gate: ReviewGateKind,
    cycleOrdinal: UInt64,
    prefix: String
) throws -> RunState {
    let head = try workflowTestDigest("1")
    let scenario = try LaneBReviewScenario.make(
        acceptedCurrentScope: false,
        runID: state.runID,
        gate: gate,
        cycleOrdinal: cycleOrdinal,
        preFreezeEventHead: head,
        activeProfileDigest: state.canonSnapshotDigest
    )
    let closure = try verifiedReviewClosure(scenario)
    var state = try reduceReview(
        state,
        event: WorkflowEvent(
            id: "\(prefix)-freeze",
            kind: .reviewBaselineFrozen,
            reviewRound: reviewRoundInput(for: scenario.baseline)
        ),
        head: head
    )
    state = try reduceReview(
        state,
        event: WorkflowEvent(id: "\(prefix)-inventory-closed", kind: .reviewInventoryClosed),
        head: scenario.currentness.currentEventHead,
        baseline: scenario.baseline.digest,
        closureFact: closure
    )
    return try reduceReview(
        state,
        event: WorkflowEvent(id: "\(prefix)-converged", kind: .reviewConverged),
        head: try workflowTestDigest("3")
    )
}
