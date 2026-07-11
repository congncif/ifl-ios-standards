import IFLContracts

public enum ControlRequest: String, Codable, CaseIterable, Hashable, Sendable {
    case pause
    case resume
    case userInputReceived = "user_input_received"
    case blockerResolved = "blocker_resolved"
    case cancel
    case fail
}

public struct PendingControlFact: Hashable, Sendable {
    public let id: String
    public let status: RunStatus
    public let reasonDigest: HashDigest
    public let eventHead: HashDigest
    public let policyDigest: HashDigest

    init(
        id: String,
        status: RunStatus,
        reasonDigest: HashDigest,
        eventHead: HashDigest,
        policyDigest: HashDigest
    ) throws {
        guard WorkflowIdentifier.isValid(id),
              status == .waitingForUser || status == .blocked
        else { throw WorkflowPolicyError.invalidControlProof }
        self.id = id
        self.status = status
        self.reasonDigest = reasonDigest
        self.eventHead = eventHead
        self.policyDigest = policyDigest
    }
}

public struct VerifiedControlResolutionFact: Hashable, Sendable {
    public let actorID: ActorID
    public let principalID: PrincipalID
    public let policyDigest: HashDigest
    public let pendingControlID: String
    public let pendingReasonDigest: HashDigest
    public let pendingEventHead: HashDigest
    public let resolutionEvidenceDigest: HashDigest
    public let revalidationPassed: Bool

    init(
        actorID: ActorID,
        principalID: PrincipalID,
        policyDigest: HashDigest,
        pendingControlID: String,
        pendingReasonDigest: HashDigest,
        pendingEventHead: HashDigest,
        resolutionEvidenceDigest: HashDigest,
        revalidationPassed: Bool
    ) throws {
        guard WorkflowIdentifier.isValid(pendingControlID) else {
            throw WorkflowPolicyError.invalidControlProof
        }
        self.actorID = actorID
        self.principalID = principalID
        self.policyDigest = policyDigest
        self.pendingControlID = pendingControlID
        self.pendingReasonDigest = pendingReasonDigest
        self.pendingEventHead = pendingEventHead
        self.resolutionEvidenceDigest = resolutionEvidenceDigest
        self.revalidationPassed = revalidationPassed
    }
}

public struct ControlEventDecision: Hashable, Sendable {
    public let eventKind: WorkflowEventKind?
    public let nextStatus: RunStatus
    public let resolution: ResolutionKind

    init(
        eventKind: WorkflowEventKind?,
        nextStatus: RunStatus,
        resolution: ResolutionKind
    ) {
        self.eventKind = eventKind
        self.nextStatus = nextStatus
        self.resolution = resolution
    }
}

public struct ControlEventPolicy: Sendable {
    public init() {}

    public func resolve(
        pending: PendingControlFact,
        proof: VerifiedControlResolutionFact
    ) throws -> ControlEventDecision {
        guard proof.policyDigest == pending.policyDigest,
              proof.pendingControlID == pending.id,
              proof.pendingReasonDigest == pending.reasonDigest,
              proof.pendingEventHead == pending.eventHead
        else { throw WorkflowPolicyError.invalidControlProof }
        guard proof.revalidationPassed else {
            return ControlEventDecision(
                eventKind: nil,
                nextStatus: pending.status,
                resolution: pending.status == .blocked ? .block : .waitForUser
            )
        }
        switch pending.status {
        case .waitingForUser:
            return ControlEventDecision(
                eventKind: .userInputReceived,
                nextStatus: .running,
                resolution: .continueWorkflow
            )
        case .blocked:
            return ControlEventDecision(
                eventKind: .blockerResolved,
                nextStatus: .running,
                resolution: .continueWorkflow
            )
        default:
            throw WorkflowPolicyError.invalidControlProof
        }
    }

    public func decideLifecycle(
        status: RunStatus,
        request: ControlRequest
    ) throws -> ControlEventDecision {
        let result: (WorkflowEventKind, RunStatus)
        switch (status, request) {
        case (.running, .pause): result = (.pause, .paused)
        case (.paused, .resume): result = (.resume, .running)
        case (.running, .cancel), (.paused, .cancel): result = (.cancel, .cancelled)
        case (.running, .fail), (.paused, .fail): result = (.fail, .failed)
        default: throw WorkflowPolicyError.illegalControlRequest
        }
        return ControlEventDecision(
            eventKind: result.0,
            nextStatus: result.1,
            resolution: result.1 == .failed ? .fail : .continueWorkflow
        )
    }
}

public enum RootCauseDependencyRelation: String, Hashable, Sendable {
    case sameStage = "same_stage"
    case targetFeedsFailure = "target_feeds_failure"
    case unverified
}

public struct VerifiedRootCauseFact: Hashable, Sendable {
    public let failingStage: WorkflowStage
    public let failingCheckID: String
    public let evidenceDigest: HashDigest
    public let policyDigest: HashDigest
    public let dependencyRelation: RootCauseDependencyRelation
    public let target: RootCauseStage

    init(
        failingStage: WorkflowStage,
        failingCheckID: String,
        evidenceDigest: HashDigest,
        policyDigest: HashDigest,
        dependencyRelation: RootCauseDependencyRelation,
        target: RootCauseStage
    ) throws {
        guard WorkflowIdentifier.isValid(failingCheckID) else {
            throw WorkflowPolicyError.invalidRootCauseFact
        }
        self.failingStage = failingStage
        self.failingCheckID = failingCheckID
        self.evidenceDigest = evidenceDigest
        self.policyDigest = policyDigest
        self.dependencyRelation = dependencyRelation
        self.target = target
    }
}

public struct RollbackDecision: Hashable, Sendable {
    public let target: WorkflowStage
    public let invalidatedStages: [WorkflowStage]

    init(target: WorkflowStage, invalidatedStages: [WorkflowStage]) {
        self.target = target
        self.invalidatedStages = invalidatedStages
    }
}

public enum RollbackPolicy {
    public static func decide(
        _ fact: VerifiedRootCauseFact
    ) throws -> RollbackDecision {
        guard fact.dependencyRelation != .unverified,
              let targetIndex = rollbackOrder.firstIndex(of: targetStage(fact.target)),
              let failingIndex = rollbackOrder.firstIndex(of: fact.failingStage)
        else { throw WorkflowPolicyError.invalidRootCauseFact }
        switch fact.dependencyRelation {
        case .sameStage:
            guard targetIndex == failingIndex else {
                throw WorkflowPolicyError.invalidRootCauseFact
            }
        case .targetFeedsFailure:
            guard targetIndex <= failingIndex else {
                throw WorkflowPolicyError.invalidRootCauseFact
            }
        case .unverified:
            throw WorkflowPolicyError.invalidRootCauseFact
        }
        return RollbackDecision(
            target: rollbackOrder[targetIndex],
            invalidatedStages: Array(rollbackOrder[targetIndex...])
        )
    }

    private static func targetStage(_ target: RootCauseStage) -> WorkflowStage {
        switch target {
        case .requirements: .requirements
        case .design: .design
        case .architecture: .architecture
        case .plan: .plan
        case .executePhase: .executePhase
        }
    }

    private static let rollbackOrder: [WorkflowStage] = [
        .requirements,
        .requirementGate,
        .design,
        .designGate,
        .architecture,
        .architectureGate,
        .plan,
        .planGate,
        .executePhase,
        .checkpoint,
        .review,
        .finalVerification,
        .finalGate,
    ]
}
