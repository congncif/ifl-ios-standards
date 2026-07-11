import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("ReleaseTransitionTests")
struct ReleaseTransitionTests {
    @Test("plugin release uses the six closed event wire values")
    func releaseEventWireValues() throws {
        let expectations: [(WorkflowEventKind, String)] = [
            (.candidateSubmitted, "candidate_submitted"),
            (.releaseChecksPassed, "release_checks_passed"),
            (.releaseChecksFailed, "release_checks_failed"),
            (.productReleaseApproved, "product_release_approved"),
            (.releaseChangesRequired, "release_changes_required"),
            (.closeQualification, "close_qualification"),
        ]
        for (kind, rawValue) in expectations {
            #expect(kind.rawValue == rawValue)
            #expect(WorkflowEventKind(rawValue: rawValue) == kind)
        }
    }

    @Test("release generation starts at one and advances through qualification")
    func releaseHappyPath() throws {
        var state = try releaseStartState()
        #expect(state.candidateGenerationID?.rawValue == 1)
        #expect(state.stage == .candidateAssembly)

        let path: [(WorkflowEventKind, WorkflowStage, RunStatus)] = [
            (.candidateSubmitted, .releaseVerification, .running),
            (.releaseChecksPassed, .productReleaseGate, .running),
            (.productReleaseApproved, .readyForExternalReleaseEffect, .running),
            (.closeQualification, .readyForExternalReleaseEffect, .completed),
        ]
        for (index, step) in path.enumerated() {
            state = try reduceRelease(
                state,
                event: WorkflowEvent(
                    id: "release-happy-\(index)",
                    kind: step.0,
                    candidateGenerationID: try requiredGeneration(state)
                )
            )
            #expect(state.stage == step.1)
            #expect(state.status == step.2)
        }
    }

    @Test("release events reject generation zero and a stale generation")
    func releaseGenerationValidation() throws {
        let zeroEvent = Data(
            """
            {"candidate_generation_id":0,"id":"zero-generation","kind":"candidate_submitted","schema_version":1}
            """.utf8
        )
        #expect(throws: Error.self) {
            try CanonicalJSON.decode(WorkflowEvent.self, from: zeroEvent)
        }

        let state = try releaseStartState()
        let stale = try CandidateGenerationID(validating: 2)
        #expect(throws: WorkflowError.staleCandidateGeneration) {
            try reduceRelease(
                state,
                event: WorkflowEvent(
                    id: "stale-candidate",
                    kind: .candidateSubmitted,
                    candidateGenerationID: stale
                )
            )
        }
    }

    @Test("each invalidation advances once and preserves inactive generations")
    func invalidationIsIdempotent() throws {
        var state = try releaseStartState()
        let generationOne = try #require(state.candidateGenerationID)
        state = try reduceRelease(
            state,
            event: WorkflowEvent(
                id: "submit-one",
                kind: .candidateSubmitted,
                candidateGenerationID: generationOne
            )
        )
        let failed = try WorkflowEvent(
            id: "checks-failed-one",
            kind: .releaseChecksFailed,
            candidateGenerationID: generationOne
        )
        state = try reduceRelease(state, event: failed)
        #expect(state.candidateGenerationID?.rawValue == 2)
        #expect(state.inactiveCandidateGenerationIDs.map(\.rawValue) == [1])
        #expect(state.stage == .candidateAssembly)

        let replay = try reduceRelease(state, event: failed)
        #expect(replay == state)
        #expect(replay.candidateGenerationID?.rawValue == 2)
        #expect(replay.inactiveCandidateGenerationIDs.map(\.rawValue) == [1])

        let generationTwo = try #require(state.candidateGenerationID)
        state = try reduceRelease(
            state,
            event: WorkflowEvent(
                id: "input-invalidated-two",
                kind: .candidateInputInvalidated,
                candidateGenerationID: generationTwo
            )
        )
        #expect(state.candidateGenerationID?.rawValue == 3)
        #expect(state.inactiveCandidateGenerationIDs.map(\.rawValue) == [1, 2])
    }

    @Test("candidate generation overflow fails instead of wrapping")
    func generationOverflowFailsSafely() throws {
        let maximum = try CandidateGenerationID(validating: UInt64.max)
        var state = try releaseStartState()
        state.candidateGenerationID = maximum

        #expect(throws: ContractError.self) {
            try reduceRelease(
                state,
                event: WorkflowEvent(
                    id: "maximum-invalidated",
                    kind: .candidateInputInvalidated,
                    candidateGenerationID: maximum
                )
            )
        }
    }

    @Test("ready release allows only current-generation qualification E1 targets")
    func releaseEffectAllowlist() throws {
        let ready = try readyReleaseState()
        let generation = try #require(ready.candidateGenerationID)
        let allowedTargets = [
            ReleaseEffectTarget.qualificationPayload,
            .finalQualificationManifest,
            .finalQualificationSignature,
            .distributionSHA256Sums,
            .terminalReport,
        ]

        for target in allowedTargets {
            #expect(
                PluginReleaseWorkflow.allows(
                    ReleaseEffectRequest(
                        effectClass: .e1,
                        target: target,
                        candidateGenerationID: generation
                    ),
                    in: ready
                )
            )
        }

        let nextGeneration = try generation.next()
        #expect(!PluginReleaseWorkflow.allows(
            ReleaseEffectRequest(
                effectClass: .e1,
                target: .qualificationPayload,
                candidateGenerationID: nextGeneration
            ),
            in: ready
        ))
        #expect(!PluginReleaseWorkflow.allows(
            ReleaseEffectRequest(
                effectClass: .e1,
                target: try ReleaseEffectTarget(validating: "unrelated-local-write"),
                candidateGenerationID: generation
            ),
            in: ready
        ))
        for effectClass in [EffectClass.e2, .e3] {
            #expect(!PluginReleaseWorkflow.allows(
                ReleaseEffectRequest(
                    effectClass: effectClass,
                    target: .qualificationPayload,
                    candidateGenerationID: generation
                ),
                in: ready
            ))
        }

        let completed = try reduceRelease(
            ready,
            event: WorkflowEvent(
                id: "close-for-effect-test",
                kind: .closeQualification,
                candidateGenerationID: generation
            )
        )
        #expect(!PluginReleaseWorkflow.allows(
            ReleaseEffectRequest(
                effectClass: .e1,
                target: .terminalReport,
                candidateGenerationID: generation
            ),
            in: completed
        ))
    }

    @Test("R-02.1-004 plugin release definition contains and executes all six guarded rows")
    func completeReleaseDefinitionAndRows() throws {
        #expect(PluginReleaseWorkflow.definition.transitions == [
            .init(from: .candidateAssembly, event: .candidateSubmitted, to: .releaseVerification),
            .init(from: .releaseVerification, event: .releaseChecksPassed, to: .productReleaseGate),
            .init(from: .releaseVerification, event: .releaseChecksFailed, to: .candidateAssembly),
            .init(
                from: .productReleaseGate,
                event: .productReleaseApproved,
                to: .readyForExternalReleaseEffect
            ),
            .init(from: .productReleaseGate, event: .releaseChangesRequired, to: .candidateAssembly),
            .init(
                from: .readyForExternalReleaseEffect,
                event: .closeQualification,
                to: .readyForExternalReleaseEffect
            ),
        ])

        var state = try releaseStartState()
        let generationOne = try requiredGeneration(state)
        state = try reduceReleaseExactly(
            state,
            event: WorkflowEvent(
                id: "six-submit-one",
                kind: .candidateSubmitted,
                candidateGenerationID: generationOne
            )
        )
        let failed = try WorkflowEvent(
            id: "six-failed-one",
            kind: .releaseChecksFailed,
            candidateGenerationID: generationOne
        )
        state = try reduceReleaseExactly(state, event: failed)
        #expect(state.stage == .candidateAssembly)
        #expect(state.candidateGenerationID?.rawValue == 2)
        #expect(try reduceReleaseExactly(state, event: failed) == state)

        #expect(throws: WorkflowError.eventIDCollision) {
            try reduceReleaseExactly(
                state,
                event: WorkflowEvent(
                    id: failed.id,
                    kind: .releaseChecksFailed,
                    candidateGenerationID: try CandidateGenerationID(validating: 2)
                )
            )
        }

        let generationTwo = try requiredGeneration(state)
        state = try reduceReleaseExactly(
            state,
            event: WorkflowEvent(
                id: "six-submit-two",
                kind: .candidateSubmitted,
                candidateGenerationID: generationTwo
            )
        )
        state = try reduceReleaseExactly(
            state,
            event: WorkflowEvent(
                id: "six-pass-two",
                kind: .releaseChecksPassed,
                candidateGenerationID: generationTwo
            )
        )
        state = try reduceReleaseExactly(
            state,
            event: WorkflowEvent(
                id: "six-changes-two",
                kind: .releaseChangesRequired,
                candidateGenerationID: generationTwo
            )
        )
        #expect(state.stage == .candidateAssembly)
        #expect(state.candidateGenerationID?.rawValue == 3)

        let generationThree = try requiredGeneration(state)
        let submitThree = try WorkflowEvent(
            id: "six-submit-three",
            kind: .candidateSubmitted,
            candidateGenerationID: generationThree
        )
        #expect(throws: WorkflowError.missingGuard) {
            try WorkflowReducer().decide(
                definition: PluginReleaseWorkflow.definition,
                state: state,
                event: submitThree,
                context: transitionContext(guards: [])
            )
        }
        #expect(throws: WorkflowError.missingGuard) {
            try WorkflowReducer().decide(
                definition: PluginReleaseWorkflow.definition,
                state: state,
                event: submitThree,
                context: transitionContext(guards: [.candidateSubmitted, .releaseChecksPassed])
            )
        }
        let stale = try WorkflowEvent(
            id: "six-stale",
            kind: .candidateSubmitted,
            candidateGenerationID: generationTwo
        )
        #expect(throws: WorkflowError.staleCandidateGeneration) {
            try reduceReleaseExactly(state, event: stale)
        }
    }
}

func releaseStartState() throws -> RunState {
    try RunState.startPluginRelease(
        runID: workflowTestRunID,
        workItemID: "IIS-0002",
        mode: .auto,
        canonSnapshotDigest: workflowTestDigest("a")
    )
}

func releaseContext() throws -> TransitionContext {
    try TransitionContext(
        actorID: ActorID(validating: "release-actor"),
        principalID: PrincipalID(validating: "release-principal"),
        currentEventHead: workflowTestDigest("b"),
        satisfiedGuards: []
    )
}

func reduceRelease(_ state: RunState, event: WorkflowEvent) throws -> RunState {
    try WorkflowReducer().decide(
        definition: PluginReleaseWorkflow.definition,
        state: state,
        event: event,
        context: exactContext(for: event.kind)
    ).proposedState
}

func reduceReleaseExactly(_ state: RunState, event: WorkflowEvent) throws -> RunState {
    try WorkflowReducer().decide(
        definition: PluginReleaseWorkflow.definition,
        state: state,
        event: event,
        context: exactContext(for: event.kind)
    ).proposedState
}

func readyReleaseState() throws -> RunState {
    var state = try releaseStartState()
    for (index, kind) in [
        WorkflowEventKind.candidateSubmitted,
        .releaseChecksPassed,
        .productReleaseApproved,
    ].enumerated() {
        state = try reduceRelease(
            state,
            event: WorkflowEvent(
                id: "ready-release-\(index)",
                kind: kind,
                candidateGenerationID: try requiredGeneration(state)
            )
        )
    }
    return state
}

func requiredGeneration(_ state: RunState) throws -> CandidateGenerationID {
    guard let generation = state.candidateGenerationID else {
        throw WorkflowError.invalidState
    }
    return generation
}
