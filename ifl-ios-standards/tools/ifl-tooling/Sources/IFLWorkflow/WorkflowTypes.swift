import Foundation
import IFLCanon
import IFLContracts

public enum WorkType: String, Codable, CaseIterable, Sendable {
    case engineeringRun = "engineering_run"
    case pluginRelease = "plugin_release"
}

public enum WorkflowMode: String, Codable, CaseIterable, Sendable {
    case coWorking = "co_working"
    case auto = "auto"
}

public enum WorkflowStage: String, Codable, CaseIterable, Sendable {
    case intake = "intake"
    case requirements = "requirements"
    case requirementGate = "requirement_gate"
    case design = "design"
    case designGate = "design_gate"
    case architecture = "architecture"
    case architectureGate = "architecture_gate"
    case plan = "plan"
    case planGate = "plan_gate"
    case executePhase = "execute_phase"
    case checkpoint = "checkpoint"
    case review = "review"
    case finalVerification = "final_verification"
    case finalGate = "final_gate"
    case readyForHandoff = "ready_for_handoff"
    case candidateAssembly = "candidate_assembly"
    case releaseVerification = "release_verification"
    case productReleaseGate = "product_release_gate"
    case readyForExternalReleaseEffect = "ready_for_external_release_effect"
}

public enum RunStatus: String, Codable, CaseIterable, Sendable {
    case running = "running"
    case paused = "paused"
    case waitingForUser = "waiting_for_user"
    case blocked = "blocked"
    case completed = "completed"
    case cancelled = "cancelled"
    case failed = "failed"
}

public struct ActorID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(validating rawValue: String) throws {
        guard WorkflowIdentifier.isValid(rawValue) else {
            throw WorkflowError.invalidIdentifier
        }
        self.rawValue = rawValue
    }

    public init?(rawValue: String) {
        guard WorkflowIdentifier.isValid(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct PrincipalID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(validating rawValue: String) throws {
        guard WorkflowIdentifier.isValid(rawValue) else {
            throw WorkflowError.invalidIdentifier
        }
        self.rawValue = rawValue
    }

    public init?(rawValue: String) {
        guard WorkflowIdentifier.isValid(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum WorkflowGuard: String, Codable, CaseIterable, Hashable, Sendable {
    case intakeRecorded = "intake_recorded"
    case requirementsSubmitted = "requirements_submitted"
    case requirementApproved = "requirement_approved"
    case designSubmitted = "design_submitted"
    case designApproved = "design_approved"
    case architectureSubmitted = "architecture_submitted"
    case architectureApproved = "architecture_approved"
    case planSubmitted = "plan_submitted"
    case planApproved = "plan_approved"
    case phaseSubmitted = "phase_submitted"
    case checkpointPassed = "checkpoint_passed"
    case reviewApproved = "review_approved"
    case runChecksPassed = "run_checks_passed"
    case runApproved = "run_approved"
    case closeRun = "close_run"
    case candidateSubmitted = "candidate_submitted"
    case releaseChecksPassed = "release_checks_passed"
    case releaseChecksFailed = "release_checks_failed"
    case productReleaseApproved = "product_release_approved"
    case releaseChangesRequired = "release_changes_required"
    case closeQualification = "close_qualification"
    case candidateInputInvalidated = "candidate_input_invalidated"
}

public struct TransitionContext: Sendable {
    public let actorID: ActorID
    public let principalID: PrincipalID
    public let currentEventHead: HashDigest
    public let currentReviewBaselineDigest: HashDigest?
    public let hasRemainingExecutionPhases: Bool
    public let satisfiedGuards: Set<WorkflowGuard>
    public let canonSnapshot: CanonSnapshot?

    public init(
        actorID: ActorID,
        principalID: PrincipalID,
        currentEventHead: HashDigest,
        currentReviewBaselineDigest: HashDigest? = nil,
        hasRemainingExecutionPhases: Bool = false,
        satisfiedGuards: Set<WorkflowGuard>,
        canonSnapshot: CanonSnapshot? = nil
    ) throws {
        self.actorID = actorID
        self.principalID = principalID
        self.currentEventHead = currentEventHead
        self.currentReviewBaselineDigest = currentReviewBaselineDigest
        self.hasRemainingExecutionPhases = hasRemainingExecutionPhases
        self.satisfiedGuards = satisfiedGuards
        self.canonSnapshot = canonSnapshot
    }
}

public struct ProcessedWorkflowEvent: Codable, Hashable, Sendable {
    public let id: String
    public let kind: WorkflowEventKind
    public let candidateGenerationID: CandidateGenerationID?
    public let eventDigest: HashDigest

    init(recording event: WorkflowEvent) throws {
        id = event.id
        kind = event.kind
        candidateGenerationID = event.candidateGenerationID
        eventDigest = CanonicalTreeDigest.sha256(try CanonicalJSON.encode(event))
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        guard WorkflowIdentifier.isValid(id) else { throw WorkflowError.invalidIdentifier }
        let kind = try container.decode(WorkflowEventKind.self, forKey: .kind)
        let generation = try container.decodeIfPresent(
            CandidateGenerationID.self,
            forKey: .candidateGenerationID
        )
        guard kind.requiresCandidateGeneration == (generation != nil) else {
            throw WorkflowError.invalidState
        }
        self.id = id
        self.kind = kind
        candidateGenerationID = generation
        eventDigest = try container.decode(HashDigest.self, forKey: .eventDigest)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case kind
        case candidateGenerationID = "candidate_generation_id"
        case eventDigest = "event_digest"
    }
}

public struct RunState: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let runID: RunID
    public let workItemID: String
    public let workType: WorkType
    public let mode: WorkflowMode
    public let canonSnapshotDigest: HashDigest
    public internal(set) var stage: WorkflowStage
    public internal(set) var status: RunStatus
    public internal(set) var candidateGenerationID: CandidateGenerationID?
    public internal(set) var inactiveCandidateGenerationIDs: [CandidateGenerationID]
    public internal(set) var processedEvents: [ProcessedWorkflowEvent]
    public internal(set) var reviewCycle: ReviewCycleState?
    public internal(set) var nextReviewCycleOrdinal: UInt64

    private init(
        schemaVersion: Int,
        runID: RunID,
        workItemID: String,
        workType: WorkType,
        mode: WorkflowMode,
        canonSnapshotDigest: HashDigest,
        stage: WorkflowStage,
        status: RunStatus,
        candidateGenerationID: CandidateGenerationID?,
        inactiveCandidateGenerationIDs: [CandidateGenerationID],
        processedEvents: [ProcessedWorkflowEvent],
        reviewCycle: ReviewCycleState?,
        nextReviewCycleOrdinal: UInt64
    ) throws {
        guard schemaVersion == 1,
              WorkflowIdentifier.isValid(workItemID),
              Self.isValidStageStatusPair(workType: workType, stage: stage, status: status)
        else { throw WorkflowError.invalidState }

        let allowedStages = workType == .engineeringRun
            ? EngineeringWorkflow.definition.stages
            : PluginReleaseWorkflow.definition.stages
        guard allowedStages.contains(stage) else { throw WorkflowError.invalidState }

        switch workType {
        case .engineeringRun:
            guard candidateGenerationID == nil,
                  inactiveCandidateGenerationIDs.isEmpty
            else { throw WorkflowError.invalidState }
            if let reviewCycle {
                try reviewCycle.validate(
                    runID: runID,
                    stage: stage,
                    nextCycleOrdinal: nextReviewCycleOrdinal
                )
            }
        case .pluginRelease:
            guard let generation = candidateGenerationID,
                  reviewCycle == nil,
                  nextReviewCycleOrdinal == 0,
                  Self.hasCanonicalGenerationHistory(
                      inactiveCandidateGenerationIDs,
                      current: generation
                  )
            else { throw WorkflowError.invalidState }
        }
        guard Set(inactiveCandidateGenerationIDs).count == inactiveCandidateGenerationIDs.count,
              Set(processedEvents.map(\.id)).count == processedEvents.count
        else { throw WorkflowError.invalidState }

        self.schemaVersion = schemaVersion
        self.runID = runID
        self.workItemID = workItemID
        self.workType = workType
        self.mode = mode
        self.canonSnapshotDigest = canonSnapshotDigest
        self.stage = stage
        self.status = status
        self.candidateGenerationID = candidateGenerationID
        self.inactiveCandidateGenerationIDs = inactiveCandidateGenerationIDs
        self.processedEvents = processedEvents
        self.reviewCycle = reviewCycle
        self.nextReviewCycleOrdinal = nextReviewCycleOrdinal
    }

    public static func startEngineering(
        runID: RunID,
        workItemID: String,
        mode: WorkflowMode,
        canonSnapshotDigest: HashDigest
    ) throws -> RunState {
        guard WorkflowIdentifier.isValid(workItemID) else { throw WorkflowError.invalidIdentifier }
        return try RunState(
            schemaVersion: 1,
            runID: runID,
            workItemID: workItemID,
            workType: .engineeringRun,
            mode: mode,
            canonSnapshotDigest: canonSnapshotDigest,
            stage: .intake,
            status: .running,
            candidateGenerationID: nil,
            inactiveCandidateGenerationIDs: [],
            processedEvents: [],
            reviewCycle: nil,
            nextReviewCycleOrdinal: 0
        )
    }

    public static func startPluginRelease(
        runID: RunID,
        workItemID: String,
        mode: WorkflowMode,
        canonSnapshotDigest: HashDigest
    ) throws -> RunState {
        guard WorkflowIdentifier.isValid(workItemID) else { throw WorkflowError.invalidIdentifier }
        let generation = try CandidateGenerationID(validating: 1)
        return try RunState(
            schemaVersion: 1,
            runID: runID,
            workItemID: workItemID,
            workType: .pluginRelease,
            mode: mode,
            canonSnapshotDigest: canonSnapshotDigest,
            stage: .candidateAssembly,
            status: .running,
            candidateGenerationID: generation,
            inactiveCandidateGenerationIDs: [],
            processedEvents: [],
            reviewCycle: nil,
            nextReviewCycleOrdinal: 0
        )
    }

    public var isTerminal: Bool {
        status == .completed || status == .cancelled || status == .failed
    }

    public var hasValidTerminalPair: Bool {
        Self.isValidStageStatusPair(workType: workType, stage: stage, status: status)
    }

    public static func isValidStageStatusPair(
        workType: WorkType,
        stage: WorkflowStage,
        status: RunStatus
    ) -> Bool {
        switch (workType, stage, status) {
        case (.engineeringRun, .readyForHandoff, .completed),
             (.pluginRelease, .readyForExternalReleaseEffect, .completed):
            true
        case (_, _, .completed):
            false
        default:
            true
        }
    }

    private static func hasCanonicalGenerationHistory(
        _ inactive: [CandidateGenerationID],
        current: CandidateGenerationID
    ) -> Bool {
        guard UInt64(inactive.count) == current.rawValue - 1 else { return false }
        return inactive.enumerated().allSatisfy { index, generation in
            generation.rawValue == UInt64(index) + 1
        }
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            runID: container.decode(RunID.self, forKey: .runID),
            workItemID: container.decode(String.self, forKey: .workItemID),
            workType: container.decode(WorkType.self, forKey: .workType),
            mode: container.decode(WorkflowMode.self, forKey: .mode),
            canonSnapshotDigest: container.decode(HashDigest.self, forKey: .canonSnapshotDigest),
            stage: container.decode(WorkflowStage.self, forKey: .stage),
            status: container.decode(RunStatus.self, forKey: .status),
            candidateGenerationID: container.decodeIfPresent(
                CandidateGenerationID.self,
                forKey: .candidateGenerationID
            ),
            inactiveCandidateGenerationIDs: container.decode(
                [CandidateGenerationID].self,
                forKey: .inactiveCandidateGenerationIDs
            ),
            processedEvents: container.decode([ProcessedWorkflowEvent].self, forKey: .processedEvents),
            reviewCycle: container.decodeIfPresent(ReviewCycleState.self, forKey: .reviewCycle),
            nextReviewCycleOrdinal: container.decode(UInt64.self, forKey: .nextReviewCycleOrdinal)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case runID = "run_id"
        case workItemID = "work_item_id"
        case workType = "work_type"
        case mode
        case canonSnapshotDigest = "canon_snapshot_digest"
        case stage
        case status
        case candidateGenerationID = "candidate_generation_id"
        case inactiveCandidateGenerationIDs = "inactive_candidate_generation_ids"
        case processedEvents = "processed_events"
        case reviewCycle = "review_cycle"
        case nextReviewCycleOrdinal = "next_review_cycle_ordinal"
    }
}

public enum WorkflowError: Error, Equatable, Sendable {
    case illegalTransition
    case invalidDefinition
    case invalidIdentifier
    case invalidState
    case missingGuard
    case terminalState
    case eventIDCollision
    case reviewCycleNotAllowed
    case invalidReviewRound
    case missingRemediation
    case exceptionPolicyRequired
    case staleCandidateGeneration
    case unknownField
    case ordinalOverflow
}

enum WorkflowIdentifier {
    static func isValid(_ value: String) -> Bool {
        !value.isEmpty &&
            value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
            value.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
    }
}

struct WorkflowDynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

func rejectUnknownFields(from decoder: any Decoder, allowed: Set<String>) throws {
    let container = try decoder.container(keyedBy: WorkflowDynamicCodingKey.self)
    guard container.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
        throw WorkflowError.unknownField
    }
}

func incrementChecked(_ value: UInt64) throws -> UInt64 {
    let (next, overflow) = value.addingReportingOverflow(1)
    guard !overflow else { throw WorkflowError.ordinalOverflow }
    return next
}
