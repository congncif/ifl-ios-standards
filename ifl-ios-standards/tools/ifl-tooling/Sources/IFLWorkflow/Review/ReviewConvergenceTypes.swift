import IFLContracts

public enum ReviewRoundKind: String, Codable, CaseIterable, Sendable {
    case initial = "initial"
    case normalConfirmation = "normal_confirmation"
    case exception = "exception"
}

public enum ReviewGateKind: String, Codable, CaseIterable, Sendable {
    case requirements = "requirements"
    case design = "design"
    case architecture = "architecture"
    case plan = "plan"
    case checkpoint = "checkpoint"
    case review = "review"
    case final = "final"

    public static func admit(
        stage: WorkflowStage,
        workType: WorkType,
        evidenceKind: ReviewEvidenceKind
    ) throws -> ReviewGateKind {
        guard workType == .engineeringRun,
              evidenceKind == .findingProducingReview
        else { throw WorkflowError.reviewCycleNotAllowed }

        guard let gate = findingProducingGate(for: stage) else {
            throw WorkflowError.reviewCycleNotAllowed
        }
        return gate
    }

    static func findingProducingGate(for stage: WorkflowStage) -> ReviewGateKind? {
        switch stage {
        case .requirementGate: return .requirements
        case .designGate: return .design
        case .architectureGate: return .architecture
        case .planGate: return .plan
        case .checkpoint: return .checkpoint
        case .review: return .review
        case .finalGate: return .final
        default: return nil
        }
    }
}

public enum ReviewEvidenceKind: String, Codable, CaseIterable, Sendable {
    case findingProducingReview = "finding_producing_review"
    case pureScriptCheck = "pure_script_check"
    case approvalOnly = "approval_only"
}

public enum ReviewCyclePhase: String, Codable, CaseIterable, Sendable {
    case collectingInitial = "collecting_initial"
    case awaitingRemediation = "awaiting_remediation"
    case collectingNormalConfirmation = "collecting_normal_confirmation"
    case collectingException = "collecting_exception"
    case converged = "converged"
    case invalidated = "invalidated"
}

public struct RedactionPolicyBinding: Codable, Hashable, Sendable {
    public let identity: String
    public let digest: HashDigest

    public init(identity: String, digest: HashDigest) throws {
        guard WorkflowIdentifier.isValid(identity) else { throw WorkflowError.invalidIdentifier }
        self.identity = identity
        self.digest = digest
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            identity: container.decode(String.self, forKey: .identity),
            digest: container.decode(HashDigest.self, forKey: .digest)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case identity
        case digest
    }
}

public struct ReviewRoundInput: Codable, Hashable, Sendable {
    public let cycleID: ReviewCycleID?
    public let gate: ReviewGateKind
    public let cycleOrdinal: UInt64?
    public let kind: ReviewRoundKind
    public let semanticOrdinal: UInt64
    public let roundAnchorEventHead: HashDigest
    public let predecessorBaselineDigest: HashDigest?
    public let redactionPolicy: RedactionPolicyBinding

    private init(
        cycleID: ReviewCycleID?,
        gate: ReviewGateKind,
        cycleOrdinal: UInt64?,
        kind: ReviewRoundKind,
        semanticOrdinal: UInt64,
        roundAnchorEventHead: HashDigest,
        predecessorBaselineDigest: HashDigest?,
        redactionPolicy: RedactionPolicyBinding
    ) throws {
        switch kind {
        case .initial:
            guard cycleID == nil,
                  cycleOrdinal != nil,
                  semanticOrdinal == 0,
                  predecessorBaselineDigest == nil
            else { throw WorkflowError.invalidReviewRound }
        case .normalConfirmation:
            guard cycleID != nil,
                  cycleOrdinal == nil,
                  semanticOrdinal == 1,
                  predecessorBaselineDigest != nil
            else { throw WorkflowError.invalidReviewRound }
        case .exception:
            guard cycleID != nil,
                  cycleOrdinal == nil,
                  semanticOrdinal >= 2,
                  predecessorBaselineDigest != nil
            else { throw WorkflowError.invalidReviewRound }
        }
        self.cycleID = cycleID
        self.gate = gate
        self.cycleOrdinal = cycleOrdinal
        self.kind = kind
        self.semanticOrdinal = semanticOrdinal
        self.roundAnchorEventHead = roundAnchorEventHead
        self.predecessorBaselineDigest = predecessorBaselineDigest
        self.redactionPolicy = redactionPolicy
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            cycleID: container.decodeIfPresent(ReviewCycleID.self, forKey: .cycleID),
            gate: container.decode(ReviewGateKind.self, forKey: .gate),
            cycleOrdinal: container.decodeIfPresent(UInt64.self, forKey: .cycleOrdinal),
            kind: container.decode(ReviewRoundKind.self, forKey: .kind),
            semanticOrdinal: container.decode(UInt64.self, forKey: .semanticOrdinal),
            roundAnchorEventHead: container.decode(HashDigest.self, forKey: .roundAnchorEventHead),
            predecessorBaselineDigest: container.decodeIfPresent(
                HashDigest.self,
                forKey: .predecessorBaselineDigest
            ),
            redactionPolicy: container.decode(RedactionPolicyBinding.self, forKey: .redactionPolicy)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case cycleID = "cycle_id"
        case gate
        case cycleOrdinal = "cycle_ordinal"
        case kind
        case semanticOrdinal = "semantic_ordinal"
        case roundAnchorEventHead = "round_anchor_event_head"
        case predecessorBaselineDigest = "predecessor_baseline_digest"
        case redactionPolicy = "redaction_policy"
    }

    public static func initial(
        gate: ReviewGateKind,
        cycleOrdinal: UInt64,
        preFreezeEventHead: HashDigest,
        redactionPolicy: RedactionPolicyBinding
    ) throws -> ReviewRoundInput {
        try ReviewRoundInput(
            cycleID: nil,
            gate: gate,
            cycleOrdinal: cycleOrdinal,
            kind: .initial,
            semanticOrdinal: 0,
            roundAnchorEventHead: preFreezeEventHead,
            predecessorBaselineDigest: nil,
            redactionPolicy: redactionPolicy
        )
    }

    public static func later(
        cycleID: ReviewCycleID,
        gate: ReviewGateKind,
        kind: ReviewRoundKind,
        semanticOrdinal: UInt64,
        roundAnchorEventHead: HashDigest,
        predecessorBaselineDigest: HashDigest,
        redactionPolicy: RedactionPolicyBinding
    ) throws -> ReviewRoundInput {
        try ReviewRoundInput(
            cycleID: cycleID,
            gate: gate,
            cycleOrdinal: nil,
            kind: kind,
            semanticOrdinal: semanticOrdinal,
            roundAnchorEventHead: roundAnchorEventHead,
            predecessorBaselineDigest: predecessorBaselineDigest,
            redactionPolicy: redactionPolicy
        )
    }
}

public struct ReviewCycleState: Codable, Hashable, Sendable {
    public let id: ReviewCycleID
    public let gate: ReviewGateKind
    public let cycleOrdinal: UInt64
    public var phase: ReviewCyclePhase
    public var currentRoundID: ReviewRoundID
    public var currentRoundKind: ReviewRoundKind
    public var currentSemanticOrdinal: UInt64
    public var didRecordRemediation: Bool
    public var didRecordConfirmation: Bool
    public var convergenceReceiptID: ReceiptID?
    public let redactionPolicy: RedactionPolicyBinding
    public let cyclePreFreezeEventHead: HashDigest
    public var currentRoundAnchorEventHead: HashDigest
    public var predecessorBaselineDigest: HashDigest?
    public var closedRoundID: ReviewRoundID?
    public var closedBaselineDigest: HashDigest?
    public var closedRegisterDigest: HashDigest?
    public var closedPathDecision: IssueRegisterPathDecision?
    public var lastRemediatedRoundID: ReviewRoundID?
    public var confirmationReceiptID: ReceiptID?

    init(
        id: ReviewCycleID,
        gate: ReviewGateKind,
        cycleOrdinal: UInt64,
        phase: ReviewCyclePhase,
        currentRoundID: ReviewRoundID,
        currentRoundKind: ReviewRoundKind,
        currentSemanticOrdinal: UInt64,
        didRecordRemediation: Bool,
        didRecordConfirmation: Bool,
        convergenceReceiptID: ReceiptID? = nil,
        redactionPolicy: RedactionPolicyBinding,
        cyclePreFreezeEventHead: HashDigest,
        currentRoundAnchorEventHead: HashDigest,
        predecessorBaselineDigest: HashDigest?,
        closedRoundID: ReviewRoundID? = nil,
        closedBaselineDigest: HashDigest? = nil,
        closedRegisterDigest: HashDigest? = nil,
        closedPathDecision: IssueRegisterPathDecision? = nil,
        lastRemediatedRoundID: ReviewRoundID? = nil,
        confirmationReceiptID: ReceiptID? = nil
    ) throws {
        self.id = id
        self.gate = gate
        self.cycleOrdinal = cycleOrdinal
        self.phase = phase
        self.currentRoundID = currentRoundID
        self.currentRoundKind = currentRoundKind
        self.currentSemanticOrdinal = currentSemanticOrdinal
        self.didRecordRemediation = didRecordRemediation
        self.didRecordConfirmation = didRecordConfirmation
        self.convergenceReceiptID = convergenceReceiptID
        self.redactionPolicy = redactionPolicy
        self.cyclePreFreezeEventHead = cyclePreFreezeEventHead
        self.currentRoundAnchorEventHead = currentRoundAnchorEventHead
        self.predecessorBaselineDigest = predecessorBaselineDigest
        self.closedRoundID = closedRoundID
        self.closedBaselineDigest = closedBaselineDigest
        self.closedRegisterDigest = closedRegisterDigest
        self.closedPathDecision = closedPathDecision
        self.lastRemediatedRoundID = lastRemediatedRoundID
        self.confirmationReceiptID = confirmationReceiptID
        try validateShape()
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(ReviewCycleID.self, forKey: .id),
            gate: container.decode(ReviewGateKind.self, forKey: .gate),
            cycleOrdinal: container.decode(UInt64.self, forKey: .cycleOrdinal),
            phase: container.decode(ReviewCyclePhase.self, forKey: .phase),
            currentRoundID: container.decode(ReviewRoundID.self, forKey: .currentRoundID),
            currentRoundKind: container.decode(ReviewRoundKind.self, forKey: .currentRoundKind),
            currentSemanticOrdinal: container.decode(UInt64.self, forKey: .currentSemanticOrdinal),
            didRecordRemediation: container.decode(Bool.self, forKey: .didRecordRemediation),
            didRecordConfirmation: container.decode(Bool.self, forKey: .didRecordConfirmation),
            convergenceReceiptID: container.decodeIfPresent(
                ReceiptID.self,
                forKey: .convergenceReceiptID
            ),
            redactionPolicy: container.decode(RedactionPolicyBinding.self, forKey: .redactionPolicy),
            cyclePreFreezeEventHead: container.decode(HashDigest.self, forKey: .cyclePreFreezeEventHead),
            currentRoundAnchorEventHead: container.decode(
                HashDigest.self,
                forKey: .currentRoundAnchorEventHead
            ),
            predecessorBaselineDigest: container.decodeIfPresent(
                HashDigest.self,
                forKey: .predecessorBaselineDigest
            ),
            closedRoundID: container.decodeIfPresent(ReviewRoundID.self, forKey: .closedRoundID),
            closedBaselineDigest: container.decodeIfPresent(
                HashDigest.self,
                forKey: .closedBaselineDigest
            ),
            closedRegisterDigest: container.decodeIfPresent(
                HashDigest.self,
                forKey: .closedRegisterDigest
            ),
            closedPathDecision: container.decodeIfPresent(
                IssueRegisterPathDecision.self,
                forKey: .closedPathDecision
            ),
            lastRemediatedRoundID: container.decodeIfPresent(
                ReviewRoundID.self,
                forKey: .lastRemediatedRoundID
            ),
            confirmationReceiptID: container.decodeIfPresent(
                ReceiptID.self,
                forKey: .confirmationReceiptID
            )
        )
    }

    var hasVerifiedCurrentRoundClosure: Bool {
        closedRoundID == currentRoundID &&
            closedBaselineDigest != nil &&
            closedRegisterDigest != nil &&
            closedPathDecision != nil
    }

    var hasVerifiedTerminalConvergence: Bool {
        guard phase == .converged,
              convergenceReceiptID != nil,
              hasVerifiedCurrentRoundClosure,
              closedPathDecision == .directConvergenceNoAcceptedCurrentScope
        else { return false }
        switch currentRoundKind {
        case .initial:
            return !didRecordRemediation &&
                !didRecordConfirmation &&
                confirmationReceiptID == nil
        case .normalConfirmation, .exception:
            return didRecordRemediation &&
                didRecordConfirmation &&
                confirmationReceiptID != nil &&
                lastRemediatedRoundID != nil &&
                lastRemediatedRoundID != currentRoundID
        }
    }

    mutating func clearCurrentRoundClosure() {
        closedRoundID = nil
        closedBaselineDigest = nil
        closedRegisterDigest = nil
        closedPathDecision = nil
    }

    mutating func installClosure(_ fact: VerifiedReviewRoundClosureFact) {
        closedRoundID = fact.roundID
        closedBaselineDigest = fact.baselineDigest
        closedRegisterDigest = fact.registerDigest
        closedPathDecision = fact.pathDecision
    }

    func validate(runID: RunID, stage: WorkflowStage, nextCycleOrdinal: UInt64) throws {
        try validateShape()
        guard ReviewGateKind.findingProducingGate(for: stage) == gate else {
            throw WorkflowError.invalidState
        }
        let expectedCycleID = try ReviewCycleID.derive(
            runID: runID,
            gate: gate,
            cycleOrdinal: cycleOrdinal,
            preFreezeEventHead: cyclePreFreezeEventHead
        )
        let expectedRoundID = try ReviewRoundID.derive(
            runID: runID,
            gate: gate,
            cycleID: id,
            kind: currentRoundKind,
            semanticOrdinal: currentSemanticOrdinal,
            roundAnchorEventHead: currentRoundAnchorEventHead,
            predecessorBaselineDigest: predecessorBaselineDigest
        )
        guard id == expectedCycleID, currentRoundID == expectedRoundID else {
            throw WorkflowError.invalidState
        }

        if phase == .invalidated {
            guard try incrementChecked(cycleOrdinal) == nextCycleOrdinal else {
                throw WorkflowError.invalidState
            }
        } else {
            guard cycleOrdinal == nextCycleOrdinal else { throw WorkflowError.invalidState }
        }
    }

    private func validateShape() throws {
        let closurePresence = [
            closedRoundID != nil,
            closedBaselineDigest != nil,
            closedRegisterDigest != nil,
            closedPathDecision != nil,
        ]
        guard closurePresence.allSatisfy({ !$0 }) || closurePresence.allSatisfy({ $0 }) else {
            throw WorkflowError.invalidState
        }
        if let closedRoundID {
            guard closedRoundID == currentRoundID else { throw WorkflowError.invalidState }
        }
        if let lastRemediatedRoundID {
            guard didRecordRemediation else { throw WorkflowError.invalidState }
            if lastRemediatedRoundID == currentRoundID {
                guard hasVerifiedCurrentRoundClosure,
                      closedPathDecision == .requiresRemediation
                else { throw WorkflowError.invalidState }
            }
        }
        if confirmationReceiptID != nil {
            guard didRecordConfirmation else { throw WorkflowError.invalidState }
        }
        if closedPathDecision == .requiresRemediation,
           phase != .invalidated,
           phase != .converged {
            guard phase == .awaitingRemediation else { throw WorkflowError.invalidState }
        }
        if phase == .converged {
            guard hasVerifiedTerminalConvergence else { throw WorkflowError.invalidState }
        } else if phase != .invalidated {
            guard convergenceReceiptID == nil else { throw WorkflowError.invalidState }
        }
        switch currentRoundKind {
        case .initial:
            guard currentSemanticOrdinal == 0,
                  predecessorBaselineDigest == nil,
                  !didRecordConfirmation,
                  confirmationReceiptID == nil,
                  [.collectingInitial, .awaitingRemediation, .converged, .invalidated].contains(phase)
            else { throw WorkflowError.invalidState }
            if phase == .collectingInitial || phase == .converged {
                guard !didRecordRemediation else { throw WorkflowError.invalidState }
            }
            if hasVerifiedCurrentRoundClosure {
                guard phase != .collectingInitial else { throw WorkflowError.invalidState }
            }
        case .normalConfirmation:
            guard currentSemanticOrdinal == 1,
                  predecessorBaselineDigest != nil,
                  didRecordRemediation,
                  [.collectingNormalConfirmation, .awaitingRemediation, .converged, .invalidated]
                    .contains(phase)
            else { throw WorkflowError.invalidState }
            if phase == .converged {
                guard didRecordConfirmation,
                      confirmationReceiptID != nil
                else { throw WorkflowError.invalidState }
            }
            if confirmationReceiptID != nil {
                guard hasVerifiedCurrentRoundClosure else { throw WorkflowError.invalidState }
            }
            if phase == .awaitingRemediation {
                guard hasVerifiedCurrentRoundClosure,
                      closedPathDecision == .requiresRemediation
                else { throw WorkflowError.invalidState }
            }
        case .exception:
            guard currentSemanticOrdinal >= 2,
                  predecessorBaselineDigest != nil,
                  didRecordRemediation,
                  didRecordConfirmation,
                  [.collectingException, .awaitingRemediation, .converged, .invalidated]
                    .contains(phase)
            else { throw WorkflowError.invalidState }
            if phase == .awaitingRemediation {
                guard hasVerifiedCurrentRoundClosure,
                      closedPathDecision == .requiresRemediation
                else { throw WorkflowError.invalidState }
            }
            if phase == .converged {
                guard confirmationReceiptID != nil else { throw WorkflowError.invalidState }
            }
        }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case gate
        case cycleOrdinal = "cycle_ordinal"
        case phase
        case currentRoundID = "current_round_id"
        case currentRoundKind = "current_round_kind"
        case currentSemanticOrdinal = "current_semantic_ordinal"
        case didRecordRemediation = "did_record_remediation"
        case didRecordConfirmation = "did_record_confirmation"
        case convergenceReceiptID = "convergence_receipt_id"
        case redactionPolicy = "redaction_policy"
        case cyclePreFreezeEventHead = "cycle_pre_freeze_event_head"
        case currentRoundAnchorEventHead = "current_round_anchor_event_head"
        case predecessorBaselineDigest = "predecessor_baseline_digest"
        case closedRoundID = "closed_round_id"
        case closedBaselineDigest = "closed_baseline_digest"
        case closedRegisterDigest = "closed_register_digest"
        case closedPathDecision = "closed_path_decision"
        case lastRemediatedRoundID = "last_remediated_round_id"
        case confirmationReceiptID = "confirmation_receipt_id"
    }
}
