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
                  cycle.phase == .converged,
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
        if event.kind == .reviewExceptionOpened || event.reviewRound?.kind == .exception {
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
                      cycle.didRecordRemediation
                else { throw WorkflowError.missingRemediation }
                let expectedOrdinal = try incrementChecked(cycle.currentSemanticOrdinal)
                guard input.cycleID == cycle.id,
                      input.gate == cycle.gate,
                      input.semanticOrdinal == expectedOrdinal,
                      input.semanticOrdinal == 1,
                      input.predecessorBaselineDigest == context.currentReviewBaselineDigest,
                      input.redactionPolicy == cycle.redactionPolicy
                else { throw WorkflowError.invalidReviewRound }
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
            guard proposed.reviewCycle?.phase == .collectingInitial else {
                throw WorkflowError.illegalTransition
            }
        case .reviewInventoryClosed:
            guard var cycle = proposed.reviewCycle,
                  cycle.phase == .collectingInitial
            else { throw WorkflowError.illegalTransition }
            cycle.phase = .awaitingRemediation
            proposed.reviewCycle = cycle
        case .reviewRemediationRecorded:
            guard var cycle = proposed.reviewCycle,
                  cycle.phase == .awaitingRemediation,
                  !cycle.didRecordRemediation
            else { throw WorkflowError.illegalTransition }
            cycle.didRecordRemediation = true
            proposed.reviewCycle = cycle
        case .reviewConfirmationRecorded:
            guard var cycle = proposed.reviewCycle,
                  cycle.phase == .collectingNormalConfirmation,
                  !cycle.didRecordConfirmation
            else { throw WorkflowError.illegalTransition }
            cycle.didRecordConfirmation = true
            proposed.reviewCycle = cycle
        case .reviewConverged:
            guard var cycle = proposed.reviewCycle else {
                throw WorkflowError.illegalTransition
            }
            let isDirect = cycle.phase == .awaitingRemediation && !cycle.didRecordRemediation
            let isConfirmed = cycle.phase == .collectingNormalConfirmation && cycle.didRecordConfirmation
            guard isDirect || isConfirmed else { throw WorkflowError.illegalTransition }
            cycle.phase = .converged
            proposed.reviewCycle = cycle
        case .reviewInvalidated:
            guard var cycle = proposed.reviewCycle,
                  cycle.phase != .invalidated
            else { throw WorkflowError.illegalTransition }
            proposed.nextReviewCycleOrdinal = try incrementChecked(cycle.cycleOrdinal)
            cycle.phase = .invalidated
            proposed.reviewCycle = cycle
        case .reviewExceptionOpened:
            throw WorkflowError.exceptionPolicyRequired
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
