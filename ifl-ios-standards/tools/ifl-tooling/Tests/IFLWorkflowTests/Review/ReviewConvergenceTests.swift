import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("ReviewConvergenceTests")
struct ReviewConvergenceTests {
    @Test("accepted issues form one complete remediation batch and an explicit successor")
    func remediationIsCompleteAndCurrent() throws {
        let source = try LaneBReviewScenario.make(acceptedCurrentScope: true)
        let successor = try source.makeSuccessorBaseline()
        let evidence = try laneBRemediationEvidence(publicationAnchor: laneBDigest("8"))
        let change = try RemediationChange(
            fingerprint: #require(source.register.entries.first?.fingerprint),
            preChangeArtifact: source.artifact,
            postChangeArtifact: successor.artifact,
            evidence: evidence
        )
        let remediation = try laneBVerifiedRemediation(
            source: source,
            successorBaseline: successor.baseline,
            changes: [change]
        )
        let batch = remediation.batch

        #expect(batch.sourceRegisterDigest == source.register.digest)
        #expect(batch.sourceBaselineDigest == source.baseline.digest)
        #expect(batch.assignedFingerprints == source.register.acceptedCurrentScopeAssignments)
        #expect(batch.resolvedTransitions.count == 1)
        #expect(batch.resolvedTransitions.allSatisfy { $0.current == .resolved })
        #expect(batch.successorBaselineDigest == remediation.successorBaseline.digest)
        #expect(remediation.plannedEvidence.count == RemediationEvidenceKind.allCases.count)
        #expect(remediation.plannedEvidence.allSatisfy {
            $0.payload.publicationAnchorEventHead == remediation.planning.publicationAnchorEventHead &&
                $0.payload.implementationAuthorityDigest ==
                remediation.implementationAuthority.provenanceDigest &&
                $0.payloadDigest == $0.evidence.receipt.digest
        })
        let bytes = try CanonicalJSON.encode(batch)
        #expect(try RemediationBatch.decodeCanonical(from: bytes) == batch)
        let object = try #require(
            JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        )
        #expect(object["remediation_event_head"] == nil)

        let missingCurrentReviewEvidence = try RemediationChange(
            fingerprint: #require(source.register.entries.first?.fingerprint),
            preChangeArtifact: source.artifact,
            postChangeArtifact: successor.artifact,
            evidence: Array(evidence.dropLast())
        )
        #expect(throws: WorkflowPolicyError.invalidDispositionEvidence) {
            try laneBVerifiedRemediation(
                source: source,
                successorBaseline: successor.baseline,
                changes: [missingCurrentReviewEvidence]
            )
        }

        let nonImplementer = VerifiedAuthorityFact(
            actorID: try ActorID(validating: "read-only-reviewer"),
            principalID: try PrincipalID(validating: "read-only-principal"),
            roles: [.standardsValidator],
            principalKind: .agent,
            independentContextDigest: laneBDigest("7"),
            hasAuthorshipEdge: false,
            hasSourceWriteCapability: false
        )
        #expect(throws: WorkflowPolicyError.invalidDispositionEvidence) {
            try laneBVerifiedRemediation(
                source: source,
                successorBaseline: successor.baseline,
                changes: [change],
                implementingAuthority: nonImplementer
            )
        }

        let invalidAuthorities = try [
            VerifiedAuthorityFact(
                actorID: ActorID(validating: "implementing-agent"),
                principalID: PrincipalID(validating: "implementing-principal"),
                roles: [.standardsValidator],
                principalKind: .agent,
                independentContextDigest: laneBDigest("6"),
                hasAuthorshipEdge: true,
                hasSourceWriteCapability: true
            ),
            VerifiedAuthorityFact(
                actorID: ActorID(validating: "implementing-agent"),
                principalID: PrincipalID(validating: "implementing-principal"),
                roles: [.author],
                principalKind: .agent,
                independentContextDigest: laneBDigest("6"),
                hasAuthorshipEdge: false,
                hasSourceWriteCapability: true
            ),
            VerifiedAuthorityFact(
                actorID: ActorID(validating: "implementing-agent"),
                principalID: PrincipalID(validating: "implementing-principal"),
                roles: [.author],
                principalKind: .agent,
                independentContextDigest: laneBDigest("6"),
                hasAuthorshipEdge: true,
                hasSourceWriteCapability: false
            ),
            VerifiedAuthorityFact(
                actorID: ActorID(validating: "implementing-agent"),
                principalID: PrincipalID(validating: "implementing-principal"),
                roles: [.author],
                principalKind: .human,
                independentContextDigest: laneBDigest("6"),
                hasAuthorshipEdge: true,
                hasSourceWriteCapability: true
            ),
        ]
        for invalidAuthority in invalidAuthorities {
            #expect(throws: WorkflowPolicyError.invalidDispositionEvidence) {
                try laneBVerifiedRemediation(
                    source: source,
                    successorBaseline: successor.baseline,
                    changes: [change],
                    implementingAuthority: invalidAuthority
                )
            }
        }
    }

    @Test("RRC-05 remediation evidence payload is typed and requires published provenance")
    func remediationEvidencePayloadRequiresPublishedProvenance() throws {
        #expect(ReviewRemediationEvidencePayload.self is any Encodable.Type)
        #expect(ReviewRemediationEvidencePayload.self is any Decodable.Type)

        let source = try String(
            contentsOf: laneAWorkflowSource("Review/RemediationBatch.swift"),
            encoding: .utf8
        )
        #expect(source.contains("ReviewRemediationEvidencePayload.decodeCanonical"))
        #expect(source.contains("VerifiedPublishedReviewReceipt"))
        #expect(source.contains("implementationAuthority.implementingPrincipalID"))
        #expect(source.contains("implementationAuthority.implementingContextDigest"))
        #expect(source.contains("ReviewCommittedRemediationVerifier"))
        #expect(source.contains("receiptManifest"))
        #expect(source.contains("persistedRun.events"))
    }

    @Test("RRC-05 planned remediation evidence cannot be replayed at another H_before")
    func remediationEvidenceRejectsEarlierAnchorReplay() throws {
        let source = try LaneBReviewScenario.make(acceptedCurrentScope: true)
        let successorTemplate = try source.makeSuccessorBaseline()
        let authority = VerifiedAuthorityFact(
            actorID: try ActorID(validating: "implementing-agent"),
            principalID: try PrincipalID(validating: "implementing-principal"),
            roles: [.author],
            principalKind: .agent,
            independentContextDigest: laneBDigest("6"),
            hasAuthorshipEdge: true,
            hasSourceWriteCapability: true
        )
        let templateChange = try RemediationChange(
            fingerprint: #require(source.register.entries.first?.fingerprint),
            preChangeArtifact: source.artifact,
            postChangeArtifact: successorTemplate.artifact,
            evidence: laneBRemediationEvidence(publicationAnchor: laneBDigest("8"))
        )
        let original = try laneBPlannedRemediation(
            source: source,
            successorBaseline: successorTemplate.baseline,
            changes: [templateChange],
            implementingAuthority: authority
        )
        let advancedHead = laneBDigest("9")
        let successor = try laneBReanchorSuccessorBaseline(
            successorTemplate.baseline,
            source: source,
            eventHead: advancedHead
        )
        let advancedPlanning = try ReviewCapabilityTestFactory.verifyRemediationPlanningContext(
            sourceRegister: source.verifiedRegister,
            successorBaseline: successor,
            publicationAnchorEventHead: advancedHead
        )
        let advancedAuthority = try ReviewImplementationAuthorityVerifier.verify(
            authority: authority,
            planning: advancedPlanning
        )

        #expect(throws: WorkflowPolicyError.invalidDispositionEvidence) {
            try ReviewRemediationVerifier.verifySuccessor(
                sourceRegister: source.verifiedRegister,
                changes: original.changes,
                plannedEvidence: original.plannedEvidence,
                implementationAuthority: advancedAuthority,
                successorBaseline: successor,
                planning: advancedPlanning
            )
        }
    }

    @Test("committed remediation recovery requires one exact atomic receipt closure")
    func committedRemediationRecoveryIsAtomicAndRestartSafe() throws {
        let source = try LaneBReviewScenario.make(acceptedCurrentScope: true)
        let successorTemplate = try source.makeSuccessorBaseline()
        let committed = try laneBCommittedRemediation(
            source: source,
            successorTemplate: successorTemplate.baseline
        )

        #expect(committed.successor.batch == committed.plannedSuccessor.batch)
        #expect(committed.successor.sourceBaseline == source.baseline)
        #expect(committed.successor.successorBaseline == committed.successorScenario.baseline)
        #expect(committed.successor.publicationAnchorEventHead ==
            committed.plannedSuccessor.planning.publicationAnchorEventHead)
        #expect(committed.successor.producedEventHead == committed.persistedRun.eventHead)
        #expect(committed.successor.receipts.count ==
            RemediationEvidenceKind.allCases.count + 3)

        #expect(throws: PersistenceError.integrityViolation) {
            try laneBCommittedRemediation(
                source: source,
                successorTemplate: successorTemplate.baseline,
                includeUnexpectedReceipt: true
            )
        }
    }

    @Test("RRC-05 receipt authority validates the active chain before any confirmation exists")
    func receiptAuthorityRejectsBrokenPreConfirmationChain() throws {
        let scenario = try LaneBReviewScenario.make(acceptedCurrentScope: false)
        let valid = try laneBReceiptAuthority(scenario: scenario)
        let broken = PersistedRun(
            state: valid.persistedRun.state,
            stateBytes: valid.persistedRun.stateBytes,
            stateDigest: valid.persistedRun.stateDigest,
            events: [],
            eventHead: valid.persistedRun.eventHead,
            receipts: valid.persistedRun.receipts
        )

        #expect(throws: PersistenceError.integrityViolation) {
            try ReviewCapabilityTestFactory.verifyReceiptAuthority(
                persistedRun: broken,
                currentness: valid.authority.currentness,
                policies: scenario.policies,
                approvalRecords: []
            )
        }
    }

    @Test("direct and remediated convergence remain distinct immutable paths")
    func directAndConfirmedReceipts() throws {
        let direct = try LaneBReviewScenario.make(acceptedCurrentScope: false)
        let directAuthority = try laneBReceiptAuthority(scenario: direct)
        let directAnchor = directAuthority.authority.eventHead
        let directReceipt = try ReviewConvergenceValidator.issueDirectConvergence(
            register: direct.verifiedRegister,
            authority: directAuthority.authority,
            publicationAnchorEventHead: directAnchor
        )
        let directObject = try laneBJSONObject(directReceipt)
        #expect(directReceipt.schemaVersion == 2)
        #expect(directReceipt.publicationAnchorEventHead == directAnchor)
        #expect(directObject["publication_anchor_event_head"] as? String
            == directAnchor.rawValue)
        #expect(directObject["final_event_head"] == nil)
        #expect(directReceipt.path == .directConvergenceNoAcceptedCurrentScope)
        #expect(directReceipt.confirmationReceiptDigest == nil)
        #expect(directReceipt.remediationBatchDigests.isEmpty)
        #expect(try ConvergenceReceipt.decodeCanonical(
            from: CanonicalJSON.encode(directReceipt)
        ) == directReceipt)

        let source = try LaneBReviewScenario.make(acceptedCurrentScope: true)
        let successorTemplate = try source.makeSuccessorBaseline()
        let committedBundle = try laneBCommittedRemediation(
            source: source,
            successorTemplate: successorTemplate.baseline
        )
        let remediation = committedBundle.successor
        let successor = try successorTemplate.replacingBaseline(
            remediation.successorBaseline
        )
        let batch = remediation.batch
        let confirmationScenario = try successor.makeConfirmationRegister()
        let lineageReceipts = try laneBLineageSeedReceipts(
            source: source,
            confirmation: confirmationScenario
        )
        let confirmationAuthority = try laneBReceiptAuthority(
            scenario: confirmationScenario,
            priorPersistedRun: committedBundle.persistedRun,
            lineageReceipts: lineageReceipts
        )
        let confirmationAnchor = confirmationAuthority.authority.eventHead
        let confirmation = try ReviewConvergenceValidator.issueConfirmation(
            successor: remediation,
            confirmationRegister: confirmationScenario.verifiedRegister,
            authority: confirmationAuthority.authority,
            publicationAnchorEventHead: confirmationAnchor
        )
        let confirmationObject = try laneBJSONObject(confirmation)
        #expect(confirmation.schemaVersion == 2)
        #expect(confirmation.publicationAnchorEventHead == confirmationAnchor)
        #expect(confirmationObject["publication_anchor_event_head"] as? String
            == confirmationAnchor.rawValue)
        #expect(confirmationObject["final_event_head"] == nil)
        #expect(try ConfirmationReceipt.decodeCanonical(
            from: CanonicalJSON.encode(confirmation)
        ) == confirmation)

        let confirmedRun = try laneBAppendConfirmation(
            confirmation,
            scenario: confirmationScenario,
            to: confirmationAuthority.persistedRun
        )
        let repeatedAuthority = try laneBReceiptAuthority(
            scenario: confirmationScenario,
            priorPersistedRun: confirmedRun
        )
        #expect(throws: WorkflowPolicyError.normalConfirmationAlreadyRecorded) {
            try ReviewConvergenceValidator.issueConfirmation(
                successor: remediation,
                confirmationRegister: confirmationScenario.verifiedRegister,
                authority: repeatedAuthority.authority,
                publicationAnchorEventHead: repeatedAuthority.authority.eventHead
            )
        }
        let sourceAuthority = try laneBReceiptAuthority(scenario: source)
        #expect(throws: WorkflowPolicyError.remediationRequired) {
            try ReviewConvergenceValidator.issueDirectConvergence(
                register: source.verifiedRegister,
                authority: sourceAuthority.authority,
                publicationAnchorEventHead: sourceAuthority.authority.eventHead
            )
        }

        let convergenceAuthority = repeatedAuthority
        let lineage = try laneBConfirmationLineage(
            source: source,
            successor: successor,
            remediation: remediation,
            confirmationScenario: confirmationScenario,
            confirmation: confirmation,
            confirmationAuthority: confirmationAuthority.authority,
            authority: convergenceAuthority
        )
        let converged = try ReviewConvergenceValidator.issueConfirmedConvergence(
            lineage: lineage,
            authority: convergenceAuthority.authority,
            publicationAnchorEventHead: convergenceAuthority.authority.eventHead
        )
        let convergedObject = try laneBJSONObject(converged)
        #expect(converged.schemaVersion == 2)
        #expect(converged.publicationAnchorEventHead == convergenceAuthority.authority.eventHead)
        #expect(convergedObject["publication_anchor_event_head"] as? String
            == convergenceAuthority.authority.eventHead.rawValue)
        #expect(convergedObject["final_event_head"] == nil)
        #expect(converged.path == .confirmedRemediation)
        #expect(converged.baselineLineage == [source.baseline.digest, successor.baseline.digest])
        #expect(converged.registerDigests
            == [source.register.digest, confirmationScenario.register.digest])
        #expect(converged.remediationBatchDigests == [batch.digest])
        #expect(converged.confirmationReceiptDigest == confirmation.digest)
        #expect(converged.publicationAnchorEventHead == convergenceAuthority.authority.eventHead)
        let plannedConvergence = try ReviewSemanticIngress.verifyConvergenceReceipt(
            bytes: CanonicalJSON.encode(converged),
            lineage: lineage,
            authority: convergenceAuthority.authority
        )
        #expect(plannedConvergence.payloadDigest
            == CanonicalTreeDigest.sha256(try CanonicalJSON.encode(converged)))

        let directComparableAuthority = try laneBReceiptAuthority(scenario: direct)
        let directComparable = try ReviewConvergenceValidator.issueDirectConvergence(
            register: direct.verifiedRegister,
            authority: directComparableAuthority.authority,
            publicationAnchorEventHead: directComparableAuthority.authority.eventHead
        )
        #expect(directComparable.receiptID != converged.receiptID)
    }

    @Test("literal confirmation and exception facts drive independent Task-2 decisions")
    func literalDecisionFixtures() throws {
        let expectedFixtureSHA256 = [
            "second-normal-confirmation.json": "03d96b8cd4dfb9ac6d95c037ae1c7c5fc6717805dde01f7182a77faef93a10a3",
            "exception-medium-only.json": "0b4e2fadf63ad8c3a13b448f4d91dbadc7d67f24dd3b3e999f4086bab6b20991",
            "exception-new-high.json": "3c2afaec6dd88089bb92da97e2e07f99e9da53ea819806a95e0e47661067917c",
        ]
        let confirmation = try normalConfirmationFixture()
        let confirmationBytes = try reviewFixtureData("second-normal-confirmation.json")
        try expectCanonicalReviewFixture(
            confirmation,
            rawBytes: confirmationBytes
        )
        #expect(CanonicalTreeDigest.sha256(confirmationBytes).rawValue
            == expectedFixtureSHA256["second-normal-confirmation.json"])
        #expect(CanonicalTreeDigest.sha256(confirmation.historyBytes).rawValue
            == confirmation.expectedHistorySHA256)
        #expect(confirmation.productionWireType == "KernelReviewHistory/v1")
        #expect(confirmation.requestedRoundKind == ReviewRoundKind.normalConfirmation.rawValue)
        #expect(confirmation.expectedDecision == "rejected")
        #expect(confirmation.expectedError == "normal_confirmation_already_recorded")
        let history = try CanonicalJSON.decode(
            KernelReviewHistory.self,
            from: confirmation.historyBytes
        )
        #expect(try CanonicalJSON.encode(history) == confirmation.historyBytes)
        #expect(throws: WorkflowPolicyError.normalConfirmationAlreadyRecorded) {
            try ReviewConvergencePolicy().admitNormalConfirmation(history)
        }
        var historyWithUnknownField = try laneBJSONObject(history)
        historyWithUnknownField["caller_claim"] = true
        #expect(throws: (any Error).self) {
            try CanonicalJSON.decode(
                KernelReviewHistory.self,
                from: laneBCanonicalJSONObject(historyWithUnknownField)
            )
        }

        for filename in ["exception-medium-only.json", "exception-new-high.json"] {
            let fixture = try exceptionFixture(filename)
            let fixtureBytes = try reviewFixtureData(filename)
            try expectCanonicalReviewFixture(
                fixture,
                rawBytes: fixtureBytes
            )
            #expect(CanonicalTreeDigest.sha256(fixtureBytes).rawValue
                == expectedFixtureSHA256[filename])
            #expect(CanonicalTreeDigest.sha256(fixture.contextBytes).rawValue
                == fixture.expectedContextSHA256)
            #expect(fixture.productionWireType == "ReviewExceptionContext/v1")
            let context = try CanonicalJSON.decode(
                ReviewExceptionContext.self,
                from: fixture.contextBytes
            )
            #expect(try CanonicalJSON.encode(context) == fixture.contextBytes)
            var contextWithUnknownField = try laneBJSONObject(context)
            contextWithUnknownField["caller_claim"] = true
            #expect(throws: (any Error).self) {
                try CanonicalJSON.decode(
                    ReviewExceptionContext.self,
                    from: laneBCanonicalJSONObject(contextWithUnknownField)
                )
            }
            let decision = ReviewConvergenceValidator.evaluateException(
                context,
                budget: try AttemptBudget.standardV1(policyDigest: laneBDigest("f"))
            )
            switch (fixture.expectedDecision, decision) {
            case ("not_eligible", .notEligible):
                #expect(fixture.expectedNextSemanticOrdinal == nil)
                #expect(fixture.expectedRemainingExceptionRounds == nil)
                #expect(fixture.expectedQualifyingFingerprints.isEmpty)
            case ("eligible", .eligible(let proof)):
                #expect(proof.qualifyingFingerprints.map(\.rawValue)
                    == fixture.expectedQualifyingFingerprints)
                #expect(proof.nextSemanticOrdinal == fixture.expectedNextSemanticOrdinal)
                #expect(proof.remainingExceptionRounds
                    == fixture.expectedRemainingExceptionRounds)
            default:
                Issue.record("unexpected exception decision: \(decision)")
            }
        }
    }

    @Test("RC-04 accepted issue cannot be remediated through an unrelated artifact")
    func remediationMapsExactIssueArtifact() throws {
        let target = try laneBArtifact(
            id: "review-source",
            scopeValue: "Sources/Review",
            hashCharacter: "3"
        )
        let unrelated = try laneBArtifact(
            id: "review-support",
            scopeValue: "Sources/Support",
            hashCharacter: "4"
        )
        let source = try LaneBReviewScenario.make(
            acceptedCurrentScope: true,
            targetArtifact: target,
            artifactScopes: [target, unrelated]
        )
        let changedUnrelated = try laneBArtifact(
            id: "review-support",
            scopeValue: "Sources/Support",
            hashCharacter: "5"
        )
        let successor = try laneBSuccessorBaseline(
            source: source,
            artifacts: [target, changedUnrelated]
        )
        let unrelatedChange = try RemediationChange(
            fingerprint: #require(source.register.entries.first?.fingerprint),
            preChangeArtifact: unrelated,
            postChangeArtifact: changedUnrelated,
            evidence: laneBRemediationEvidence(publicationAnchor: laneBDigest("8"))
        )

        #expect(throws: (any Error).self) {
            try laneBVerifiedRemediation(
                source: source,
                successorBaseline: successor,
                changes: [unrelatedChange],
            )
        }
    }

    @Test("RC-04 successor preserves run gate anchor and every unaffected artifact")
    func remediationSuccessorIsDeterministic() throws {
        let target = try laneBArtifact(
            id: "review-source",
            scopeValue: "Sources/Review",
            hashCharacter: "3"
        )
        let unaffected = try laneBArtifact(
            id: "review-support",
            scopeValue: "Sources/Support",
            hashCharacter: "4"
        )
        let source = try LaneBReviewScenario.make(
            acceptedCurrentScope: true,
            targetArtifact: target,
            artifactScopes: [target, unaffected]
        )
        let changedTarget = try laneBArtifact(
            id: "review-source",
            scopeValue: "Sources/Review",
            hashCharacter: "9"
        )
        let change = try RemediationChange(
            fingerprint: #require(source.register.entries.first?.fingerprint),
            preChangeArtifact: target,
            postChangeArtifact: changedTarget,
            evidence: laneBRemediationEvidence(publicationAnchor: laneBDigest("8"))
        )
        let crossRun = RunID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000025")!
        )
        let wrongLineage = try laneBSuccessorBaseline(
            source: source,
            artifacts: [changedTarget, unaffected],
            runID: crossRun,
            gate: .design,
            anchor: laneBDigest("0")
        )
        #expect(throws: (any Error).self) {
            try laneBVerifiedRemediation(
                source: source,
                successorBaseline: wrongLineage,
                changes: [change],
            )
        }

        let alteredUnaffected = try laneBArtifact(
            id: "review-support",
            scopeValue: "Sources/Support",
            hashCharacter: "a"
        )
        let nonDeterministic = try laneBSuccessorBaseline(
            source: source,
            artifacts: [changedTarget, alteredUnaffected]
        )
        #expect(throws: (any Error).self) {
            try laneBVerifiedRemediation(
                source: source,
                successorBaseline: nonDeterministic,
                changes: [change],
            )
        }
    }

    @Test("RRC-03 every remediated round mints the deterministic next review baseline")
    func remediationSuccessorAdvancesNormalAndExceptionRounds() throws {
        let initial = try LaneBReviewScenario.make(acceptedCurrentScope: true)
        let normal = try initial.makeSuccessorBaseline()
            .makeConfirmationRegister(acceptedCurrentScope: true)
        let firstException = try laneBRemediationSuccessorBaseline(
            source: normal,
            kind: .exception,
            semanticOrdinal: 2,
            anchor: laneBDigest("a"),
            artifactHash: "a"
        )
        let first = try laneBVerifiedRemediation(
            source: normal,
            successorBaseline: firstException
        )
        #expect(first.successorBaseline.kind == .exception)
        #expect(first.successorBaseline.semanticOrdinal == 2)

        let exceptionSource = try laneBScenario(
            replacing: normal,
            baseline: firstException,
            acceptedCurrentScope: true
        )
        let secondException = try laneBRemediationSuccessorBaseline(
            source: exceptionSource,
            kind: .exception,
            semanticOrdinal: 3,
            anchor: laneBDigest("b"),
            artifactHash: "b"
        )
        let second = try laneBVerifiedRemediation(
            source: exceptionSource,
            successorBaseline: secondException
        )
        #expect(second.successorBaseline.kind == .exception)
        #expect(second.successorBaseline.semanticOrdinal == 3)
        #expect(second.successorBaseline.predecessorBaselineDigest == firstException.digest)
    }

    @Test("RC-04 decoded resolved transition evidence equals its exact change evidence")
    func transitionEvidenceCannotBeSubstituted() throws {
        let source = try LaneBReviewScenario.make(acceptedCurrentScope: true)
        let successor = try source.makeSuccessorBaseline()
        let batch = try laneBVerifiedRemediation(
            source: source,
            successorBaseline: successor.baseline
        ).batch
        var object = try laneBJSONObject(batch)
        var transitions = try #require(object["resolved_transitions"] as? [[String: Any]])
        var first = try #require(transitions.first)
        var evidence = try #require(first["evidence_digests"] as? [String])
        evidence[0] = laneBDigest("0").rawValue
        first["evidence_digests"] = evidence
        transitions[0] = first
        object["resolved_transitions"] = transitions
        var payload = object
        payload.removeValue(forKey: "batch_digest")
        object["batch_digest"] = CanonicalTreeDigest.sha256(
            try laneBCanonicalJSONObject(payload)
        ).rawValue

        #expect(throws: (any Error).self) {
            try RemediationBatch.decodeCanonical(from: laneBCanonicalJSONObject(object))
        }
    }

    @Test("RC-05 only an initial joined register may mint direct convergence")
    func confirmationBaselineCannotMintDirectConvergence() throws {
        let source = try LaneBReviewScenario.make(acceptedCurrentScope: false)
        let successor = try source.makeSuccessorBaseline()
        let confirmation = try successor.makeConfirmationRegister()
        let authority = try laneBReceiptAuthority(scenario: confirmation)

        #expect(throws: (any Error).self) {
            try ReviewConvergenceValidator.issueDirectConvergence(
                register: confirmation.verifiedRegister,
                authority: authority.authority,
                publicationAnchorEventHead: authority.authority.eventHead
            )
        }
    }

    @Test("RC-05 normal confirmation records dispositioned nonblocking findings")
    func confirmationAllowsNonblockingEntries() throws {
        let source = try LaneBReviewScenario.make(acceptedCurrentScope: true)
        let successorTemplate = try source.makeSuccessorBaseline()
        let committedBundle = try laneBCommittedRemediation(
            source: source,
            successorTemplate: successorTemplate.baseline
        )
        let remediation = committedBundle.successor
        let successor = try successorTemplate.replacingBaseline(
            remediation.successorBaseline
        )
        let confirmation = try successor.makeConfirmationRegister(nonblockingFinding: true)
        #expect(confirmation.register.entries.count == 1)
        #expect(confirmation.register.acceptedCurrentScopeAssignments.isEmpty)
        #expect(confirmation.register.pathDecision == .directConvergenceNoAcceptedCurrentScope)

        let authority = try laneBReceiptAuthority(
            scenario: confirmation,
            priorPersistedRun: committedBundle.persistedRun,
            lineageReceipts: try laneBLineageSeedReceipts(
                source: source,
                confirmation: confirmation
            )
        )
        let receipt = try ReviewConvergenceValidator.issueConfirmation(
            successor: remediation,
            confirmationRegister: confirmation.verifiedRegister,
            authority: authority.authority,
            publicationAnchorEventHead: authority.authority.eventHead
        )
        #expect(receipt.confirmationRegisterDigest == confirmation.register.digest)
    }

    @Test("RC-05 foreign exception proof cannot enter convergence lineage")
    func exceptionLineageRejectsCrossCycleProof() throws {
        let source = try LaneBReviewScenario.make(acceptedCurrentScope: true)
        let successorTemplate = try source.makeSuccessorBaseline()
        let committedBundle = try laneBCommittedRemediation(
            source: source,
            successorTemplate: successorTemplate.baseline
        )
        let remediation = committedBundle.successor
        let successor = try successorTemplate.replacingBaseline(
            remediation.successorBaseline
        )
        let confirmationScenario = try successor.makeConfirmationRegister(
            acceptedCurrentScope: true
        )
        let lineageReceipts = try laneBLineageSeedReceipts(
            source: source,
            confirmation: confirmationScenario
        )
        let confirmationAuthority = try laneBReceiptAuthority(
            scenario: confirmationScenario,
            priorPersistedRun: committedBundle.persistedRun,
            lineageReceipts: lineageReceipts
        )
        let confirmation = try ReviewConvergenceValidator.issueConfirmation(
            successor: remediation,
            confirmationRegister: confirmationScenario.verifiedRegister,
            authority: confirmationAuthority.authority,
            publicationAnchorEventHead: confirmationAuthority.authority.eventHead
        )
        let confirmedRun = try laneBAppendConfirmation(
            confirmation,
            scenario: confirmationScenario,
            to: confirmationAuthority.persistedRun
        )
        let exceptionBaseline = try laneBRemediationSuccessorBaseline(
            source: confirmationScenario,
            kind: .exception,
            semanticOrdinal: 2,
            anchor: confirmedRun.eventHead,
            artifactHash: "a"
        )
        let exceptionArtifact = try #require(
            exceptionBaseline.artifactScopes.first {
                $0.id == confirmationScenario.artifact.id
            }
        )
        let exceptionChange = try RemediationChange(
            fingerprint: #require(confirmationScenario.register.entries.first?.fingerprint),
            preChangeArtifact: confirmationScenario.artifact,
            postChangeArtifact: exceptionArtifact,
            evidence: laneBRemediationEvidence(
                publicationAnchor: confirmedRun.eventHead,
                receiptIDSuffix: "exception"
            )
        )
        let plannedExceptionRemediation = try laneBVerifiedRemediation(
            source: confirmationScenario,
            successorBaseline: exceptionBaseline,
            changes: [exceptionChange]
        )
        let exceptionRemediationRun = try laneBAppendCommittedRemediation(
            plannedExceptionRemediation,
            to: confirmedRun,
            includeUnexpectedReceipt: false
        )
        let exceptionRemediation = try ReviewCommittedRemediationVerifier.verify(
            sourceRegister: confirmationScenario.verifiedRegister,
            batch: plannedExceptionRemediation.batch,
            successorBaseline: exceptionBaseline,
            persistedRun: exceptionRemediationRun
        )
        let exceptionScenario = try laneBScenario(
            replacing: confirmationScenario,
            baseline: exceptionBaseline,
            acceptedCurrentScope: false
        )
        let foreign = try laneBForeignExceptionProof()
        let convergenceAuthority = try laneBReceiptAuthority(
            scenario: exceptionScenario,
            priorPersistedRun: exceptionRemediationRun,
            lineageReceipts: try laneBExceptionLineageReceipts(
                scenario: exceptionScenario,
                proof: foreign
            )
        )
        let publishedLineage = try laneBCommittedLineageReceipts(
            in: convergenceAuthority.persistedRun
        )

        #expect(throws: WorkflowPolicyError.invalidExceptionProof) {
            try ReviewConfirmationLineageVerifier.verify(
                registers: [
                    source.verifiedRegister,
                    confirmationScenario.verifiedRegister,
                    exceptionScenario.verifiedRegister,
                ],
                remediation: [remediation, exceptionRemediation],
                confirmationReceipts: [confirmation],
                exceptionRounds: [foreign],
                convergenceReceipts: [],
                receipts: publishedLineage,
                persistedRun: convergenceAuthority.persistedRun,
                authority: convergenceAuthority.authority
            )
        }
    }

    @Test("RC-01/02 convergence receipt binds current artifact facts and deterministic ID")
    func convergenceReceiptRejectsClaimedCurrentnessAndReceiptID() throws {
        let direct = try LaneBReviewScenario.make(acceptedCurrentScope: false)
        let authority = try laneBReceiptAuthority(scenario: direct)
        let finalHead = authority.authority.eventHead
        let receipt = try ReviewConvergenceValidator.issueDirectConvergence(
            register: direct.verifiedRegister,
            authority: authority.authority,
            publicationAnchorEventHead: finalHead
        )
        #expect(receipt.schemaVersion == 2)
        #expect(receipt.publicationAnchorEventHead == finalHead)
        #expect(receipt.receiptID.hasPrefix("review-convergence-"))
        #expect(receipt.receiptID.dropFirst("review-convergence-".count).count == 64)
        #expect(!receipt.receiptID.hasSuffix(String(finalHead.rawValue.prefix(16))))

        var mutatedArtifacts = direct.baseline.artifactScopes
        mutatedArtifacts[0] = try laneBArtifact(hashCharacter: "f")
        #expect(throws: (any Error).self) {
            try ReviewCapabilityTestFactory.verifyCurrentness(
                baseline: direct.baseline,
                currentArtifacts: mutatedArtifacts,
                currentEventHead: finalHead
            )
        }
        let other = try LaneBReviewScenario.make(
            acceptedCurrentScope: false,
            targetArtifact: laneBArtifact(hashCharacter: "4")
        )
        let otherAuthority = try laneBReceiptAuthority(scenario: other)
        #expect(throws: (any Error).self) {
            try ReviewConvergenceValidator.issueDirectConvergence(
                register: direct.verifiedRegister,
                authority: otherAuthority.authority,
                publicationAnchorEventHead: otherAuthority.authority.eventHead
            )
        }

        var object = try laneBJSONObject(receipt)
        object["receipt_id"] = "review-convergence-caller-claim"
        let claimedIDBytes = try laneBCanonicalJSONObject(object)
        #expect(throws: (any Error).self) {
            try ReviewSemanticIngress.verifyConvergenceReceipt(
                bytes: claimedIDBytes,
                register: direct.verifiedRegister,
                authority: authority.authority
            )
        }
    }
}

struct LaneBReviewScenario {
    let runID: RunID
    let cycleOrdinal: UInt64
    let cyclePreFreezeEventHead: HashDigest
    let baseline: ReviewBaseline
    let roster: FrozenReviewerRoster
    let assignment: ReviewerAssignment
    let artifact: ArtifactReference
    let components: IssueFingerprintComponents
    let register: IssueRegister
    let verifiedRegister: VerifiedIssueRegister
    let inventories: VerifiedCompleteInventorySet
    let policies: VerifiedReviewPolicySet
    let currentness: VerifiedReviewScopeCurrentness

    static func make(
        acceptedCurrentScope: Bool,
        targetArtifact: ArtifactReference? = nil,
        artifactScopes: [ArtifactReference]? = nil,
        runID requestedRunID: RunID? = nil,
        gate: ReviewGateKind = .architecture,
        cycleOrdinal: UInt64 = 0,
        preFreezeEventHead: HashDigest = laneBDigest("4"),
        activeProfileDigest: HashDigest = laneBDigest("5")
    ) throws -> LaneBReviewScenario {
        let runID = requestedRunID ?? RunID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000024")!
        )
        let redaction = try RedactionPolicyBinding(
            identity: "review-redaction-v1",
            digest: laneBDigest("1")
        )
        let assignment = try ReviewerAssignment(
            id: ReviewAssignmentID(validating: "architecture-reviewer"),
            requiredRole: AuthorityRole.standardsValidator.rawValue,
            assuranceClass: .heightened,
            independenceConstraints: [
                .distinctPrincipal, .noAuthorshipEdge, .noSourceWriteCapability,
            ],
            checklistDigest: laneBDigest("2"),
            redactionPolicy: redaction,
            expectedActorID: ActorID(validating: "reviewer-agent"),
            expectedPrincipalID: PrincipalID(validating: "reviewer-principal"),
            evidenceKind: .findingProducingReview
        )
        let roster = try FrozenReviewerRoster.freeze(
            assignments: [assignment],
            redactionPolicy: redaction
        )
        let artifact: ArtifactReference
        if let targetArtifact {
            artifact = targetArtifact
        } else {
            artifact = try laneBArtifact(hashCharacter: "3")
        }
        let frozenArtifactScopes = artifactScopes ?? [artifact]
        let round = try ReviewRoundInput.initial(
            gate: gate,
            cycleOrdinal: cycleOrdinal,
            preFreezeEventHead: preFreezeEventHead,
            redactionPolicy: redaction
        )
        let baseline = try ReviewBaseline.freeze(
            runID: runID,
            roundInput: round,
            artifactScopes: frozenArtifactScopes,
            activeProfileDigest: activeProfileDigest,
            riskPolicyDigest: laneBDigest("6"),
            assurancePolicyDigest: laneBDigest("7"),
            convergencePolicyDigest: laneBDigest("8"),
            roster: roster
        )
        let components = try IssueFingerprintComponents(
            identity: ReviewFindingIdentity(kind: .rule, value: "IFL-REVIEW-001"),
            artifactID: artifact.id,
            scopeSelector: artifact.scope,
            locationSelector: "review-convergence",
            invariantID: "complete-atomic-review",
            expectedClass: "complete",
            actualClass: "partial"
        )
        let registerBundle = try makeRegister(
            baseline: baseline,
            cycleOrdinal: cycleOrdinal,
            cyclePreFreezeEventHead: preFreezeEventHead,
            roster: roster,
            assignment: assignment,
            artifact: artifact,
            components: components,
            acceptedCurrentScope: acceptedCurrentScope
        )
        return LaneBReviewScenario(
            runID: runID,
            cycleOrdinal: cycleOrdinal,
            cyclePreFreezeEventHead: preFreezeEventHead,
            baseline: baseline,
            roster: roster,
            assignment: assignment,
            artifact: artifact,
            components: components,
            register: registerBundle.register,
            verifiedRegister: registerBundle.verifiedRegister,
            inventories: registerBundle.inventories,
            policies: registerBundle.policies,
            currentness: registerBundle.currentness
        )
    }

    func makeSuccessorBaseline(
        anchor: HashDigest = laneBDigest("8")
    ) throws -> LaneBSuccessorScenario {
        let artifact = try laneBArtifact(hashCharacter: "9")
        let round = try ReviewRoundInput.later(
            cycleID: baseline.cycleID,
            gate: baseline.gate,
            kind: .normalConfirmation,
            semanticOrdinal: 1,
            roundAnchorEventHead: anchor,
            predecessorBaselineDigest: baseline.digest,
            redactionPolicy: baseline.redactionPolicy
        )
        let successor = try ReviewBaseline.freeze(
            runID: runID,
            roundInput: round,
            artifactScopes: [artifact],
            activeProfileDigest: baseline.activeProfileDigest,
            riskPolicyDigest: baseline.riskPolicyDigest,
            assurancePolicyDigest: baseline.assurancePolicyDigest,
            convergencePolicyDigest: baseline.convergencePolicyDigest,
            roster: roster
        )
        return LaneBSuccessorScenario(
            runID: runID,
            cycleOrdinal: cycleOrdinal,
            cyclePreFreezeEventHead: cyclePreFreezeEventHead,
            baseline: successor,
            roster: roster,
            assignment: assignment,
            artifact: artifact,
            components: components,
            currentness: try ReviewCapabilityTestFactory.verifyCurrentness(
                baseline: successor,
                currentArtifacts: successor.artifactScopes,
                currentEventHead: laneBDigest("e")
            )
        )
    }
}

struct LaneBSuccessorScenario {
    let runID: RunID
    let cycleOrdinal: UInt64
    let cyclePreFreezeEventHead: HashDigest
    let baseline: ReviewBaseline
    let roster: FrozenReviewerRoster
    let assignment: ReviewerAssignment
    let artifact: ArtifactReference
    let components: IssueFingerprintComponents
    let currentness: VerifiedReviewScopeCurrentness

    func replacingBaseline(
        _ replacement: ReviewBaseline
    ) throws -> LaneBSuccessorScenario {
        guard replacement.runID == runID,
              replacement.cycleID == baseline.cycleID,
              replacement.kind == baseline.kind,
              replacement.gate == baseline.gate,
              replacement.semanticOrdinal == baseline.semanticOrdinal,
              replacement.predecessorBaselineDigest == baseline.predecessorBaselineDigest,
              replacement.artifactScopes == baseline.artifactScopes,
              replacement.rosterDigest == roster.digest
        else { throw WorkflowPolicyError.invalidPolicy }
        return LaneBSuccessorScenario(
            runID: runID,
            cycleOrdinal: cycleOrdinal,
            cyclePreFreezeEventHead: cyclePreFreezeEventHead,
            baseline: replacement,
            roster: roster,
            assignment: assignment,
            artifact: artifact,
            components: components,
            currentness: try ReviewCapabilityTestFactory.verifyCurrentness(
                baseline: replacement,
                currentArtifacts: replacement.artifactScopes,
                currentEventHead: replacement.preCreationEventHead
            )
        )
    }

    func makeConfirmationRegister(
        acceptedCurrentScope: Bool = false,
        nonblockingFinding: Bool = false
    ) throws -> LaneBReviewScenario {
        let registerBundle = try makeRegister(
            baseline: baseline,
            cycleOrdinal: cycleOrdinal,
            cyclePreFreezeEventHead: cyclePreFreezeEventHead,
            roster: roster,
            assignment: assignment,
            artifact: artifact,
            components: components,
            acceptedCurrentScope: acceptedCurrentScope,
            nonblockingFinding: nonblockingFinding
        )
        return LaneBReviewScenario(
            runID: runID,
            cycleOrdinal: cycleOrdinal,
            cyclePreFreezeEventHead: cyclePreFreezeEventHead,
            baseline: baseline,
            roster: roster,
            assignment: assignment,
            artifact: artifact,
            components: components,
            register: registerBundle.register,
            verifiedRegister: registerBundle.verifiedRegister,
            inventories: registerBundle.inventories,
            policies: registerBundle.policies,
            currentness: registerBundle.currentness
        )
    }

    func makeExceptionRegister(
        semanticOrdinal: UInt64 = 2,
        eventHead: HashDigest = laneBDigest("e"),
        acceptedCurrentScope: Bool = false
    ) throws -> LaneBReviewScenario {
        let round = try ReviewRoundInput.later(
            cycleID: baseline.cycleID,
            gate: baseline.gate,
            kind: .exception,
            semanticOrdinal: semanticOrdinal,
            roundAnchorEventHead: eventHead,
            predecessorBaselineDigest: baseline.digest,
            redactionPolicy: baseline.redactionPolicy
        )
        let exceptionBaseline = try ReviewBaseline.freeze(
            runID: runID,
            roundInput: round,
            artifactScopes: baseline.artifactScopes,
            activeProfileDigest: baseline.activeProfileDigest,
            riskPolicyDigest: baseline.riskPolicyDigest,
            assurancePolicyDigest: baseline.assurancePolicyDigest,
            convergencePolicyDigest: baseline.convergencePolicyDigest,
            roster: roster
        )
        let bundle = try makeRegister(
            baseline: exceptionBaseline,
            cycleOrdinal: cycleOrdinal,
            cyclePreFreezeEventHead: cyclePreFreezeEventHead,
            roster: roster,
            assignment: assignment,
            artifact: artifact,
            components: components,
            acceptedCurrentScope: acceptedCurrentScope
        )
        return LaneBReviewScenario(
            runID: runID,
            cycleOrdinal: cycleOrdinal,
            cyclePreFreezeEventHead: cyclePreFreezeEventHead,
            baseline: exceptionBaseline,
            roster: roster,
            assignment: assignment,
            artifact: artifact,
            components: components,
            register: bundle.register,
            verifiedRegister: bundle.verifiedRegister,
            inventories: bundle.inventories,
            policies: bundle.policies,
            currentness: bundle.currentness
        )
    }
}

struct LaneBRegisterBundle {
    let register: IssueRegister
    let verifiedRegister: VerifiedIssueRegister
    let inventories: VerifiedCompleteInventorySet
    let policies: VerifiedReviewPolicySet
    let currentness: VerifiedReviewScopeCurrentness
}

struct LaneBReceiptAuthorityBundle {
    let authority: VerifiedReviewReceiptAuthority
    let persistedRun: PersistedRun
}

func laneBReceiptAuthority(
    scenario: LaneBReviewScenario,
    confirmationReceipt: ConfirmationReceipt? = nil,
    priorPersistedRun: PersistedRun? = nil,
    lineageReceipts: [PersistedReceipt] = []
) throws -> LaneBReceiptAuthorityBundle {
    let fixture = try laneBBaselineFixture(
        baseline: scenario.baseline,
        roster: scenario.roster
    )
    let submission = try laneACapabilitySubmission(
        fixture: fixture,
        assignment: scenario.assignment,
        findings: []
    )
    let persistedRun: PersistedRun
    if let priorPersistedRun {
        guard confirmationReceipt == nil else {
            throw PersistenceError.integrityViolation
        }
        let priorCycle = priorPersistedRun.state.reviewCycle
        if lineageReceipts.isEmpty,
           priorCycle?.currentRoundID == scenario.baseline.roundID,
           priorCycle?.currentRoundKind == scenario.baseline.kind {
            persistedRun = priorPersistedRun
        } else {
            persistedRun = try laneBAdvanceReviewScenario(
                scenario,
                from: priorPersistedRun,
                lineageReceipts: lineageReceipts
            )
        }
    } else {
        let initialCycle = try laneBReviewCycleState(
            scenario: scenario,
            confirmationReceiptID: nil
        )
        let baseRun = try laneAPersistedRun(
            baseline: scenario.baseline,
            submission: submission,
            stage: laneBWorkflowStage(for: scenario.baseline.gate),
            reviewCycle: initialCycle,
            additionalReceipts: lineageReceipts
        )
        persistedRun = try confirmationReceipt.map {
            try laneBAppendConfirmation(
                $0,
                scenario: scenario,
                to: baseRun
            )
        } ?? baseRun
    }
    let currentness = try ReviewCapabilityTestFactory.verifyCurrentness(
        baseline: scenario.baseline,
        currentArtifacts: scenario.baseline.artifactScopes,
        currentEventHead: persistedRun.eventHead
    )
    return LaneBReceiptAuthorityBundle(
        authority: try ReviewCapabilityTestFactory.verifyReceiptAuthority(
            persistedRun: persistedRun,
            currentness: currentness,
            policies: scenario.policies,
            approvalRecords: []
        ),
        persistedRun: persistedRun
    )
}

private func laneBAdvanceReviewScenario(
    _ scenario: LaneBReviewScenario,
    from persistedRun: PersistedRun,
    lineageReceipts: [PersistedReceipt]
) throws -> PersistedRun {
    guard persistedRun.state.runID == scenario.runID else {
        throw PersistenceError.integrityViolation
    }
    let confirmationReceiptID: ReceiptID?
    let eventID: String
    let eventKind: WorkflowEventKind
    switch scenario.baseline.kind {
    case .initial:
        throw PersistenceError.integrityViolation
    case .normalConfirmation:
        guard !lineageReceipts.isEmpty else { throw PersistenceError.integrityViolation }
        confirmationReceiptID = nil
        eventID = "review-inventory-set-\(scenario.baseline.digest.rawValue.prefix(16))"
        eventKind = .reviewInventoryClosed
    case .exception:
        guard let recordedConfirmation = persistedRun.state.reviewCycle?.confirmationReceiptID
        else { throw PersistenceError.integrityViolation }
        confirmationReceiptID = recordedConfirmation
        eventID = "review-exception-\(scenario.baseline.semanticOrdinal)"
        eventKind = .reviewExceptionOpened
    }
    var state = persistedRun.state
    state.stage = laneBWorkflowStage(for: scenario.baseline.gate)
    state.reviewCycle = try laneBReviewCycleState(
        scenario: scenario,
        confirmationReceiptID: confirmationReceiptID
    )
    let event = try WorkflowEvent(id: eventID, kind: eventKind)
    state.processedEvents.append(try ProcessedWorkflowEvent(recording: event))
    let fallbackID = try ReceiptID(validating: eventID)
    let effectiveReceipts = lineageReceipts.isEmpty ? [PersistedReceipt(
        kind: try ReceiptKind(validating: "review-exception-test"),
        id: fallbackID,
        transactionID: try TransactionID(rawValue: "seed-\(eventID)"),
        transactionDigest: laneBDigest("0"),
        payloadDigest: CanonicalTreeDigest.sha256(laneAReceiptPayload(fallbackID)),
        payloadBytes: laneAReceiptPayload(fallbackID)
    )] : lineageReceipts
    let writes = try effectiveReceipts.map { receipt in
        let write = try ReceiptTableWrite(
            kind: receipt.kind,
            id: receipt.id,
            canonicalPayloadBytes: receipt.payloadBytes
        )
        guard write.payloadDigest == receipt.payloadDigest else {
            throw PersistenceError.integrityViolation
        }
        return write
    }.sorted {
        ($0.kind.rawValue, $0.id.rawValue) < ($1.kind.rawValue, $1.id.rawValue)
    }
    let transaction = try StateTransaction(
        id: TransactionID(rawValue: "txn-\(eventID)"),
        runRoot: FileManager.default.temporaryDirectory.appendingPathComponent(
            scenario.runID.filesystemComponent,
            isDirectory: true
        ),
        expectedStateDigest: persistedRun.stateDigest,
        expectedEventHead: persistedRun.eventHead,
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
    let stateDigest = CanonicalTreeDigest.sha256(transaction.stateBytes)
    let record = try EventLogRecord(
        sequence: UInt64(persistedRun.events.count + 1),
        runID: scenario.runID,
        transactionID: transaction.id,
        previousDigest: persistedRun.eventHead,
        previousStateDigest: persistedRun.stateDigest,
        stateDigest: stateDigest,
        transactionDigest: transaction.digest,
        fencingToken: FencingToken(validating: UInt64(persistedRun.events.count + 1)),
        writerOwnerID: "review-exception-test",
        receiptManifest: manifest,
        event: event
    )
    return PersistedRun(
        state: state,
        stateBytes: transaction.stateBytes,
        stateDigest: stateDigest,
        events: persistedRun.events + [record],
        eventHead: record.recordDigest,
        receipts: persistedRun.receipts + writes.map { write in
            PersistedReceipt(
                kind: write.kind,
                id: write.id,
                transactionID: transaction.id,
                transactionDigest: transaction.digest,
                payloadDigest: write.payloadDigest,
                payloadBytes: write.payloadBytes
            )
        }
    )
}

private func laneBReviewCycleState(
    scenario: LaneBReviewScenario,
    confirmationReceiptID: ReceiptID?
) throws -> ReviewCycleState {
    let didRecordConfirmation = confirmationReceiptID != nil
    let phase: ReviewCyclePhase
    let didRecordRemediation: Bool
    switch scenario.baseline.kind {
    case .initial:
        phase = .collectingInitial
        didRecordRemediation = false
    case .normalConfirmation:
        phase = didRecordConfirmation &&
            scenario.register.pathDecision == .requiresRemediation
            ? .awaitingRemediation
            : .collectingNormalConfirmation
        didRecordRemediation = true
    case .exception:
        guard didRecordConfirmation else {
            throw PersistenceError.integrityViolation
        }
        phase = .collectingException
        didRecordRemediation = true
    }
    let hasClosedConfirmation = scenario.baseline.kind == .normalConfirmation &&
        didRecordConfirmation
    return try ReviewCycleState(
        id: scenario.baseline.cycleID,
        gate: scenario.baseline.gate,
        cycleOrdinal: scenario.cycleOrdinal,
        phase: phase,
        currentRoundID: scenario.baseline.roundID,
        currentRoundKind: scenario.baseline.kind,
        currentSemanticOrdinal: scenario.baseline.semanticOrdinal,
        didRecordRemediation: didRecordRemediation,
        didRecordConfirmation: didRecordConfirmation,
        redactionPolicy: scenario.baseline.redactionPolicy,
        cyclePreFreezeEventHead: scenario.cyclePreFreezeEventHead,
        currentRoundAnchorEventHead: scenario.baseline.preCreationEventHead,
        predecessorBaselineDigest: scenario.baseline.predecessorBaselineDigest,
        closedRoundID: hasClosedConfirmation ? scenario.baseline.roundID : nil,
        closedBaselineDigest: hasClosedConfirmation ? scenario.baseline.digest : nil,
        closedRegisterDigest: hasClosedConfirmation ? scenario.register.digest : nil,
        closedPathDecision: hasClosedConfirmation ? scenario.register.pathDecision : nil,
        confirmationReceiptID: confirmationReceiptID
    )
}

private func laneBSyntheticConfirmationReceiptID(
    for baseline: ReviewBaseline
) throws -> ReceiptID {
    try ReceiptID(
        validating: "review-confirmation-fixture-" +
            String(baseline.cycleID.rawValue.prefix(12))
    )
}

private func laneBAppendConfirmation(
    _ receipt: ConfirmationReceipt,
    scenario: LaneBReviewScenario,
    to persistedRun: PersistedRun
) throws -> PersistedRun {
    let receiptID = try ReceiptID(validating: receipt.receiptID)
    guard receipt.publicationAnchorEventHead == persistedRun.eventHead else {
        throw PersistenceError.integrityViolation
    }
    var state = persistedRun.state
    state.reviewCycle = try laneBReviewCycleState(
        scenario: scenario,
        confirmationReceiptID: receiptID
    )
    let event = try WorkflowEvent(
        id: receiptID.rawValue,
        kind: .reviewConfirmationRecorded
    )
    state.processedEvents.append(try ProcessedWorkflowEvent(recording: event))
    let kind = try ReceiptKind(validating: "review-confirmation")
    let write = try ReceiptTableWrite(kind: kind, id: receiptID, value: receipt)
    let transaction = try StateTransaction(
        id: TransactionID(rawValue: "txn-\(receiptID.rawValue)"),
        runRoot: FileManager.default.temporaryDirectory.appendingPathComponent(
            scenario.runID.filesystemComponent,
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
        kind: kind,
        id: receiptID,
        envelopeDigest: CanonicalTreeDigest.sha256(envelopeBytes),
        payloadDigest: write.payloadDigest,
        envelopeBytes: envelopeBytes
    )
    let stateDigest = CanonicalTreeDigest.sha256(transaction.stateBytes)
    let priorFencingToken = try #require(persistedRun.events.last).fencingToken.rawValue
    let record = try EventLogRecord(
        sequence: UInt64(persistedRun.events.count + 1),
        runID: scenario.runID,
        transactionID: transaction.id,
        previousDigest: persistedRun.eventHead,
        previousStateDigest: persistedRun.stateDigest,
        stateDigest: stateDigest,
        transactionDigest: transaction.digest,
        fencingToken: FencingToken(validating: priorFencingToken + 1),
        writerOwnerID: "review-confirmation-test",
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
            kind: kind,
            id: receiptID,
            transactionID: transaction.id,
            transactionDigest: transaction.digest,
            payloadDigest: write.payloadDigest,
            payloadBytes: write.payloadBytes
        )]
    )
}

private func laneBWorkflowStage(
    for gate: ReviewGateKind
) -> WorkflowStage {
    switch gate {
    case .requirements: .requirementGate
    case .design: .designGate
    case .architecture: .architectureGate
    case .plan: .planGate
    case .checkpoint: .checkpoint
    case .review: .review
    case .final: .finalGate
    }
}

private func laneBLineageSeedReceipts(
    source: LaneBReviewScenario,
    confirmation: LaneBReviewScenario
) throws -> [PersistedReceipt] {
    var receipts: [PersistedReceipt] = []
    receipts.append(try laneBSeedReceipt(
        kind: "review-baseline",
        id: "review-baseline-\(source.baseline.digest.rawValue.prefix(16))",
        value: source.baseline
    ))
    for inventory in source.inventories.inventories + confirmation.inventories.inventories {
        receipts.append(try laneBSeedReceipt(
            kind: "review-inventory",
            id: "review-inventory-\(inventory.digest.rawValue.prefix(16))",
            value: inventory
        ))
    }
    for register in [source.register, confirmation.register] {
        receipts.append(try laneBSeedReceipt(
            kind: "issue-register",
            id: "issue-register-\(register.digest.rawValue.prefix(16))",
            value: register
        ))
    }
    return receipts
}

private func laneBExceptionLineageReceipts(
    scenario: LaneBReviewScenario,
    proof: ReviewExceptionEligibility
) throws -> [PersistedReceipt] {
    var receipts: [PersistedReceipt] = []
    for inventory in scenario.inventories.inventories {
        receipts.append(try laneBSeedReceipt(
            kind: "review-inventory",
            id: "review-inventory-\(inventory.digest.rawValue.prefix(16))",
            value: inventory
        ))
    }
    receipts.append(try laneBSeedReceipt(
        kind: "issue-register",
        id: "issue-register-\(scenario.register.digest.rawValue.prefix(16))",
        value: scenario.register
    ))
    receipts.append(try laneBSeedReceipt(
        kind: "review-exception",
        id: "review-exception-\(proof.proofDigest.rawValue.prefix(16))",
        value: ReviewExceptionReceiptPayload(
            proof: proof,
            successorBaselineDigest: scenario.baseline.digest
        )
    ))
    return receipts
}

private func laneBSeedReceipt(
    kind: String,
    id: String,
    value: some Encodable
) throws -> PersistedReceipt {
    let receiptKind = try ReceiptKind(validating: kind)
    let receiptID = try ReceiptID(validating: id)
    let bytes = try CanonicalJSON.encode(value)
    return PersistedReceipt(
        kind: receiptKind,
        id: receiptID,
        transactionID: try TransactionID(rawValue: "seed-\(receiptID.rawValue)"),
        transactionDigest: CanonicalTreeDigest.sha256(Data("seed-\(id)".utf8)),
        payloadDigest: CanonicalTreeDigest.sha256(bytes),
        payloadBytes: bytes
    )
}

private func laneBCommittedLineageReceipts(
    in persistedRun: PersistedRun
) throws -> [VerifiedPublishedReviewReceipt] {
    let semanticKinds = Set([
        "review-baseline",
        "review-inventory",
        "issue-register",
        "review-remediation-batch",
        "review-confirmation",
        "review-exception",
        "review-convergence",
    ])
    return try persistedRun.receipts.filter {
        semanticKinds.contains($0.kind.rawValue)
    }.sorted {
        ($0.kind.rawValue, $0.id.rawValue) < ($1.kind.rawValue, $1.id.rawValue)
    }.map { receipt in
        try ReviewCommittedReceiptVerifier.verify(
            id: receipt.id,
            kind: receipt.kind,
            digest: receipt.payloadDigest,
            in: persistedRun
        )
    }
}

func laneBConfirmationLineage(
    source: LaneBReviewScenario,
    successor: LaneBSuccessorScenario,
    remediation: VerifiedCommittedRemediationSuccessor,
    confirmationScenario: LaneBReviewScenario,
    confirmation: ConfirmationReceipt,
    confirmationAuthority: VerifiedReviewReceiptAuthority,
    authority: LaneBReceiptAuthorityBundle
) throws -> VerifiedConfirmationLineage {
    let committed = try laneBCommittedLineageReceipts(in: authority.persistedRun)
    let preliminary = try ReviewConfirmationLineageVerifier.verify(
        registers: [source.verifiedRegister, confirmationScenario.verifiedRegister],
        remediation: [remediation],
        confirmationReceipts: [confirmation],
        exceptionRounds: [],
        convergenceReceipts: [],
        receipts: committed,
        persistedRun: authority.persistedRun,
        authority: authority.authority
    )
    _ = try ReviewSemanticIngress.verifyConfirmationReceipt(
        bytes: CanonicalJSON.encode(confirmation),
        successor: remediation,
        confirmationRegister: confirmationScenario.verifiedRegister,
        authority: confirmationAuthority
    )
    return try ReviewConfirmationLineageVerifier.verify(
        registers: preliminary.verifiedRegisters,
        remediation: preliminary.remediationSuccessors,
        confirmationReceipts: preliminary.confirmationReceipts,
        exceptionRounds: preliminary.exceptionRounds,
        convergenceReceipts: preliminary.convergenceReceipts,
        receipts: committed,
        persistedRun: authority.persistedRun,
        authority: authority.authority
    )
}

func laneBSuccessorBaseline(
    source: LaneBReviewScenario,
    artifacts: [ArtifactReference],
    runID: RunID? = nil,
    gate: ReviewGateKind? = nil,
    anchor: HashDigest = laneBDigest("8")
) throws -> ReviewBaseline {
    let round = try ReviewRoundInput.later(
        cycleID: source.baseline.cycleID,
        gate: gate ?? source.baseline.gate,
        kind: .normalConfirmation,
        semanticOrdinal: 1,
        roundAnchorEventHead: anchor,
        predecessorBaselineDigest: source.baseline.digest,
        redactionPolicy: source.baseline.redactionPolicy
    )
    return try ReviewBaseline.freeze(
        runID: runID ?? source.runID,
        roundInput: round,
        artifactScopes: artifacts,
        activeProfileDigest: source.baseline.activeProfileDigest,
        riskPolicyDigest: source.baseline.riskPolicyDigest,
        assurancePolicyDigest: source.baseline.assurancePolicyDigest,
        convergencePolicyDigest: source.baseline.convergencePolicyDigest,
        roster: source.roster
    )
}

func laneBRemediationSuccessorBaseline(
    source: LaneBReviewScenario,
    kind: ReviewRoundKind,
    semanticOrdinal: UInt64,
    anchor: HashDigest,
    artifactHash: Character
) throws -> ReviewBaseline {
    let artifact = try laneBArtifact(hashCharacter: artifactHash)
    let round = try ReviewRoundInput.later(
        cycleID: source.baseline.cycleID,
        gate: source.baseline.gate,
        kind: kind,
        semanticOrdinal: semanticOrdinal,
        roundAnchorEventHead: anchor,
        predecessorBaselineDigest: source.baseline.digest,
        redactionPolicy: source.baseline.redactionPolicy
    )
    return try ReviewBaseline.freeze(
        runID: source.runID,
        roundInput: round,
        artifactScopes: [artifact],
        activeProfileDigest: source.baseline.activeProfileDigest,
        riskPolicyDigest: source.baseline.riskPolicyDigest,
        assurancePolicyDigest: source.baseline.assurancePolicyDigest,
        convergencePolicyDigest: source.baseline.convergencePolicyDigest,
        roster: source.roster
    )
}

func laneBScenario(
    replacing source: LaneBReviewScenario,
    baseline: ReviewBaseline,
    acceptedCurrentScope: Bool
) throws -> LaneBReviewScenario {
    let artifact = try #require(
        baseline.artifactScopes.first(where: { $0.id == source.artifact.id })
    )
    let bundle = try makeRegister(
        baseline: baseline,
        cycleOrdinal: source.cycleOrdinal,
        cyclePreFreezeEventHead: source.cyclePreFreezeEventHead,
        roster: source.roster,
        assignment: source.assignment,
        artifact: artifact,
        components: source.components,
        acceptedCurrentScope: acceptedCurrentScope
    )
    return LaneBReviewScenario(
        runID: source.runID,
        cycleOrdinal: source.cycleOrdinal,
        cyclePreFreezeEventHead: source.cyclePreFreezeEventHead,
        baseline: baseline,
        roster: source.roster,
        assignment: source.assignment,
        artifact: artifact,
        components: source.components,
        register: bundle.register,
        verifiedRegister: bundle.verifiedRegister,
        inventories: bundle.inventories,
        policies: bundle.policies,
        currentness: bundle.currentness
    )
}

func laneBVerifiedRemediation(
    source: LaneBReviewScenario,
    successorBaseline: ReviewBaseline,
    changes: [RemediationChange]? = nil,
    implementingAuthority requestedAuthority: VerifiedAuthorityFact? = nil
) throws -> VerifiedRemediationSuccessor {
    let implementingAuthority: VerifiedAuthorityFact
    if let requestedAuthority {
        implementingAuthority = requestedAuthority
    } else {
        implementingAuthority = VerifiedAuthorityFact(
            actorID: try ActorID(validating: "implementing-agent"),
            principalID: try PrincipalID(validating: "implementing-principal"),
            roles: [.author],
            principalKind: .agent,
            independentContextDigest: laneBDigest("6"),
            hasAuthorshipEdge: true,
            hasSourceWriteCapability: true
        )
    }
    let changeTemplates: [RemediationChange]
    if let changes {
        changeTemplates = changes
    } else {
        let postChangeArtifact = try #require(
            successorBaseline.artifactScopes.first { $0.id == source.artifact.id }
        )
        changeTemplates = [
            try RemediationChange(
                fingerprint: try #require(source.register.entries.first?.fingerprint),
                preChangeArtifact: source.artifact,
                postChangeArtifact: postChangeArtifact,
                evidence: try laneBRemediationEvidence(
                    publicationAnchor: successorBaseline.preCreationEventHead
                )
            ),
        ]
    }
    let planned = try laneBPlannedRemediation(
        source: source,
        successorBaseline: successorBaseline,
        changes: changeTemplates,
        implementingAuthority: implementingAuthority
    )
    return try ReviewRemediationVerifier.verifySuccessor(
        sourceRegister: source.verifiedRegister,
        changes: planned.changes,
        plannedEvidence: planned.plannedEvidence,
        implementationAuthority: planned.implementationAuthority,
        successorBaseline: successorBaseline,
        planning: planned.planning
    )
}

struct LaneBCommittedRemediationBundle {
    let successor: VerifiedCommittedRemediationSuccessor
    let plannedSuccessor: VerifiedRemediationSuccessor
    let successorScenario: LaneBReviewScenario
    let persistedRun: PersistedRun
}

/// Produces the durable remediation capability used by lifecycle tests. The caller supplies the
/// semantic successor shape; the helper re-anchors it to the actual H_before of the test run,
/// publishes all fixed and typed-evidence receipts in one event, then recovers from persisted data.
func laneBCommittedRemediation(
    source: LaneBReviewScenario,
    successorTemplate: ReviewBaseline,
    includeUnexpectedReceipt: Bool = false
) throws -> LaneBCommittedRemediationBundle {
    let sourceFixture = try laneBBaselineFixture(
        baseline: source.baseline,
        roster: source.roster
    )
    let sourceSubmission = try laneACapabilitySubmission(
        fixture: sourceFixture,
        assignment: source.assignment,
        findings: []
    )
    let sourceCycle = try laneBCollectingReviewCycleState(
        baseline: source.baseline,
        cycleOrdinal: source.cycleOrdinal,
        cyclePreFreezeEventHead: source.cyclePreFreezeEventHead
    )
    let sourceRun = try laneAPersistedRun(
        baseline: source.baseline,
        submission: sourceSubmission,
        stage: laneBWorkflowStage(for: source.baseline.gate),
        reviewCycle: sourceCycle
    )
    let successorBaseline = try laneBReanchorSuccessorBaseline(
        successorTemplate,
        source: source,
        eventHead: sourceRun.eventHead
    )
    let planned = try laneBVerifiedRemediation(
        source: source,
        successorBaseline: successorBaseline
    )
    let successorScenario = try laneBScenario(
        replacing: source,
        baseline: successorBaseline,
        acceptedCurrentScope: false
    )
    let persistedRun = try laneBAppendCommittedRemediation(
        planned,
        to: sourceRun,
        includeUnexpectedReceipt: includeUnexpectedReceipt
    )
    let committed = try ReviewCommittedRemediationVerifier.verify(
        sourceRegister: source.verifiedRegister,
        batch: planned.batch,
        successorBaseline: successorBaseline,
        persistedRun: persistedRun
    )
    return LaneBCommittedRemediationBundle(
        successor: committed,
        plannedSuccessor: planned,
        successorScenario: successorScenario,
        persistedRun: persistedRun
    )
}

private func laneBAppendCommittedRemediation(
    _ successor: VerifiedRemediationSuccessor,
    to persistedRun: PersistedRun,
    includeUnexpectedReceipt: Bool
) throws -> PersistedRun {
    let anchor = persistedRun.eventHead
    let suffix = String(anchor.rawValue.prefix(16))
    let eventID = "review-remediation-batch-\(suffix)"
    let event = try WorkflowEvent(id: eventID, kind: .reviewRemediationRecorded)
    var state = persistedRun.state
    let sourceBaseline = successor.sourceRegister.baseline
    let sourceRegister = successor.sourceRegister.register
    guard var cycle = state.reviewCycle,
          state.runID == sourceBaseline.runID,
          cycle.id == sourceBaseline.cycleID,
          cycle.gate == sourceBaseline.gate,
          cycle.currentRoundID == sourceBaseline.roundID,
          cycle.currentRoundKind == sourceBaseline.kind,
          cycle.currentSemanticOrdinal == sourceBaseline.semanticOrdinal,
          cycle.currentRoundAnchorEventHead == sourceBaseline.preCreationEventHead,
          cycle.predecessorBaselineDigest == sourceBaseline.predecessorBaselineDigest,
          sourceRegister.pathDecision == .requiresRemediation,
          !sourceRegister.acceptedCurrentScopeAssignments.isEmpty
    else { throw PersistenceError.integrityViolation }
    cycle.phase = .awaitingRemediation
    cycle.closedRoundID = sourceBaseline.roundID
    cycle.closedBaselineDigest = sourceBaseline.digest
    cycle.closedRegisterDigest = sourceRegister.digest
    cycle.closedPathDecision = sourceRegister.pathDecision
    cycle.didRecordRemediation = true
    cycle.lastRemediatedRoundID = sourceBaseline.roundID
    if sourceBaseline.kind != .initial {
        cycle.didRecordConfirmation = true
        if cycle.confirmationReceiptID == nil {
            cycle.confirmationReceiptID = try laneBSyntheticConfirmationReceiptID(
                for: sourceBaseline
            )
        }
    }
    state.reviewCycle = cycle
    state.processedEvents.append(try ProcessedWorkflowEvent(recording: event))

    var receiptInputs: [(String, String, Data)] = try [
        (
            "review-baseline",
            "review-baseline-\(suffix)",
            CanonicalJSON.encode(successor.successorBaseline)
        ),
        (
            "review-remediation-batch",
            eventID,
            CanonicalJSON.encode(successor.batch)
        ),
        (
            "review-resolved-transitions",
            "review-resolved-transitions-\(suffix)",
            CanonicalJSON.encode(ReviewResolvedTransitionsReceiptPayload(batch: successor.batch))
        ),
    ]
    receiptInputs.append(contentsOf: successor.plannedEvidence.map {
        ($0.payload.receiptKind.rawValue, $0.payload.receiptID.rawValue, $0.payloadBytes)
    })
    if includeUnexpectedReceipt {
        receiptInputs.append((
            "review-remediation-extra",
            "review-remediation-extra-\(suffix)",
            try CanonicalJSON.encode(["unexpected": true])
        ))
    }
    let writes = try receiptInputs.map { input in
        try ReceiptTableWrite(
            kind: ReceiptKind(validating: input.0),
            id: ReceiptID(validating: input.1),
            canonicalPayloadBytes: input.2
        )
    }.sorted {
        ($0.kind.rawValue, $0.id.rawValue) < ($1.kind.rawValue, $1.id.rawValue)
    }
    let transaction = try StateTransaction(
        id: TransactionID(rawValue: "txn-\(eventID)"),
        runRoot: FileManager.default.temporaryDirectory.appendingPathComponent(
            successor.sourceBaseline.runID.filesystemComponent,
            isDirectory: true
        ),
        expectedStateDigest: persistedRun.stateDigest,
        expectedEventHead: anchor,
        state: state,
        event: event,
        receiptWrites: writes
    )
    let manifest = try writes.map { write -> ReceiptManifestEntry in
        let envelope = ReceiptEnvelope(write: write, transaction: transaction)
        let bytes = try CanonicalJSON.encode(envelope)
        return ReceiptManifestEntry(
            kind: write.kind,
            id: write.id,
            envelopeDigest: CanonicalTreeDigest.sha256(bytes),
            payloadDigest: write.payloadDigest,
            envelopeBytes: bytes
        )
    }
    let stateDigest = CanonicalTreeDigest.sha256(transaction.stateBytes)
    let priorFencingToken = try #require(persistedRun.events.last).fencingToken.rawValue
    let record = try EventLogRecord(
        sequence: UInt64(persistedRun.events.count + 1),
        runID: successor.sourceBaseline.runID,
        transactionID: transaction.id,
        previousDigest: anchor,
        previousStateDigest: persistedRun.stateDigest,
        stateDigest: stateDigest,
        transactionDigest: transaction.digest,
        fencingToken: FencingToken(validating: priorFencingToken + 1),
        writerOwnerID: "review-remediation-test",
        receiptManifest: manifest,
        event: event
    )
    return PersistedRun(
        state: state,
        stateBytes: transaction.stateBytes,
        stateDigest: stateDigest,
        events: persistedRun.events + [record],
        eventHead: record.recordDigest,
        receipts: persistedRun.receipts + writes.map { write in
            PersistedReceipt(
                kind: write.kind,
                id: write.id,
                transactionID: transaction.id,
                transactionDigest: transaction.digest,
                payloadDigest: write.payloadDigest,
                payloadBytes: write.payloadBytes
            )
        }
    )
}

struct LaneBPlannedRemediation {
    let planning: VerifiedReviewRemediationPlanningContext
    let implementationAuthority: VerifiedReviewImplementationAuthority
    let plannedEvidence: [VerifiedPlannedRemediationEvidence]
    let changes: [RemediationChange]
}

func laneBPlannedRemediation(
    source: LaneBReviewScenario,
    successorBaseline: ReviewBaseline,
    changes: [RemediationChange],
    implementingAuthority: VerifiedAuthorityFact
) throws -> LaneBPlannedRemediation {
    let planning = try ReviewCapabilityTestFactory.verifyRemediationPlanningContext(
        sourceRegister: source.verifiedRegister,
        successorBaseline: successorBaseline,
        publicationAnchorEventHead: successorBaseline.preCreationEventHead
    )
    let scopedAuthority = try ReviewImplementationAuthorityVerifier.verify(
        authority: implementingAuthority,
        planning: planning
    )
    var plannedEvidence: [VerifiedPlannedRemediationEvidence] = []
    let plannedChanges = try changes.map { change in
        let evidence = try change.evidence.map { evidence in
            let planned = try ReviewRemediationEvidencePlanner.plan(
                receiptID: evidence.receipt.id,
                kind: evidence.kind,
                fingerprint: change.fingerprint,
                preChangeArtifact: change.preChangeArtifact,
                postChangeArtifact: change.postChangeArtifact,
                sourceRegister: source.verifiedRegister,
                implementationAuthority: scopedAuthority
            )
            plannedEvidence.append(planned)
            return planned.evidence
        }
        return try RemediationChange(
            fingerprint: change.fingerprint,
            preChangeArtifact: change.preChangeArtifact,
            postChangeArtifact: change.postChangeArtifact,
            evidence: evidence
        )
    }
    return LaneBPlannedRemediation(
        planning: planning,
        implementationAuthority: scopedAuthority,
        plannedEvidence: plannedEvidence,
        changes: plannedChanges
    )
}

private func laneBReanchorSuccessorBaseline(
    _ baseline: ReviewBaseline,
    source: LaneBReviewScenario,
    eventHead: HashDigest
) throws -> ReviewBaseline {
    guard baseline.kind != .initial,
          let predecessor = baseline.predecessorBaselineDigest
    else { throw WorkflowError.invalidReviewRound }
    let input = try ReviewRoundInput.later(
        cycleID: baseline.cycleID,
        gate: baseline.gate,
        kind: baseline.kind,
        semanticOrdinal: baseline.semanticOrdinal,
        roundAnchorEventHead: eventHead,
        predecessorBaselineDigest: predecessor,
        redactionPolicy: baseline.redactionPolicy
    )
    return try ReviewBaseline.freeze(
        runID: baseline.runID,
        roundInput: input,
        artifactScopes: baseline.artifactScopes,
        activeProfileDigest: baseline.activeProfileDigest,
        riskPolicyDigest: baseline.riskPolicyDigest,
        assurancePolicyDigest: baseline.assurancePolicyDigest,
        convergencePolicyDigest: baseline.convergencePolicyDigest,
        roster: source.roster
    )
}

func laneBForeignExceptionProof() throws -> ReviewExceptionEligibility {
    let runID = RunID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000026")!)
    let initialHead = laneBDigest("1")
    let cycleID = try ReviewCycleID.derive(
        runID: runID,
        gate: .review,
        cycleOrdinal: 0,
        preFreezeEventHead: initialHead
    )
    let roundID = try ReviewRoundID.derive(
        runID: runID,
        gate: .review,
        cycleID: cycleID,
        kind: .initial,
        semanticOrdinal: 0,
        roundAnchorEventHead: initialHead,
        predecessorBaselineDigest: nil
    )
    let baselineDigest = laneBDigest("2")
    let registerDigest = laneBDigest("3")
    let history = KernelReviewHistory(
        entries: [
            KernelReviewHistoryEntry(
                kind: .registerJoined,
                roundID: roundID,
                registerDigest: registerDigest,
                baselineDigest: baselineDigest,
                eventHead: laneBDigest("4")
            ),
            KernelReviewHistoryEntry(
                kind: .remediationRecorded,
                roundID: roundID,
                registerDigest: registerDigest,
                baselineDigest: baselineDigest,
                eventHead: laneBDigest("5")
            ),
            KernelReviewHistoryEntry(
                kind: .confirmationRecorded,
                roundID: roundID,
                registerDigest: registerDigest,
                baselineDigest: baselineDigest,
                eventHead: laneBDigest("6")
            ),
        ],
        priorExceptionRoundIDs: []
    )
    let context = ReviewExceptionContext(
        runID: runID,
        cycleID: cycleID,
        gate: .review,
        precedingRoundID: roundID,
        precedingRegisterDigest: registerDigest,
        precedingBaselineDigest: baselineDigest,
        roundAnchorEventHead: laneBDigest("7"),
        immediatelyPreceding: [],
        current: [
            ReviewFindingSummary(
                fingerprint: try FailureFingerprint(validatingWire: laneBDigest("8").rawValue),
                severity: .high,
                mustFix: false,
                state: .active
            ),
        ],
        history: history,
        exhaustionCause: .authorityOrDecisionRequired
    )
    let budget = try AttemptBudget.standardV1(policyDigest: laneBDigest("9"))
    guard case let .eligible(proof) = ReviewConvergencePolicy().evaluateException(
        context,
        budget: budget
    ) else { throw WorkflowPolicyError.invalidExceptionProof }
    return proof
}

func laneBJSONObject(_ value: some Encodable) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(
        with: CanonicalJSON.encode(value)
    ) as? [String: Any] else {
        throw WorkflowPolicyError.invalidPolicy
    }
    return object
}

func laneBCanonicalJSONObject(_ object: [String: Any]) throws -> Data {
    try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

func makeRegister(
    baseline: ReviewBaseline,
    cycleOrdinal: UInt64,
    cyclePreFreezeEventHead: HashDigest,
    roster: FrozenReviewerRoster,
    assignment: ReviewerAssignment,
    artifact: ArtifactReference,
    components: IssueFingerprintComponents,
    acceptedCurrentScope: Bool,
    nonblockingFinding: Bool = false
) throws -> LaneBRegisterBundle {
    let findings: [ReviewerFinding]
    if acceptedCurrentScope {
        findings = [
            try ReviewerFinding(
                findingID: "finding-review-001",
                components: components,
                severity: .high,
                mustFixClaim: true,
                title: "Atomic review state is incomplete",
                message: "The accepted finding requires current remediation evidence.",
                evidenceReferences: ["record-review"],
                confidenceBasis: "deterministic-check",
                reportedAt: "2026-07-12T00:00:00.000Z"
            ),
        ]
    } else if nonblockingFinding {
        findings = [
            try ReviewerFinding(
                findingID: "finding-review-nonblocking",
                components: components,
                severity: .medium,
                mustFixClaim: false,
                title: "Nonblocking confirmation observation",
                message: "The observation is dispositioned and does not require remediation.",
                evidenceReferences: ["record-review"],
                confidenceBasis: "deterministic-check",
                reportedAt: "2026-07-12T00:00:00.000Z"
            ),
        ]
    } else {
        findings = []
    }
    let fixture = try laneBBaselineFixture(
        baseline: baseline,
        roster: roster
    )
    let reviewCycle = try laneBCollectingReviewCycleState(
        baseline: baseline,
        cycleOrdinal: cycleOrdinal,
        cyclePreFreezeEventHead: cyclePreFreezeEventHead
    )
    let stage = laneBWorkflowStage(for: baseline.gate)
    let verifiedInventory = try laneAVerifiedInventory(
        fixture: fixture,
        assignment: assignment,
        findings: findings,
        stage: stage,
        reviewCycle: reviewCycle
    )
    var collector = ReviewInventoryCollector(baseline: baseline)
    guard case let .complete(completeInventories) = try collector.accept(
        verifiedInventory.inventory,
        authority: verifiedInventory.authority,
        currentness: verifiedInventory.currentness
    ) else {
        throw WorkflowPolicyError.invalidPolicy
    }
    let findingPolicy = try FrozenReviewFindingPolicy.freeze(
        mustFixIdentities: acceptedCurrentScope
            ? [ReviewFindingIdentity(kind: .rule, value: "IFL-REVIEW-001")]
            : []
    )
    let dispositionPolicy = try FrozenDispositionPolicy.freeze(
        authorizedPrincipalIDs: [PrincipalID(validating: "kernel-principal")],
        mandatorySeverities: [.critical],
        permitsAuthenticatedHumanRiskAcceptance: false
    )
    let policies = try ReviewPolicyVerifier.verify(
        findingPolicy: findingPolicy,
        dispositionPolicy: dispositionPolicy,
        baseline: baseline
    )
    let dispositionEvidence: [VerifiedReviewDispositionEvidence]
    let fingerprint = try IssueFingerprint.derive(from: components)
    if acceptedCurrentScope {
        dispositionEvidence = [try laneAVerifiedDispositionEvidence(
            fingerprint: fingerprint,
            severity: .high,
            mustFix: true,
            baseline: baseline,
            policies: policies,
            stage: stage,
            reviewCycle: reviewCycle
        )]
    } else if nonblockingFinding {
        dispositionEvidence = [try laneBVerifiedRefutationEvidence(
            fingerprint: fingerprint,
            baseline: baseline,
            policies: policies,
            stage: stage,
            reviewCycle: reviewCycle
        )]
    } else {
        dispositionEvidence = []
    }
    let register = try IssueRegister.issue(
        baseline: baseline,
        inventories: completeInventories,
        policies: policies,
        dispositionEvidence: dispositionEvidence
    )
    let verifiedRegister = try ReviewSemanticIngress.verifyRegister(
        bytes: CanonicalJSON.encode(register),
        baseline: baseline,
        inventories: completeInventories,
        policies: policies,
        dispositionEvidence: dispositionEvidence
    )
    return LaneBRegisterBundle(
        register: register,
        verifiedRegister: verifiedRegister,
        inventories: completeInventories,
        policies: policies,
        currentness: verifiedInventory.currentness
    )
}

private func laneBCollectingReviewCycleState(
    baseline: ReviewBaseline,
    cycleOrdinal: UInt64,
    cyclePreFreezeEventHead: HashDigest
) throws -> ReviewCycleState {
    let phase: ReviewCyclePhase
    let didRecordRemediation: Bool
    let confirmationReceiptID: ReceiptID?
    switch baseline.kind {
    case .initial:
        guard baseline.cycleOrdinal == cycleOrdinal,
              baseline.preCreationEventHead == cyclePreFreezeEventHead
        else { throw WorkflowError.invalidReviewRound }
        phase = .collectingInitial
        didRecordRemediation = false
        confirmationReceiptID = nil
    case .normalConfirmation:
        guard baseline.cycleOrdinal == nil else {
            throw WorkflowError.invalidReviewRound
        }
        phase = .collectingNormalConfirmation
        didRecordRemediation = true
        confirmationReceiptID = nil
    case .exception:
        guard baseline.cycleOrdinal == nil else {
            throw WorkflowError.invalidReviewRound
        }
        phase = .collectingException
        didRecordRemediation = true
        confirmationReceiptID = try laneBSyntheticConfirmationReceiptID(for: baseline)
    }
    return try ReviewCycleState(
        id: baseline.cycleID,
        gate: baseline.gate,
        cycleOrdinal: cycleOrdinal,
        phase: phase,
        currentRoundID: baseline.roundID,
        currentRoundKind: baseline.kind,
        currentSemanticOrdinal: baseline.semanticOrdinal,
        didRecordRemediation: didRecordRemediation,
        didRecordConfirmation: confirmationReceiptID != nil,
        redactionPolicy: baseline.redactionPolicy,
        cyclePreFreezeEventHead: cyclePreFreezeEventHead,
        currentRoundAnchorEventHead: baseline.preCreationEventHead,
        predecessorBaselineDigest: baseline.predecessorBaselineDigest,
        confirmationReceiptID: confirmationReceiptID
    )
}

func laneBBaselineFixture(
    baseline: ReviewBaseline,
    roster: FrozenReviewerRoster
) throws -> LaneABaselineFixture {
    let roundInput: ReviewRoundInput
    switch baseline.kind {
    case .initial:
        roundInput = try .initial(
            gate: baseline.gate,
            cycleOrdinal: baseline.cycleOrdinal ?? 0,
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
    return LaneABaselineFixture(
        runID: baseline.runID,
        redactionPolicy: baseline.redactionPolicy,
        roster: roster,
        artifacts: baseline.artifactScopes,
        roundInput: roundInput,
        expectedCycleID: baseline.cycleID,
        expectedRoundID: baseline.roundID,
        baseline: baseline
    )
}

func laneBVerifiedRefutationEvidence(
    fingerprint: IssueFingerprint,
    baseline: ReviewBaseline,
    policies: VerifiedReviewPolicySet,
    stage: WorkflowStage,
    reviewCycle: ReviewCycleState
) throws -> VerifiedReviewDispositionEvidence {
    let policy = try FrozenDispositionPolicy.freeze(
        authorizedPrincipalIDs: [PrincipalID(validating: "kernel-principal")],
        mandatorySeverities: [.critical],
        permitsAuthenticatedHumanRiskAcceptance: false
    )
    let evidenceID = try ReceiptID(
        validating: "refutation-\(fingerprint.rawValue.prefix(16))"
    )
    let authorityContextDigest = laneBDigest("3")
    let payload = try CanonicalJSON.encode(ReviewDispositionEvidenceReceiptPayload(
        receiptID: evidenceID,
        runID: baseline.runID,
        baselineDigest: baseline.digest,
        fingerprint: fingerprint.failureFingerprint,
        severity: .medium,
        mustFix: false,
        evidenceKind: .refutation,
        refutationEvidenceReferences: [evidenceID.rawValue],
        humanRiskAcceptance: false,
        disputed: false,
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
        severity: .medium,
        mustFix: false,
        evidenceKind: .refutation,
        refutationEvidenceReferences: [evidenceID.rawValue],
        humanRiskAcceptance: false,
        disputed: false,
        authority: claim
    )
    let rawEvidence = IssueDispositionEvidence(
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
    let fixture = try laneBBaselineFixture(
        baseline: baseline,
        roster: baseline.roster
    )
    let assignment = try #require(baseline.roster.assignments.first)
    let submission = try laneACapabilitySubmission(
        fixture: fixture,
        assignment: assignment,
        findings: []
    )
    let persistedRun = try laneAPersistedRun(
        baseline: baseline,
        submission: submission,
        stage: stage,
        reviewCycle: reviewCycle,
        additionalReceipts: [persistedEvidence]
    )
    let authority = VerifiedAuthorityFact(
        actorID: claim.actorID,
        principalID: claim.principalID,
        roles: [.kernel],
        principalKind: .kernel,
        independentContextDigest: authorityContextDigest,
        hasAuthorshipEdge: false,
        hasSourceWriteCapability: false
    )
    return try ReviewAuthorityVerifier.verifyDispositionEvidence(
        evidence: rawEvidence,
        authority: authority,
        persistedRun: persistedRun,
        policies: policies
    )
}

func laneBRemediationEvidence(
    publicationAnchor eventHead: HashDigest,
    receiptIDSuffix: String = "current"
) throws -> [RemediationEvidence] {
    try [
        RemediationEvidence(
            kind: .command,
            receipt: laneAReceiptReference("command-\(receiptIDSuffix)"),
            publicationAnchorEventHead: eventHead
        ),
        RemediationEvidence(
            kind: .staticAnalysis,
            receipt: laneAReceiptReference("static-\(receiptIDSuffix)"),
            publicationAnchorEventHead: eventHead
        ),
        RemediationEvidence(
            kind: .review,
            receipt: laneAReceiptReference("review-\(receiptIDSuffix)"),
            publicationAnchorEventHead: eventHead
        ),
    ]
}

func laneBArtifact(hashCharacter: Character) throws -> ArtifactReference {
    try laneBArtifact(
        id: "review-source",
        scopeValue: "Sources/Review",
        hashCharacter: hashCharacter
    )
}

func laneBArtifact(
    id: String,
    scopeValue: String,
    hashCharacter: Character
) throws -> ArtifactReference {
    try ArtifactReference(
        id: ArtifactID(validating: id),
        type: .source,
        scope: ArtifactScope(kind: .path, value: scopeValue),
        contentHash: CanonicalTreeDigest.sha256(laneBArtifactBytes(hashCharacter, id: id))
    )
}

func laneBArtifactBytes(_ character: Character) -> Data {
    laneBArtifactBytes(character, id: "review-source")
}

func laneBArtifactBytes(_ character: Character, id: String) -> Data {
    Data("\(id)-v\(character)".utf8)
}

func laneBDigest(_ character: Character) -> HashDigest {
    try! HashDigest(validating: String(repeating: character, count: 64))
}

private struct NormalConfirmationFixture: Codable, Equatable {
    let expectedDecision: String
    let expectedError: String
    let expectedHistorySHA256: String
    let fixtureKind: String
    let historyBytes: Data
    let productionWireType: String
    let requestedRoundKind: String
    let schemaVersion: Int

    init(from decoder: any Decoder) throws {
        try rejectReviewFixtureFields(decoder, allowed: CodingKeys.allCases.map(\.rawValue))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        expectedDecision = try values.decode(String.self, forKey: .expectedDecision)
        expectedError = try values.decode(String.self, forKey: .expectedError)
        expectedHistorySHA256 = try values.decode(String.self, forKey: .expectedHistorySHA256)
        fixtureKind = try values.decode(String.self, forKey: .fixtureKind)
        historyBytes = Data(try values.decode(String.self, forKey: .historyBytes).utf8)
        productionWireType = try values.decode(String.self, forKey: .productionWireType)
        requestedRoundKind = try values.decode(String.self, forKey: .requestedRoundKind)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
    }

    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(expectedDecision, forKey: .expectedDecision)
        try values.encode(expectedError, forKey: .expectedError)
        try values.encode(expectedHistorySHA256, forKey: .expectedHistorySHA256)
        try values.encode(fixtureKind, forKey: .fixtureKind)
        try values.encode(String(decoding: historyBytes, as: UTF8.self), forKey: .historyBytes)
        try values.encode(productionWireType, forKey: .productionWireType)
        try values.encode(requestedRoundKind, forKey: .requestedRoundKind)
        try values.encode(schemaVersion, forKey: .schemaVersion)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case expectedDecision = "expected_decision"
        case expectedError = "expected_error"
        case expectedHistorySHA256 = "expected_history_sha256"
        case fixtureKind = "fixture_kind"
        case historyBytes = "history_bytes"
        case productionWireType = "production_wire_type"
        case requestedRoundKind = "requested_round_kind"
        case schemaVersion = "schema_version"
    }
}

private struct ReviewExceptionFixture: Codable, Equatable {
    let contextBytes: Data
    let expectedContextSHA256: String
    let expectedDecision: String
    let expectedNextSemanticOrdinal: UInt64?
    let expectedQualifyingFingerprints: [String]
    let expectedRemainingExceptionRounds: Int?
    let fixtureKind: String
    let productionWireType: String
    let schemaVersion: Int

    init(from decoder: any Decoder) throws {
        try rejectReviewFixtureFields(decoder, allowed: CodingKeys.allCases.map(\.rawValue))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        contextBytes = Data(try values.decode(String.self, forKey: .contextBytes).utf8)
        expectedContextSHA256 = try values.decode(String.self, forKey: .expectedContextSHA256)
        expectedDecision = try values.decode(String.self, forKey: .expectedDecision)
        expectedNextSemanticOrdinal = try values.decodeIfPresent(
            UInt64.self,
            forKey: .expectedNextSemanticOrdinal
        )
        expectedQualifyingFingerprints = try values.decode(
            [String].self,
            forKey: .expectedQualifyingFingerprints
        )
        expectedRemainingExceptionRounds = try values.decodeIfPresent(
            Int.self,
            forKey: .expectedRemainingExceptionRounds
        )
        fixtureKind = try values.decode(String.self, forKey: .fixtureKind)
        productionWireType = try values.decode(String.self, forKey: .productionWireType)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
    }

    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(String(decoding: contextBytes, as: UTF8.self), forKey: .contextBytes)
        try values.encode(expectedContextSHA256, forKey: .expectedContextSHA256)
        try values.encode(expectedDecision, forKey: .expectedDecision)
        try values.encodeIfPresent(
            expectedNextSemanticOrdinal,
            forKey: .expectedNextSemanticOrdinal
        )
        try values.encode(
            expectedQualifyingFingerprints,
            forKey: .expectedQualifyingFingerprints
        )
        try values.encodeIfPresent(
            expectedRemainingExceptionRounds,
            forKey: .expectedRemainingExceptionRounds
        )
        try values.encode(fixtureKind, forKey: .fixtureKind)
        try values.encode(productionWireType, forKey: .productionWireType)
        try values.encode(schemaVersion, forKey: .schemaVersion)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case contextBytes = "context_bytes"
        case expectedContextSHA256 = "expected_context_sha256"
        case expectedDecision = "expected_decision"
        case expectedNextSemanticOrdinal = "expected_next_semantic_ordinal"
        case expectedQualifyingFingerprints = "expected_qualifying_fingerprints"
        case expectedRemainingExceptionRounds = "expected_remaining_exception_rounds"
        case fixtureKind = "fixture_kind"
        case productionWireType = "production_wire_type"
        case schemaVersion = "schema_version"
    }
}

private func normalConfirmationFixture() throws -> NormalConfirmationFixture {
    try CanonicalJSON.decode(
        NormalConfirmationFixture.self,
        from: reviewFixtureData("second-normal-confirmation.json")
    )
}

private func exceptionFixture(_ filename: String) throws -> ReviewExceptionFixture {
    try CanonicalJSON.decode(ReviewExceptionFixture.self, from: reviewFixtureData(filename))
}

private func expectCanonicalReviewFixture<Value: Codable & Equatable>(
    _ fixture: Value,
    rawBytes: Data
) throws {
    var canonical = try CanonicalJSON.encode(fixture)
    canonical.append(0x0A)
    #expect(rawBytes == canonical)
    #expect(rawBytes.last == 0x0A)
    #expect(!rawBytes.dropLast().contains(0x0A))
}

private func reviewFixtureData(_ filename: String) throws -> Data {
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

private struct ReviewFixtureCodingKey: CodingKey {
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

private func rejectReviewFixtureFields(_ decoder: any Decoder, allowed: [String]) throws {
    let values = try decoder.container(keyedBy: ReviewFixtureCodingKey.self)
    guard values.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "unexpected review convergence fixture field"
            )
        )
    }
}
