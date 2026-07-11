import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("TerminalInvariantTests")
struct TerminalInvariantTests {
    @Test("global controls hold and resume at the same stage")
    func globalControlStatuses() throws {
        var state = try RunState.startEngineering(
            runID: workflowTestRunID,
            workItemID: "IIS-0002",
            mode: .coWorking,
            canonSnapshotDigest: workflowTestDigest("a")
        )
        let path: [(WorkflowEventKind, RunStatus)] = [
            (.pause, .paused),
            (.resume, .running),
            (.waitForUser, .waitingForUser),
            (.userInputReceived, .running),
            (.block, .blocked),
            (.blockerResolved, .running),
        ]
        for (index, step) in path.enumerated() {
            let priorStage = state.stage
            state = try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: state,
                event: WorkflowEvent(id: "global-control-\(index)", kind: step.0),
                context: engineeringContext()
            ).proposedState
            #expect(state.stage == priorStage)
            #expect(state.status == step.1)
        }
    }

    @Test("completed is valid only at the work-type-specific terminal stage")
    func completedPairIsWorkTypeSpecific() {
        #expect(RunState.isValidStageStatusPair(
            workType: .engineeringRun,
            stage: .readyForHandoff,
            status: .completed
        ))
        #expect(RunState.isValidStageStatusPair(
            workType: .pluginRelease,
            stage: .readyForExternalReleaseEffect,
            status: .completed
        ))
        #expect(!RunState.isValidStageStatusPair(
            workType: .engineeringRun,
            stage: .review,
            status: .completed
        ))
        #expect(!RunState.isValidStageStatusPair(
            workType: .pluginRelease,
            stage: .productReleaseGate,
            status: .completed
        ))
        #expect(RunState.isValidStageStatusPair(
            workType: .engineeringRun,
            stage: .review,
            status: .running
        ))
    }

    @Test("completed engineering run rejects every later transition")
    func completedEngineeringIsImmutable() throws {
        let completed = try completedEngineeringState()
        #expect(completed.stage == .readyForHandoff)
        #expect(completed.status == .completed)
        #expect(completed.isTerminal)

        #expect(throws: WorkflowError.terminalState) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: completed,
                event: WorkflowEvent(id: "after-engineering-close", kind: .closeRun),
                context: engineeringContext()
            )
        }
    }

    @Test("completed qualification cannot be reopened or authorize another write")
    func completedReleaseIsImmutable() throws {
        let ready = try readyReleaseState()
        let generation = try requiredGeneration(ready)
        let completed = try reduceRelease(
            ready,
            event: WorkflowEvent(
                id: "terminal-close-qualification",
                kind: .closeQualification,
                candidateGenerationID: generation
            )
        )

        #expect(throws: WorkflowError.terminalState) {
            try reduceRelease(
                completed,
                event: WorkflowEvent(
                    id: "terminal-input-change",
                    kind: .candidateInputInvalidated,
                    candidateGenerationID: generation
                )
            )
        }
        #expect(!PluginReleaseWorkflow.allows(
            ReleaseEffectRequest(
                effectClass: .e1,
                target: .qualificationPayload,
                candidateGenerationID: generation
            ),
            in: completed
        ))

        let replacementRunID = RunID(
            rawValue: UUID(uuidString: "28b71a1e-d066-42ff-b324-a3295db301d2")!
        )
        let replacement = try RunState.startPluginRelease(
            runID: replacementRunID,
            workItemID: "IIS-0002",
            mode: .auto,
            canonSnapshotDigest: workflowTestDigest("a")
        )
        #expect(replacement.runID != completed.runID)
        #expect(replacement.candidateGenerationID?.rawValue == 1)
    }

    @Test("cancelled and failed runs are terminal at their last stage")
    func controlTerminalsAreImmutable() throws {
        let engineering = try RunState.startEngineering(
            runID: workflowTestRunID,
            workItemID: "IIS-0002",
            mode: .coWorking,
            canonSnapshotDigest: workflowTestDigest("a")
        )
        let cancelled = try WorkflowReducer().decide(
            definition: EngineeringWorkflow.definition,
            state: engineering,
            event: WorkflowEvent(id: "cancel-run", kind: .cancel),
            context: engineeringContext()
        ).proposedState
        #expect(cancelled.stage == .intake)
        #expect(cancelled.status == .cancelled)
        #expect(throws: WorkflowError.terminalState) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: cancelled,
                event: WorkflowEvent(id: "resume-cancelled", kind: .resume),
                context: engineeringContext()
            )
        }

        let release = try releaseStartState()
        let failed = try WorkflowReducer().decide(
            definition: PluginReleaseWorkflow.definition,
            state: release,
            event: WorkflowEvent(id: "fail-release", kind: .fail),
            context: releaseContext()
        ).proposedState
        #expect(failed.stage == .candidateAssembly)
        #expect(failed.status == .failed)
        #expect(throws: WorkflowError.terminalState) {
            try WorkflowReducer().decide(
                definition: PluginReleaseWorkflow.definition,
                state: failed,
                event: WorkflowEvent(id: "resume-failed", kind: .resume),
                context: releaseContext()
            )
        }
    }

    @Test("an invalid completed pair is rejected before event processing")
    func invalidCompletedPairIsRejected() throws {
        var invalid = try RunState.startEngineering(
            runID: workflowTestRunID,
            workItemID: "IIS-0002",
            mode: .auto,
            canonSnapshotDigest: workflowTestDigest("a")
        )
        invalid.status = .completed

        #expect(throws: WorkflowError.invalidState) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: invalid,
                event: WorkflowEvent(id: "invalid-completed", kind: .intakeRecorded),
                context: engineeringContext()
            )
        }
    }

    @Test("R-02.1-002 resolves exact and colliding replays before terminal rejection")
    func terminalReplayPrecedence() throws {
        let engineering = try completedEngineeringState()
        let exactEngineering = try WorkflowEvent(
            id: "terminal-engineering-14",
            kind: .closeRun
        )
        let replayedEngineering = try WorkflowReducer().decide(
            definition: EngineeringWorkflow.definition,
            state: engineering,
            event: exactEngineering,
            context: engineeringContext()
        ).proposedState
        #expect(replayedEngineering == engineering)

        #expect(throws: WorkflowError.eventIDCollision) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: engineering,
                event: WorkflowEvent(id: exactEngineering.id, kind: .runApproved),
                context: engineeringContext()
            )
        }

        let ready = try readyReleaseState()
        let generation = try requiredGeneration(ready)
        let close = try WorkflowEvent(
            id: "terminal-release-replay",
            kind: .closeQualification,
            candidateGenerationID: generation
        )
        let completed = try reduceRelease(ready, event: close)
        #expect(try reduceRelease(completed, event: close) == completed)

        #expect(throws: WorkflowError.eventIDCollision) {
            try reduceRelease(
                completed,
                event: WorkflowEvent(
                    id: close.id,
                    kind: .closeQualification,
                    candidateGenerationID: generation.next()
                )
            )
        }
    }

    @Test("R-02.1-002 ordinary events cannot advance any held run")
    func heldRunsRejectOrdinaryProgress() throws {
        let controls: [(WorkflowEventKind, RunStatus)] = [
            (.pause, .paused),
            (.waitForUser, .waitingForUser),
            (.block, .blocked),
        ]
        for (index, control) in controls.enumerated() {
            let running = try RunState.startEngineering(
                runID: workflowTestRunID,
                workItemID: "IIS-0002",
                mode: .auto,
                canonSnapshotDigest: workflowTestDigest("a")
            )
            let held = try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: running,
                event: WorkflowEvent(id: "held-control-\(index)", kind: control.0),
                context: engineeringContext()
            ).proposedState
            #expect(held.status == control.1)
            #expect(throws: WorkflowError.illegalTransition) {
                try WorkflowReducer().decide(
                    definition: EngineeringWorkflow.definition,
                    state: held,
                    event: WorkflowEvent(id: "held-progress-\(index)", kind: .intakeRecorded),
                    context: engineeringContext()
                )
            }
        }
    }
}

func completedEngineeringState() throws -> RunState {
    var state = try RunState.startEngineering(
        runID: workflowTestRunID,
        workItemID: "IIS-0002",
        mode: .auto,
        canonSnapshotDigest: workflowTestDigest("a")
    )
    let events: [WorkflowEventKind] = [
        .intakeRecorded,
        .requirementsSubmitted,
        .requirementApproved,
        .designSubmitted,
        .designApproved,
        .architectureSubmitted,
        .architectureApproved,
        .planSubmitted,
        .planApproved,
        .phaseSubmitted,
        .checkpointPassed,
        .reviewApproved,
        .runChecksPassed,
        .runApproved,
        .closeRun,
    ]
    for (index, kind) in events.enumerated() {
        if let gate = ReviewGateKind.findingProducingGate(for: state.stage) {
            state = try directlyConvergedReview(
                state,
                gate: gate,
                cycleOrdinal: state.nextReviewCycleOrdinal,
                prefix: "terminal-engineering-\(index)-gate"
            )
        }
        state = try WorkflowReducer().decide(
            definition: EngineeringWorkflow.definition,
            state: state,
            event: WorkflowEvent(id: "terminal-engineering-\(index)", kind: kind),
            context: exactContext(for: kind)
        ).proposedState
    }
    return state
}
