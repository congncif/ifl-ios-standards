import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("EngineeringTransitionTests")
struct EngineeringTransitionTests {
    @Test("workflow state and event schemas are closed canonical v1 contracts")
    func workflowSchemas() throws {
        let state = try workflowSchemaObject("workflow-state.schema.json")
        let event = try workflowSchemaObject("workflow-event.schema.json")

        #expect(state["$id"] as? String == "urn:ifl:standards:schema:workflow-state:v1")
        #expect(event["$id"] as? String == "urn:ifl:standards:schema:workflow-event:v1")
        for schema in [state, event] {
            #expect(schema["$schema"] as? String == "https://json-schema.org/draft/2020-12/schema")
            #expect(schema["type"] as? String == "object")
            #expect(schema["additionalProperties"] as? Bool == false)
            let properties = try #require(schema["properties"] as? [String: Any])
            let schemaVersion = try #require(properties["schema_version"] as? [String: Any])
            #expect(schemaVersion["const"] as? Int == 1)
        }

        let stateProperties = try #require(state["properties"] as? [String: Any])
        let workType = try #require(stateProperties["work_type"] as? [String: Any])
        let status = try #require(stateProperties["status"] as? [String: Any])
        let stage = try #require(stateProperties["stage"] as? [String: Any])
        #expect(Set(workType["enum"] as? [String] ?? []) == Set(WorkType.allCases.map(\.rawValue)))
        #expect(Set(status["enum"] as? [String] ?? []) == Set(RunStatus.allCases.map(\.rawValue)))
        #expect(Set(stage["enum"] as? [String] ?? []) == Set(WorkflowStage.allCases.map(\.rawValue)))

        let eventProperties = try #require(event["properties"] as? [String: Any])
        let eventKind = try #require(eventProperties["kind"] as? [String: Any])
        #expect(Set(eventKind["enum"] as? [String] ?? []) == Set(WorkflowEventKind.allCases.map(\.rawValue)))

        for filename in ["workflow-state.schema.json", "workflow-event.schema.json"] {
            let url = workflowSchemaURL(filename)
            let actual = try Data(contentsOf: url)
            let value = try JSONSerialization.jsonObject(with: actual)
            var canonical = try JSONSerialization.data(
                withJSONObject: value,
                options: [.sortedKeys, .withoutEscapingSlashes]
            )
            canonical.append(0x0A)
            #expect(actual == canonical, "\(filename) must be sorted compact JSON plus one LF")
        }
    }

    @Test("workflow state and event encode with schema wire keys")
    func workflowWireKeys() throws {
        let state = try RunState.startPluginRelease(
            runID: workflowTestRunID,
            workItemID: "IIS-0002",
            mode: .auto,
            canonSnapshotDigest: workflowTestDigest("a")
        )
        let stateObject = try #require(
            JSONSerialization.jsonObject(with: CanonicalJSON.encode(state)) as? [String: Any]
        )
        #expect(stateObject["schema_version"] as? Int == 1)
        #expect(stateObject["run_id"] as? String == workflowTestRunID.filesystemComponent)
        #expect(stateObject["candidate_generation_id"] as? Int == 1)
        #expect(stateObject["schemaVersion"] == nil)

        let event = try WorkflowEvent(
            id: "wire-event",
            kind: .candidateSubmitted,
            candidateGenerationID: try CandidateGenerationID(validating: 1)
        )
        let eventObject = try #require(
            JSONSerialization.jsonObject(with: CanonicalJSON.encode(event)) as? [String: Any]
        )
        #expect(eventObject["schema_version"] as? Int == 1)
        #expect(eventObject["candidate_generation_id"] as? Int == 1)
        #expect(eventObject["candidateGenerationID"] == nil)

        var invalidState = stateObject
        invalidState["status"] = "completed"
        invalidState["stage"] = "product_release_gate"
        #expect(throws: Error.self) {
            try CanonicalJSON.decode(
                RunState.self,
                from: JSONSerialization.data(withJSONObject: invalidState, options: [.sortedKeys])
            )
        }

        var invalidEvent = eventObject
        invalidEvent["schema_version"] = 2
        #expect(throws: Error.self) {
            try CanonicalJSON.decode(
                WorkflowEvent.self,
                from: JSONSerialization.data(withJSONObject: invalidEvent, options: [.sortedKeys])
            )
        }
    }

    @Test("engineering workflow has no gate bypass")
    func engineeringHappyPathStages() {
        #expect(EngineeringWorkflow.definition.stages == [
            .intake, .requirements, .requirementGate, .design, .designGate,
            .architecture, .architectureGate, .plan, .planGate, .executePhase,
            .checkpoint, .review, .finalVerification, .finalGate, .readyForHandoff,
        ])
    }

    @Test("plugin release workflow has the approved four-stage sequence")
    func pluginReleaseStages() {
        #expect(PluginReleaseWorkflow.definition.stages == [
            .candidateAssembly,
            .releaseVerification,
            .productReleaseGate,
            .readyForExternalReleaseEffect,
        ])
    }

    @Test("a caller cannot jump from intake to the plan gate")
    func illegalJumpIsRejected() throws {
        let state = try RunState.startEngineering(
            runID: workflowTestRunID,
            workItemID: "IIS-0002",
            mode: .coWorking,
            canonSnapshotDigest: workflowTestDigest("a")
        )
        let event = try WorkflowEvent(id: "event-plan-jump", kind: .planSubmitted)

        #expect(throws: WorkflowError.illegalTransition) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: state,
                event: event,
                context: try exactContext(for: event.kind)
            )
        }
    }

    @Test("the closed engineering event table reaches handoff without bypassing a gate")
    func engineeringHappyPathReducesDeterministically() throws {
        var state = try RunState.startEngineering(
            runID: workflowTestRunID,
            workItemID: "IIS-0002",
            mode: .auto,
            canonSnapshotDigest: workflowTestDigest("a")
        )
        let path: [(WorkflowEventKind, WorkflowStage)] = [
            (.intakeRecorded, .requirements),
            (.requirementsSubmitted, .requirementGate),
            (.requirementApproved, .design),
            (.designSubmitted, .designGate),
            (.designApproved, .architecture),
            (.architectureSubmitted, .architectureGate),
            (.architectureApproved, .plan),
            (.planSubmitted, .planGate),
            (.planApproved, .executePhase),
            (.phaseSubmitted, .checkpoint),
            (.checkpointPassed, .review),
            (.reviewApproved, .finalVerification),
            (.runChecksPassed, .finalGate),
            (.runApproved, .readyForHandoff),
        ]

        for (index, step) in path.enumerated() {
            if let gate = ReviewGateKind.findingProducingGate(for: state.stage) {
                state = try directlyConvergedReview(
                    state,
                    gate: gate,
                    cycleOrdinal: state.nextReviewCycleOrdinal,
                    prefix: "engineering-\(index)-gate"
                )
            }
            let event = try WorkflowEvent(id: "engineering-\(index)", kind: step.0)
            state = try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: state,
                event: event,
                context: try exactContext(for: event.kind)
            ).proposedState
            #expect(state.stage == step.1)
            #expect(state.status == .running)
        }
    }

    @Test("R-02.1-001 rejects injected and duplicate workflow definitions")
    func canonicalDefinitionCannotBeInjected() throws {
        let state = try RunState.startEngineering(
            runID: workflowTestRunID,
            workItemID: "IIS-0002",
            mode: .auto,
            canonSnapshotDigest: workflowTestDigest("a")
        )
        let event = try WorkflowEvent(id: "definition-injection", kind: .intakeRecorded)
        let injected = WorkflowDefinition(
            workType: .engineeringRun,
            stages: EngineeringWorkflow.definition.stages,
            transitions: [
                .init(from: .intake, event: .intakeRecorded, to: .planGate),
            ]
        )
        #expect(throws: WorkflowError.invalidDefinition) {
            try WorkflowReducer().decide(
                definition: injected,
                state: state,
                event: event,
                context: exactContext(for: .intakeRecorded)
            )
        }

        let duplicate = WorkflowDefinition(
            workType: .engineeringRun,
            stages: EngineeringWorkflow.definition.stages,
            transitions: EngineeringWorkflow.definition.transitions + [
                .init(from: .intake, event: .intakeRecorded, to: .requirements),
            ]
        )
        #expect(throws: WorkflowError.invalidDefinition) {
            try WorkflowReducer().decide(
                definition: duplicate,
                state: state,
                event: event,
                context: exactContext(for: .intakeRecorded)
            )
        }

        let crossWorkType = WorkflowDefinition(
            workType: .engineeringRun,
            stages: [.intake, .candidateAssembly],
            transitions: [
                .init(from: .intake, event: .intakeRecorded, to: .candidateAssembly),
            ]
        )
        #expect(throws: WorkflowError.invalidDefinition) {
            try WorkflowReducer().decide(
                definition: crossWorkType,
                state: state,
                event: event,
                context: exactContext(for: .intakeRecorded)
            )
        }
    }

    @Test("R-02.1-007 requires an exact graph guard and permits empty non-graph context")
    func exactGuardSets() throws {
        let state = try RunState.startEngineering(
            runID: workflowTestRunID,
            workItemID: "IIS-0002",
            mode: .auto,
            canonSnapshotDigest: workflowTestDigest("a")
        )
        let event = try WorkflowEvent(id: "guard-intake", kind: .intakeRecorded)

        _ = try WorkflowReducer().decide(
            definition: EngineeringWorkflow.definition,
            state: state,
            event: event,
            context: exactContext(for: .intakeRecorded)
        )
        #expect(throws: WorkflowError.missingGuard) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: state,
                event: event,
                context: transitionContext(guards: [.intakeRecorded, .planSubmitted])
            )
        }

        let empty = try transitionContext(guards: [])
        #expect(empty.satisfiedGuards.isEmpty)
        #expect(throws: WorkflowError.missingGuard) {
            try WorkflowReducer().decide(
                definition: EngineeringWorkflow.definition,
                state: state,
                event: event,
                context: empty
            )
        }
    }

    @Test("R-02.1-005 and R-02.1-008 reject malicious wire shapes with schema parity")
    func maliciousWireCorpus() throws {
        var engineering = try RunState.startEngineering(
            runID: workflowTestRunID,
            workItemID: "IIS-0002",
            mode: .auto,
            canonSnapshotDigest: workflowTestDigest("a")
        )
        engineering = try WorkflowReducer().decide(
            definition: EngineeringWorkflow.definition,
            state: engineering,
            event: WorkflowEvent(id: "wire-intake", kind: .intakeRecorded),
            context: exactContext(for: .intakeRecorded)
        ).proposedState
        let validState = try workflowJSONObject(engineering)
        #expect(try decodeWorkflowState(validState).stage == .requirements)

        var stateUnknown = validState
        stateUnknown["unknown_state_field"] = true

        var invalidProcessedID = validState
        var processed = try #require(invalidProcessedID["processed_events"] as? [[String: Any]])
        processed[0]["id"] = " "
        invalidProcessedID["processed_events"] = processed

        var unknownProcessed = validState
        processed = try #require(unknownProcessed["processed_events"] as? [[String: Any]])
        processed[0]["unknown_processed_field"] = true
        unknownProcessed["processed_events"] = processed

        var inactiveEngineering = validState
        inactiveEngineering["inactive_candidate_generation_ids"] = [1]

        for invalid in [stateUnknown, invalidProcessedID, unknownProcessed, inactiveEngineering] {
            #expect(throws: Error.self) { try decodeWorkflowState(invalid) }
        }

        var release = try releaseStartState()
        for index in 0..<2 {
            release = try reduceReleaseExactly(
                release,
                event: WorkflowEvent(
                    id: "wire-generation-\(index)",
                    kind: .candidateInputInvalidated,
                    candidateGenerationID: try requiredGeneration(release)
                )
            )
        }
        let validGenerationHistory = try workflowJSONObject(release)
        #expect(try decodeWorkflowState(validGenerationHistory).candidateGenerationID?.rawValue == 3)
        var reorderedHistory = validGenerationHistory
        reorderedHistory["inactive_candidate_generation_ids"] = [2, 1]
        var gappedHistory = validGenerationHistory
        gappedHistory["inactive_candidate_generation_ids"] = [1]
        for invalid in [reorderedHistory, gappedHistory] {
            #expect(throws: Error.self) { try decodeWorkflowState(invalid) }
        }

        let reviewHead = try workflowTestDigest("3")
        var reviewState = try reviewGateState()
        reviewState = try reduceReview(
            reviewState,
            event: WorkflowEvent(
                id: "wire-review-freeze",
                kind: .reviewBaselineFrozen,
                reviewRound: .initial(
                    gate: .requirements,
                    cycleOrdinal: 0,
                    preFreezeEventHead: reviewHead,
                    redactionPolicy: reviewRedactionPolicy
                )
            ),
            head: reviewHead
        )
        var inconsistentReview = try workflowJSONObject(reviewState)
        var reviewCycle = try #require(inconsistentReview["review_cycle"] as? [String: Any])
        reviewCycle["phase"] = "collecting_normal_confirmation"
        reviewCycle["did_record_remediation"] = false
        inconsistentReview["review_cycle"] = reviewCycle
        #expect(throws: Error.self) { try decodeWorkflowState(inconsistentReview) }

        let reviewEvent = try WorkflowEvent(
            id: "wire-review-event",
            kind: .reviewBaselineFrozen,
            reviewRound: .initial(
                gate: .requirements,
                cycleOrdinal: 0,
                preFreezeEventHead: reviewHead,
                redactionPolicy: reviewRedactionPolicy
            )
        )
        let validEvent = try workflowJSONObject(reviewEvent)
        #expect(try decodeWorkflowEvent(validEvent).kind == .reviewBaselineFrozen)

        var eventUnknown = validEvent
        eventUnknown["unknown_event_field"] = true
        var invalidRedactionIdentity = validEvent
        var round = try #require(invalidRedactionIdentity["review_round"] as? [String: Any])
        var policy = try #require(round["redaction_policy"] as? [String: Any])
        policy["identity"] = ""
        round["redaction_policy"] = policy
        invalidRedactionIdentity["review_round"] = round

        var unknownPolicy = validEvent
        round = try #require(unknownPolicy["review_round"] as? [String: Any])
        policy = try #require(round["redaction_policy"] as? [String: Any])
        policy["unknown_policy_field"] = true
        round["redaction_policy"] = policy
        unknownPolicy["review_round"] = round

        for invalid in [eventUnknown, invalidRedactionIdentity, unknownPolicy] {
            #expect(throws: Error.self) { try decodeWorkflowEvent(invalid) }
        }

        let overflowEvent = Data(
            """
            {"candidate_generation_id":18446744073709551616,"id":"overflow","kind":"candidate_submitted","schema_version":1}
            """.utf8
        )
        #expect(throws: Error.self) {
            try CanonicalJSON.decode(WorkflowEvent.self, from: overflowEvent)
        }

        let stateSchema = try workflowSchemaObject("workflow-state.schema.json")
        let eventSchema = try workflowSchemaObject("workflow-event.schema.json")
        let stateDefinitions = try #require(stateSchema["$defs"] as? [String: Any])
        let eventDefinitions = try #require(eventSchema["$defs"] as? [String: Any])
        let stateGeneration = try #require(stateDefinitions["candidate_generation"] as? [String: Any])
        let eventGeneration = try #require(eventDefinitions["candidate_generation"] as? [String: Any])
        #expect((stateGeneration["maximum"] as? NSNumber)?.stringValue == "18446744073709551615")
        #expect((eventGeneration["maximum"] as? NSNumber)?.stringValue == "18446744073709551615")

        let reviewCycleSchema = try #require(stateDefinitions["review_cycle"] as? [String: Any])
        #expect((reviewCycleSchema["allOf"] as? [[String: Any]])?.isEmpty == false)

        let stateAllOf = try #require(stateSchema["allOf"] as? [[String: Any]])
        let engineeringThen = try #require(stateAllOf.first?["then"] as? [String: Any])
        let engineeringProperties = try #require(engineeringThen["properties"] as? [String: Any])
        let inactive = try #require(
            engineeringProperties["inactive_candidate_generation_ids"] as? [String: Any]
        )
        #expect(inactive["maxItems"] as? Int == 0)
    }
}

func workflowSchemaURL(_ filename: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("standards/canon/schemas/v1/\(filename)")
}

func workflowSchemaObject(_ filename: String) throws -> [String: Any] {
    let url = workflowSchemaURL(filename)
    return try #require(
        JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    )
}

func workflowJSONObject(_ value: some Encodable) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: CanonicalJSON.encode(value)) as? [String: Any])
}

func decodeWorkflowState(_ object: [String: Any]) throws -> RunState {
    try CanonicalJSON.decode(
        RunState.self,
        from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    )
}

func decodeWorkflowEvent(_ object: [String: Any]) throws -> WorkflowEvent {
    try CanonicalJSON.decode(
        WorkflowEvent.self,
        from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    )
}

let workflowTestRunID = RunID(
    rawValue: UUID(uuidString: "8e0a27c1-c8ef-44cc-bf68-2927277b57f3")!
)

func workflowTestDigest(_ character: Character) throws -> HashDigest {
    try HashDigest(validating: String(repeating: String(character), count: 64))
}

func engineeringContext(
    currentEventHead: HashDigest? = nil,
    currentReviewBaselineDigest: HashDigest? = nil,
    hasRemainingExecutionPhases: Bool = false
) throws -> TransitionContext {
    try TransitionContext(
        actorID: ActorID(validating: "engineering-author"),
        principalID: PrincipalID(validating: "engineering-principal"),
        currentEventHead: currentEventHead ?? workflowTestDigest("b"),
        currentReviewBaselineDigest: currentReviewBaselineDigest,
        hasRemainingExecutionPhases: hasRemainingExecutionPhases,
        satisfiedGuards: []
    )
}

func transitionContext(
    guards: Set<WorkflowGuard>,
    currentEventHead: HashDigest? = nil,
    currentReviewBaselineDigest: HashDigest? = nil,
    hasRemainingExecutionPhases: Bool = false
) throws -> TransitionContext {
    try TransitionContext(
        actorID: ActorID(validating: "engineering-author"),
        principalID: PrincipalID(validating: "engineering-principal"),
        currentEventHead: currentEventHead ?? workflowTestDigest("b"),
        currentReviewBaselineDigest: currentReviewBaselineDigest,
        hasRemainingExecutionPhases: hasRemainingExecutionPhases,
        satisfiedGuards: guards
    )
}

func exactContext(for event: WorkflowEventKind) throws -> TransitionContext {
    guard let guardValue = WorkflowGuard(rawValue: event.rawValue) else {
        return try transitionContext(guards: [])
    }
    return try transitionContext(guards: [guardValue])
}
