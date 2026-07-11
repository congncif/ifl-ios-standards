import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("IssueDispositionPolicyTests")
struct IssueDispositionPolicyTests {
    @Test("disposition kinds retain all five exact wire values")
    func exactWireValues() throws {
        let values: [(IssueDispositionKind, String)] = [
            (.acceptedCurrentScope, "accepted_current_scope"),
            (.duplicate, "duplicate"),
            (.rejectedWithEvidence, "rejected_with_evidence"),
            (.deferredByPolicy, "deferred_by_policy"),
            (.resolved, "resolved"),
        ]
        for (value, wire) in values {
            let bytes = try CanonicalJSON.encode(value)
            #expect(String(decoding: bytes, as: UTF8.self) == "\"\(wire)\"")
            #expect(try CanonicalJSON.decode(IssueDispositionKind.self, from: bytes) == value)
        }
    }

    @Test("RC-08 initial kind is a closed four-case type without resolved")
    func initialKindExcludesResolved() {
        #expect(InitialIssueDispositionKind.allCases == [
            .acceptedCurrentScope,
            .duplicate,
            .rejectedWithEvidence,
            .deferredByPolicy,
        ])
        #expect(InitialIssueDispositionKind(rawValue: "resolved") == nil)
    }

    @Test("RC-08 accepted scope preserves assignment and scope basis in immutable history")
    func acceptedScopeBasis() throws {
        let input = try dispositionEnvelope(
            evidenceKind: .acceptedScope,
            remediationAssignmentID: "remediation-assignment-1",
            scopeDigest: workflowTestDigest("8")
        )
        let record = try applied(derive(input))
        #expect(record.current == .acceptedCurrentScope)
        guard case let .acceptedCurrentScope(basis) = record.basis else {
            Issue.record("expected accepted-current-scope basis")
            return
        }
        let expectedScopeDigest = try workflowTestDigest("8")
        #expect(basis.remediationAssignmentID == "remediation-assignment-1")
        #expect(basis.scopeDigest == expectedScopeDigest)
        #expect(record.history.count == 1)
        #expect(record.history[0].basis == record.basis)
    }

    @Test("RC-08 duplicate fixture preserves canonical target and equivalence basis")
    func duplicateBasis() throws {
        let input = try dispositionFixture("disposition-duplicate-linked.json")
        let record = try applied(derive(input))
        guard case let .duplicate(basis) = record.basis else {
            Issue.record("expected duplicate basis")
            return
        }
        #expect(basis.canonicalFingerprint == input.canonicalFingerprint)
        #expect(basis.equivalenceEvidenceReferences == input.equivalenceEvidenceReferences)
        #expect(record.current == .duplicate)
        #expect(!record.entersRemediation)
    }

    @Test("RC-08 rejection and deferral fixtures retain their complete basis")
    func rejectionAndDeferralBasis() throws {
        let rejectedInput = try dispositionFixture("disposition-rejected-with-evidence.json")
        let rejected = try applied(derive(rejectedInput))
        guard case let .rejectedWithEvidence(basis) = rejected.basis else {
            Issue.record("expected rejection basis")
            return
        }
        #expect(basis.evidenceReferences == rejectedInput.refutationEvidenceReferences)

        let deferredInput = try dispositionFixture("disposition-deferred-by-policy.json")
        let deferred = try applied(derive(deferredInput))
        guard case let .deferredByPolicy(basis) = deferred.basis else {
            Issue.record("expected deferral basis")
            return
        }
        #expect(basis.governingClauseDigest == deferredInput.governingClauseDigest)
        #expect(basis.accountableOwner == deferredInput.accountableOwner)
        #expect(basis.scope == deferredInput.deferredScope)
        #expect(basis.revisitCondition == deferredInput.revisitCondition)
    }

    @Test("RC-03 verified disposition authority cannot be manufactured by fixture claims")
    func forgedAuthorityIsRejected() throws {
        let forged = try dispositionFixture("disposition-agent-forged.json")
        #expect(throws: WorkflowPolicyError.invalidDispositionEvidence) {
            try IssueDispositionPolicy().deriveInitial(
                from: forged,
                verifiedAuthority: verifiedAuthority(for: forged, kind: .kernel),
                frozenPolicy: dispositionPolicy()
            )
        }
    }

    @Test("RC-08 unsupported duplicate and must-fix deferral still fail")
    func unsupportedDispositionFacts() throws {
        for filename in [
            "disposition-duplicate-unlinked.json",
            "disposition-deferred-must-fix.json",
        ] {
            let input = try dispositionFixture(filename)
            #expect(throws: WorkflowPolicyError.invalidDispositionEvidence) {
                try derive(input)
            }
        }
    }

    @Test("RC-08 authenticated conflicting facts wait for exact user control")
    func conflictingFactsWaitForUser() throws {
        let input = try dispositionEnvelope(
            evidenceKind: .equivalence,
            canonicalFingerprint: fingerprint("canonical"),
            equivalenceEvidenceReferences: ["equivalence-proof"],
            governingClauseDigest: workflowTestDigest("9"),
            accountableOwner: "ios-owner",
            deferredScope: "candidate-scope",
            revisitCondition: "before-release",
            authorityEvidenceReferences: ["equivalence-proof"]
        )
        guard case let .waitingForUser(request) = try derive(input) else {
            Issue.record("expected waiting-for-user disposition")
            return
        }
        #expect(request == .userInputReceived)
    }

    @Test("RC-08 authenticated unclassifiable facts wait instead of throwing")
    func unclassifiableFactsWaitForUser() throws {
        let input = try dispositionEnvelope(evidenceKind: nil)
        guard case let .waitingForUser(request) = try derive(input) else {
            Issue.record("expected waiting-for-user disposition")
            return
        }
        #expect(request == .userInputReceived)
    }

    @Test("Residual D-003 missing governing-policy owner waits after hard policy checks")
    func missingDeferralOwnerWaitsButUnsupportedDeferralFails() throws {
        let ambiguous = try dispositionEnvelope(
            evidenceKind: .governingPolicy,
            governingClauseDigest: workflowTestDigest("9"),
            accountableOwner: nil,
            deferredScope: "candidate-scope",
            revisitCondition: "before-release"
        )
        guard case let .waitingForUser(request) = try derive(ambiguous) else {
            Issue.record("expected missing accountable owner to wait for user")
            return
        }
        #expect(request == .userInputReceived)

        let unsupported = try dispositionEnvelope(
            evidenceKind: .governingPolicy,
            mustFix: true,
            governingClauseDigest: workflowTestDigest("9"),
            accountableOwner: nil,
            deferredScope: "candidate-scope",
            revisitCondition: "before-release"
        )
        #expect(throws: WorkflowPolicyError.invalidDispositionEvidence) {
            try derive(unsupported)
        }
    }

    @Test("exact disposition evidence references must match verified authority")
    func exactEvidenceBinding() throws {
        let input = try dispositionEnvelope(
            evidenceKind: .equivalence,
            canonicalFingerprint: fingerprint("canonical"),
            equivalenceEvidenceReferences: ["equivalence-proof"],
            authorityEvidenceReferences: ["unrelated-proof"]
        )
        #expect(throws: WorkflowPolicyError.invalidDispositionEvidence) {
            try derive(input)
        }
    }
}

private func dispositionFixture(_ filename: String) throws -> DispositionEvidenceEnvelope {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("verification/fixtures/workflow/review/\(filename)")
    return try CanonicalJSON.decode(
        DispositionEvidenceEnvelope.self,
        from: Data(contentsOf: url)
    )
}

private func dispositionPolicy() throws -> FrozenDispositionPolicy {
    try FrozenDispositionPolicy(
        digest: workflowTestDigest("6"),
        authorizedPrincipalIDs: [PrincipalID(validating: "kernel-principal")],
        mandatorySeverities: [.critical],
        permitsAuthenticatedHumanRiskAcceptance: false
    )
}

private func derive(
    _ input: DispositionEvidenceEnvelope
) throws -> IssueDispositionDecision {
    try IssueDispositionPolicy().deriveInitial(
        from: input,
        verifiedAuthority: verifiedAuthority(for: input, kind: .kernel),
        frozenPolicy: dispositionPolicy()
    )
}

private func verifiedAuthority(
    for input: DispositionEvidenceEnvelope,
    kind: VerifiedDispositionAuthorityKind
) -> VerifiedDispositionAuthorityFact {
    VerifiedDispositionAuthorityFact(
        actorID: input.authority.actorID,
        principalID: input.authority.principalID,
        kind: kind,
        authorityPolicyDigest: input.authority.authorityPolicyDigest,
        rationaleDigest: input.authority.rationaleDigest,
        evidenceReferences: input.authority.evidenceReferences
    )
}

private func dispositionEnvelope(
    evidenceKind: DispositionEvidenceKind?,
    mustFix: Bool = false,
    remediationAssignmentID: String? = nil,
    scopeDigest: HashDigest? = nil,
    canonicalFingerprint: FailureFingerprint? = nil,
    equivalenceEvidenceReferences: [String] = [],
    refutationEvidenceReferences: [String] = [],
    governingClauseDigest: HashDigest? = nil,
    accountableOwner: String? = nil,
    deferredScope: String? = nil,
    revisitCondition: String? = nil,
    humanRiskAcceptance: Bool = false,
    authorityEvidenceReferences: [String] = ["evidence-1"]
) throws -> DispositionEvidenceEnvelope {
    let authority = try DispositionAuthorityClaim(
        actorID: ActorID(validating: "kernel-actor"),
        principalID: PrincipalID(validating: "kernel-principal"),
        claimedKind: .kernel,
        claimedAuthenticated: true,
        authorityPolicyDigest: workflowTestDigest("6"),
        rationaleDigest: workflowTestDigest("7"),
        evidenceReferences: authorityEvidenceReferences
    )
    return try DispositionEvidenceEnvelope(
        issueFingerprint: fingerprint("issue"),
        severity: .medium,
        mustFix: mustFix,
        evidenceKind: evidenceKind,
        remediationAssignmentID: remediationAssignmentID,
        scopeDigest: scopeDigest,
        canonicalFingerprint: canonicalFingerprint,
        equivalenceEvidenceReferences: equivalenceEvidenceReferences,
        refutationEvidenceReferences: refutationEvidenceReferences,
        governingClauseDigest: governingClauseDigest,
        accountableOwner: accountableOwner,
        deferredScope: deferredScope,
        revisitCondition: revisitCondition,
        humanRiskAcceptance: humanRiskAcceptance,
        disputed: false,
        authority: authority
    )
}

private func fingerprint(_ value: String) throws -> FailureFingerprint {
    try failure("disposition-\(value)")
}

private func applied(_ decision: IssueDispositionDecision) throws -> IssueDispositionRecord {
    guard case let .applied(record) = decision else {
        throw WorkflowPolicyError.invalidDispositionEvidence
    }
    return record
}
