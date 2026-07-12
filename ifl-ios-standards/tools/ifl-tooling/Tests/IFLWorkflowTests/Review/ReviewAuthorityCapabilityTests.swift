import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("ReviewAuthorityCapabilityTests")
struct ReviewAuthorityCapabilityTests {
    @Test("RC-01 reviewer authority is derived from independent identity, receipts, and currentness")
    func derivesReviewerAuthorityFromVerifiedFacts() throws {
        let scenario = try LaneAReviewAuthorityScenario.make()
        let authority = try scenario.verify()
        let inventory = try ReviewerFindingInventory.ingest(
            submission: scenario.submission,
            against: scenario.baseline.baseline,
            authority: authority
        )

        #expect(inventory.assignmentID == scenario.assignment.id)
        #expect(inventory.submissionDigest == (try scenario.submission.canonicalDigest()))
        #expect(inventory.envelope.artifact.contentHash
            == inventory.redactionMetadata.sanitizedEnvelopeDigest)
    }

    @Test("RC-01 authorship, source-write, actor, and principal conflicts cannot issue authority")
    func rejectsNonIndependentAuthorityFacts() throws {
        let scenario = try LaneAReviewAuthorityScenario.make()
        let invalidFacts = try [
            scenario.authorityFact(hasAuthorshipEdge: true),
            scenario.authorityFact(hasSourceWriteCapability: true),
            scenario.authorityFact(actorID: ActorID(validating: "different-reviewer")),
            scenario.authorityFact(principalID: PrincipalID(validating: "different-principal")),
        ]

        for fact in invalidFacts {
            #expect(throws: (any Error).self) {
                try scenario.verify(authority: fact)
            }
        }
    }

    @Test("RRC-05 reviewer principal and context must both differ from the sealed author")
    func rejectsAuthorPrincipalOrContextReuse() throws {
        let distinct = try LaneAReviewAuthorityScenario.make()
        #expect(try distinct.verify().assignmentID == distinct.assignment.id)

        let samePrincipal = try LaneAReviewAuthorityScenario.make(
            authorPrincipalID: distinct.assignment.expectedPrincipalID
        )
        #expect(throws: WorkflowPolicyError.invalidPolicy) {
            try samePrincipal.verify()
        }

        let sameContext = try LaneAReviewAuthorityScenario.make(
            authorContextDigest: laneADigest("1")
        )
        #expect(throws: WorkflowPolicyError.invalidPolicy) {
            try sameContext.verify()
        }

        let sameActor = try LaneAReviewAuthorityScenario.make(
            authorActorID: distinct.assignment.expectedActorID
        )
        #expect(throws: WorkflowPolicyError.invalidPolicy) {
            try sameActor.verify()
        }

        #expect(!(VerifiedReviewAuthorshipContext.self is any Encodable.Type))
        #expect(!(VerifiedReviewAuthorshipContext.self is any Decodable.Type))
    }

    @Test("RRC-05 authorship authority is sealed to the complete reviewed artifact set")
    func authorshipAuthorityIsTargetScoped() throws {
        let scenario = try LaneAReviewAuthorityScenario.make()
        let author = try laneAAuthorAuthorityFact()
        let context = try ReviewAuthorshipContextVerifier.verify(
            authorAuthorities: [author],
            authoredArtifacts: scenario.baseline.baseline.artifactScopes,
            baseline: scenario.baseline.baseline,
            currentness: scenario.currentness
        )

        #expect(context.authorActorIDs == [author.actorID])
        #expect(context.authoredArtifactSetDigest == scenario.currentness.currentArtifactSetDigest)
        #expect(context.authorshipProvenanceDigest != laneADigest("0"))
        #expect(throws: WorkflowPolicyError.invalidPolicy) {
            try ReviewAuthorshipContextVerifier.verify(
                authorAuthorities: [author],
                authoredArtifacts: Array(scenario.baseline.baseline.artifactScopes.dropLast()),
                baseline: scenario.baseline.baseline,
                currentness: scenario.currentness
            )
        }

        let reviewerAsSecondAuthor = try laneAAuthorAuthorityFact(
            actorID: scenario.assignment.expectedActorID,
            principalID: PrincipalID(validating: "second-author-principal"),
            independentContextDigest: laneADigest("4")
        )
        let multiAuthorContext = try ReviewAuthorshipContextVerifier.verify(
            authorAuthorities: [author, reviewerAsSecondAuthor],
            authoredArtifacts: scenario.baseline.baseline.artifactScopes,
            baseline: scenario.baseline.baseline,
            currentness: scenario.currentness
        )
        #expect(throws: WorkflowPolicyError.invalidPolicy) {
            try ReviewAuthorityVerifier.verifyInventoryAuthority(
                submission: scenario.submission,
                baseline: scenario.baseline.baseline,
                assignment: scenario.assignment,
                authority: scenario.authority,
                authorshipContext: multiAuthorContext,
                persistedRun: scenario.persistedRun,
                currentness: scenario.currentness
            )
        }
    }

    @Test("RRC-04 same-artifact authority cannot cross the active review cycle")
    func rejectsStaleActiveCycleWithMatchingArtifacts() throws {
        let scenario = try LaneAReviewAuthorityScenario.make()
        let otherBaseline = try LaneABaselineFixture.make(
            preFreezeEventHead: laneADigest("2")
        ).baseline
        let crossedRun = try laneAPersistedRun(
            baseline: scenario.baseline.baseline,
            submission: scenario.submission,
            reviewCycle: laneAReviewCycleState(for: otherBaseline)
        )
        let currentness = try ReviewCapabilityTestFactory.verifyCurrentness(
            baseline: scenario.baseline.baseline,
            currentArtifacts: scenario.baseline.artifacts,
            currentEventHead: crossedRun.eventHead
        )
        let authorship = try laneAAuthorshipContext(
            baseline: scenario.baseline.baseline,
            currentness: currentness
        )

        #expect(throws: WorkflowPolicyError.invalidPolicy) {
            try ReviewAuthorityVerifier.verifyInventoryAuthority(
                submission: scenario.submission,
                baseline: scenario.baseline.baseline,
                assignment: scenario.assignment,
                authority: scenario.authority,
                authorshipContext: authorship,
                persistedRun: crossedRun,
                currentness: currentness
            )
        }
    }

    @Test("RC-01 every envelope receipt must exist with exact immutable payload bytes")
    func rejectsMissingOrTamperedEnvelopeReceipt() throws {
        let scenario = try LaneAReviewAuthorityScenario.make()
        let missing = scenario.persistedRun(replacingReceipts: Array(
            scenario.persistedRun.receipts.dropLast()
        ))
        #expect(throws: (any Error).self) {
            try scenario.verify(persistedRun: missing)
        }

        var receipts = scenario.persistedRun.receipts
        let original = try #require(receipts.first)
        receipts[0] = PersistedReceipt(
            kind: original.kind,
            id: original.id,
            transactionID: original.transactionID,
            transactionDigest: original.transactionDigest,
            payloadDigest: original.payloadDigest,
            payloadBytes: Data("tampered-receipt-payload".utf8)
        )
        #expect(throws: (any Error).self) {
            try scenario.verify(
                persistedRun: scenario.persistedRun(replacingReceipts: receipts)
            )
        }
    }

    @Test("RRC-05 an envelope receipt from an earlier active-chain head cannot authorize current facts")
    func rejectsEarlierEnvelopeReceiptReplay() throws {
        let scenario = try LaneAReviewAuthorityScenario.make()
        let advanced = try laneAAdvanceEnvelopeRun(scenario.persistedRun)
        let currentness = try ReviewCapabilityTestFactory.verifyCurrentness(
            baseline: scenario.baseline.baseline,
            currentArtifacts: scenario.baseline.artifacts,
            currentEventHead: advanced.eventHead
        )
        let authorship = try laneAAuthorshipContext(
            baseline: scenario.baseline.baseline,
            currentness: currentness
        )

        #expect(throws: PersistenceError.integrityViolation) {
            try ReviewAuthorityVerifier.verifyInventoryAuthority(
                submission: scenario.submission,
                baseline: scenario.baseline.baseline,
                assignment: scenario.assignment,
                authority: scenario.authority,
                authorshipContext: authorship,
                persistedRun: advanced,
                currentness: currentness
            )
        }
    }

    @Test("RC-01 submission must match every frozen assignment and policy field")
    func rejectsSubmissionBindingDrift() throws {
        let scenario = try LaneAReviewAuthorityScenario.make()
        let otherPolicy = try RedactionPolicyBinding(
            identity: "review-redaction-other-v1",
            digest: laneADigest("f")
        )
        let invalidSubmissions = try [
            laneAReplacingSubmission(
                scenario.submission,
                checklistDigest: laneADigest("f")
            ),
            laneAReplacingSubmission(
                scenario.submission,
                actorID: ActorID(validating: "reviewer-impostor")
            ),
            laneAReplacingSubmission(
                scenario.submission,
                role: "unfrozen_role"
            ),
            laneAReplacingSubmission(
                scenario.submission,
                complete: false
            ),
            laneAReplacingSubmission(
                scenario.submission,
                redactionPolicy: otherPolicy
            ),
        ]

        for submission in invalidSubmissions {
            #expect(throws: (any Error).self) {
                try ReviewAuthorityVerifier.verifyInventoryAuthority(
                    submission: submission,
                    baseline: scenario.baseline.baseline,
                    assignment: scenario.assignment,
                    authority: scenario.authority,
                    authorshipContext: scenario.authorshipContext,
                    persistedRun: scenario.persistedRun,
                    currentness: scenario.currentness
                )
            }
        }
    }

    @Test("RC-01 redaction metadata must attest the exact persisted envelope artifact")
    func rejectsUnboundRedactionOutput() throws {
        let scenario = try LaneAReviewAuthorityScenario.make(
            sanitizedEnvelopeDigest: laneADigest("f")
        )
        #expect(scenario.submission.redactionMetadata.sanitizedEnvelopeDigest
            != scenario.submission.envelope.artifact.contentHash)
        #expect(throws: (any Error).self) {
            try scenario.verify()
        }
    }

    @Test("RRC-05 envelope receipt payload is typed and requires published provenance")
    func envelopeReceiptPayloadRequiresPublishedProvenance() throws {
        #expect(ReviewEnvelopeReceiptPayload.self is any Encodable.Type)
        #expect(ReviewEnvelopeReceiptPayload.self is any Decodable.Type)

        let source = try String(
            contentsOf: laneAWorkflowSource("Review/ReviewAuthorityCapabilities.swift"),
            encoding: .utf8
        )
        #expect(source.contains("ReviewEnvelopeReceiptPayload.decodeCanonical"))
        #expect(source.contains("VerifiedPublishedReviewReceipt"))
        #expect(source.contains("transactionID"))
        #expect(source.contains("transactionDigest"))
        #expect(source.contains("receiptManifest"))
        #expect(source.contains("persistedRun.events"))
    }

    @Test("RC-01 scoped mutation and a capability for another baseline are both stale")
    func rejectsStaleScopeCurrentness() throws {
        let scenario = try LaneAReviewAuthorityScenario.make()
        var currentArtifacts = scenario.baseline.artifacts
        let changed = try ArtifactReference(
            id: currentArtifacts[0].id,
            type: currentArtifacts[0].type,
            scope: currentArtifacts[0].scope,
            contentHash: laneADigest("f")
        )
        currentArtifacts[0] = changed
        #expect(throws: (any Error).self) {
            try ReviewCapabilityTestFactory.verifyCurrentness(
                baseline: scenario.baseline.baseline,
                currentArtifacts: currentArtifacts,
                currentEventHead: scenario.currentEventHead
            )
        }

        let other = try LaneAReviewAuthorityScenario.make(
            preFreezeEventHead: laneADigest("2")
        )
        #expect(throws: (any Error).self) {
            try scenario.verify(currentness: other.currentness)
        }
    }

    @Test("RC-01 production source exposes no public caller-minting authority factory")
    func productionAuthorityHasNoPublicTestMint() throws {
        let source = try String(
            contentsOf: laneAWorkflowSource("Review/ReviewerFindingInventory.swift"),
            encoding: .utf8
        )
        #expect(!source.contains("public static func testing("))
        #expect(!source.contains("let independenceSatisfied: Bool"))
        #expect(!source.contains("let envelopeRecorded: Bool"))
        #expect(!source.contains("try? submission.canonicalDigest()"))
    }
}

struct LaneAReviewAuthorityScenario {
    let baseline: LaneABaselineFixture
    let assignment: ReviewerAssignment
    let submission: ReviewerFindingSubmission
    let authority: VerifiedAuthorityFact
    let authorshipContext: VerifiedReviewAuthorshipContext
    let persistedRun: PersistedRun
    let currentness: VerifiedReviewScopeCurrentness
    let currentEventHead: HashDigest

    static func make(
        assignmentIndex: Int = 0,
        preFreezeEventHead: HashDigest = laneADigest("3"),
        sanitizedEnvelopeDigest: HashDigest? = nil,
        authorActorID: ActorID? = nil,
        authorPrincipalID: PrincipalID? = nil,
        authorContextDigest: HashDigest = laneADigest("2"),
        reviewerContextDigest: HashDigest = laneADigest("1"),
        findings: [ReviewerFinding] = []
    ) throws -> LaneAReviewAuthorityScenario {
        let baseline = try LaneABaselineFixture.make(
            preFreezeEventHead: preFreezeEventHead
        )
        let assignment = baseline.roster.assignments[assignmentIndex]
        let submission = try laneACapabilitySubmission(
            fixture: baseline,
            assignment: assignment,
            sanitizedEnvelopeDigest: sanitizedEnvelopeDigest,
            independentContextDigest: reviewerContextDigest,
            findings: findings
        )
        let persistedRun = try laneAPersistedRun(
            baseline: baseline.baseline,
            submission: submission,
            independentContextDigest: reviewerContextDigest
        )
        let currentEventHead = persistedRun.eventHead
        let currentness = try ReviewCapabilityTestFactory.verifyCurrentness(
            baseline: baseline.baseline,
            currentArtifacts: baseline.artifacts,
            currentEventHead: currentEventHead
        )
        let authority = try laneAReviewerAuthorityFact(
            assignment: assignment,
            independentContextDigest: reviewerContextDigest
        )
        let authorshipContext = try laneAAuthorshipContext(
            baseline: baseline.baseline,
            currentness: currentness,
            authorActorID: authorActorID,
            authorPrincipalID: authorPrincipalID,
            independentContextDigest: authorContextDigest
        )
        return LaneAReviewAuthorityScenario(
            baseline: baseline,
            assignment: assignment,
            submission: submission,
            authority: authority,
            authorshipContext: authorshipContext,
            persistedRun: persistedRun,
            currentness: currentness,
            currentEventHead: currentEventHead
        )
    }

    func verify(
        authority: VerifiedAuthorityFact? = nil,
        persistedRun: PersistedRun? = nil,
        currentness: VerifiedReviewScopeCurrentness? = nil
    ) throws -> VerifiedReviewerInventoryAuthority {
        try ReviewAuthorityVerifier.verifyInventoryAuthority(
            submission: submission,
            baseline: baseline.baseline,
            assignment: assignment,
            authority: authority ?? self.authority,
            authorshipContext: authorshipContext,
            persistedRun: persistedRun ?? self.persistedRun,
            currentness: currentness ?? self.currentness
        )
    }

    func authorityFact(
        actorID: ActorID? = nil,
        principalID: PrincipalID? = nil,
        independentContextDigest: HashDigest = laneADigest("1"),
        hasAuthorshipEdge: Bool = false,
        hasSourceWriteCapability: Bool = false
    ) throws -> VerifiedAuthorityFact {
        try laneAReviewerAuthorityFact(
            assignment: assignment,
            actorID: actorID,
            principalID: principalID,
            independentContextDigest: independentContextDigest,
            hasAuthorshipEdge: hasAuthorshipEdge,
            hasSourceWriteCapability: hasSourceWriteCapability
        )
    }

    func persistedRun(replacingReceipts receipts: [PersistedReceipt]) -> PersistedRun {
        PersistedRun(
            state: persistedRun.state,
            stateBytes: persistedRun.stateBytes,
            stateDigest: persistedRun.stateDigest,
            events: persistedRun.events,
            eventHead: persistedRun.eventHead,
            receipts: receipts
        )
    }
}

struct LaneAVerifiedInventoryInput {
    let inventory: ReviewerFindingInventory
    let authority: VerifiedReviewerInventoryAuthority
    let currentness: VerifiedReviewScopeCurrentness
}

func laneAVerifiedInventory(
    fixture: LaneABaselineFixture,
    assignment: ReviewerAssignment,
    findings: [ReviewerFinding],
    stage: WorkflowStage = .architectureGate,
    reviewCycle: ReviewCycleState? = nil
) throws -> LaneAVerifiedInventoryInput {
    let submission = try laneACapabilitySubmission(
        fixture: fixture,
        assignment: assignment,
        findings: findings
    )
    let persistedRun = try laneAPersistedRun(
        baseline: fixture.baseline,
        submission: submission,
        stage: stage,
        reviewCycle: reviewCycle
    )
    let currentness = try ReviewCapabilityTestFactory.verifyCurrentness(
        baseline: fixture.baseline,
        currentArtifacts: fixture.artifacts,
        currentEventHead: persistedRun.eventHead
    )
    let authority = try ReviewAuthorityVerifier.verifyInventoryAuthority(
        submission: submission,
        baseline: fixture.baseline,
        assignment: assignment,
        authority: laneAReviewerAuthorityFact(assignment: assignment),
        authorshipContext: laneAAuthorshipContext(
            baseline: fixture.baseline,
            currentness: currentness
        ),
        persistedRun: persistedRun,
        currentness: currentness
    )
    return LaneAVerifiedInventoryInput(
        inventory: try ReviewerFindingInventory.ingest(
            submission: submission,
            against: fixture.baseline,
            authority: authority
        ),
        authority: authority,
        currentness: currentness
    )
}

func laneAVerifiedInventories(
    fixture: LaneABaselineFixture,
    inputs: [(assignment: ReviewerAssignment, findings: [ReviewerFinding])],
    stage: WorkflowStage = .architectureGate,
    reviewCycle: ReviewCycleState? = nil
) throws -> [LaneAVerifiedInventoryInput] {
    let submissions = try inputs.map { input in
        (
            assignment: input.assignment,
            submission: try laneACapabilitySubmission(
                fixture: fixture,
                assignment: input.assignment,
                findings: input.findings
            )
        )
    }
    return try laneAVerifiedInventories(
        fixture: fixture,
        submissions: submissions,
        stage: stage,
        reviewCycle: reviewCycle
    )
}

func laneAVerifiedInventories(
    fixture: LaneABaselineFixture,
    submissions: [(assignment: ReviewerAssignment, submission: ReviewerFindingSubmission)],
    stage: WorkflowStage = .architectureGate,
    reviewCycle: ReviewCycleState? = nil
) throws -> [LaneAVerifiedInventoryInput] {
    guard let first = submissions.first else { return [] }
    let additionalReceipts = try submissions.dropFirst().flatMap { input in
        try laneAEnvelopePersistedReceipts(
            submission: input.submission,
            baseline: fixture.baseline
        )
    }
    let persistedRun = try laneAPersistedRun(
        baseline: fixture.baseline,
        submission: first.submission,
        stage: stage,
        reviewCycle: reviewCycle,
        additionalReceipts: additionalReceipts
    )
    let currentness = try ReviewCapabilityTestFactory.verifyCurrentness(
        baseline: fixture.baseline,
        currentArtifacts: fixture.artifacts,
        currentEventHead: persistedRun.eventHead
    )
    return try submissions.map { input in
        let authority = try ReviewAuthorityVerifier.verifyInventoryAuthority(
            submission: input.submission,
            baseline: fixture.baseline,
            assignment: input.assignment,
            authority: laneAReviewerAuthorityFact(assignment: input.assignment),
            authorshipContext: laneAAuthorshipContext(
                baseline: fixture.baseline,
                currentness: currentness
            ),
            persistedRun: persistedRun,
            currentness: currentness
        )
        return LaneAVerifiedInventoryInput(
            inventory: try ReviewerFindingInventory.ingest(
                submission: input.submission,
                against: fixture.baseline,
                authority: authority
            ),
            authority: authority,
            currentness: currentness
        )
    }
}

func laneACapabilitySubmission(
    fixture: LaneABaselineFixture,
    assignment: ReviewerAssignment,
    sanitizedEnvelopeDigest: HashDigest? = nil,
    independentContextDigest: HashDigest = laneADigest("1"),
    receiptIDSuffix: String? = nil,
    findings: [ReviewerFinding]
) throws -> ReviewerFindingSubmission {
    let assignmentSuffix = assignment.id.rawValue
    let receiptSuffix = receiptIDSuffix.map { "\(assignmentSuffix)-\($0)" }
        ?? assignmentSuffix
    let artifact = try laneAArtifact(
        id: "envelope-\(assignmentSuffix)",
        hash: assignmentSuffix == "assignment-architecture" ? "a" : "b",
        scope: "workflow"
    )
    let submittedMetadata = try ReviewRedactionMetadata(
        policy: fixture.redactionPolicy,
        sanitizedEnvelopeDigest: sanitizedEnvelopeDigest ?? artifact.contentHash,
        replacementTokenCount: findings.isEmpty ? 0 : 1,
        containsRawSensitiveData: false
    )
    let persistedMetadata = try ReviewRedactionMetadata(
        policy: fixture.redactionPolicy,
        sanitizedEnvelopeDigest: artifact.contentHash,
        replacementTokenCount: submittedMetadata.replacementTokenCount,
        containsRawSensitiveData: false
    )
    let effectKind = try ReceiptKind(validating: "review-envelope-effect")
    let domainKind = try ReceiptKind(validating: "review-envelope-domain")
    let recordKind = try ReceiptKind(validating: "review-envelope-record")
    let effectID = try ReceiptID(validating: "effect-\(receiptSuffix)")
    let domainID = try ReceiptID(validating: "domain-\(receiptSuffix)")
    let recordID = try ReceiptID(validating: "record-\(receiptSuffix)")
    let placeholderDigest = laneADigest("0")

    func makeSubmission(
        metadata: ReviewRedactionMetadata,
        effectReceipt: ImmutableReceiptReference,
        domainReceipt: ImmutableReceiptReference,
        recordReceipt: ImmutableReceiptReference
    ) throws -> ReviewerFindingSubmission {
        try ReviewerFindingSubmission(
            baselineDigest: fixture.baseline.digest,
            roundID: fixture.baseline.roundID,
            rosterDigest: fixture.roster.digest,
            assignmentID: assignment.id,
            checklistDigest: assignment.checklistDigest,
            redactionPolicy: fixture.redactionPolicy,
            redactionMetadata: metadata,
            actorID: assignment.expectedActorID,
            principalID: assignment.expectedPrincipalID,
            role: assignment.requiredRole,
            envelope: ReviewerEnvelopeBinding(
                artifact: artifact,
                effectReceipt: effectReceipt,
                domainReceipt: domainReceipt,
                recordReceipt: recordReceipt
            ),
            complete: true,
            findings: findings
        )
    }

    let placeholderEffect = ImmutableReceiptReference(id: effectID, digest: placeholderDigest)
    let placeholderDomain = ImmutableReceiptReference(id: domainID, digest: placeholderDigest)
    let placeholderRecord = ImmutableReceiptReference(id: recordID, digest: placeholderDigest)
    let payloadSeed = try makeSubmission(
        metadata: persistedMetadata,
        effectReceipt: placeholderEffect,
        domainReceipt: placeholderDomain,
        recordReceipt: placeholderRecord
    )
    let effectPayload = try ReviewEnvelopeReceiptPayload(
        submission: payloadSeed,
        baseline: fixture.baseline,
        receiptID: effectID,
        receiptKind: effectKind,
        independentContextDigest: independentContextDigest
    )
    let domainPayload = try ReviewEnvelopeReceiptPayload(
        submission: payloadSeed,
        baseline: fixture.baseline,
        receiptID: domainID,
        receiptKind: domainKind,
        independentContextDigest: independentContextDigest
    )
    let effectReceipt = ImmutableReceiptReference(
        id: effectID,
        digest: CanonicalTreeDigest.sha256(try CanonicalJSON.encode(effectPayload))
    )
    let domainReceipt = ImmutableReceiptReference(
        id: domainID,
        digest: CanonicalTreeDigest.sha256(try CanonicalJSON.encode(domainPayload))
    )
    let recordSeed = try makeSubmission(
        metadata: persistedMetadata,
        effectReceipt: effectReceipt,
        domainReceipt: domainReceipt,
        recordReceipt: placeholderRecord
    )
    let recordPayload = try ReviewEnvelopeReceiptPayload(
        submission: recordSeed,
        baseline: fixture.baseline,
        receiptID: recordID,
        receiptKind: recordKind,
        independentContextDigest: independentContextDigest
    )
    let recordReceipt = ImmutableReceiptReference(
        id: recordID,
        digest: CanonicalTreeDigest.sha256(try CanonicalJSON.encode(recordPayload))
    )
    return try makeSubmission(
        metadata: submittedMetadata,
        effectReceipt: effectReceipt,
        domainReceipt: domainReceipt,
        recordReceipt: recordReceipt
    )
}

func laneAReplacingSubmission(
    _ submission: ReviewerFindingSubmission,
    checklistDigest: HashDigest? = nil,
    actorID: ActorID? = nil,
    role: String? = nil,
    complete: Bool? = nil,
    redactionPolicy: RedactionPolicyBinding? = nil
) throws -> ReviewerFindingSubmission {
    try ReviewerFindingSubmission(
        baselineDigest: submission.baselineDigest,
        roundID: submission.roundID,
        rosterDigest: submission.rosterDigest,
        assignmentID: submission.assignmentID,
        checklistDigest: checklistDigest ?? submission.checklistDigest,
        redactionPolicy: redactionPolicy ?? submission.redactionPolicy,
        redactionMetadata: submission.redactionMetadata,
        actorID: actorID ?? submission.actorID,
        principalID: submission.principalID,
        role: role ?? submission.role,
        envelope: submission.envelope,
        complete: complete ?? submission.complete,
        findings: submission.findings
    )
}

func laneAReceiptReference(_ id: String) throws -> ImmutableReceiptReference {
    let receiptID = try ReceiptID(validating: id)
    return ImmutableReceiptReference(
        id: receiptID,
        digest: CanonicalTreeDigest.sha256(laneAReceiptPayload(receiptID))
    )
}

func laneAReceiptPayload(_ id: ReceiptID) -> Data {
    Data("{\"receipt_id\":\"\(id.rawValue)\",\"schema_version\":1}".utf8)
}

func laneAEnvelopePersistedReceipts(
    submission: ReviewerFindingSubmission,
    baseline: ReviewBaseline,
    independentContextDigest: HashDigest = laneADigest("1")
) throws -> [PersistedReceipt] {
    let references: [(ReceiptKind, ImmutableReceiptReference)] = try [
        (
            ReceiptKind(validating: "review-envelope-effect"),
            submission.envelope.effectReceipt
        ),
        (
            ReceiptKind(validating: "review-envelope-domain"),
            submission.envelope.domainReceipt
        ),
        (
            ReceiptKind(validating: "review-envelope-record"),
            submission.envelope.recordReceipt
        ),
    ]
    let transactionID = try TransactionID(rawValue: "staged-review-envelope")
    let transactionDigest = CanonicalTreeDigest.sha256(Data(transactionID.rawValue.utf8))
    return try references.map { kind, reference in
        let payload = try ReviewEnvelopeReceiptPayload(
            submission: submission,
            baseline: baseline,
            receiptID: reference.id,
            receiptKind: kind,
            independentContextDigest: independentContextDigest
        )
        let write = try ReceiptTableWrite(kind: kind, id: reference.id, value: payload)
        guard write.payloadDigest == reference.digest else {
            throw PersistenceError.integrityViolation
        }
        return PersistedReceipt(
            kind: write.kind,
            id: write.id,
            transactionID: transactionID,
            transactionDigest: transactionDigest,
            payloadDigest: write.payloadDigest,
            payloadBytes: write.payloadBytes
        )
    }
}

func laneAReviewerAuthorityFact(
    assignment: ReviewerAssignment,
    actorID: ActorID? = nil,
    principalID: PrincipalID? = nil,
    independentContextDigest: HashDigest = laneADigest("1"),
    hasAuthorshipEdge: Bool = false,
    hasSourceWriteCapability: Bool = false
) throws -> VerifiedAuthorityFact {
    guard let role = AuthorityRole(rawValue: assignment.requiredRole) else {
        throw WorkflowPolicyError.invalidPolicy
    }
    return VerifiedAuthorityFact(
        actorID: actorID ?? assignment.expectedActorID,
        principalID: principalID ?? assignment.expectedPrincipalID,
        roles: [role],
        principalKind: .agent,
        independentContextDigest: independentContextDigest,
        hasAuthorshipEdge: hasAuthorshipEdge,
        hasSourceWriteCapability: hasSourceWriteCapability
    )
}

func laneAAuthorshipContext(
    baseline: ReviewBaseline,
    currentness: VerifiedReviewScopeCurrentness,
    authorActorID: ActorID? = nil,
    authorPrincipalID: PrincipalID? = nil,
    independentContextDigest: HashDigest = laneADigest("2")
) throws -> VerifiedReviewAuthorshipContext {
    let resolvedAuthorPrincipalID: PrincipalID
    if let authorPrincipalID {
        resolvedAuthorPrincipalID = authorPrincipalID
    } else {
        resolvedAuthorPrincipalID = try PrincipalID(validating: "author-principal")
    }
    let authorAuthority = try laneAAuthorAuthorityFact(
        actorID: authorActorID,
        principalID: resolvedAuthorPrincipalID,
        independentContextDigest: independentContextDigest
    )
    return try ReviewAuthorshipContextVerifier.verify(
        authorAuthorities: [authorAuthority],
        authoredArtifacts: baseline.artifactScopes,
        baseline: baseline,
        currentness: currentness
    )
}

func laneAAuthorAuthorityFact(
    actorID: ActorID? = nil,
    principalID: PrincipalID? = nil,
    independentContextDigest: HashDigest = laneADigest("2")
) throws -> VerifiedAuthorityFact {
    let resolvedActorID: ActorID
    if let actorID {
        resolvedActorID = actorID
    } else {
        resolvedActorID = try ActorID(validating: "review-author")
    }
    let resolvedPrincipalID: PrincipalID
    if let principalID {
        resolvedPrincipalID = principalID
    } else {
        resolvedPrincipalID = try PrincipalID(validating: "author-principal")
    }
    return VerifiedAuthorityFact(
        actorID: resolvedActorID,
        principalID: resolvedPrincipalID,
        roles: [.author],
        principalKind: .agent,
        independentContextDigest: independentContextDigest,
        hasAuthorshipEdge: true,
        hasSourceWriteCapability: true
    )
}

func laneAReviewCycleState(for baseline: ReviewBaseline) throws -> ReviewCycleState {
    guard baseline.kind == .initial,
          let cycleOrdinal = baseline.cycleOrdinal
    else { throw WorkflowError.invalidReviewRound }
    return try ReviewCycleState(
        id: baseline.cycleID,
        gate: baseline.gate,
        cycleOrdinal: cycleOrdinal,
        phase: .collectingInitial,
        currentRoundID: baseline.roundID,
        currentRoundKind: baseline.kind,
        currentSemanticOrdinal: baseline.semanticOrdinal,
        didRecordRemediation: false,
        didRecordConfirmation: false,
        redactionPolicy: baseline.redactionPolicy,
        cyclePreFreezeEventHead: baseline.preCreationEventHead,
        currentRoundAnchorEventHead: baseline.preCreationEventHead,
        predecessorBaselineDigest: baseline.predecessorBaselineDigest
    )
}

func laneAPersistedRun(
    baseline: ReviewBaseline,
    submission: ReviewerFindingSubmission,
    independentContextDigest: HashDigest = laneADigest("1"),
    stage: WorkflowStage = .architectureGate,
    reviewCycle: ReviewCycleState? = nil,
    additionalReceipts: [PersistedReceipt] = []
) throws -> PersistedRun {
    var state = try RunState.startEngineering(
        runID: baseline.runID,
        workItemID: "IIS-0002",
        mode: .auto,
        canonSnapshotDigest: baseline.activeProfileDigest
    )
    state.stage = stage
    let activeReviewCycle = try reviewCycle ?? laneAReviewCycleState(for: baseline)
    state.reviewCycle = activeReviewCycle
    state.nextReviewCycleOrdinal = activeReviewCycle.cycleOrdinal
    let event = try WorkflowEvent(
        id: "review-envelope-\(submission.assignmentID.rawValue)",
        kind: .reviewInventoryRecorded
    )
    state.processedEvents.append(try ProcessedWorkflowEvent(recording: event))

    let persistedSubmission = try ReviewerFindingSubmission(
        baselineDigest: submission.baselineDigest,
        roundID: submission.roundID,
        rosterDigest: submission.rosterDigest,
        assignmentID: submission.assignmentID,
        checklistDigest: submission.checklistDigest,
        redactionPolicy: submission.redactionPolicy,
        redactionMetadata: ReviewRedactionMetadata(
            policy: submission.redactionPolicy,
            sanitizedEnvelopeDigest: submission.envelope.artifact.contentHash,
            replacementTokenCount: submission.redactionMetadata.replacementTokenCount,
            containsRawSensitiveData: false
        ),
        actorID: submission.actorID,
        principalID: submission.principalID,
        role: submission.role,
        envelope: submission.envelope,
        complete: submission.complete,
        findings: submission.findings
    )
    let references: [(ReceiptKind, ImmutableReceiptReference)] = try [
        (
            ReceiptKind(validating: "review-envelope-effect"),
            submission.envelope.effectReceipt
        ),
        (
            ReceiptKind(validating: "review-envelope-domain"),
            submission.envelope.domainReceipt
        ),
        (
            ReceiptKind(validating: "review-envelope-record"),
            submission.envelope.recordReceipt
        ),
    ]
    let envelopeWrites = try references.map { kind, reference -> ReceiptTableWrite in
        let payload = try ReviewEnvelopeReceiptPayload(
            submission: persistedSubmission,
            baseline: baseline,
            receiptID: reference.id,
            receiptKind: kind,
            independentContextDigest: independentContextDigest
        )
        let write = try ReceiptTableWrite(kind: kind, id: reference.id, value: payload)
        guard write.payloadDigest == reference.digest else {
            throw PersistenceError.integrityViolation
        }
        return write
    }
    let additionalWrites = try additionalReceipts.map { receipt in
        let write = try ReceiptTableWrite(
            kind: receipt.kind,
            id: receipt.id,
            canonicalPayloadBytes: receipt.payloadBytes
        )
        guard write.payloadDigest == receipt.payloadDigest else {
            throw PersistenceError.integrityViolation
        }
        return write
    }
    let writes = (envelopeWrites + additionalWrites).sorted {
        ($0.kind.rawValue, $0.id.rawValue) < ($1.kind.rawValue, $1.id.rawValue)
    }
    let transaction = try StateTransaction(
        id: TransactionID(rawValue: "review-envelope-\(submission.assignmentID.rawValue)"),
        runRoot: FileManager.default.temporaryDirectory.appendingPathComponent(
            baseline.runID.filesystemComponent,
            isDirectory: true
        ),
        expectedStateDigest: nil,
        expectedEventHead: nil,
        state: state,
        event: event,
        receiptWrites: writes
    )
    let manifest = try writes.map { write -> ReceiptManifestEntry in
        let envelope = ReceiptEnvelope(write: write, transaction: transaction)
        let envelopeBytes = try CanonicalJSON.encode(envelope)
        return ReceiptManifestEntry(
            kind: write.kind,
            id: write.id,
            envelopeDigest: CanonicalTreeDigest.sha256(envelopeBytes),
            payloadDigest: write.payloadDigest,
            envelopeBytes: envelopeBytes
        )
    }
    let stateBytes = transaction.stateBytes
    let stateDigest = CanonicalTreeDigest.sha256(stateBytes)
    let record = try EventLogRecord(
        sequence: 1,
        runID: baseline.runID,
        transactionID: transaction.id,
        previousDigest: nil,
        previousStateDigest: nil,
        stateDigest: stateDigest,
        transactionDigest: transaction.digest,
        fencingToken: FencingToken(validating: 1),
        writerOwnerID: "review-envelope-writer",
        receiptManifest: manifest,
        event: event
    )
    let receipts = writes.map { write in
        PersistedReceipt(
            kind: write.kind,
            id: write.id,
            transactionID: transaction.id,
            transactionDigest: transaction.digest,
            payloadDigest: write.payloadDigest,
            payloadBytes: write.payloadBytes
        )
    }
    return PersistedRun(
        state: state,
        stateBytes: stateBytes,
        stateDigest: stateDigest,
        events: [record],
        eventHead: record.recordDigest,
        receipts: receipts
    )
}

func laneAAdvanceEnvelopeRun(
    _ persistedRun: PersistedRun
) throws -> PersistedRun {
    var state = persistedRun.state
    let event = try WorkflowEvent(
        id: "review-envelope-advance",
        kind: .reviewInventoryRecorded
    )
    state.processedEvents.append(try ProcessedWorkflowEvent(recording: event))
    let receiptID = try ReceiptID(validating: "review-envelope-advance")
    let write = try ReceiptTableWrite(
        kind: ReceiptKind(validating: "review-advance"),
        id: receiptID,
        canonicalPayloadBytes: laneAReceiptPayload(receiptID)
    )
    let transaction = try StateTransaction(
        id: TransactionID(rawValue: "review-envelope-advance"),
        runRoot: FileManager.default.temporaryDirectory.appendingPathComponent(
            state.runID.filesystemComponent,
            isDirectory: true
        ),
        expectedStateDigest: persistedRun.stateDigest,
        expectedEventHead: persistedRun.eventHead,
        state: state,
        event: event,
        receiptWrites: [write]
    )
    let envelope = ReceiptEnvelope(write: write, transaction: transaction)
    let envelopeBytes = try CanonicalJSON.encode(envelope)
    let manifest = ReceiptManifestEntry(
        kind: write.kind,
        id: write.id,
        envelopeDigest: CanonicalTreeDigest.sha256(envelopeBytes),
        payloadDigest: write.payloadDigest,
        envelopeBytes: envelopeBytes
    )
    let stateDigest = CanonicalTreeDigest.sha256(transaction.stateBytes)
    let record = try EventLogRecord(
        sequence: UInt64(persistedRun.events.count + 1),
        runID: state.runID,
        transactionID: transaction.id,
        previousDigest: persistedRun.eventHead,
        previousStateDigest: persistedRun.stateDigest,
        stateDigest: stateDigest,
        transactionDigest: transaction.digest,
        fencingToken: FencingToken(validating: UInt64(persistedRun.events.count + 1)),
        writerOwnerID: "review-envelope-advance",
        receiptManifest: [manifest],
        event: event
    )
    return PersistedRun(
        state: state,
        stateBytes: transaction.stateBytes,
        stateDigest: stateDigest,
        events: persistedRun.events + [record],
        eventHead: record.recordDigest,
        receipts: persistedRun.receipts + [PersistedReceipt(
            kind: write.kind,
            id: write.id,
            transactionID: transaction.id,
            transactionDigest: transaction.digest,
            payloadDigest: write.payloadDigest,
            payloadBytes: write.payloadBytes
        )]
    )
}

func laneAWorkflowSource(_ relativePath: String) -> URL {
    var root = URL(fileURLWithPath: #filePath)
    while root.lastPathComponent != "ifl-ios-standards", root.path != "/" {
        root.deleteLastPathComponent()
    }
    return root
        .appendingPathComponent("tools/ifl-tooling/Sources/IFLWorkflow")
        .appendingPathComponent(relativePath)
}
