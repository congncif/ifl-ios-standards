import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("ReviewBaselineTests")
struct ReviewBaselineTests {
    @Test("baseline freezes pre-derived round identity, exact scopes, policies, and roster")
    func deterministicBaselineFreeze() throws {
        let fixture = try LaneABaselineFixture.make()
        let reversedRoster = try FrozenReviewerRoster.freeze(
            assignments: fixture.roster.assignments.reversed(),
            redactionPolicy: fixture.redactionPolicy
        )
        let reversedBaseline = try ReviewBaseline.freeze(
            runID: fixture.runID,
            roundInput: fixture.roundInput,
            artifactScopes: fixture.artifacts.reversed(),
            activeProfileDigest: laneADigest("4"),
            riskPolicyDigest: laneADigest("5"),
            assurancePolicyDigest: laneADigest("6"),
            convergencePolicyDigest: laneADigest("7"),
            roster: reversedRoster
        )

        #expect(fixture.baseline.cycleID == fixture.expectedCycleID)
        #expect(fixture.baseline.roundID == fixture.expectedRoundID)
        #expect(fixture.baseline.kind == .initial)
        #expect(fixture.baseline.gate == .architecture)
        #expect(fixture.baseline.preCreationEventHead == fixture.roundInput.roundAnchorEventHead)
        #expect(fixture.baseline.redactionPolicy == fixture.redactionPolicy)
        #expect(fixture.baseline.rosterDigest == fixture.roster.digest)
        #expect(fixture.roster.assignments.map(\.id.rawValue) == [
            "assignment-architecture", "assignment-security",
        ])
        #expect(reversedRoster.digest == fixture.roster.digest)
        #expect(reversedBaseline.digest == fixture.baseline.digest)
        #expect(try CanonicalJSON.encode(reversedBaseline)
            == CanonicalJSON.encode(fixture.baseline))

        let encoded = try CanonicalJSON.encode(fixture.baseline)
        #expect(try digestOmitting("baseline_digest", from: encoded) == fixture.baseline.digest)
        let rosterBytes = try CanonicalJSON.encode(fixture.roster)
        #expect(try digestOmitting("roster_digest", from: rosterBytes) == fixture.roster.digest)
    }

    @Test("roster rejects duplicate assignments and non-finding evidence")
    func rosterAuthorityIsClosed() throws {
        let fixture = try LaneABaselineFixture.make()
        let assignment = fixture.roster.assignments[0]
        #expect(throws: (any Error).self) {
            try FrozenReviewerRoster.freeze(
                assignments: [assignment, assignment],
                redactionPolicy: fixture.redactionPolicy
            )
        }

        for evidenceKind in [ReviewEvidenceKind.approvalOnly, .pureScriptCheck] {
            let invalid = try laneAAssignment(
                id: "assignment-invalid-\(evidenceKind.rawValue)",
                role: "standards_validator",
                actor: "reviewer-invalid",
                principal: "principal-invalid",
                checklist: "c",
                evidenceKind: evidenceKind,
                redactionPolicy: fixture.redactionPolicy
            )
            #expect(throws: (any Error).self) {
                try FrozenReviewerRoster.freeze(
                    assignments: [invalid],
                    redactionPolicy: fixture.redactionPolicy
                )
            }
        }

        let mismatchedRedaction = try RedactionPolicyBinding(
            identity: "other-redaction-v1",
            digest: laneADigest("e")
        )
        #expect(throws: (any Error).self) {
            try FrozenReviewerRoster.freeze(
                assignments: fixture.roster.assignments,
                redactionPolicy: mismatchedRedaction
            )
        }

        let duplicatePrincipal = try laneAAssignment(
            id: "assignment-duplicate-principal",
            role: "security_privacy_reviewer",
            actor: "reviewer-distinct-actor",
            principal: fixture.roster.assignments[0].expectedPrincipalID.rawValue,
            checklist: "b",
            redactionPolicy: fixture.redactionPolicy
        )
        #expect(throws: (any Error).self) {
            try FrozenReviewerRoster.freeze(
                assignments: [fixture.roster.assignments[0], duplicatePrincipal],
                redactionPolicy: fixture.redactionPolicy
            )
        }
    }

    @Test("baseline strict decode rejects unknown, noncanonical, and self-inconsistent bytes")
    func strictBaselineDecode() throws {
        let fixture = try LaneABaselineFixture.make()
        let bytes = try CanonicalJSON.encode(fixture.baseline)
        #expect(try ReviewBaseline.decodeCanonical(from: bytes) == fixture.baseline)
        #expect(try CanonicalJSON.encode(ReviewBaseline.decodeCanonical(from: bytes)) == bytes)

        var unknown = try jsonObject(bytes)
        unknown["unknown"] = true
        var wrongKind = try jsonObject(bytes)
        wrongKind["round_kind"] = "normal_confirmation"
        var wrongHead = try jsonObject(bytes)
        wrongHead["pre_creation_event_head"] = String(repeating: "e", count: 64)
        var wrongPolicy = try jsonObject(bytes)
        wrongPolicy["convergence_policy_digest"] = String(repeating: "e", count: 64)
        var wrongDigest = try jsonObject(bytes)
        wrongDigest["baseline_digest"] = String(repeating: "e", count: 64)

        for mutation in [unknown, wrongKind, wrongHead, wrongPolicy, wrongDigest] {
            #expect(throws: (any Error).self) {
                try ReviewBaseline.decodeCanonical(from: canonicalJSONObject(mutation))
            }
        }

        var trailingLF = bytes
        trailingLF.append(0x0A)
        #expect(throws: (any Error).self) {
            try ReviewBaseline.decodeCanonical(from: trailingLF)
        }
    }

    @Test("inventory ingress binds exact baseline, assignment, redaction, receipts, and authority")
    func exactInventoryIngress() throws {
        let scenario = try LaneAReviewAuthorityScenario.make()
        let fixture = scenario.baseline
        let assignment = scenario.assignment
        let submission = scenario.submission
        let authority = try scenario.verify()
        let inventory = try ReviewerFindingInventory.ingest(
            submission: submission,
            against: fixture.baseline,
            authority: authority
        )

        #expect(inventory.assignmentID == assignment.id)
        #expect(inventory.baselineDigest == fixture.baseline.digest)
        #expect(inventory.roundID == fixture.baseline.roundID)
        #expect(inventory.rosterDigest == fixture.roster.digest)
        #expect(inventory.complete)
        #expect(inventory.findings.isEmpty)
        #expect(try CanonicalJSON.encode(inventory)
            == CanonicalJSON.encode(ReviewerFindingInventory.ingest(
                submission: submission,
                against: fixture.baseline,
                authority: authority
            )))
        let bytes = try CanonicalJSON.encode(inventory)
        #expect(try ReviewerFindingInventory.decodeCanonical(from: bytes) == inventory)
    }

    @Test("RC-02 submission decode replays every nested invariant and canonical order")
    func strictSubmissionDecode() throws {
        let fixture = try LaneABaselineFixture.make()
        let assignment = fixture.roster.assignments[0]
        let findings = try [
            laneAFinding(severity: .high, suffix: "decode-b"),
            laneAFinding(
                severity: .medium,
                suffix: "decode-a",
                components: laneAIssueComponents(location: "architecture/interactor")
            ),
        ]
        let submission = try laneACapabilitySubmission(
            fixture: fixture,
            assignment: assignment,
            findings: findings
        )
        let bytes = try CanonicalJSON.encode(submission)
        #expect(try ReviewerFindingSubmission.decodeCanonical(from: bytes) == submission)

        var version = try laneAJSONObject(bytes)
        version["schema_version"] = 2
        var negativeRedaction = try laneAJSONObject(bytes)
        var redaction = try #require(negativeRedaction["redaction_metadata"] as? [String: Any])
        redaction["replacement_token_count"] = -1
        negativeRedaction["redaction_metadata"] = redaction
        var duplicateReceipt = try laneAJSONObject(bytes)
        var envelope = try #require(duplicateReceipt["envelope"] as? [String: Any])
        let effect = try #require(envelope["effect_receipt"] as? [String: Any])
        var domain = try #require(envelope["domain_receipt"] as? [String: Any])
        domain["id"] = effect["id"]
        envelope["domain_receipt"] = domain
        duplicateReceipt["envelope"] = envelope
        var uppercaseReceipt = try laneAJSONObject(bytes)
        var uppercaseEnvelope = try #require(
            uppercaseReceipt["envelope"] as? [String: Any]
        )
        var uppercaseEffect = try #require(
            uppercaseEnvelope["effect_receipt"] as? [String: Any]
        )
        uppercaseEffect["id"] = "Effect-Assignment-Architecture"
        uppercaseEnvelope["effect_receipt"] = uppercaseEffect
        uppercaseReceipt["envelope"] = uppercaseEnvelope
        var invalidTimestamp = try laneAJSONObject(bytes)
        var timestampFindings = try #require(invalidTimestamp["findings"] as? [[String: Any]])
        timestampFindings[0]["reported_at"] = "2026-07-12T00:00:00Z"
        invalidTimestamp["findings"] = timestampFindings
        var invalidIdentity = try laneAJSONObject(bytes)
        var identityFindings = try #require(invalidIdentity["findings"] as? [[String: Any]])
        var components = try #require(identityFindings[0]["components"] as? [String: Any])
        var identity = try #require(components["identity"] as? [String: Any])
        identity["value"] = "not-a-rule-id"
        components["identity"] = identity
        identityFindings[0]["components"] = components
        invalidIdentity["findings"] = identityFindings
        var reordered = try laneAJSONObject(bytes)
        reordered["findings"] = Array(
            try #require(reordered["findings"] as? [[String: Any]]).reversed()
        )
        var unknownNested = try laneAJSONObject(bytes)
        var unknownMetadata = try #require(
            unknownNested["redaction_metadata"] as? [String: Any]
        )
        unknownMetadata["unknown"] = true
        unknownNested["redaction_metadata"] = unknownMetadata

        for mutation in [
            version,
            negativeRedaction,
            duplicateReceipt,
            uppercaseReceipt,
            invalidTimestamp,
            invalidIdentity,
            reordered,
            unknownNested,
        ] {
            #expect(throws: (any Error).self) {
                try ReviewerFindingSubmission.decodeCanonical(
                    from: laneACanonicalJSONObject(mutation)
                )
            }
        }
    }

    @Test("collector is collect-all, permutation invariant, and semantically idempotent")
    func collectAllJoin() throws {
        let fixture = try LaneABaselineFixture.make()
        let firstSubmission = try laneACapabilitySubmission(
            fixture: fixture,
            assignment: fixture.roster.assignments[0],
            findings: [laneAFinding(severity: .critical, suffix: "architecture")]
        )
        let secondSubmission = try laneACapabilitySubmission(
            fixture: fixture,
            assignment: fixture.roster.assignments[1],
            findings: []
        )
        let changedSubmission = try laneACapabilitySubmission(
            fixture: fixture,
            assignment: fixture.roster.assignments[0],
            receiptIDSuffix: "changed",
            findings: [laneAFinding(severity: .high, suffix: "changed")]
        )
        let inventories = try laneAVerifiedInventories(
            fixture: fixture,
            submissions: [
                (
                    assignment: fixture.roster.assignments[0],
                    submission: firstSubmission
                ),
                (
                    assignment: fixture.roster.assignments[1],
                    submission: secondSubmission
                ),
                (
                    assignment: fixture.roster.assignments[0],
                    submission: changedSubmission
                ),
            ]
        )
        let first = try #require(inventories.first)
        let second = try #require(inventories.dropFirst().first)
        let changed = try #require(inventories.last)

        var forward = ReviewInventoryCollector(baseline: fixture.baseline)
        guard case .pending(let firstMissing) = try forward.accept(
            first.inventory,
            authority: first.authority,
            currentness: first.currentness
        ) else {
            Issue.record("expected pending first inventory")
            return
        }
        #expect(firstMissing == [fixture.roster.assignments[1].id])
        guard case .pending(let duplicateMissing) = try forward.accept(
            first.inventory,
            authority: first.authority,
            currentness: first.currentness
        ) else {
            Issue.record("expected idempotent pending duplicate")
            return
        }
        #expect(duplicateMissing == firstMissing)
        guard case .complete(let forwardJoin) = try forward.accept(
            second.inventory,
            authority: second.authority,
            currentness: second.currentness
        ) else {
            Issue.record("expected complete inventory capability")
            return
        }

        var reverse = ReviewInventoryCollector(baseline: fixture.baseline)
        _ = try reverse.accept(
            second.inventory,
            authority: second.authority,
            currentness: second.currentness
        )
        guard case .complete(let reverseJoin) = try reverse.accept(
            first.inventory,
            authority: first.authority,
            currentness: first.currentness
        ) else {
            Issue.record("expected reverse complete inventory capability")
            return
        }
        #expect(try CanonicalJSON.encode(forwardJoin.inventories)
            == CanonicalJSON.encode(reverseJoin.inventories))

        #expect(throws: (any Error).self) {
            try forward.accept(
                changed.inventory,
                authority: changed.authority,
                currentness: changed.currentness
            )
        }

        let otherFixture = try LaneABaselineFixture.make(
            preFreezeEventHead: laneADigest("d")
        )
        let mixed = try laneAVerifiedInventory(
            fixture: otherFixture,
            assignment: otherFixture.roster.assignments[1],
            findings: []
        )
        var mixedCollector = ReviewInventoryCollector(baseline: fixture.baseline)
        #expect(throws: (any Error).self) {
            try mixedCollector.accept(
                mixed.inventory,
                authority: mixed.authority,
                currentness: mixed.currentness
            )
        }
    }

    @Test("RC-07 eight lane-A fixtures contain strict production wire and independent hashes")
    func literalReviewFixtures() throws {
        for filename in laneAProductionFixtureNames {
            let raw = try laneAReviewFixtureData(filename)
            #expect(raw.last == 0x0A)
            #expect(!raw.dropLast().contains(0x0A))
            let canonical = Data(raw.dropLast())
            let fixture = try CanonicalJSON.decode(
                LaneAProductionReviewFixture.self,
                from: canonical
            )
            #expect(fixture.fixtureID == String(filename.dropLast(".json".count)))
            #expect(try CanonicalJSON.encode(fixture) == canonical)
            let expectedFixtureHash = try #require(laneAProductionFixtureHashes[filename])
            #expect(CanonicalTreeDigest.sha256(raw) == expectedFixtureHash)

            let baselineBytes = try CanonicalJSON.encode(fixture.baseline)
            #expect(try ReviewBaseline.decodeCanonical(from: baselineBytes) == fixture.baseline)
            #expect(CanonicalTreeDigest.sha256(baselineBytes) == fixture.hashes.baseline)
            #expect(try fixture.alternateBaselines.enumerated().allSatisfy { index, baseline in
                let bytes = try CanonicalJSON.encode(baseline)
                return try ReviewBaseline.decodeCanonical(from: bytes) == baseline &&
                    CanonicalTreeDigest.sha256(bytes) == fixture.hashes.alternateBaselines[index]
            })
            #expect(try fixture.inventories.enumerated().allSatisfy { index, inventory in
                let bytes = try CanonicalJSON.encode(inventory)
                return try ReviewerFindingInventory.decodeCanonical(from: bytes) == inventory &&
                    CanonicalTreeDigest.sha256(bytes) == fixture.hashes.inventories[index]
            })
            #expect(CanonicalTreeDigest.sha256(try CanonicalJSON.encode(fixture.currentArtifacts))
                == fixture.hashes.currentArtifacts)
            if let register = fixture.register {
                let bytes = try CanonicalJSON.encode(register)
                let expectedHash = try #require(fixture.hashes.register)
                #expect(try IssueRegister.decodeCanonical(from: bytes) == register)
                #expect(CanonicalTreeDigest.sha256(bytes) == expectedHash)
            } else {
                #expect(fixture.hashes.register == nil)
            }
            if let batch = fixture.remediationBatch {
                let bytes = try CanonicalJSON.encode(batch)
                let expectedHash = try #require(fixture.hashes.remediationBatch)
                #expect(try RemediationBatch.decodeCanonical(from: bytes) == batch)
                #expect(CanonicalTreeDigest.sha256(bytes) == expectedHash)
            } else {
                #expect(fixture.hashes.remediationBatch == nil)
            }
            if let successor = fixture.successorBaseline {
                let bytes = try CanonicalJSON.encode(successor)
                let expectedHash = try #require(fixture.hashes.successorBaseline)
                #expect(try ReviewBaseline.decodeCanonical(from: bytes) == successor)
                #expect(CanonicalTreeDigest.sha256(bytes) == expectedHash)
            } else {
                #expect(fixture.hashes.successorBaseline == nil)
            }
            #expect(try fixture.resolvedTransitions.enumerated().allSatisfy { index, transition in
                let bytes = try CanonicalJSON.encode(transition)
                let decoded = try CanonicalJSON.decode(
                    RemediationResolvedTransition.self,
                    from: bytes
                )
                let reencoded = try CanonicalJSON.encode(decoded)
                return decoded == transition &&
                    reencoded == bytes &&
                    CanonicalTreeDigest.sha256(bytes) == fixture.hashes.resolvedTransitions[index]
            })
        }
    }
}

struct LaneABaselineFixture {
    let runID: RunID
    let redactionPolicy: RedactionPolicyBinding
    let roster: FrozenReviewerRoster
    let artifacts: [ArtifactReference]
    let roundInput: ReviewRoundInput
    let expectedCycleID: ReviewCycleID
    let expectedRoundID: ReviewRoundID
    let baseline: ReviewBaseline

    static func make(
        preFreezeEventHead: HashDigest = laneADigest("3")
    ) throws -> LaneABaselineFixture {
        let runID = RunID(rawValue: UUID(uuidString: "00000000-0000-4000-8000-000000000042")!)
        let redaction = try RedactionPolicyBinding(
            identity: "review-redaction-v1",
            digest: laneADigest("8")
        )
        let assignments = try [
            laneAAssignment(
                id: "assignment-security",
                role: "security_privacy_reviewer",
                actor: "reviewer-security",
                principal: "principal-security",
                checklist: "d",
                assurance: .heightened,
                redactionPolicy: redaction
            ),
            laneAAssignment(
                id: "assignment-architecture",
                role: "standards_validator",
                actor: "reviewer-architecture",
                principal: "principal-architecture",
                checklist: "c",
                assurance: .critical,
                redactionPolicy: redaction
            ),
        ]
        let roster = try FrozenReviewerRoster.freeze(
            assignments: assignments,
            redactionPolicy: redaction
        )
        let artifacts = try [
            laneAArtifact(id: "artifact-source", hash: "b", scope: "workflow.source"),
            laneAArtifact(id: "artifact-architecture", hash: "a", scope: "workflow"),
        ]
        let input = try ReviewRoundInput.initial(
            gate: .architecture,
            cycleOrdinal: 0,
            preFreezeEventHead: preFreezeEventHead,
            redactionPolicy: redaction
        )
        let cycleID = try ReviewCycleID.derive(
            runID: runID,
            gate: input.gate,
            cycleOrdinal: 0,
            preFreezeEventHead: preFreezeEventHead
        )
        let roundID = try ReviewRoundID.derive(
            runID: runID,
            gate: input.gate,
            cycleID: cycleID,
            kind: input.kind,
            semanticOrdinal: input.semanticOrdinal,
            roundAnchorEventHead: input.roundAnchorEventHead,
            predecessorBaselineDigest: nil
        )
        let baseline = try ReviewBaseline.freeze(
            runID: runID,
            roundInput: input,
            artifactScopes: artifacts,
            activeProfileDigest: laneADigest("4"),
            riskPolicyDigest: laneADigest("5"),
            assurancePolicyDigest: laneADigest("6"),
            convergencePolicyDigest: laneADigest("7"),
            roster: roster
        )
        return LaneABaselineFixture(
            runID: runID,
            redactionPolicy: redaction,
            roster: roster,
            artifacts: artifacts,
            roundInput: input,
            expectedCycleID: cycleID,
            expectedRoundID: roundID,
            baseline: baseline
        )
    }
}

func laneAAssignment(
    id: String,
    role: String,
    actor: String,
    principal: String,
    checklist: Character,
    assurance: ReviewAssuranceClass = .heightened,
    evidenceKind: ReviewEvidenceKind = .findingProducingReview,
    redactionPolicy: RedactionPolicyBinding
) throws -> ReviewerAssignment {
    try ReviewerAssignment(
        id: ReviewAssignmentID(validating: id),
        requiredRole: role,
        assuranceClass: assurance,
        independenceConstraints: [
            .distinctPrincipal, .noAuthorshipEdge, .noSourceWriteCapability,
        ],
        checklistDigest: laneADigest(checklist),
        redactionPolicy: redactionPolicy,
        expectedActorID: ActorID(validating: actor),
        expectedPrincipalID: PrincipalID(validating: principal),
        evidenceKind: evidenceKind
    )
}

func laneAArtifact(id: String, hash: Character, scope: String) throws -> ArtifactReference {
    try ArtifactReference(
        id: ArtifactID(validating: id),
        type: .architecture,
        scope: ArtifactScope(kind: .semanticSelector, value: scope),
        contentHash: laneADigest(hash)
    )
}

func laneASubmission(
    fixture: LaneABaselineFixture,
    assignment: ReviewerAssignment,
    checklistDigest: HashDigest? = nil,
    actorID: ActorID? = nil,
    complete: Bool = true,
    findings: [ReviewerFinding]
) throws -> ReviewerFindingSubmission {
    let suffix = assignment.id.rawValue
    let artifact = try laneAArtifact(
        id: "envelope-\(suffix)",
        hash: suffix == "assignment-architecture" ? "a" : "b",
        scope: "workflow"
    )
    return try ReviewerFindingSubmission(
        baselineDigest: fixture.baseline.digest,
        roundID: fixture.baseline.roundID,
        rosterDigest: fixture.roster.digest,
        assignmentID: assignment.id,
        checklistDigest: checklistDigest ?? assignment.checklistDigest,
        redactionPolicy: fixture.redactionPolicy,
        redactionMetadata: ReviewRedactionMetadata(
            policy: fixture.redactionPolicy,
            sanitizedEnvelopeDigest: artifact.contentHash,
            replacementTokenCount: findings.isEmpty ? 0 : 1,
            containsRawSensitiveData: false
        ),
        actorID: actorID ?? assignment.expectedActorID,
        principalID: assignment.expectedPrincipalID,
        role: assignment.requiredRole,
        envelope: ReviewerEnvelopeBinding(
            artifact: artifact,
            effectReceipt: laneAReceiptReference("effect-\(suffix)"),
            domainReceipt: laneAReceiptReference("domain-\(suffix)"),
            recordReceipt: laneAReceiptReference("record-\(suffix)")
        ),
        complete: complete,
        findings: findings
    )
}

func laneAInventory(
    fixture: LaneABaselineFixture,
    assignment: ReviewerAssignment,
    findings: [ReviewerFinding]
) throws -> ReviewerFindingInventory {
    try laneAVerifiedInventory(
        fixture: fixture,
        assignment: assignment,
        findings: findings
    ).inventory
}

func laneAFinding(
    severity: RiskClass,
    suffix: String,
    components: IssueFingerprintComponents? = nil,
    mustFix: Bool = false
) throws -> ReviewerFinding {
    try ReviewerFinding(
        findingID: "finding-\(suffix)",
        components: components ?? laneAIssueComponents(),
        severity: severity,
        mustFixClaim: mustFix,
        title: "Review title \(suffix)",
        message: "Review message \(suffix)",
        evidenceReferences: ["evidence-\(suffix)"],
        confidenceBasis: "verified-source-\(suffix)",
        reportedAt: "2026-07-12T00:00:00.000Z"
    )
}

func laneAIssueComponents(
    identity: ReviewFindingIdentity? = nil,
    artifactID: String = "artifact-architecture",
    scope: String = "workflow",
    location: String = "architecture/view",
    invariant: String = "view-humility",
    expected: String = "humble_view",
    actual: String = "view_owns_business_decision"
) throws -> IssueFingerprintComponents {
    try IssueFingerprintComponents(
        identity: identity ?? ReviewFindingIdentity(kind: .rule, value: "IFL-ARCH-001"),
        artifactID: ArtifactID(validating: artifactID),
        scopeSelector: ArtifactScope(kind: .semanticSelector, value: scope),
        locationSelector: location,
        invariantID: invariant,
        expectedClass: expected,
        actualClass: actual
    )
}

func laneADigest(_ character: Character) -> HashDigest {
    try! HashDigest(validating: String(repeating: character, count: 64))
}

private func digestOmitting(_ key: String, from bytes: Data) throws -> HashDigest {
    var object = try jsonObject(bytes)
    object.removeValue(forKey: key)
    return CanonicalTreeDigest.sha256(try canonicalJSONObject(object))
}

func laneAJSONObject(_ bytes: Data) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
        throw LaneATestError.invalidFixture
    }
    return object
}

func laneACanonicalJSONObject(_ object: [String: Any]) throws -> Data {
    try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

private func jsonObject(_ bytes: Data) throws -> [String: Any] {
    try laneAJSONObject(bytes)
}

private func canonicalJSONObject(_ object: [String: Any]) throws -> Data {
    try laneACanonicalJSONObject(object)
}

struct LaneAProductionReviewFixture: Codable, Equatable {
    let schemaVersion: Int
    let fixtureID: String
    let baseline: ReviewBaseline
    let alternateBaselines: [ReviewBaseline]
    let inventories: [ReviewerFindingInventory]
    let register: IssueRegister?
    let successorBaseline: ReviewBaseline?
    let remediationBatch: RemediationBatch?
    let resolvedTransitions: [RemediationResolvedTransition]
    let currentArtifacts: [ArtifactReference]
    let currentEventHead: HashDigest
    let hashes: LaneAProductionWireHashes
    let expected: LaneAExpectedReviewOutcome

    init(from decoder: any Decoder) throws {
        try laneARejectUnknown(decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        fixtureID = try values.decode(String.self, forKey: .fixtureID)
        baseline = try values.decode(ReviewBaseline.self, forKey: .baseline)
        alternateBaselines = try values.decode([ReviewBaseline].self, forKey: .alternateBaselines)
        inventories = try values.decode([ReviewerFindingInventory].self, forKey: .inventories)
        register = try values.decodeIfPresent(IssueRegister.self, forKey: .register)
        successorBaseline = try values.decodeIfPresent(
            ReviewBaseline.self,
            forKey: .successorBaseline
        )
        remediationBatch = try values.decodeIfPresent(
            RemediationBatch.self,
            forKey: .remediationBatch
        )
        resolvedTransitions = try values.decode(
            [RemediationResolvedTransition].self,
            forKey: .resolvedTransitions
        )
        currentArtifacts = try values.decode([ArtifactReference].self, forKey: .currentArtifacts)
        currentEventHead = try values.decode(HashDigest.self, forKey: .currentEventHead)
        hashes = try values.decode(LaneAProductionWireHashes.self, forKey: .hashes)
        expected = try values.decode(LaneAExpectedReviewOutcome.self, forKey: .expected)
        guard schemaVersion == 1,
              !fixtureID.isEmpty,
              hashes.alternateBaselines.count == alternateBaselines.count,
              hashes.inventories.count == inventories.count,
              hashes.resolvedTransitions.count == resolvedTransitions.count,
              !currentArtifacts.isEmpty
        else { throw LaneAProductionFixtureError.invalidFixture }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case fixtureID = "fixture_id"
        case baseline
        case alternateBaselines = "alternate_baselines"
        case inventories
        case register
        case successorBaseline = "successor_baseline"
        case remediationBatch = "remediation_batch"
        case resolvedTransitions = "resolved_transitions"
        case currentArtifacts = "current_artifacts"
        case currentEventHead = "current_event_head"
        case hashes
        case expected
    }
}

struct LaneAProductionWireHashes: Codable, Equatable {
    let baseline: HashDigest
    let alternateBaselines: [HashDigest]
    let inventories: [HashDigest]
    let register: HashDigest?
    let successorBaseline: HashDigest?
    let remediationBatch: HashDigest?
    let resolvedTransitions: [HashDigest]
    let currentArtifacts: HashDigest

    init(from decoder: any Decoder) throws {
        try laneARejectUnknown(decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        baseline = try values.decode(HashDigest.self, forKey: .baseline)
        alternateBaselines = try values.decode([HashDigest].self, forKey: .alternateBaselines)
        inventories = try values.decode([HashDigest].self, forKey: .inventories)
        register = try values.decodeIfPresent(HashDigest.self, forKey: .register)
        successorBaseline = try values.decodeIfPresent(HashDigest.self, forKey: .successorBaseline)
        remediationBatch = try values.decodeIfPresent(HashDigest.self, forKey: .remediationBatch)
        resolvedTransitions = try values.decode([HashDigest].self, forKey: .resolvedTransitions)
        currentArtifacts = try values.decode(HashDigest.self, forKey: .currentArtifacts)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case baseline
        case alternateBaselines = "alternate_baselines"
        case inventories
        case register
        case successorBaseline = "successor_baseline"
        case remediationBatch = "remediation_batch"
        case resolvedTransitions = "resolved_transitions"
        case currentArtifacts = "current_artifacts"
    }
}

enum LaneAExpectedReviewDecision: String, Codable, Equatable {
    case joined
    case pending
    case rejected
    case requiresRemediation = "requires_remediation"
    case remediated
}

enum LaneAExpectedReviewError: String, Codable, Equatable {
    case none
    case missingReviewer = "missing_reviewer"
    case mixedBaseline = "mixed_baseline"
    case baselineMutated = "baseline_mutated"
    case remediationEvidenceMissing = "remediation_evidence_missing"
    case illegalResolvedTransition = "illegal_resolved_transition"
}

struct LaneAExpectedReviewOutcome: Codable, Equatable {
    let decision: LaneAExpectedReviewDecision
    let error: LaneAExpectedReviewError
    let missingAssignmentIDs: [ReviewAssignmentID]
    let entryFingerprints: [IssueFingerprint]
    let pathDecision: IssueRegisterPathDecision?

    init(from decoder: any Decoder) throws {
        try laneARejectUnknown(decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        decision = try values.decode(LaneAExpectedReviewDecision.self, forKey: .decision)
        error = try values.decode(LaneAExpectedReviewError.self, forKey: .error)
        missingAssignmentIDs = try values.decode(
            [ReviewAssignmentID].self,
            forKey: .missingAssignmentIDs
        )
        entryFingerprints = try values.decode(
            [IssueFingerprint].self,
            forKey: .entryFingerprints
        )
        pathDecision = try values.decodeIfPresent(
            IssueRegisterPathDecision.self,
            forKey: .pathDecision
        )
        guard missingAssignmentIDs == missingAssignmentIDs.sorted(),
              entryFingerprints == entryFingerprints.sorted()
        else { throw LaneAProductionFixtureError.invalidFixture }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case decision
        case error
        case missingAssignmentIDs = "missing_assignment_ids"
        case entryFingerprints = "entry_fingerprints"
        case pathDecision = "path_decision"
    }
}

let laneAProductionFixtureNames = [
    "baseline-mutated-during-collection.json",
    "common-baseline-complete.json",
    "disposition-accepted-current-scope-resolved.json",
    "disposition-resolved-without-remediation.json",
    "missing-reviewer.json",
    "mixed-baseline.json",
    "remediation-evidence-missing.json",
    "reordered-duplicate-findings.json",
]

let laneAProductionFixtureHashes: [String: HashDigest] = [
    "baseline-mutated-during-collection.json": try! HashDigest(
        validating: "342d256bc0c4ebcc33fd0b3ac5bfee02ca927be88368d333b1f12ebc8b977b3c"
    ),
    "common-baseline-complete.json": try! HashDigest(
        validating: "708c39c4f2af39cbdfa456d1203074496ba4c617eab9a0bca23dbf493647026c"
    ),
    "disposition-accepted-current-scope-resolved.json": try! HashDigest(
        validating: "69840d8610f851a1c2d8e293bac1d350d209b81b711fbc71bc05525756e80c4a"
    ),
    "disposition-resolved-without-remediation.json": try! HashDigest(
        validating: "6cf64514fee00d32552f0f414fb84322ac3bd5bbedd3c30c42203a4a8eb23f71"
    ),
    "missing-reviewer.json": try! HashDigest(
        validating: "d390841369aba196ce1a9a237899cf147d8cb4366f36a2bc671e71f43fdfba54"
    ),
    "mixed-baseline.json": try! HashDigest(
        validating: "a396b79acff32572f04ebc2e556f83e9afdab28cd3f500f1c6fa668f24dd0862"
    ),
    "remediation-evidence-missing.json": try! HashDigest(
        validating: "c089e099e640d9d75871f085dcfdc9c7de8534d09f2a88998a28b2a25f06fd56"
    ),
    "reordered-duplicate-findings.json": try! HashDigest(
        validating: "bab619fed3bc2214ddbd67859ae8e89a672a65c12f760ae956b6546e54ddf128"
    ),
]

func laneAProductionFixture(_ filename: String) throws -> LaneAProductionReviewFixture {
    let raw = try laneAReviewFixtureData(filename)
    guard raw.last == 0x0A else { throw LaneAProductionFixtureError.invalidFixture }
    return try CanonicalJSON.decode(
        LaneAProductionReviewFixture.self,
        from: Data(raw.dropLast())
    )
}

func laneAReviewFixtureData(_ filename: String) throws -> Data {
    var root = URL(fileURLWithPath: #filePath)
    while root.lastPathComponent != "ifl-ios-standards", root.path != "/" {
        root.deleteLastPathComponent()
    }
    return try Data(
        contentsOf: root
            .appendingPathComponent("verification/fixtures/workflow/review")
            .appendingPathComponent(filename)
    )
}

private struct LaneAFixtureCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

private func laneARejectUnknown(_ decoder: any Decoder, allowed: Set<String>) throws {
    let values = try decoder.container(keyedBy: LaneAFixtureCodingKey.self)
    guard values.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
        throw LaneATestError.invalidFixture
    }
}

private enum LaneATestError: Error {
    case invalidFixture
}

enum LaneAProductionFixtureError: Error {
    case invalidFixture
}
