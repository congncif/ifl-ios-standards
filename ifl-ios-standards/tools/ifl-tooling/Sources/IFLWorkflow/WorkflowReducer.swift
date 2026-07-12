import IFLContracts

public protocol WorkflowReducing: Sendable {
    func decide(
        definition: WorkflowDefinition,
        state: RunState,
        event: WorkflowEvent,
        context: TransitionContext
    ) throws -> TransitionDecision
}

public struct WorkflowReducer: WorkflowReducing, Sendable {
    public init() {}

    public func decide(
        definition: WorkflowDefinition,
        state: RunState,
        event: WorkflowEvent,
        context: TransitionContext
    ) throws -> TransitionDecision {
        try definition.validateCanonical(for: state.workType)
        guard state.hasValidTerminalPair else { throw WorkflowError.invalidState }

        let eventDigest = CanonicalTreeDigest.sha256(try CanonicalJSON.encode(event))
        if let prior = state.processedEvents.first(where: { $0.id == event.id }) {
            guard prior.kind == event.kind,
                  prior.candidateGenerationID == event.candidateGenerationID,
                  prior.eventDigest == eventDigest
            else { throw WorkflowError.eventIDCollision }
            return TransitionDecision(proposedState: state, reasonCode: "idempotent_replay")
        }
        guard !state.isTerminal else { throw WorkflowError.terminalState }
        guard context.verifiedReviewExceptionAdmission == nil ||
            event.kind == .reviewExceptionOpened
        else {
            throw WorkflowError.invalidExceptionProof
        }
        guard context.verifiedReviewRoundClosure == nil ||
                event.kind == .reviewInventoryClosed
        else { throw WorkflowError.invalidReviewRound }

        if event.kind.isGlobalControlEvent {
            return try decideGlobalControl(state: state, event: event, context: context)
        }

        guard state.status == .running else { throw WorkflowError.illegalTransition }

        if event.kind.isReviewEvent {
            return try decideReview(state: state, event: event, context: context)
        }
        if state.workType == .pluginRelease {
            return try decideRelease(
                definition: definition,
                state: state,
                event: event,
                context: context
            )
        }

        guard state.workType == .engineeringRun,
              event.candidateGenerationID == nil,
              let requiredGuard = event.kind.requiredGuard,
              context.satisfiedGuards == [requiredGuard]
        else { throw WorkflowError.missingGuard }

        let destination: WorkflowStage?
        if state.stage == .checkpoint,
           event.kind == .checkpointPassed,
           context.hasRemainingExecutionPhases {
            destination = .executePhase
        } else {
            destination = definition.destination(from: state.stage, for: event.kind)
        }
        guard let destination else { throw WorkflowError.illegalTransition }

        var proposed = state
        if let requiredGate = ReviewGateKind.findingProducingGate(for: state.stage) {
            guard let cycle = state.reviewCycle,
                  cycle.gate == requiredGate,
                  cycle.hasVerifiedTerminalConvergence,
                  cycle.cycleOrdinal == state.nextReviewCycleOrdinal
            else { throw WorkflowError.illegalTransition }
            proposed.nextReviewCycleOrdinal = try incrementChecked(state.nextReviewCycleOrdinal)
            proposed.reviewCycle = nil
        }
        proposed.stage = destination
        if event.kind == .closeRun {
            proposed.status = .completed
        }
        proposed.processedEvents.append(
            try ProcessedWorkflowEvent(recording: event)
        )
        guard proposed.hasValidTerminalPair else { throw WorkflowError.invalidState }
        return TransitionDecision(proposedState: proposed, reasonCode: event.kind.rawValue)
    }

    private func decideGlobalControl(
        state: RunState,
        event: WorkflowEvent,
        context: TransitionContext
    ) throws -> TransitionDecision {
        guard event.candidateGenerationID == nil,
              event.reviewRound == nil,
              context.satisfiedGuards.isEmpty
        else { throw WorkflowError.missingGuard }

        var proposed = state
        switch (state.status, event.kind) {
        case (.running, .pause):
            proposed.status = .paused
        case (.paused, .resume):
            proposed.status = .running
        case (.running, .waitForUser):
            proposed.status = .waitingForUser
        case (.waitingForUser, .userInputReceived):
            proposed.status = .running
        case (.running, .block):
            proposed.status = .blocked
        case (.blocked, .blockerResolved):
            proposed.status = .running
        case (_, .cancel):
            proposed.status = .cancelled
        case (_, .fail):
            proposed.status = .failed
        default:
            throw WorkflowError.illegalTransition
        }

        proposed.processedEvents.append(
            try ProcessedWorkflowEvent(recording: event)
        )
        return TransitionDecision(proposedState: proposed, reasonCode: event.kind.rawValue)
    }

    private func decideRelease(
        definition: WorkflowDefinition,
        state: RunState,
        event: WorkflowEvent,
        context: TransitionContext
    ) throws -> TransitionDecision {
        guard event.kind.isReleaseEvent else { throw WorkflowError.illegalTransition }
        guard let currentGeneration = state.candidateGenerationID,
              event.candidateGenerationID == currentGeneration
        else { throw WorkflowError.staleCandidateGeneration }
        guard let requiredGuard = event.kind.requiredGuard,
              context.satisfiedGuards == [requiredGuard]
        else { throw WorkflowError.missingGuard }

        var proposed = state
        switch event.kind {
        case .releaseChecksFailed:
            guard definition.destination(from: state.stage, for: event.kind) == .candidateAssembly else {
                throw WorkflowError.illegalTransition
            }
            try invalidateCurrentGeneration(in: &proposed)
        case .releaseChangesRequired:
            guard definition.destination(from: state.stage, for: event.kind) == .candidateAssembly else {
                throw WorkflowError.illegalTransition
            }
            try invalidateCurrentGeneration(in: &proposed)
        case .candidateInputInvalidated:
            try invalidateCurrentGeneration(in: &proposed)
        default:
            guard let destination = definition.destination(from: state.stage, for: event.kind) else {
                throw WorkflowError.illegalTransition
            }
            proposed.stage = destination
            if event.kind == .closeQualification {
                proposed.status = .completed
            }
        }

        proposed.processedEvents.append(
            try ProcessedWorkflowEvent(recording: event)
        )
        guard proposed.hasValidTerminalPair else { throw WorkflowError.invalidState }
        return TransitionDecision(proposedState: proposed, reasonCode: event.kind.rawValue)
    }

    private func invalidateCurrentGeneration(in state: inout RunState) throws {
        guard let current = state.candidateGenerationID else {
            throw WorkflowError.invalidState
        }
        let next = try current.next()
        state.inactiveCandidateGenerationIDs.append(current)
        state.candidateGenerationID = next
        state.stage = .candidateAssembly
        state.status = .running
    }

    private func decideReview(
        state: RunState,
        event: WorkflowEvent,
        context: TransitionContext
    ) throws -> TransitionDecision {
        guard state.workType == .engineeringRun else {
            throw WorkflowError.reviewCycleNotAllowed
        }
        guard context.satisfiedGuards.isEmpty else { throw WorkflowError.missingGuard }
        if event.reviewRound?.kind == .exception {
            throw WorkflowError.exceptionPolicyRequired
        }

        var proposed = state
        switch event.kind {
        case .reviewBaselineFrozen:
            guard let input = event.reviewRound else { throw WorkflowError.invalidReviewRound }
            let admittedGate = try ReviewGateKind.admit(
                stage: state.stage,
                workType: state.workType,
                evidenceKind: .findingProducingReview
            )
            guard admittedGate == input.gate,
                  input.roundAnchorEventHead == context.currentEventHead
            else { throw WorkflowError.invalidReviewRound }

            switch input.kind {
            case .initial:
                let existingCycle = state.reviewCycle
                let canReplace = existingCycle == nil || existingCycle?.phase == .invalidated
                guard canReplace,
                      let cycleOrdinal = input.cycleOrdinal,
                      cycleOrdinal == state.nextReviewCycleOrdinal,
                      input.cycleID == nil,
                      input.semanticOrdinal == 0,
                      input.predecessorBaselineDigest == nil
                else { throw WorkflowError.invalidReviewRound }
                if let existingCycle {
                    guard existingCycle.gate == input.gate else {
                        throw WorkflowError.invalidReviewRound
                    }
                }
                let cycleID = try ReviewCycleID.derive(
                    runID: state.runID,
                    gate: input.gate,
                    cycleOrdinal: cycleOrdinal,
                    preFreezeEventHead: input.roundAnchorEventHead
                )
                let roundID = try ReviewRoundID.derive(
                    runID: state.runID,
                    gate: input.gate,
                    cycleID: cycleID,
                    kind: .initial,
                    semanticOrdinal: 0,
                    roundAnchorEventHead: input.roundAnchorEventHead,
                    predecessorBaselineDigest: nil
                )
                proposed.reviewCycle = try ReviewCycleState(
                    id: cycleID,
                    gate: input.gate,
                    cycleOrdinal: cycleOrdinal,
                    phase: .collectingInitial,
                    currentRoundID: roundID,
                    currentRoundKind: .initial,
                    currentSemanticOrdinal: 0,
                    didRecordRemediation: false,
                    didRecordConfirmation: false,
                    redactionPolicy: input.redactionPolicy,
                    cyclePreFreezeEventHead: input.roundAnchorEventHead,
                    currentRoundAnchorEventHead: input.roundAnchorEventHead,
                    predecessorBaselineDigest: nil
                )
            case .normalConfirmation:
                guard var cycle = state.reviewCycle,
                      cycle.phase == .awaitingRemediation,
                      cycle.currentRoundKind == .initial,
                      cycle.hasVerifiedCurrentRoundClosure,
                      cycle.closedPathDecision == .requiresRemediation,
                      cycle.lastRemediatedRoundID == cycle.currentRoundID,
                      cycle.confirmationReceiptID == nil,
                      let closedBaselineDigest = cycle.closedBaselineDigest
                else { throw WorkflowError.missingRemediation }
                let expectedOrdinal = try incrementChecked(cycle.currentSemanticOrdinal)
                guard input.cycleID == cycle.id,
                      input.gate == cycle.gate,
                      input.semanticOrdinal == expectedOrdinal,
                      input.semanticOrdinal == 1,
                      input.predecessorBaselineDigest == closedBaselineDigest,
                      context.currentReviewBaselineDigest == closedBaselineDigest,
                      input.redactionPolicy == cycle.redactionPolicy
                else { throw WorkflowError.invalidReviewRound }
                cycle.clearCurrentRoundClosure()
                cycle.currentRoundID = try ReviewRoundID.derive(
                    runID: state.runID,
                    gate: input.gate,
                    cycleID: cycle.id,
                    kind: .normalConfirmation,
                    semanticOrdinal: input.semanticOrdinal,
                    roundAnchorEventHead: input.roundAnchorEventHead,
                    predecessorBaselineDigest: input.predecessorBaselineDigest
                )
                cycle.currentRoundKind = .normalConfirmation
                cycle.currentSemanticOrdinal = input.semanticOrdinal
                cycle.currentRoundAnchorEventHead = input.roundAnchorEventHead
                cycle.predecessorBaselineDigest = input.predecessorBaselineDigest
                cycle.phase = .collectingNormalConfirmation
                proposed.reviewCycle = cycle
            case .exception:
                throw WorkflowError.exceptionPolicyRequired
            }

        case .reviewInventoryRecorded:
            guard let phase = proposed.reviewCycle?.phase,
                  [.collectingInitial, .collectingNormalConfirmation, .collectingException]
                    .contains(phase),
                  proposed.reviewCycle?.closedRoundID == nil
            else {
                throw WorkflowError.illegalTransition
            }
        case .reviewInventoryClosed:
            guard let closure = context.verifiedReviewRoundClosure else {
                throw WorkflowError.invalidReviewRound
            }
            guard var cycle = proposed.reviewCycle,
                  [.collectingInitial, .collectingNormalConfirmation, .collectingException]
                    .contains(cycle.phase),
                  cycle.closedRoundID == nil
            else { throw WorkflowError.illegalTransition }
            guard closure.runID == state.runID,
                  closure.cycleID == cycle.id,
                  closure.gate == cycle.gate,
                  closure.roundID == cycle.currentRoundID,
                  closure.roundKind == cycle.currentRoundKind,
                  closure.semanticOrdinal == cycle.currentSemanticOrdinal,
                  closure.roundAnchorEventHead == cycle.currentRoundAnchorEventHead,
                  closure.predecessorBaselineDigest == cycle.predecessorBaselineDigest,
                  closure.baselineDigest == context.currentReviewBaselineDigest,
                  closure.currentEventHead == context.currentEventHead,
                  closure.activeProfileDigest == state.canonSnapshotDigest,
                  closure.redactionPolicy == cycle.redactionPolicy
            else { throw WorkflowError.invalidReviewRound }
            cycle.installClosure(closure)
            if cycle.currentRoundKind == .initial ||
                closure.pathDecision == .requiresRemediation {
                cycle.phase = .awaitingRemediation
            }
            proposed.reviewCycle = cycle
        case .reviewRemediationRecorded:
            guard var cycle = proposed.reviewCycle,
                  cycle.phase == .awaitingRemediation,
                  cycle.hasVerifiedCurrentRoundClosure,
                  cycle.closedPathDecision == .requiresRemediation,
                  cycle.lastRemediatedRoundID != cycle.currentRoundID
            else { throw WorkflowError.illegalTransition }
            cycle.didRecordRemediation = true
            cycle.lastRemediatedRoundID = cycle.currentRoundID
            proposed.reviewCycle = cycle
        case .reviewConfirmationRecorded:
            guard var cycle = proposed.reviewCycle,
                  cycle.currentRoundKind == .normalConfirmation,
                  [.collectingNormalConfirmation, .awaitingRemediation].contains(cycle.phase),
                  cycle.hasVerifiedCurrentRoundClosure,
                  cycle.confirmationReceiptID == nil
            else { throw WorkflowError.illegalTransition }
            cycle.didRecordConfirmation = true
            cycle.confirmationReceiptID = try ReceiptID(validating: event.id)
            proposed.reviewCycle = cycle
        case .reviewConverged:
            guard var cycle = proposed.reviewCycle else {
                throw WorkflowError.illegalTransition
            }
            guard cycle.hasVerifiedCurrentRoundClosure else {
                throw WorkflowError.illegalTransition
            }
            if cycle.closedPathDecision == .requiresRemediation {
                throw WorkflowError.missingRemediation
            }
            let isDirect = cycle.currentRoundKind == .initial &&
                cycle.phase == .awaitingRemediation &&
                cycle.closedPathDecision == .directConvergenceNoAcceptedCurrentScope
            let isConfirmed = cycle.currentRoundKind == .normalConfirmation &&
                cycle.phase == .collectingNormalConfirmation &&
                cycle.closedPathDecision == .directConvergenceNoAcceptedCurrentScope &&
                cycle.confirmationReceiptID != nil
            let isConfirmedException = cycle.currentRoundKind == .exception &&
                cycle.phase == .collectingException &&
                cycle.closedPathDecision == .directConvergenceNoAcceptedCurrentScope &&
                cycle.confirmationReceiptID != nil
            guard isDirect || isConfirmed || isConfirmedException,
                  cycle.convergenceReceiptID == nil
            else { throw WorkflowError.illegalTransition }
            cycle.convergenceReceiptID = try ReceiptID(validating: event.id)
            cycle.phase = .converged
            proposed.reviewCycle = cycle
        case .reviewInvalidated:
            guard var cycle = proposed.reviewCycle,
                  cycle.phase != .invalidated
            else { throw WorkflowError.illegalTransition }
            proposed.nextReviewCycleOrdinal = try incrementChecked(cycle.cycleOrdinal)
            cycle.phase = .invalidated
            cycle.clearCurrentRoundClosure()
            cycle.lastRemediatedRoundID = nil
            cycle.confirmationReceiptID = nil
            proposed.reviewCycle = cycle
        case .reviewExceptionOpened:
            guard let admission = context.verifiedReviewExceptionAdmission else {
                throw WorkflowError.exceptionPolicyRequired
            }
            let proof = admission.eligibility
            let frozenBudget = admission.frozenBudget
            guard var cycle = proposed.reviewCycle,
                  let closedRoundID = cycle.closedRoundID,
                  let closedBaselineDigest = cycle.closedBaselineDigest,
                  let closedRegisterDigest = cycle.closedRegisterDigest,
                  proof.hasValidDigest,
                  proof.runID == state.runID,
                  proof.cycleID == cycle.id,
                  proof.gate == cycle.gate,
                  cycle.currentRoundKind == .normalConfirmation ||
                    cycle.currentRoundKind == .exception,
                  cycle.phase == .awaitingRemediation,
                  cycle.hasVerifiedCurrentRoundClosure,
                  cycle.closedPathDecision == .requiresRemediation,
                  cycle.lastRemediatedRoundID == cycle.currentRoundID,
                  cycle.confirmationReceiptID != nil,
                  proof.precedingRoundID == closedRoundID,
                  proof.precedingRegisterDigest == closedRegisterDigest,
                  proof.precedingBaselineDigest == closedBaselineDigest,
                  proof.precedingBaselineDigest == context.currentReviewBaselineDigest,
                  admission.remediation.sourceRegister.register.digest == closedRegisterDigest,
                  admission.remediation.sourceRegister.baseline.digest == closedBaselineDigest,
                  admission.successorBaseline.preCreationEventHead ==
                    proof.roundAnchorEventHead,
                  frozenBudget.runID == state.runID,
                  frozenBudget.cycleID == cycle.id,
                  frozenBudget.policyVersion == proof.policyVersion,
                  frozenBudget.policyDigest == proof.budgetDigest,
                  frozenBudget.boundEventHead == proof.roundAnchorEventHead,
                  proof.nextSemanticOrdinal == (try ReviewConvergencePolicy()
                    .nextExceptionSemanticOrdinal(after: cycle.currentSemanticOrdinal)),
                  proof.nextSemanticOrdinal >= 2,
                  proof.remainingExceptionRounds >= 0,
                  proof.policyVersion == 1,
                  !proof.qualifyingFingerprints.isEmpty,
                  Set(proof.qualifyingFingerprints).count == proof.qualifyingFingerprints.count,
                  cycle.didRecordRemediation,
                  cycle.didRecordConfirmation,
                  proof.nextRoundID == (try ReviewRoundID.derive(
                    runID: state.runID,
                    gate: cycle.gate,
                    cycleID: cycle.id,
                    kind: .exception,
                    semanticOrdinal: proof.nextSemanticOrdinal,
                    roundAnchorEventHead: proof.roundAnchorEventHead,
                    predecessorBaselineDigest: proof.precedingBaselineDigest
                  )),
                  proof.nextRoundID == admission.successorBaseline.roundID,
                  proof.nextSemanticOrdinal == admission.successorBaseline.semanticOrdinal,
                  admission.successorBaseline.kind == .exception,
                  admission.successorBaseline.predecessorBaselineDigest ==
                    proof.precedingBaselineDigest
            else { throw WorkflowError.invalidExceptionProof }
            cycle.clearCurrentRoundClosure()
            cycle.phase = .collectingException
            cycle.currentRoundID = admission.successorBaseline.roundID
            cycle.currentRoundKind = .exception
            cycle.currentSemanticOrdinal = admission.successorBaseline.semanticOrdinal
            cycle.currentRoundAnchorEventHead = admission.successorBaseline.preCreationEventHead
            cycle.predecessorBaselineDigest = admission.successorBaseline.predecessorBaselineDigest
            proposed.reviewCycle = cycle
        default:
            throw WorkflowError.illegalTransition
        }

        proposed.processedEvents.append(
            try ProcessedWorkflowEvent(recording: event)
        )
        return TransitionDecision(proposedState: proposed, reasonCode: event.kind.rawValue)
    }

}

private extension WorkflowEventKind {
    var isReviewEvent: Bool {
        switch self {
        case .reviewBaselineFrozen, .reviewInventoryRecorded, .reviewInventoryClosed,
             .reviewRemediationRecorded, .reviewConfirmationRecorded, .reviewExceptionOpened,
             .reviewConverged, .reviewInvalidated:
            true
        default:
            false
        }
    }

    var isReleaseEvent: Bool {
        switch self {
        case .candidateSubmitted, .releaseChecksPassed, .releaseChecksFailed,
             .productReleaseApproved, .releaseChangesRequired, .closeQualification,
             .candidateInputInvalidated:
            true
        default:
            false
        }
    }

    var isGlobalControlEvent: Bool {
        switch self {
        case .pause, .resume, .waitForUser, .userInputReceived, .block,
             .blockerResolved, .cancel, .fail:
            true
        default:
            false
        }
    }
}
