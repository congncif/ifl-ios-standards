import IFLContracts

public enum WorkflowEventKind: String, Codable, CaseIterable, Sendable {
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
    case reviewBaselineFrozen = "review_baseline_frozen"
    case reviewInventoryRecorded = "review_inventory_recorded"
    case reviewInventoryClosed = "review_inventory_closed"
    case reviewRemediationRecorded = "review_remediation_recorded"
    case reviewConfirmationRecorded = "review_confirmation_recorded"
    case reviewExceptionOpened = "review_exception_opened"
    case reviewConverged = "review_converged"
    case reviewInvalidated = "review_invalidated"
    case candidateSubmitted = "candidate_submitted"
    case releaseChecksPassed = "release_checks_passed"
    case releaseChecksFailed = "release_checks_failed"
    case productReleaseApproved = "product_release_approved"
    case releaseChangesRequired = "release_changes_required"
    case closeQualification = "close_qualification"
    case candidateInputInvalidated = "candidate_input_invalidated"
    case pause = "pause"
    case resume = "resume"
    case waitForUser = "wait_for_user"
    case userInputReceived = "user_input_received"
    case block = "block"
    case blockerResolved = "blocker_resolved"
    case cancel = "cancel"
    case fail = "fail"

    var requiredGuard: WorkflowGuard? {
        WorkflowGuard(rawValue: rawValue)
    }
}

public struct WorkflowEvent: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let id: String
    public let kind: WorkflowEventKind
    public let candidateGenerationID: CandidateGenerationID?
    public let reviewRound: ReviewRoundInput?

    public init(
        id: String,
        kind: WorkflowEventKind,
        candidateGenerationID: CandidateGenerationID? = nil,
        reviewRound: ReviewRoundInput? = nil
    ) throws {
        guard WorkflowIdentifier.isValid(id) else { throw WorkflowError.invalidIdentifier }
        let requiresGeneration = kind.requiresCandidateGeneration
        guard requiresGeneration == (candidateGenerationID != nil) else {
            throw WorkflowError.staleCandidateGeneration
        }
        let requiresReviewRound = kind == .reviewBaselineFrozen
        guard requiresReviewRound == (reviewRound != nil) else {
            throw WorkflowError.invalidReviewRound
        }
        schemaVersion = 1
        self.id = id
        self.kind = kind
        self.candidateGenerationID = candidateGenerationID
        self.reviewRound = reviewRound
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else { throw WorkflowError.invalidState }
        try self.init(
            id: container.decode(String.self, forKey: .id),
            kind: container.decode(WorkflowEventKind.self, forKey: .kind),
            candidateGenerationID: container.decodeIfPresent(
                CandidateGenerationID.self,
                forKey: .candidateGenerationID
            ),
            reviewRound: container.decodeIfPresent(ReviewRoundInput.self, forKey: .reviewRound)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case id
        case kind
        case candidateGenerationID = "candidate_generation_id"
        case reviewRound = "review_round"
    }
}

extension WorkflowEventKind {
    var requiresCandidateGeneration: Bool {
        switch self {
        case .candidateSubmitted, .releaseChecksPassed, .releaseChecksFailed,
             .productReleaseApproved, .releaseChangesRequired, .closeQualification,
             .candidateInputInvalidated:
            true
        default:
            false
        }
    }
}
