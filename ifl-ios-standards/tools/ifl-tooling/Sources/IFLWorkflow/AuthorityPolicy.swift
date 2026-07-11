import IFLContracts

public enum ApprovalKind: String, Codable, CaseIterable, Hashable, Sendable {
    case userApproved = "USER_APPROVED"
    case autoApproved = "AUTO_APPROVED"
}

public enum NonApprovedGateVerdict: String, CaseIterable, Hashable, Sendable {
    case changesRequired = "CHANGES_REQUIRED"
    case userInputRequired = "USER_INPUT_REQUIRED"
    case blocked = "BLOCKED"

    public var gateVerdict: GateVerdict {
        switch self {
        case .changesRequired: .changesRequired
        case .userInputRequired: .userInputRequired
        case .blocked: .blocked
        }
    }

    init?(_ verdict: GateVerdict) {
        switch verdict {
        case .approved: return nil
        case .changesRequired: self = .changesRequired
        case .userInputRequired: self = .userInputRequired
        case .blocked: self = .blocked
        }
    }
}

public enum VerifiedPrincipalKind: String, Hashable, Sendable {
    case human
    case agent
    case kernel
    case reviewerSet = "reviewer_set"
}

public struct VerifiedAuthorityFact: Hashable, Sendable {
    public let actorID: ActorID
    public let principalID: PrincipalID
    public let roles: Set<AuthorityRole>
    public let principalKind: VerifiedPrincipalKind
    public let independentContextDigest: HashDigest
    public let hasAuthorshipEdge: Bool
    public let hasSourceWriteCapability: Bool

    init(
        actorID: ActorID,
        principalID: PrincipalID,
        roles: Set<AuthorityRole>,
        principalKind: VerifiedPrincipalKind,
        independentContextDigest: HashDigest,
        hasAuthorshipEdge: Bool,
        hasSourceWriteCapability: Bool
    ) {
        self.actorID = actorID
        self.principalID = principalID
        self.roles = roles
        self.principalKind = principalKind
        self.independentContextDigest = independentContextDigest
        self.hasAuthorshipEdge = hasAuthorshipEdge
        self.hasSourceWriteCapability = hasSourceWriteCapability
    }
}

public struct AuthorityEvidence: Hashable, Sendable {
    public let author: VerifiedAuthorityFact?
    public let validators: [VerifiedAuthorityFact]

    init(author: VerifiedAuthorityFact?, validators: [VerifiedAuthorityFact]) {
        self.author = author
        self.validators = validators
    }
}

public struct ApprovalDecision: Hashable, Sendable {
    private enum State: Hashable, Sendable {
        case notApproved(NonApprovedGateVerdict)
        case waitingForAuthority
        case approved(ApprovalKind)
    }

    private let state: State

    public var substantiveVerdict: GateVerdict {
        switch state {
        case let .notApproved(verdict): verdict.gateVerdict
        case .waitingForAuthority, .approved: .approved
        }
    }

    public var finalVerdict: GateVerdict {
        switch state {
        case let .notApproved(verdict): verdict.gateVerdict
        case .waitingForAuthority: .userInputRequired
        case .approved: .approved
        }
    }

    public var approvalKind: ApprovalKind? {
        guard case let .approved(kind) = state else { return nil }
        return kind
    }

    private init(state: State) {
        self.state = state
    }

    static func noApprovalRequired(
        _ verdict: NonApprovedGateVerdict
    ) -> ApprovalDecision {
        ApprovalDecision(state: .notApproved(verdict))
    }

    static func waitingForAuthority() -> ApprovalDecision {
        ApprovalDecision(state: .waitingForAuthority)
    }

    static func approved(kind: ApprovalKind) -> ApprovalDecision {
        ApprovalDecision(state: .approved(kind))
    }
}

public struct VerifiedModeChangeFact: Hashable, Sendable {
    public let currentMode: WorkflowMode
    public let targetMode: WorkflowMode
    public let atCheckpoint: Bool
    public let userAuthorized: Bool
    public let reevaluationPassed: Bool
    public let eventHead: HashDigest

    init(
        currentMode: WorkflowMode,
        targetMode: WorkflowMode,
        atCheckpoint: Bool,
        userAuthorized: Bool,
        reevaluationPassed: Bool,
        eventHead: HashDigest
    ) {
        self.currentMode = currentMode
        self.targetMode = targetMode
        self.atCheckpoint = atCheckpoint
        self.userAuthorized = userAuthorized
        self.reevaluationPassed = reevaluationPassed
        self.eventHead = eventHead
    }
}

public enum ModeChangeDecision: Hashable, Sendable {
    case allowed(WorkflowMode)
    case waitingForUser
    case changesRequired
}

public struct AuthorityPolicy: Sendable {
    public let gatePolicy: GatePolicy

    public init(gatePolicy: GatePolicy) {
        self.gatePolicy = gatePolicy
    }

    public func qualify(
        gateDecision: GateDecision,
        stage: WorkflowStage,
        mode: WorkflowMode,
        context: ActivePolicyContext,
        escalationFlags: Set<AuthorityEscalationFlag>,
        evidence: AuthorityEvidence
    ) throws -> ApprovalDecision {
        if let nonApproved = NonApprovedGateVerdict(gateDecision.verdict) {
            return .noApprovalRequired(nonApproved)
        }
        let requirement = try gatePolicy.authorityRequirement(
            stage: stage,
            mode: mode,
            context: context,
            escalationFlags: escalationFlags
        )
        guard let selected = selectValidators(
            requirement: requirement,
            evidence: evidence
        ) else { return .waitingForAuthority() }

        if requirement.requiresHuman,
           selected.contains(where: { $0.principalKind != .human }) {
            return .waitingForAuthority()
        }
        if requirement.enforcer == .allRoles,
           !isIndependent(
            author: evidence.author,
            validators: selected,
            principalPolicy: requirement.distinctPrincipalPolicy
           ) {
            return .waitingForAuthority()
        }
        let userApproved = requirement.requiresHuman ||
            selected.contains(where: { $0.principalKind == .human })
        return .approved(kind: userApproved ? .userApproved : .autoApproved)
    }

    public func decideModeChange(
        _ fact: VerifiedModeChangeFact
    ) throws -> ModeChangeDecision {
        guard fact.currentMode != fact.targetMode else {
            return .allowed(fact.currentMode)
        }
        guard fact.atCheckpoint else { return .changesRequired }
        switch (fact.currentMode, fact.targetMode) {
        case (.auto, .coWorking):
            return .allowed(.coWorking)
        case (.coWorking, .auto):
            guard fact.userAuthorized else { return .waitingForUser }
            guard fact.reevaluationPassed else { return .changesRequired }
            return .allowed(.auto)
        case (.auto, .auto), (.coWorking, .coWorking):
            return .allowed(fact.currentMode)
        }
    }

    private func selectValidators(
        requirement: GateAuthorityRequirement,
        evidence: AuthorityEvidence
    ) -> [VerifiedAuthorityFact]? {
        switch requirement.enforcer {
        case .kernel:
            guard let fact = evidence.validators.first(where: {
                $0.roles.contains(.kernel) && $0.principalKind == .kernel
            }) else { return nil }
            return [fact]
        case .reviewerSet:
            guard let fact = evidence.validators.first(where: {
                $0.roles.contains(.reviewerSet) && $0.principalKind == .reviewerSet
            }) else { return nil }
            return [fact]
        case .allRoles:
            guard let author = evidence.author else { return nil }
            let roles = requirement.requiredRoles.sorted(by: { $0.rawValue < $1.rawValue })
            return selectIndependentValidators(
                roles: roles,
                at: 0,
                author: author,
                candidates: evidence.validators,
                selected: [],
                requiresHuman: requirement.requiresHuman,
                principalPolicy: requirement.distinctPrincipalPolicy
            )
        }
    }

    private func selectIndependentValidators(
        roles: [AuthorityRole],
        at index: Int,
        author: VerifiedAuthorityFact,
        candidates: [VerifiedAuthorityFact],
        selected: [VerifiedAuthorityFact],
        requiresHuman: Bool,
        principalPolicy: DistinctPrincipalPolicy
    ) -> [VerifiedAuthorityFact]? {
        guard index < roles.count else { return selected }
        for candidate in candidates where candidate.roles.contains(roles[index]) {
            guard (!requiresHuman || candidate.principalKind == .human),
                  isIndependentCandidate(
                    candidate,
                    author: author,
                    selected: selected,
                    principalPolicy: principalPolicy
                  )
            else { continue }
            if let result = selectIndependentValidators(
                roles: roles,
                at: index + 1,
                author: author,
                candidates: candidates,
                selected: selected + [candidate],
                requiresHuman: requiresHuman,
                principalPolicy: principalPolicy
            ) {
                return result
            }
        }
        return nil
    }

    private func isIndependentCandidate(
        _ candidate: VerifiedAuthorityFact,
        author: VerifiedAuthorityFact,
        selected: [VerifiedAuthorityFact],
        principalPolicy: DistinctPrincipalPolicy
    ) -> Bool {
        guard candidate.actorID != author.actorID,
              candidate.independentContextDigest != author.independentContextDigest,
              !candidate.hasAuthorshipEdge,
              !candidate.hasSourceWriteCapability,
              selected.allSatisfy({
                $0.actorID != candidate.actorID &&
                    $0.independentContextDigest != candidate.independentContextDigest
              })
        else { return false }
        guard principalPolicy == .strict else { return true }
        return candidate.principalID != author.principalID &&
            selected.allSatisfy({ $0.principalID != candidate.principalID })
    }

    private func isIndependent(
        author: VerifiedAuthorityFact?,
        validators: [VerifiedAuthorityFact],
        principalPolicy: DistinctPrincipalPolicy
    ) -> Bool {
        guard let author else { return false }
        guard validators.allSatisfy({ validator in
            validator.actorID != author.actorID &&
                validator.independentContextDigest != author.independentContextDigest &&
                !validator.hasAuthorshipEdge &&
                !validator.hasSourceWriteCapability
        }) else { return false }
        guard Set(validators.map(\.actorID)).count == validators.count,
              Set(validators.map(\.independentContextDigest)).count == validators.count
        else { return false }
        guard principalPolicy == .strict else { return true }
        return validators.allSatisfy({ $0.principalID != author.principalID }) &&
            Set(validators.map(\.principalID)).count == validators.count
    }
}
