@testable import IFLWorkflow
import Testing

@Suite("RollbackTests")
struct RollbackTests {
    @Test("RC-07 verified root cause returns target and full downstream invalidation closure")
    func downstreamInvalidationClosure() throws {
        let fact = try rootCause(
            failingStage: .finalGate,
            target: .requirements,
            relation: .targetFeedsFailure
        )
        let decision = try RollbackPolicy.decide(fact)
        #expect(decision.target == .requirements)
        #expect(decision.invalidatedStages == [
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
        ])
    }

    @Test("RC-07 execute root cause invalidates only execution downstream")
    func executionClosure() throws {
        let decision = try RollbackPolicy.decide(
            rootCause(
                failingStage: .checkpoint,
                target: .executePhase,
                relation: .targetFeedsFailure
            )
        )
        #expect(decision.target == .executePhase)
        #expect(decision.invalidatedStages == [
            .executePhase, .checkpoint, .review, .finalVerification, .finalGate,
        ])
    }

    @Test("RC-07 asserted target without a legal dependency relation is rejected")
    func invalidRootCauseRelation() throws {
        #expect(throws: WorkflowPolicyError.invalidRootCauseFact) {
            try RollbackPolicy.decide(
                rootCause(
                    failingStage: .requirements,
                    target: .plan,
                    relation: .targetFeedsFailure
                )
            )
        }
        #expect(throws: WorkflowPolicyError.invalidRootCauseFact) {
            try RollbackPolicy.decide(
                rootCause(
                    failingStage: .finalGate,
                    target: .requirements,
                    relation: .unverified
                )
            )
        }
    }

    @Test("root cause targets form a closed authoring-only set")
    func closedTargets() {
        #expect(Set(RootCauseStage.allCases) == [
            .requirements, .design, .architecture, .plan, .executePhase,
        ])
    }
}

private func rootCause(
    failingStage: WorkflowStage,
    target: RootCauseStage,
    relation: RootCauseDependencyRelation
) throws -> VerifiedRootCauseFact {
    try VerifiedRootCauseFact(
        failingStage: failingStage,
        failingCheckID: "workflow-check",
        evidenceDigest: workflowTestDigest("1"),
        policyDigest: workflowTestDigest("2"),
        dependencyRelation: relation,
        target: target
    )
}
