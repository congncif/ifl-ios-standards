import IFLContracts

public enum WorkflowPolicyError: Error, Equatable, Sendable {
    case invalidPolicy
    case unknownGate
    case missingSubstantiveVerdict
    case illegalControlRequest
    case invalidControlProof
    case invalidRollbackTarget
    case invalidRootCauseFact
    case invalidAttemptBudget
    case invalidAttemptHistory
    case invalidFingerprintInput
    case initialReviewRequired
    case remediationRequired
    case normalConfirmationAlreadyRecorded
    case invalidDispositionEvidence
    case invalidExceptionProof
}

public enum GateVerdict: String, Codable, CaseIterable, Hashable, Sendable {
    case approved = "APPROVED"
    case changesRequired = "CHANGES_REQUIRED"
    case userInputRequired = "USER_INPUT_REQUIRED"
    case blocked = "BLOCKED"

    fileprivate var precedence: Int {
        switch self {
        case .approved: 0
        case .changesRequired: 1
        case .userInputRequired: 2
        case .blocked: 3
        }
    }
}

public enum PolicyStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case waitingForUser = "waiting_for_user"
    case blocked
    case changesRequired = "changes_required"
    case failed
}

public enum ResolutionKind: String, Codable, CaseIterable, Hashable, Sendable {
    case continueWorkflow = "continue_workflow"
    case waitForUser = "wait_for_user"
    case block
    case rollback
    case fail
}

public enum RootCauseStage: String, Codable, CaseIterable, Hashable, Sendable {
    case requirements
    case design
    case architecture
    case plan
    case executePhase = "execute_phase"
}

public enum FailureClassification: Hashable, Sendable {
    case userDecisionRequired
    case missingHumanAuthority
    case externalPrerequisite
    case fixableFinding(rootCause: RootCauseStage)
    case unrecoverableIntegrityViolation
}

public struct StatusClassificationDecision: Hashable, Sendable {
    public let status: PolicyStatus
    public let verdict: GateVerdict?
    public let resolution: ResolutionKind
    public let correctionTarget: RootCauseStage?

    init(
        status: PolicyStatus,
        verdict: GateVerdict?,
        resolution: ResolutionKind,
        correctionTarget: RootCauseStage?
    ) {
        self.status = status
        self.verdict = verdict
        self.resolution = resolution
        self.correctionTarget = correctionTarget
    }
}

public struct ActivePolicyContext: Hashable, Sendable {
    public let profileID: ProfileID
    public let profileDigest: HashDigest
    public let riskClass: RiskClass

    public init(
        profileID: ProfileID,
        profileDigest: HashDigest,
        riskClass: RiskClass
    ) throws {
        self.profileID = profileID
        self.profileDigest = profileDigest
        self.riskClass = riskClass
    }
}

public enum AuthorityEscalationFlag: String, Codable, CaseIterable, Hashable, Sendable {
    case materialAmbiguity = "material_ambiguity"
    case waiverRequested = "waiver_requested"
    case policyConflict = "policy_conflict"
}

public enum AuthorityRole: String, Codable, CaseIterable, Hashable, Sendable {
    case author
    case authenticatedUser = "authenticated_user"
    case requirementsValidator = "requirements_validator"
    case designValidator = "design_validator"
    case standardsValidator = "standards_validator"
    case planValidator = "plan_validator"
    case testStrategist = "test_strategist"
    case securityPrivacyReviewer = "security_privacy_reviewer"
    case dataIntegrityReviewer = "data_integrity_reviewer"
    case kernel
    case reviewerSet = "reviewer_set"
    case runEvidenceValidator = "run_evidence_validator"
    case productReleaseValidator = "product_release_validator"
    case releaseAuthority = "release_authority"
}

public enum AuthorityEnforcer: String, Codable, CaseIterable, Hashable, Sendable {
    case allRoles = "all_roles"
    case kernel
    case reviewerSet = "reviewer_set"
}

public enum DistinctPrincipalPolicy: String, Codable, CaseIterable, Hashable, Sendable {
    case strict
    case notRequired = "not_required"
}

public struct GateAuthorityKey: Hashable, Sendable {
    public let profileID: ProfileID
    public let profileDigest: HashDigest
    public let stage: WorkflowStage
    public let mode: WorkflowMode
    public let riskClass: RiskClass
    public let escalationFlags: Set<AuthorityEscalationFlag>

    init(
        profileID: ProfileID,
        profileDigest: HashDigest,
        stage: WorkflowStage,
        mode: WorkflowMode,
        riskClass: RiskClass,
        escalationFlags: Set<AuthorityEscalationFlag>
    ) {
        self.profileID = profileID
        self.profileDigest = profileDigest
        self.stage = stage
        self.mode = mode
        self.riskClass = riskClass
        self.escalationFlags = escalationFlags
    }

    public static func == (lhs: GateAuthorityKey, rhs: GateAuthorityKey) -> Bool {
        lhs.profileID == rhs.profileID &&
            lhs.profileDigest == rhs.profileDigest &&
            lhs.stage.rawValue == rhs.stage.rawValue &&
            lhs.mode.rawValue == rhs.mode.rawValue &&
            lhs.riskClass == rhs.riskClass &&
            lhs.escalationFlags == rhs.escalationFlags
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(profileID)
        hasher.combine(profileDigest)
        hasher.combine(stage.rawValue)
        hasher.combine(mode.rawValue)
        hasher.combine(riskClass)
        for flag in escalationFlags.sorted(by: { $0.rawValue < $1.rawValue }) {
            hasher.combine(flag)
        }
    }
}

public struct GateAuthorityRequirement: Hashable, Sendable {
    public let requiredRoles: Set<AuthorityRole>
    public let enforcer: AuthorityEnforcer
    public let requiresHuman: Bool
    public let distinctPrincipalPolicy: DistinctPrincipalPolicy

    init(
        requiredRoles: Set<AuthorityRole>,
        enforcer: AuthorityEnforcer,
        requiresHuman: Bool,
        distinctPrincipalPolicy: DistinctPrincipalPolicy
    ) {
        self.requiredRoles = requiredRoles
        self.enforcer = enforcer
        self.requiresHuman = requiresHuman
        self.distinctPrincipalPolicy = distinctPrincipalPolicy
    }
}

public struct GateDecision: Hashable, Sendable {
    public let verdict: GateVerdict

    init(verdict: GateVerdict) {
        self.verdict = verdict
    }
}

private struct GateAuthorityRule: Hashable, Sendable {
    let key: GateAuthorityKey
    let requirement: GateAuthorityRequirement
}

public struct GatePolicy: Sendable {
    public let policyVersion: Int
    public let policyDigest: HashDigest
    private let authorityRules: [GateAuthorityRule]

    private init(
        policyVersion: Int,
        policyDigest: HashDigest,
        authorityRules: [GateAuthorityRule]
    ) throws {
        guard policyVersion == 1,
              !authorityRules.isEmpty,
              Set(authorityRules.map(\.key)).count == authorityRules.count
        else { throw WorkflowPolicyError.invalidPolicy }
        self.policyVersion = policyVersion
        self.policyDigest = policyDigest
        self.authorityRules = authorityRules
    }

    public static func standard(
        profileID: ProfileID,
        profileDigest: HashDigest,
        policyDigest: HashDigest,
        distinctPrincipalPolicy: DistinctPrincipalPolicy,
        specialistReviewersByRisk: [RiskClass: Set<AuthorityRole>]
    ) throws -> GatePolicy {
        let permittedSpecialists: Set<AuthorityRole> = [
            .standardsValidator,
            .securityPrivacyReviewer,
            .dataIntegrityReviewer,
        ]
        let mandatoryHigh: Set<AuthorityRole> = [.securityPrivacyReviewer]
        let mandatoryCritical: Set<AuthorityRole> = [
            .securityPrivacyReviewer,
            .dataIntegrityReviewer,
        ]
        guard specialistReviewersByRisk.values.allSatisfy({
                $0.isSubset(of: permittedSpecialists)
              }),
              specialistReviewersByRisk[.high]?.isSuperset(of: mandatoryHigh) == true,
              specialistReviewersByRisk[.critical]?.isSuperset(of: mandatoryCritical) == true
        else { throw WorkflowPolicyError.invalidPolicy }
        var rules: [GateAuthorityRule] = []
        for stage in authorityGateStages {
            for mode in WorkflowMode.allCases {
                for riskClass in RiskClass.allCases {
                    for flags in escalationFlagCombinations {
                        let key = GateAuthorityKey(
                            profileID: profileID,
                            profileDigest: profileDigest,
                            stage: stage,
                            mode: mode,
                            riskClass: riskClass,
                            escalationFlags: flags
                        )
                        rules.append(
                            GateAuthorityRule(
                                key: key,
                                requirement: requirement(
                                    for: key,
                                    distinctPrincipalPolicy: distinctPrincipalPolicy,
                                    specialistReviewersByRisk: specialistReviewersByRisk
                                )
                            )
                        )
                    }
                }
            }
        }
        return try GatePolicy(
            policyVersion: 1,
            policyDigest: policyDigest,
            authorityRules: rules
        )
    }

    public static func aggregate(_ verdicts: [GateVerdict]) throws -> GateDecision {
        guard let verdict = verdicts.max(by: { $0.precedence < $1.precedence }) else {
            throw WorkflowPolicyError.missingSubstantiveVerdict
        }
        return GateDecision(verdict: verdict)
    }

    public func authorityRequirement(
        stage: WorkflowStage,
        mode: WorkflowMode,
        context: ActivePolicyContext,
        escalationFlags: Set<AuthorityEscalationFlag>
    ) throws -> GateAuthorityRequirement {
        let key = GateAuthorityKey(
            profileID: context.profileID,
            profileDigest: context.profileDigest,
            stage: stage,
            mode: mode,
            riskClass: context.riskClass,
            escalationFlags: escalationFlags
        )
        guard let rule = authorityRules.first(where: { $0.key == key }) else {
            throw WorkflowPolicyError.unknownGate
        }
        return rule.requirement
    }

    public static func classify(
        _ failure: FailureClassification
    ) throws -> StatusClassificationDecision {
        switch failure {
        case .userDecisionRequired, .missingHumanAuthority:
            StatusClassificationDecision(
                status: .waitingForUser,
                verdict: .userInputRequired,
                resolution: .waitForUser,
                correctionTarget: nil
            )
        case .externalPrerequisite:
            StatusClassificationDecision(
                status: .blocked,
                verdict: .blocked,
                resolution: .block,
                correctionTarget: nil
            )
        case let .fixableFinding(rootCause):
            StatusClassificationDecision(
                status: .changesRequired,
                verdict: .changesRequired,
                resolution: .rollback,
                correctionTarget: rootCause
            )
        case .unrecoverableIntegrityViolation:
            StatusClassificationDecision(
                status: .failed,
                verdict: nil,
                resolution: .fail,
                correctionTarget: nil
            )
        }
    }

    private static func requirement(
        for key: GateAuthorityKey,
        distinctPrincipalPolicy: DistinctPrincipalPolicy,
        specialistReviewersByRisk: [RiskClass: Set<AuthorityRole>]
    ) -> GateAuthorityRequirement {
        let requiresHuman: Bool
        var roles: Set<AuthorityRole>
        let enforcer: AuthorityEnforcer
        switch key.stage {
        case .requirementGate:
            roles = [.requirementsValidator]
            enforcer = .allRoles
            requiresHuman = key.mode == .coWorking || humanEscalationRequired(for: key)
        case .designGate:
            roles = [.designValidator]
            enforcer = .allRoles
            requiresHuman = key.mode == .coWorking || humanEscalationRequired(for: key)
        case .architectureGate:
            roles = [.standardsValidator]
            enforcer = .allRoles
            requiresHuman = key.mode == .coWorking || humanEscalationRequired(for: key)
        case .planGate:
            roles = [.planValidator, .testStrategist]
            enforcer = .allRoles
            requiresHuman = key.mode == .coWorking || humanEscalationRequired(for: key)
        case .checkpoint:
            roles = [.kernel]
            enforcer = .kernel
            requiresHuman = false
        case .review:
            roles = [.reviewerSet]
            enforcer = .reviewerSet
            requiresHuman = false
        case .finalGate:
            roles = [.runEvidenceValidator]
            enforcer = .allRoles
            requiresHuman = key.mode == .coWorking || humanEscalationRequired(for: key)
        case .productReleaseGate:
            enforcer = .allRoles
            requiresHuman = key.mode == .coWorking || !key.escalationFlags.isEmpty
            roles = requiresHuman ? [.releaseAuthority] : [.productReleaseValidator]
        default:
            roles = []
            enforcer = .allRoles
            requiresHuman = true
        }
        if enforcer == .allRoles,
           key.mode == .auto,
           !requiresHuman,
           [.designGate, .architectureGate, .finalGate].contains(key.stage) {
            roles.formUnion(specialistReviewersByRisk[key.riskClass] ?? [])
        }
        if enforcer == .allRoles, requiresHuman, key.stage != .productReleaseGate {
            roles = [.authenticatedUser]
        }
        return GateAuthorityRequirement(
            requiredRoles: roles,
            enforcer: enforcer,
            requiresHuman: requiresHuman,
            distinctPrincipalPolicy: distinctPrincipalPolicy
        )
    }

    private static func humanEscalationRequired(for key: GateAuthorityKey) -> Bool {
        switch key.stage {
        case .requirementGate, .designGate:
            key.escalationFlags.contains(.materialAmbiguity) ||
                key.escalationFlags.contains(.waiverRequested)
        case .architectureGate:
            key.escalationFlags.contains(.policyConflict) ||
                key.escalationFlags.contains(.waiverRequested)
        case .planGate:
            key.escalationFlags.contains(.materialAmbiguity) ||
                key.escalationFlags.contains(.policyConflict) ||
                key.escalationFlags.contains(.waiverRequested)
        case .finalGate:
            !key.escalationFlags.isEmpty
        default:
            false
        }
    }
}

private let authorityGateStages: [WorkflowStage] = [
    .requirementGate,
    .designGate,
    .architectureGate,
    .planGate,
    .checkpoint,
    .review,
    .finalGate,
    .productReleaseGate,
]

private let escalationFlagCombinations: [Set<AuthorityEscalationFlag>] = {
    AuthorityEscalationFlag.allCases.reduce([Set<AuthorityEscalationFlag>()]) { partial, flag in
        partial + partial.map { $0.union([flag]) }
    }
}()
