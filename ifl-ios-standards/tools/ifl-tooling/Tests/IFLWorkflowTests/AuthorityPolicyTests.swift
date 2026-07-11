import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("AuthorityPolicyTests")
struct AuthorityPolicyTests {
    @Test("RC-01 authority attaches approval only to substantive approval")
    func authorityCannotCreateGateSatisfaction() throws {
        let setup = try authoritySetup(risk: .medium)
        let changes = try GatePolicy.aggregate([.changesRequired])
        let untouched = try setup.authority.qualify(
            gateDecision: changes,
            stage: .designGate,
            mode: .auto,
            context: setup.context,
            escalationFlags: [],
            evidence: AuthorityEvidence(author: nil, validators: [])
        )
        #expect(untouched.substantiveVerdict == .changesRequired)
        #expect(untouched.finalVerdict == .changesRequired)
        #expect(untouched.approvalKind == nil)

        let approved = try GatePolicy.aggregate([.approved])
        let missingAuthority = try setup.authority.qualify(
            gateDecision: approved,
            stage: .designGate,
            mode: .auto,
            context: setup.context,
            escalationFlags: [],
            evidence: AuthorityEvidence(author: nil, validators: [])
        )
        #expect(missingAuthority.substantiveVerdict == .approved)
        #expect(missingAuthority.finalVerdict == .userInputRequired)
        #expect(missingAuthority.approvalKind == nil)
    }

    @Test("RC-04 approval kinds use uppercase canonical wire values only")
    func approvalWireValues() throws {
        let values: [(ApprovalKind, String)] = [
            (.userApproved, "USER_APPROVED"),
            (.autoApproved, "AUTO_APPROVED"),
        ]
        for (value, wire) in values {
            let bytes = try CanonicalJSON.encode(value)
            #expect(String(decoding: bytes, as: UTF8.self) == "\"\(wire)\"")
            #expect(try CanonicalJSON.decode(ApprovalKind.self, from: bytes) == value)
            #expect(throws: Error.self) {
                try CanonicalJSON.decode(
                    ApprovalKind.self,
                    from: Data("\"\(wire.lowercased())\"".utf8)
                )
            }
        }
    }

    @Test("RC-02 matrix binds profile gate roles and enforcer exactly")
    func exactEightGateMatrix() throws {
        let setup = try authoritySetup(risk: .medium)
        let rows: [(WorkflowStage, Set<AuthorityRole>, AuthorityEnforcer)] = [
            (.requirementGate, [.requirementsValidator], .allRoles),
            (.designGate, [.designValidator], .allRoles),
            (.architectureGate, [.standardsValidator], .allRoles),
            (.planGate, [.planValidator, .testStrategist], .allRoles),
            (.checkpoint, [.kernel], .kernel),
            (.review, [.reviewerSet], .reviewerSet),
            (.finalGate, [.runEvidenceValidator], .allRoles),
            (.productReleaseGate, [.productReleaseValidator], .allRoles),
        ]

        for (stage, roles, enforcer) in rows {
            let requirement = try setup.policy.authorityRequirement(
                stage: stage,
                mode: .auto,
                context: setup.context,
                escalationFlags: []
            )
            #expect(requirement.requiredRoles == roles)
            #expect(requirement.enforcer == enforcer)
            #expect(requirement.distinctPrincipalPolicy == .strict)
        }

        let otherProfile = try ActivePolicyContext(
            profileID: ProfileID(validating: "other-profile"),
            profileDigest: workflowTestDigest("f"),
            riskClass: .medium
        )
        #expect(throws: WorkflowPolicyError.unknownGate) {
            try setup.policy.authorityRequirement(
                stage: .planGate,
                mode: .auto,
                context: otherProfile,
                escalationFlags: []
            )
        }
    }

    @Test("Residual A-002 rejects omitted or incomplete mandatory risk specialists")
    func mandatoryRiskSpecialistConfiguration() throws {
        let profileID = try ProfileID(validating: "specialist-profile")
        let profileDigest = try workflowTestDigest("1")
        let policyDigest = try workflowTestDigest("2")
        let invalidConfigurations: [[RiskClass: Set<AuthorityRole>]] = [
            [:],
            [
                .high: [],
                .critical: [.securityPrivacyReviewer, .dataIntegrityReviewer],
            ],
            [
                .high: [.securityPrivacyReviewer],
                .critical: [.securityPrivacyReviewer],
            ],
            [
                .high: [.securityPrivacyReviewer],
                .critical: [.dataIntegrityReviewer],
            ],
        ]

        for configuration in invalidConfigurations {
            #expect(throws: WorkflowPolicyError.invalidPolicy) {
                try GatePolicy.standard(
                    profileID: profileID,
                    profileDigest: profileDigest,
                    policyDigest: policyDigest,
                    distinctPrincipalPolicy: .strict,
                    specialistReviewersByRisk: configuration
                )
            }
        }
    }

    @Test("RC-02 risk escalation is gate-specific and checkpoint review stay owner-controlled")
    func gateSpecificEscalation() throws {
        let high = try authoritySetup(risk: .high)
        #expect(
            try high.policy.authorityRequirement(
                stage: .requirementGate,
                mode: .auto,
                context: high.context,
                escalationFlags: []
            ).requiresHuman == false
        )
        let highRows: [(WorkflowStage, Set<AuthorityRole>)] = [
            (.designGate, [.designValidator, .securityPrivacyReviewer]),
            (.architectureGate, [.standardsValidator, .securityPrivacyReviewer]),
            (.finalGate, [.runEvidenceValidator, .securityPrivacyReviewer]),
        ]
        for (stage, roles) in highRows {
            let requirement = try high.policy.authorityRequirement(
                stage: stage,
                mode: .auto,
                context: high.context,
                escalationFlags: []
            )
            #expect(requirement.requiresHuman == false)
            #expect(requirement.requiredRoles == roles)
        }

        let critical = try authoritySetup(risk: .critical)
        for stage: WorkflowStage in [.designGate, .architectureGate, .finalGate] {
            let requirement = try critical.policy.authorityRequirement(
                stage: stage,
                mode: .auto,
                context: critical.context,
                escalationFlags: []
            )
            #expect(requirement.requiresHuman == false)
            #expect(requirement.requiredRoles.contains(.securityPrivacyReviewer))
            #expect(requirement.requiredRoles.contains(.dataIntegrityReviewer))
        }
        for stage: WorkflowStage in [.checkpoint, .review] {
            let requirement = try high.policy.authorityRequirement(
                stage: stage,
                mode: .coWorking,
                context: high.context,
                escalationFlags: [.waiverRequested]
            )
            #expect(requirement.requiresHuman == false)
        }
    }

    @Test("RC-02 plan requires both independent validator roles")
    func planRoleAndIndependenceClosure() throws {
        let setup = try authoritySetup(risk: .medium)
        let decision = try GatePolicy.aggregate([.approved])
        let author = try authorityFact(
            "author",
            roles: [.author],
            context: "a",
            kind: .agent
        )
        let planValidator = try authorityFact(
            "plan-validator",
            roles: [.planValidator],
            context: "b",
            kind: .agent
        )
        let testStrategist = try authorityFact(
            "test-strategist",
            roles: [.testStrategist],
            context: "c",
            kind: .agent
        )

        let approved = try setup.authority.qualify(
            gateDecision: decision,
            stage: .planGate,
            mode: .auto,
            context: setup.context,
            escalationFlags: [],
            evidence: AuthorityEvidence(author: author, validators: [planValidator, testStrategist])
        )
        #expect(approved.finalVerdict == .approved)
        #expect(approved.approvalKind == .autoApproved)

        let missingRole = try setup.authority.qualify(
            gateDecision: decision,
            stage: .planGate,
            mode: .auto,
            context: setup.context,
            escalationFlags: [],
            evidence: AuthorityEvidence(author: author, validators: [planValidator])
        )
        #expect(missingRole.finalVerdict == .userInputRequired)

        let sourceWriter = try authorityFact(
            "test-strategist-writer",
            roles: [.testStrategist],
            context: "c",
            kind: .agent,
            hasSourceWriteCapability: true
        )
        let notIndependent = try setup.authority.qualify(
            gateDecision: decision,
            stage: .planGate,
            mode: .auto,
            context: setup.context,
            escalationFlags: [],
            evidence: AuthorityEvidence(author: author, validators: [planValidator, sourceWriter])
        )
        #expect(notIndependent.finalVerdict == .userInputRequired)
    }

    @Test("Residual A-002 Product Release uses release authority only for co-working or exception")
    func productReleaseAuthorityRows() throws {
        let setup = try authoritySetup(risk: .medium)
        let decision = try GatePolicy.aggregate([.approved])
        let author = try authorityFact(
            "release-assembler",
            roles: [.author],
            context: "1",
            kind: .agent
        )
        let validator = try authorityFact(
            "product-release-validator",
            roles: [.productReleaseValidator],
            context: "2",
            kind: .agent
        )
        let releaseAuthority = try authorityFact(
            "release-authority",
            roles: [.releaseAuthority],
            context: "3",
            kind: .human
        )

        let automatic = try setup.authority.qualify(
            gateDecision: decision,
            stage: .productReleaseGate,
            mode: .auto,
            context: setup.context,
            escalationFlags: [],
            evidence: AuthorityEvidence(author: author, validators: [validator])
        )
        #expect(automatic.finalVerdict == .approved)
        #expect(automatic.approvalKind == .autoApproved)

        let coWorking = try setup.authority.qualify(
            gateDecision: decision,
            stage: .productReleaseGate,
            mode: .coWorking,
            context: setup.context,
            escalationFlags: [],
            evidence: AuthorityEvidence(author: author, validators: [releaseAuthority])
        )
        #expect(coWorking.finalVerdict == .approved)
        #expect(coWorking.approvalKind == .userApproved)

        let exceptionWithoutHuman = try setup.authority.qualify(
            gateDecision: decision,
            stage: .productReleaseGate,
            mode: .auto,
            context: setup.context,
            escalationFlags: [.waiverRequested],
            evidence: AuthorityEvidence(author: author, validators: [validator])
        )
        #expect(exceptionWithoutHuman.finalVerdict == .userInputRequired)
        #expect(exceptionWithoutHuman.approvalKind == nil)
    }

    @Test("Residual A-005 principal overlay never relaxes actor context or write independence")
    func principalOverlayOnlyRelaxesPrincipalInequality() throws {
        let relaxed = try authoritySetup(risk: .medium, distinctPrincipals: .notRequired)
        let strict = try authoritySetup(risk: .medium, distinctPrincipals: .strict)
        let decision = try GatePolicy.aggregate([.approved])
        let author = try authorityFact(
            "shared-author",
            roles: [.author],
            context: "4",
            kind: .agent,
            principalID: "shared-principal"
        )
        let plan = try authorityFact(
            "shared-plan",
            roles: [.planValidator],
            context: "5",
            kind: .agent,
            principalID: "shared-principal"
        )
        let strategist = try authorityFact(
            "shared-strategist",
            roles: [.testStrategist],
            context: "6",
            kind: .agent,
            principalID: "shared-principal"
        )

        let accepted = try relaxed.authority.qualify(
            gateDecision: decision,
            stage: .planGate,
            mode: .auto,
            context: relaxed.context,
            escalationFlags: [],
            evidence: AuthorityEvidence(author: author, validators: [plan, strategist])
        )
        #expect(accepted.finalVerdict == .approved)

        let strictRejection = try strict.authority.qualify(
            gateDecision: decision,
            stage: .planGate,
            mode: .auto,
            context: strict.context,
            escalationFlags: [],
            evidence: AuthorityEvidence(author: author, validators: [plan, strategist])
        )
        #expect(strictRejection.finalVerdict == .userInputRequired)

        let writer = try authorityFact(
            "shared-writer",
            roles: [.testStrategist],
            context: "6",
            kind: .agent,
            hasSourceWriteCapability: true,
            principalID: "shared-principal"
        )
        let stillRejected = try relaxed.authority.qualify(
            gateDecision: decision,
            stage: .planGate,
            mode: .auto,
            context: relaxed.context,
            escalationFlags: [],
            evidence: AuthorityEvidence(author: author, validators: [plan, writer])
        )
        #expect(stillRejected.finalVerdict == .userInputRequired)
    }

    @Test("Residual A-008 non-approved factory input excludes approved by construction")
    func nonApprovedDecisionFactoryIsClosed() {
        #expect(NonApprovedGateVerdict.allCases == [
            .changesRequired,
            .userInputRequired,
            .blocked,
        ])
        for verdict in NonApprovedGateVerdict.allCases {
            let decision = ApprovalDecision.noApprovalRequired(verdict)
            #expect(decision.substantiveVerdict == verdict.gateVerdict)
            #expect(decision.finalVerdict == verdict.gateVerdict)
            #expect(decision.approvalKind == nil)
        }
    }

    @Test("RC-02 checkpoint and review use verified owner facts instead of human authority")
    func kernelAndReviewerOwnership() throws {
        let setup = try authoritySetup(risk: .critical)
        let substantive = try GatePolicy.aggregate([.approved])
        let kernel = try authorityFact(
            "kernel",
            roles: [.kernel],
            context: "d",
            kind: .kernel
        )
        let reviewers = try authorityFact(
            "reviewer-set",
            roles: [.reviewerSet],
            context: "e",
            kind: .reviewerSet
        )

        let checkpoint = try setup.authority.qualify(
            gateDecision: substantive,
            stage: .checkpoint,
            mode: .coWorking,
            context: setup.context,
            escalationFlags: [.materialAmbiguity],
            evidence: AuthorityEvidence(author: nil, validators: [kernel])
        )
        #expect(checkpoint.finalVerdict == .approved)
        #expect(checkpoint.approvalKind == .autoApproved)

        let review = try setup.authority.qualify(
            gateDecision: substantive,
            stage: .review,
            mode: .coWorking,
            context: setup.context,
            escalationFlags: [.policyConflict],
            evidence: AuthorityEvidence(author: nil, validators: [reviewers])
        )
        #expect(review.finalVerdict == .approved)
        #expect(review.approvalKind == .autoApproved)
    }

    @Test("Residual A-006 mode changes are directional and same-mode is idempotent")
    func modeChangeGuards() throws {
        let policy = try authoritySetup(risk: .medium).authority
        let head = try workflowTestDigest("9")
        let allowed = VerifiedModeChangeFact(
            currentMode: .coWorking,
            targetMode: .auto,
            atCheckpoint: true,
            userAuthorized: true,
            reevaluationPassed: true,
            eventHead: head
        )
        #expect(try policy.decideModeChange(allowed) == .allowed(.auto))

        let missingUser = VerifiedModeChangeFact(
            currentMode: .coWorking,
            targetMode: .auto,
            atCheckpoint: true,
            userAuthorized: false,
            reevaluationPassed: true,
            eventHead: head
        )
        #expect(try policy.decideModeChange(missingUser) == .waitingForUser)

        let enterCoWorking = VerifiedModeChangeFact(
            currentMode: .auto,
            targetMode: .coWorking,
            atCheckpoint: true,
            userAuthorized: false,
            reevaluationPassed: false,
            eventHead: head
        )
        #expect(try policy.decideModeChange(enterCoWorking) == .allowed(.coWorking))

        let sameMode = VerifiedModeChangeFact(
            currentMode: .auto,
            targetMode: .auto,
            atCheckpoint: false,
            userAuthorized: false,
            reevaluationPassed: false,
            eventHead: head
        )
        #expect(try policy.decideModeChange(sameMode) == .allowed(.auto))

        let outsideCheckpoint = VerifiedModeChangeFact(
            currentMode: .auto,
            targetMode: .coWorking,
            atCheckpoint: false,
            userAuthorized: true,
            reevaluationPassed: true,
            eventHead: head
        )
        #expect(try policy.decideModeChange(outsideCheckpoint) == .changesRequired)
    }
}

private struct AuthoritySetup {
    let context: ActivePolicyContext
    let policy: GatePolicy
    let authority: AuthorityPolicy
}

private func authoritySetup(
    risk: RiskClass,
    distinctPrincipals: DistinctPrincipalPolicy = .strict
) throws -> AuthoritySetup {
    let profileID = try ProfileID(validating: "enterprise-default")
    let profileDigest = try workflowTestDigest("4")
    let context = try ActivePolicyContext(
        profileID: profileID,
        profileDigest: profileDigest,
        riskClass: risk
    )
    let policy = try GatePolicy.standard(
        profileID: profileID,
        profileDigest: profileDigest,
        policyDigest: workflowTestDigest("3"),
        distinctPrincipalPolicy: distinctPrincipals,
        specialistReviewersByRisk: [
            .high: [.securityPrivacyReviewer],
            .critical: [.securityPrivacyReviewer, .dataIntegrityReviewer],
        ]
    )
    return AuthoritySetup(
        context: context,
        policy: policy,
        authority: AuthorityPolicy(gatePolicy: policy)
    )
}

private func authorityFact(
    _ value: String,
    roles: Set<AuthorityRole>,
    context: Character,
    kind: VerifiedPrincipalKind,
    hasAuthorshipEdge: Bool = false,
    hasSourceWriteCapability: Bool = false,
    principalID: String? = nil
) throws -> VerifiedAuthorityFact {
    VerifiedAuthorityFact(
        actorID: try ActorID(validating: "actor-\(value)"),
        principalID: try PrincipalID(validating: principalID ?? "principal-\(value)"),
        roles: roles,
        principalKind: kind,
        independentContextDigest: try workflowTestDigest(context),
        hasAuthorshipEdge: hasAuthorshipEdge,
        hasSourceWriteCapability: hasSourceWriteCapability
    )
}
