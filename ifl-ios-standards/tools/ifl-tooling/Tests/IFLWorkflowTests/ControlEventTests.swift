@testable import IFLWorkflow
import Testing

@Suite("ControlEventTests")
struct ControlEventTests {
    @Test("RC-03 exact verified control proof clears its bound pending hold")
    func exactControlProof() throws {
        let pending = try pendingControl(status: .waitingForUser)
        let proof = try controlProof(revalidationPassed: true)
        let decision = try ControlEventPolicy().resolve(pending: pending, proof: proof)

        #expect(decision.eventKind == .userInputReceived)
        #expect(decision.nextStatus == .running)
        #expect(decision.resolution == .continueWorkflow)
    }

    @Test("RC-03 insufficient revalidation remains held")
    func incompleteControlProofRemainsHeld() throws {
        let pending = try pendingControl(status: .blocked)
        let proof = try controlProof(revalidationPassed: false)
        let decision = try ControlEventPolicy().resolve(pending: pending, proof: proof)

        #expect(decision.eventKind == nil)
        #expect(decision.nextStatus == .blocked)
        #expect(decision.resolution == .block)
    }

    @Test("RC-03 stale reason event head and pending identity cannot clear a hold")
    func mismatchedControlProof() throws {
        let pending = try pendingControl(status: .waitingForUser)
        let valid = try controlProof(revalidationPassed: true)
        for proof in [
            try VerifiedControlResolutionFact(
                actorID: valid.actorID,
                principalID: valid.principalID,
                policyDigest: valid.policyDigest,
                pendingControlID: "other-pending",
                pendingReasonDigest: valid.pendingReasonDigest,
                pendingEventHead: valid.pendingEventHead,
                resolutionEvidenceDigest: valid.resolutionEvidenceDigest,
                revalidationPassed: true
            ),
            try VerifiedControlResolutionFact(
                actorID: valid.actorID,
                principalID: valid.principalID,
                policyDigest: valid.policyDigest,
                pendingControlID: valid.pendingControlID,
                pendingReasonDigest: workflowTestDigest("d"),
                pendingEventHead: valid.pendingEventHead,
                resolutionEvidenceDigest: valid.resolutionEvidenceDigest,
                revalidationPassed: true
            ),
            try VerifiedControlResolutionFact(
                actorID: valid.actorID,
                principalID: valid.principalID,
                policyDigest: valid.policyDigest,
                pendingControlID: valid.pendingControlID,
                pendingReasonDigest: valid.pendingReasonDigest,
                pendingEventHead: workflowTestDigest("e"),
                resolutionEvidenceDigest: valid.resolutionEvidenceDigest,
                revalidationPassed: true
            ),
        ] {
            #expect(throws: WorkflowPolicyError.invalidControlProof) {
                try ControlEventPolicy().resolve(pending: pending, proof: proof)
            }
        }
    }

    @Test("lifecycle controls remain deterministic but cannot impersonate hold resolution")
    func lifecycleControls() throws {
        let policy = ControlEventPolicy()
        #expect(
            try policy.decideLifecycle(status: .running, request: .pause).eventKind == .pause
        )
        #expect(
            try policy.decideLifecycle(status: .paused, request: .resume).eventKind == .resume
        )
        #expect(throws: WorkflowPolicyError.illegalControlRequest) {
            try policy.decideLifecycle(status: .waitingForUser, request: .userInputReceived)
        }
        #expect(throws: WorkflowPolicyError.illegalControlRequest) {
            try policy.decideLifecycle(status: .blocked, request: .blockerResolved)
        }
    }
}

private func pendingControl(status: RunStatus) throws -> PendingControlFact {
    try PendingControlFact(
        id: "pending-control",
        status: status,
        reasonDigest: workflowTestDigest("a"),
        eventHead: workflowTestDigest("b"),
        policyDigest: workflowTestDigest("c")
    )
}

private func controlProof(
    revalidationPassed: Bool
) throws -> VerifiedControlResolutionFact {
    try VerifiedControlResolutionFact(
        actorID: ActorID(validating: "control-actor"),
        principalID: PrincipalID(validating: "control-principal"),
        policyDigest: workflowTestDigest("c"),
        pendingControlID: "pending-control",
        pendingReasonDigest: workflowTestDigest("a"),
        pendingEventHead: workflowTestDigest("b"),
        resolutionEvidenceDigest: workflowTestDigest("f"),
        revalidationPassed: revalidationPassed
    )
}
