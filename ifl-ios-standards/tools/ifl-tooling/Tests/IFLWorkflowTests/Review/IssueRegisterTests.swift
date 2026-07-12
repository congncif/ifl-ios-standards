import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("IssueRegisterTests")
struct IssueRegisterTests {
    @Test("fingerprint includes only the closed typed stable component set")
    func stableTypedFingerprint() throws {
        let components = try laneAIssueComponents()
        let expected = try IssueFingerprint.derive(from: components)
        #expect(expected.rawValue
            == "3c9d7aa47d21de2a5f83211213942feda4abcbafab0157d67e1966152a21cbd5")

        let first = try ReviewerFinding(
            findingID: "finding-first",
            components: components,
            severity: .low,
            mustFixClaim: false,
            title: "First prose",
            message: "First message",
            evidenceReferences: ["evidence-first"],
            confidenceBasis: "manual-confidence",
            reportedAt: "2026-07-12T00:00:00.000Z"
        )
        let second = try ReviewerFinding(
            findingID: "finding-second",
            components: components,
            severity: .critical,
            mustFixClaim: true,
            title: "Completely different prose",
            message: "Completely different message",
            evidenceReferences: ["evidence-second"],
            confidenceBasis: "static-confidence",
            reportedAt: "2030-01-01T00:00:00.000Z"
        )
        #expect(try IssueFingerprint.derive(from: first.components)
            == IssueFingerprint.derive(from: second.components))

        let mutations = try [
            laneAIssueComponents(identity: ReviewFindingIdentity(kind: .check, value: "CHK-ARCH-001")),
            laneAIssueComponents(artifactID: "artifact-other"),
            laneAIssueComponents(scope: "workflow.other"),
            laneAIssueComponents(location: "architecture/presenter"),
            laneAIssueComponents(invariant: "presenter-owns-formatting"),
            laneAIssueComponents(expected: "display_only"),
            laneAIssueComponents(actual: "view_formats_value"),
        ]
        let fingerprints = try mutations.map(IssueFingerprint.derive(from:))
        #expect(Set(fingerprints).count == mutations.count)
        #expect(!Set(fingerprints).contains(expected))
    }

    @Test("register deterministically merges exact duplicate fingerprints and every source")
    func deterministicRegisterJoin() throws {
        let fixture = try LaneARegisterFixture.make()
        let reverseFixture = try LaneARegisterFixture.make(reverseArrival: true)
        let forward = try fixture.issue()
        let reverse = try reverseFixture.issue()

        #expect(forward.baselineDigest == fixture.baseline.baseline.digest)
        #expect(forward.roundID == fixture.baseline.baseline.roundID)
        #expect(forward.rosterDigest == fixture.baseline.roster.digest)
        #expect(forward.entries.count == 1)
        let entry = try #require(forward.entries.first)
        #expect(entry.fingerprint == fixture.fingerprint)
        #expect(entry.severity == .critical)
        #expect(entry.mustFix)
        #expect(entry.sources.count == 2)
        #expect(Set(entry.sources.map(\.assignmentID)).count == 2)
        #expect(forward.dispositions.count == 1)
        #expect(forward.dispositions[0].fingerprint == fixture.fingerprint.failureFingerprint)
        #expect(forward.dispositions[0].current == .acceptedCurrentScope)
        #expect(forward.acceptedCurrentScopeAssignments == [fixture.fingerprint.failureFingerprint])
        #expect(forward.pathDecision == .requiresRemediation)
        #expect(try CanonicalJSON.encode(forward) == CanonicalJSON.encode(reverse))
        #expect(forward.digest == reverse.digest)
        #expect(try digestOmittingRegisterDigest(from: CanonicalJSON.encode(forward))
            == forward.digest)
    }

    @Test("every joined entry requires exactly one kernel-derived disposition")
    func exactDispositionAuthority() throws {
        let fixture = try LaneARegisterFixture.make()
        #expect(throws: (any Error).self) {
            try fixture.issue(dispositionEvidence: [])
        }
        #expect(throws: (any Error).self) {
            try fixture.issue(
                dispositionEvidence: fixture.verifiedDispositionEvidence +
                    fixture.verifiedDispositionEvidence
            )
        }

        let ambiguous = try fixture.verifiedDispositionEvidence(disputed: true)
        #expect(throws: (any Error).self) {
            try fixture.issue(dispositionEvidence: [ambiguous])
        }

        let register = try fixture.issue()
        let bytes = try CanonicalJSON.encode(register)
        #expect(try IssueRegister.decodeCanonical(from: bytes) == register)

        var object = try registerJSONObject(bytes)
        var dispositions = try #require(object["dispositions"] as? [[String: Any]])
        dispositions[0]["current"] = "resolved"
        object["dispositions"] = dispositions
        #expect(throws: (any Error).self) {
            try IssueRegister.decodeCanonical(from: registerCanonicalJSONObject(object))
        }
        #expect(InitialIssueDispositionKind(rawValue: IssueDispositionKind.resolved.rawValue) == nil)
    }

    @Test("empty complete inventories select direct convergence without fabricated dispositions")
    func directPathForEmptyRegister() throws {
        let fixture = try LaneARegisterFixture.make(findings: false)
        let register = try fixture.issue(dispositionEvidence: [])
        #expect(register.entries.isEmpty)
        #expect(register.dispositions.isEmpty)
        #expect(register.acceptedCurrentScopeAssignments.isEmpty)
        #expect(register.pathDecision == .directConvergenceNoAcceptedCurrentScope)
    }

    @Test("accepted-current-scope mapping is exact and resolved never changes initial path")
    func acceptedMappingAndResolvedPath() throws {
        let fixture = try LaneARegisterFixture.make()
        let register = try fixture.issue()
        #expect(register.acceptedCurrentScopeAssignments
            == register.dispositions.filter(\.entersRemediation).map(\.fingerprint))
        #expect(register.pathDecision == .requiresRemediation)

        let acceptedResolved = try laneAProductionFixture(
            "disposition-accepted-current-scope-resolved.json"
        )
        #expect(acceptedResolved.register?.dispositions.count == 1)
        #expect(acceptedResolved.remediationBatch?.changes.count == 1)
        #expect(acceptedResolved.resolvedTransitions.count == 1)
        #expect(acceptedResolved.resolvedTransitions[0].previous == .acceptedCurrentScope)
        #expect(acceptedResolved.resolvedTransitions[0].current == .resolved)
        #expect(acceptedResolved.expected.pathDecision == .requiresRemediation)

        let illegal = try laneAProductionFixture(
            "disposition-resolved-without-remediation.json"
        )
        #expect(illegal.remediationBatch == nil)
        #expect(illegal.resolvedTransitions.count == 1)
        #expect(illegal.expected.decision == .rejected)
        #expect(illegal.expected.error == .illegalResolvedTransition)

        let missing = try laneAProductionFixture("remediation-evidence-missing.json")
        #expect(!(missing.register?.dispositions.isEmpty ?? true))
        #expect(missing.remediationBatch == nil)
        #expect(missing.expected.error == .remediationEvidenceMissing)
    }

    @Test("reordered literal findings collapse only by independently-derived typed fingerprint")
    func reorderedDuplicateFixture() throws {
        let fixture = try laneAProductionFixture("reordered-duplicate-findings.json")
        let findings = fixture.inventories.flatMap(\.findings)
        #expect(findings.count == 2)
        let fingerprints = try findings.map { try IssueFingerprint.derive(from: $0.components) }
        #expect(Set(fingerprints).count == 1)
        #expect(fingerprints[0].rawValue
            == "3c9d7aa47d21de2a5f83211213942feda4abcbafab0157d67e1966152a21cbd5")
        #expect(fixture.expected.entryFingerprints == [fingerprints[0]])
    }

    @Test("RC-01 frozen finding and disposition policy digests derive from closed payloads")
    func frozenPolicyDigestsAreBehaviorBound() throws {
        let finding = try FrozenReviewFindingPolicy.freeze(
            mustFixIdentities: [ReviewFindingIdentity(kind: .rule, value: "IFL-ARCH-001")]
        )
        let disposition = try FrozenDispositionPolicy.freeze(
            authorizedPrincipalIDs: [PrincipalID(validating: "kernel-principal")],
            mandatorySeverities: [.critical],
            permitsAuthenticatedHumanRiskAcceptance: false
        )
        let findingPreimage = Data(
            "{\"must_fix_identities\":[{\"kind\":\"rule\",\"value\":\"IFL-ARCH-001\"}],\"schema_version\":1}".utf8
        )
        let dispositionPreimage = Data(
            "{\"authorized_principal_ids\":[\"kernel-principal\"],\"mandatory_severities\":[\"critical\"],\"permits_authenticated_human_risk_acceptance\":false,\"schema_version\":1}".utf8
        )
        #expect(finding.digest == CanonicalTreeDigest.sha256(findingPreimage))
        #expect(disposition.digest == CanonicalTreeDigest.sha256(dispositionPreimage))

        let changed = try FrozenDispositionPolicy.freeze(
            authorizedPrincipalIDs: [PrincipalID(validating: "kernel-principal")],
            mandatorySeverities: [.critical],
            permitsAuthenticatedHumanRiskAcceptance: true
        )
        #expect(changed.digest != disposition.digest)
    }
}

struct LaneARegisterFixture {
    let baseline: LaneABaselineFixture
    let verifiedInventories: [LaneAVerifiedInventoryInput]
    let completeInventories: VerifiedCompleteInventorySet
    let fingerprints: [IssueFingerprint]
    let severityByFingerprint: [FailureFingerprint: RiskClass]
    let policies: VerifiedReviewPolicySet
    let dispositionEvidenceByFingerprint: [FailureFingerprint: VerifiedReviewDispositionEvidence]

    var fingerprint: IssueFingerprint { fingerprints[0] }
    var verifiedDispositionEvidence: [VerifiedReviewDispositionEvidence] {
        fingerprints.compactMap { dispositionEvidenceByFingerprint[$0.failureFingerprint] }
    }

    static func make(
        findings: Bool = true,
        twoDistinctFindings: Bool = false,
        reverseArrival: Bool = false
    ) throws -> LaneARegisterFixture {
        let baseline = try LaneABaselineFixture.make()
        let firstComponents = try laneAIssueComponents()
        let secondComponents = twoDistinctFindings
            ? try laneAIssueComponents(location: "architecture/presenter")
            : firstComponents
        let firstFindings = findings ? [
            try laneAFinding(
                severity: .critical,
                suffix: "architecture",
                components: firstComponents,
                mustFix: false
            ),
        ] : []
        let secondFindings = findings ? [
            try laneAFinding(
                severity: .high,
                suffix: "security-duplicate",
                components: secondComponents,
                mustFix: false
            ),
        ] : []
        let inventories = try laneAVerifiedInventories(
            fixture: baseline,
            inputs: [
                (
                    assignment: baseline.roster.assignments[0],
                    findings: firstFindings
                ),
                (
                    assignment: baseline.roster.assignments[1],
                    findings: secondFindings
                ),
            ]
        )
        var collector = ReviewInventoryCollector(baseline: baseline.baseline)
        var completion: ReviewInventoryCollectionResult = .pending(
            baseline.roster.assignments.map(\.id)
        )
        let arrival = reverseArrival ? Array(inventories.reversed()) : inventories
        for inventory in arrival {
            completion = try collector.accept(
                inventory.inventory,
                authority: inventory.authority,
                currentness: inventory.currentness
            )
        }
        guard case .complete(let complete) = completion else {
            throw LaneARegisterTestError.invalidFixture
        }
        let policies = try laneAVerifiedPolicySet(baseline: baseline.baseline)
        let firstFingerprint = try IssueFingerprint.derive(from: firstComponents)
        let fingerprints: [IssueFingerprint]
        if findings {
            fingerprints = try Set(
                [firstComponents, secondComponents].map(IssueFingerprint.derive(from:))
            ).sorted()
        } else {
            fingerprints = []
        }
        var evidenceByFingerprint: [FailureFingerprint: VerifiedReviewDispositionEvidence] = [:]
        var severityByFingerprint: [FailureFingerprint: RiskClass] = [:]
        for fingerprint in fingerprints {
            let severity: RiskClass = fingerprint == firstFingerprint
                ? .critical
                : .high
            severityByFingerprint[fingerprint.failureFingerprint] = severity
            evidenceByFingerprint[fingerprint.failureFingerprint] = try laneAVerifiedDispositionEvidence(
                fingerprint: fingerprint,
                severity: severity,
                mustFix: true,
                baseline: baseline.baseline,
                policies: policies
            )
        }
        return LaneARegisterFixture(
            baseline: baseline,
            verifiedInventories: inventories,
            completeInventories: complete,
            fingerprints: fingerprints,
            severityByFingerprint: severityByFingerprint,
            policies: policies,
            dispositionEvidenceByFingerprint: evidenceByFingerprint
        )
    }

    func issue(
        dispositionEvidence: [VerifiedReviewDispositionEvidence]? = nil
    ) throws -> IssueRegister {
        try IssueRegister.issue(
            baseline: baseline.baseline,
            inventories: completeInventories,
            policies: policies,
            dispositionEvidence: dispositionEvidence ?? verifiedDispositionEvidence
        )
    }

    func verifiedDispositionEvidence(
        disputed: Bool
    ) throws -> VerifiedReviewDispositionEvidence {
        try laneAVerifiedDispositionEvidence(
            fingerprint: fingerprint,
            severity: .critical,
            mustFix: true,
            baseline: baseline.baseline,
            policies: policies,
            disputed: disputed
        )
    }

    func verifiedDispositionEvidence(
        for fingerprint: FailureFingerprint
    ) -> [VerifiedReviewDispositionEvidence] {
        dispositionEvidenceByFingerprint[fingerprint].map { [$0] } ?? []
    }

    func verifiedDuplicateEvidence(
        duplicate: FailureFingerprint,
        canonical: FailureFingerprint
    ) throws -> VerifiedReviewDispositionEvidence {
        let issue = try #require(fingerprints.first { $0.failureFingerprint == duplicate })
        let severity = try #require(severityByFingerprint[duplicate])
        return try laneAVerifiedDispositionEvidence(
            fingerprint: issue,
            severity: severity,
            mustFix: true,
            baseline: baseline.baseline,
            policies: policies,
            evidenceKind: .equivalence,
            canonicalFingerprint: canonical
        )
    }
}

func laneAVerifiedPolicySet(
    baseline: ReviewBaseline
) throws -> VerifiedReviewPolicySet {
    let findingPolicy = try FrozenReviewFindingPolicy.freeze(
        mustFixIdentities: [ReviewFindingIdentity(kind: .rule, value: "IFL-ARCH-001")]
    )
    let dispositionPolicy = try laneADispositionPolicy()
    return try ReviewPolicyVerifier.verify(
        findingPolicy: findingPolicy,
        dispositionPolicy: dispositionPolicy,
        baseline: baseline
    )
}

func laneADispositionPolicy() throws -> FrozenDispositionPolicy {
    try FrozenDispositionPolicy.freeze(
        authorizedPrincipalIDs: [PrincipalID(validating: "kernel-principal")],
        mandatorySeverities: [.critical],
        permitsAuthenticatedHumanRiskAcceptance: false
    )
}

func laneAVerifiedDispositionEvidence(
    fingerprint: IssueFingerprint,
    severity: RiskClass,
    mustFix: Bool,
    baseline: ReviewBaseline,
    policies: VerifiedReviewPolicySet,
    disputed: Bool = false,
    evidenceKind: DispositionEvidenceKind = .acceptedScope,
    canonicalFingerprint: FailureFingerprint? = nil,
    hasSourceWriteCapability: Bool = false,
    persistEvidenceReceipt: Bool = true,
    spliceEvidenceReceipt: Bool = false,
    stage: WorkflowStage = .architectureGate,
    reviewCycle: ReviewCycleState? = nil
) throws -> VerifiedReviewDispositionEvidence {
    let policy = try laneADispositionPolicy()
    let evidenceID = try ReceiptID(
        validating: "disposition-\(fingerprint.rawValue.prefix(16))"
    )
    let authorityContextDigest = laneADigest("3")
    let equivalenceReferences = evidenceKind == .equivalence
        ? [evidenceID.rawValue]
        : []
    let payload = try CanonicalJSON.encode(ReviewDispositionEvidenceReceiptPayload(
        receiptID: evidenceID,
        runID: baseline.runID,
        baselineDigest: baseline.digest,
        fingerprint: fingerprint.failureFingerprint,
        severity: severity,
        mustFix: mustFix,
        evidenceKind: evidenceKind,
        remediationAssignmentID: evidenceKind == .acceptedScope
            ? "remediation-architecture"
            : nil,
        scopeDigest: evidenceKind == .acceptedScope ? laneADigest("2") : nil,
        canonicalFingerprint: canonicalFingerprint,
        equivalenceEvidenceReferences: equivalenceReferences,
        humanRiskAcceptance: false,
        disputed: disputed,
        authorityActorID: ActorID(validating: "kernel-actor"),
        authorityPrincipalID: PrincipalID(validating: "kernel-principal"),
        authorityKind: .kernel,
        claimedAuthenticated: true,
        authorityPolicyDigest: policy.digest,
        authorityContextDigest: authorityContextDigest,
        evidenceReferences: [evidenceID.rawValue]
    ))
    let rationaleDigest = CanonicalTreeDigest.sha256(payload)
    let claim = try DispositionAuthorityClaim(
        actorID: ActorID(validating: "kernel-actor"),
        principalID: PrincipalID(validating: "kernel-principal"),
        claimedKind: .kernel,
        claimedAuthenticated: true,
        authorityPolicyDigest: policy.digest,
        rationaleDigest: rationaleDigest,
        evidenceReferences: [evidenceID.rawValue]
    )
    let envelope = try DispositionEvidenceEnvelope(
        issueFingerprint: fingerprint.failureFingerprint,
        severity: severity,
        mustFix: mustFix,
        evidenceKind: evidenceKind,
        remediationAssignmentID: evidenceKind == .acceptedScope
            ? "remediation-architecture"
            : nil,
        scopeDigest: evidenceKind == .acceptedScope ? laneADigest("2") : nil,
        canonicalFingerprint: canonicalFingerprint,
        equivalenceEvidenceReferences: equivalenceReferences,
        humanRiskAcceptance: false,
        disputed: disputed,
        authority: claim
    )
    let raw = IssueDispositionEvidence(
        fingerprint: fingerprint.failureFingerprint,
        envelope: envelope,
        verifiedAuthority: VerifiedDispositionAuthorityFact(
            actorID: claim.actorID,
            principalID: claim.principalID,
            kind: .kernel,
            authorityPolicyDigest: claim.authorityPolicyDigest,
            rationaleDigest: claim.rationaleDigest,
            evidenceReferences: claim.evidenceReferences
        )
    )
    let persistedEvidence = PersistedReceipt(
        kind: try ReceiptKind(validating: "review-disposition-evidence"),
        id: evidenceID,
        transactionID: try TransactionID(rawValue: "txn-\(evidenceID.rawValue)"),
        transactionDigest: CanonicalTreeDigest.sha256(
            Data("txn-\(evidenceID.rawValue)".utf8)
        ),
        payloadDigest: rationaleDigest,
        payloadBytes: payload
    )
    let assignment = try #require(baseline.roster.assignments.first)
    let roundInput: ReviewRoundInput
    switch baseline.kind {
    case .initial:
        roundInput = try .initial(
            gate: baseline.gate,
            cycleOrdinal: try #require(baseline.cycleOrdinal),
            preFreezeEventHead: baseline.preCreationEventHead,
            redactionPolicy: baseline.redactionPolicy
        )
    case .normalConfirmation, .exception:
        roundInput = try .later(
            cycleID: baseline.cycleID,
            gate: baseline.gate,
            kind: baseline.kind,
            semanticOrdinal: baseline.semanticOrdinal,
            roundAnchorEventHead: baseline.preCreationEventHead,
            predecessorBaselineDigest: try #require(baseline.predecessorBaselineDigest),
            redactionPolicy: baseline.redactionPolicy
        )
    }
    let fixture = LaneABaselineFixture(
        runID: baseline.runID,
        redactionPolicy: baseline.redactionPolicy,
        roster: baseline.roster,
        artifacts: baseline.artifactScopes,
        roundInput: roundInput,
        expectedCycleID: baseline.cycleID,
        expectedRoundID: baseline.roundID,
        baseline: baseline
    )
    let submission = try laneACapabilitySubmission(
        fixture: fixture,
        assignment: assignment,
        findings: []
    )
    let committedRun = try laneAPersistedRun(
        baseline: baseline,
        submission: submission,
        stage: stage,
        reviewCycle: reviewCycle,
        additionalReceipts: persistEvidenceReceipt && !spliceEvidenceReceipt
            ? [persistedEvidence]
            : []
    )
    let persistedRun = spliceEvidenceReceipt ? PersistedRun(
        state: committedRun.state,
        stateBytes: committedRun.stateBytes,
        stateDigest: committedRun.stateDigest,
        events: committedRun.events,
        eventHead: committedRun.eventHead,
        receipts: committedRun.receipts + [persistedEvidence]
    ) : committedRun
    let authority = VerifiedAuthorityFact(
        actorID: claim.actorID,
        principalID: claim.principalID,
        roles: [.kernel],
        principalKind: .kernel,
        independentContextDigest: authorityContextDigest,
        hasAuthorshipEdge: false,
        hasSourceWriteCapability: hasSourceWriteCapability
    )
    return try ReviewAuthorityVerifier.verifyDispositionEvidence(
        evidence: raw,
        authority: authority,
        persistedRun: persistedRun,
        policies: policies
    )
}

private func digestOmittingRegisterDigest(from bytes: Data) throws -> HashDigest {
    var object = try registerJSONObject(bytes)
    object.removeValue(forKey: "register_digest")
    return CanonicalTreeDigest.sha256(try registerCanonicalJSONObject(object))
}

private func registerJSONObject(_ bytes: Data) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
        throw LaneARegisterTestError.invalidFixture
    }
    return object
}

private func registerCanonicalJSONObject(_ object: [String: Any]) throws -> Data {
    try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

private enum LaneARegisterTestError: Error {
    case invalidFixture
}
