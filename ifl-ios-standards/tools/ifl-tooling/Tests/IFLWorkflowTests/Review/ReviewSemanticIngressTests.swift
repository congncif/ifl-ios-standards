import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("ReviewSemanticIngressTests")
struct ReviewSemanticIngressTests {
    @Test("RC-02 self-consistent register bytes remain untrusted until contextual replay")
    func contextuallyReplaysRegisterBytes() throws {
        let scenario = try LaneARegisterFixture.make()
        let register = try scenario.issue()
        let bytes = try CanonicalJSON.encode(register)
        let verified = try ReviewSemanticIngress.verifyRegister(
            bytes: bytes,
            baseline: scenario.baseline.baseline,
            inventories: scenario.completeInventories,
            policies: scenario.policies,
            dispositionEvidence: scenario.verifiedDispositionEvidence
        )
        #expect(verified.register == register)

        let otherBaseline = try LaneABaselineFixture.make(
            preFreezeEventHead: laneADigest("d")
        )
        #expect(throws: (any Error).self) {
            try ReviewSemanticIngress.verifyRegister(
                bytes: bytes,
                baseline: scenario.baseline.baseline,
                inventories: scenario.completeInventories,
                policies: laneAVerifiedPolicySet(baseline: otherBaseline.baseline),
                dispositionEvidence: scenario.verifiedDispositionEvidence
            )
        }

        let tampered = try laneARehashedRegisterBytes(bytes) { object in
            var entries = try laneARequireObjects(object["entries"])
            entries[0]["severity"] = "low"
            object["entries"] = entries
        }
        #expect(try IssueRegister.decodeCanonical(from: tampered).entries[0].severity == .low)
        #expect(throws: (any Error).self) {
            try ReviewSemanticIngress.verifyRegister(
                bytes: tampered,
                baseline: scenario.baseline.baseline,
                inventories: scenario.completeInventories,
                policies: scenario.policies,
                dispositionEvidence: scenario.verifiedDispositionEvidence
            )
        }
    }

    @Test("RC-02 contextual register ingress rejects ordering and unknown-field variants")
    func rejectsNoncanonicalAndUnknownRegisterWire() throws {
        let scenario = try LaneARegisterFixture.make()
        let bytes = try CanonicalJSON.encode(scenario.issue())
        var object = try laneAJSONObject(bytes)
        object["unknown"] = true
        #expect(throws: (any Error).self) {
            try ReviewSemanticIngress.verifyRegister(
                bytes: laneACanonicalJSONObject(object),
                baseline: scenario.baseline.baseline,
                inventories: scenario.completeInventories,
                policies: scenario.policies,
                dispositionEvidence: scenario.verifiedDispositionEvidence
            )
        }

        var trailingLF = bytes
        trailingLF.append(0x0A)
        #expect(throws: (any Error).self) {
            try ReviewSemanticIngress.verifyRegister(
                bytes: trailingLF,
                baseline: scenario.baseline.baseline,
                inventories: scenario.completeInventories,
                policies: scenario.policies,
                dispositionEvidence: scenario.verifiedDispositionEvidence
            )
        }
    }

    @Test("RC-02/07 direct convergence receipt trust requires contextual replay")
    func contextuallyReplaysDirectConvergenceReceipt() throws {
        let scenario = try LaneBReviewScenario.make(acceptedCurrentScope: false)
        let authority = try laneBReceiptAuthority(scenario: scenario).authority
        let eventHead = authority.eventHead
        let receipt = try ReviewConvergenceValidator.issueDirectConvergence(
            register: scenario.verifiedRegister,
            authority: authority,
            publicationAnchorEventHead: eventHead
        )
        let bytes = try CanonicalJSON.encode(receipt)
        let verified = try ReviewSemanticIngress.verifyConvergenceReceipt(
            bytes: bytes,
            register: scenario.verifiedRegister,
            authority: authority
        )
        #expect(verified.payloadBytes == bytes)

        let wrongLineage = try laneAReissueDirectConvergenceReceipt(
            receipt,
            baselineLineage: [laneBDigest("d")]
        )
        let wrongCurrentness = try laneAReissueDirectConvergenceReceipt(
            receipt,
            currentArtifactSetDigest: laneBDigest("e")
        )
        for selfConsistentWire in [wrongLineage, wrongCurrentness] {
            let tamperedBytes = try CanonicalJSON.encode(selfConsistentWire)
            #expect(
                try ConvergenceReceipt.decodeCanonical(from: tamperedBytes)
                    == selfConsistentWire
            )
            #expect(throws: (any Error).self) {
                try ReviewSemanticIngress.verifyConvergenceReceipt(
                    bytes: tamperedBytes,
                    register: scenario.verifiedRegister,
                    authority: authority
                )
            }
        }
    }

    @Test("RC-01 v2 receipt ingress rejects every final-event-head downgrade shape")
    func receiptV2DowngradeShapesFailClosed() throws {
        let scenario = try LaneBReviewScenario.make(acceptedCurrentScope: false)
        let authority = try laneBReceiptAuthority(scenario: scenario).authority
        let anchor = authority.eventHead
        let receipt = try ReviewConvergenceValidator.issueDirectConvergence(
            register: scenario.verifiedRegister,
            authority: authority,
            publicationAnchorEventHead: anchor
        )
        let bytes = try CanonicalJSON.encode(receipt)
        let canonical = try laneAJSONObject(bytes)
        #expect(canonical["schema_version"] as? Int == 2)
        #expect(canonical["publication_anchor_event_head"] as? String == anchor.rawValue)
        #expect(canonical["final_event_head"] == nil)

        var schemaV1 = canonical
        schemaV1["schema_version"] = 1
        var oldFieldOnly = canonical
        oldFieldOnly.removeValue(forKey: "publication_anchor_event_head")
        oldFieldOnly["final_event_head"] = anchor.rawValue
        var bothFields = canonical
        bothFields["final_event_head"] = anchor.rawValue
        for downgrade in [schemaV1, oldFieldOnly, bothFields] {
            #expect(throws: (any Error).self) {
                try ConvergenceReceipt.decodeCanonical(
                    from: laneACanonicalJSONObject(downgrade)
                )
            }
        }

        var wrongAnchor = canonical
        wrongAnchor["publication_anchor_event_head"] = laneBDigest("d").rawValue
        #expect(throws: (any Error).self) {
            try ReviewSemanticIngress.verifyConvergenceReceipt(
                bytes: laneACanonicalJSONObject(wrongAnchor),
                register: scenario.verifiedRegister,
                authority: authority
            )
        }
    }

    @Test("RC-03 final join rejects a finding outside the frozen artifact and scope set")
    func rejectsOutOfBaselineFinding() throws {
        let baseline = try LaneABaselineFixture.make()
        let outOfScope = try laneAFinding(
            severity: .high,
            suffix: "outside-baseline",
            components: laneAIssueComponents(
                artifactID: "artifact-outside",
                scope: "workflow.outside"
            )
        )
        let inventories = try laneAVerifiedInventories(
            fixture: baseline,
            inputs: [
                (
                    assignment: baseline.roster.assignments[0],
                    findings: [outOfScope]
                ),
                (
                    assignment: baseline.roster.assignments[1],
                    findings: []
                ),
            ]
        )
        let first = try #require(inventories.first)
        let second = try #require(inventories.last)
        var collector = ReviewInventoryCollector(baseline: baseline.baseline)
        _ = try collector.accept(
            first.inventory,
            authority: first.authority,
            currentness: first.currentness
        )
        let completion = try collector.accept(
            second.inventory,
            authority: second.authority,
            currentness: second.currentness
        )
        guard case .complete(let complete) = completion else {
            Issue.record("expected a complete inventory capability")
            return
        }
        let policies = try laneAVerifiedPolicySet(baseline: baseline.baseline)
        #expect(throws: (any Error).self) {
            try IssueRegister.issue(
                baseline: baseline.baseline,
                inventories: complete,
                policies: policies,
                dispositionEvidence: []
            )
        }
    }

    @Test("RC-03 duplicate targets must be retained non-self roots with no cycle")
    func rejectsInvalidDuplicateGraph() throws {
        let scenario = try LaneARegisterFixture.make(twoDistinctFindings: true)
        let root = try #require(scenario.fingerprints.first).failureFingerprint
        let duplicate = try #require(scenario.fingerprints.last).failureFingerprint

        for target in [duplicate, try failure("missing-duplicate-target")] {
            let evidence = try scenario.verifiedDuplicateEvidence(
                duplicate: duplicate,
                canonical: target
            )
            #expect(throws: (any Error).self) {
                try IssueRegister.issue(
                    baseline: scenario.baseline.baseline,
                    inventories: scenario.completeInventories,
                    policies: scenario.policies,
                    dispositionEvidence: scenario.verifiedDispositionEvidence(for: root) + [evidence]
                )
            }
        }

        let reverse = try scenario.verifiedDuplicateEvidence(
            duplicate: root,
            canonical: duplicate
        )
        let forward = try scenario.verifiedDuplicateEvidence(
            duplicate: duplicate,
            canonical: root
        )
        #expect(throws: (any Error).self) {
            try IssueRegister.issue(
                baseline: scenario.baseline.baseline,
                inventories: scenario.completeInventories,
                policies: scenario.policies,
                dispositionEvidence: [reverse, forward]
            )
        }
    }

    @Test("RC-04/07 eight literal production fixtures execute their typed semantic outcome")
    func productionFixtureCorpusExecutesRealDecisions() throws {
        for filename in laneAProductionFixtureNames {
            let fixture = try laneAProductionFixture(filename)
            switch fixture.expected.error {
            case .none:
                let replay = try LaneAFixtureReplay(fixture: fixture).collect()
                guard case .complete(let inventories) = replay else {
                    Issue.record("expected complete fixture \(filename)")
                    continue
                }
                if let register = fixture.register {
                    let evidence = try laneAFixtureDispositionEvidence(
                        register: register,
                        baseline: fixture.baseline,
                        policies: laneAVerifiedPolicySet(baseline: fixture.baseline)
                    )
                    let verified = try ReviewSemanticIngress.verifyRegister(
                        bytes: CanonicalJSON.encode(register),
                        baseline: fixture.baseline,
                        inventories: inventories,
                        policies: laneAVerifiedPolicySet(baseline: fixture.baseline),
                        dispositionEvidence: evidence
                    )
                    #expect(verified.register.entries.map(\.fingerprint)
                        == fixture.expected.entryFingerprints)
                    #expect(verified.register.pathDecision == fixture.expected.pathDecision)
                }
                try expectLaneARemediationFixtureSemantics(fixture)

            case .missingReviewer:
                let replay = try LaneAFixtureReplay(fixture: fixture).collect()
                guard case .pending(let missing) = replay else {
                    Issue.record("expected pending fixture \(filename)")
                    continue
                }
                #expect(missing == fixture.expected.missingAssignmentIDs)

            case .mixedBaseline, .baselineMutated:
                #expect(throws: (any Error).self) {
                    try LaneAFixtureReplay(fixture: fixture).collect()
                }

            case .remediationEvidenceMissing:
                let verified = try LaneAFixtureReplay(fixture: fixture).verifiedRegister()
                #expect(verified.register.pathDecision == .requiresRemediation)
                #expect(fixture.remediationBatch == nil)

            case .illegalResolvedTransition:
                let verified = try LaneAFixtureReplay(fixture: fixture).verifiedRegister()
                #expect(verified.register.pathDecision == .requiresRemediation)
                #expect(fixture.remediationBatch == nil)
                #expect(!fixture.resolvedTransitions.isEmpty)
            }
        }
    }

    @Test("RC-07 six review schemas are closed canonical contextual wire contracts")
    func reviewSchemaContractsAreClosedAndContextual() throws {
        #expect(
            Set(laneAReviewSchemaContracts.keys) == Set(laneAReviewSchemaFilenameLedger)
        )
        #expect(laneAReviewSchemaContracts.count == laneAReviewSchemaFilenameLedger.count)

        for filename in laneAReviewSchemaFilenameLedger {
            let contract = try #require(laneAReviewSchemaContracts[filename])
            let bytes = try Data(contentsOf: workflowSchemaURL(filename))
            #expect(bytes.last == 0x0A)
            #expect(bytes.dropLast().allSatisfy { $0 != 0x0A && $0 != 0x0D })

            let decoded = try JSONSerialization.jsonObject(with: bytes)
            let schema = try #require(decoded as? [String: Any])
            var canonical = try JSONSerialization.data(
                withJSONObject: decoded,
                options: [.sortedKeys, .withoutEscapingSlashes]
            )
            canonical.append(0x0A)
            #expect(bytes == canonical)

            #expect(
                schema["$schema"] as? String
                    == "https://json-schema.org/draft/2020-12/schema"
            )
            #expect(schema["$id"] as? String == contract.schemaID)
            #expect(schema["type"] as? String == "object")
            #expect(schema["additionalProperties"] as? Bool == false)

            let properties = try #require(schema["properties"] as? [String: Any])
            let required = try #require(schema["required"] as? [String])
            #expect(Set(properties.keys) == contract.propertyNames)
            #expect(Set(required) == contract.requiredNames)

            let canonicalIngress = try #require(
                schema["x-ifl-canonical-ingress"] as? String
            )
            let semanticValidator = try #require(
                schema["x-ifl-semantic-validator"] as? String
            )
            #expect(canonicalIngress == contract.contextualValidator)
            #expect(semanticValidator == contract.contextualValidator)
            #expect(!canonicalIngress.contains(".decodeCanonical"))
            #expect(!semanticValidator.contains(".decodeCanonical"))

            let definitions = try #require(schema["$defs"] as? [String: Any])
            var assertedFormats: [String: String] = [:]
            for (name, value) in definitions {
                guard let definition = value as? [String: Any],
                      let format = definition["format"] as? String
                else { continue }
                assertedFormats[name] = format
                #expect(definition["x-ifl-format-assertion-required"] as? Bool == true)
            }
            #expect(assertedFormats == contract.assertedFormats)

            laneAAssertClosedSchemaObjects(schema, path: filename)
            laneAAssertHardEOFPatterns(schema, path: filename)
            laneAAssertFormatsAreAsserted(schema, path: filename)

            if filename == "reviewer-finding-inventory.schema.json" {
                let timestamp = try #require(
                    definitions["canonical_timestamp"] as? [String: Any]
                )
                #expect(
                    timestamp["pattern"] as? String
                        == #"^[0-9]{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]\.[0-9]{3}Z(?![\s\S])"#
                )
                #expect(timestamp["format"] as? String == "ifl-canonical-timestamp-v1")
                #expect(timestamp["x-ifl-format-assertion-required"] as? Bool == true)
            }
            if laneAReviewReceiptSchemaFilenames.contains(filename) {
                let receiptID = try #require(
                    definitions["receipt_id"] as? [String: Any]
                )
                #expect(receiptID["type"] as? String == "string")
                #expect(receiptID["minLength"] as? Int == 1)
                #expect(receiptID["maxLength"] as? Int == 123)
                #expect(
                    receiptID["pattern"] as? String
                        == #"^[a-z0-9][a-z0-9._-]{0,122}(?![\s\S])"#
                )
            }
            if filename == "review-convergence-receipt.schema.json" {
                let remediationDigests = try #require(
                    properties["remediation_batch_digests"] as? [String: Any]
                )
                #expect(remediationDigests["type"] as? String == "array")
                #expect(remediationDigests["uniqueItems"] as? Bool == true)
                let paths = try #require(schema["oneOf"] as? [[String: Any]])
                #expect(paths.count == 2)
                let direct = try #require(paths.first { path in
                    let pathProperties = path["properties"] as? [String: Any]
                    let pathKind = pathProperties?["path_kind"] as? [String: Any]
                    return pathKind?["const"] as? String
                        == "direct_convergence_no_accepted_current_scope"
                })
                let confirmed = try #require(paths.first { path in
                    let pathProperties = path["properties"] as? [String: Any]
                    let pathKind = pathProperties?["path_kind"] as? [String: Any]
                    return pathKind?["const"] as? String == "confirmed_remediation"
                })
                let directProperties = try #require(
                    direct["properties"] as? [String: Any]
                )
                let directRemediation = try #require(
                    directProperties["remediation_batch_digests"] as? [String: Any]
                )
                #expect(directRemediation["maxItems"] as? Int == 0)
                #expect(directProperties["confirmation_receipt_digest"] as? Bool == false)
                let confirmedProperties = try #require(
                    confirmed["properties"] as? [String: Any]
                )
                let confirmedRemediation = try #require(
                    confirmedProperties["remediation_batch_digests"] as? [String: Any]
                )
                #expect(confirmedRemediation["minItems"] as? Int == 1)
                #expect((confirmed["required"] as? [String])?.contains(
                    "confirmation_receipt_digest"
                ) == true)
            }
        }
    }
}

struct LaneAFixtureReplay {
    let fixture: LaneAProductionReviewFixture

    func collect() throws -> ReviewInventoryCollectionResult {
        var collector = ReviewInventoryCollector(baseline: fixture.baseline)
        var result: ReviewInventoryCollectionResult = .pending(
            fixture.baseline.roster.assignments.map(\.id)
        )
        let capabilityFixture = try laneAFixtureReplayCapabilityFixture(
            baseline: fixture.baseline
        )
        let inputs = try fixture.inventories.map { wireInventory in
            let assignment = try #require(fixture.baseline.roster.assignments.first {
                $0.id == wireInventory.assignmentID
            })
            return LaneAFixtureReplayInput(
                wireInventory: wireInventory,
                assignment: assignment,
                submission: try laneASubmission(
                    from: wireInventory,
                    fixture: capabilityFixture,
                    assignment: assignment
                )
            )
        }
        guard let first = inputs.first else { return result }
        var additionalReceipts: [PersistedReceipt] = []
        for input in inputs.dropFirst() {
            additionalReceipts += try laneAEnvelopeReceiptInputs(
                submission: input.submission,
                baseline: fixture.baseline
            )
        }
        let persistedRun = try laneAPersistedRun(
            baseline: fixture.baseline,
            submission: first.submission,
            additionalReceipts: additionalReceipts
        )
        let currentness = try ReviewCapabilityTestFactory.verifyCurrentness(
            baseline: fixture.baseline,
            currentArtifacts: fixture.currentArtifacts,
            currentEventHead: persistedRun.eventHead
        )
        for input in inputs {
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
            let replayed = try ReviewerFindingInventory.ingest(
                submission: input.submission,
                against: fixture.baseline,
                authority: authority
            )
            #expect(
                try CanonicalJSON.encode(replayed) ==
                    CanonicalJSON.encode(input.wireInventory)
            )
            result = try collector.accept(
                replayed,
                authority: authority,
                currentness: currentness
            )
        }
        return result
    }

    func verifiedRegister() throws -> VerifiedIssueRegister {
        guard case .complete(let inventories) = try collect(),
              let register = fixture.register
        else { throw LaneAProductionFixtureError.invalidFixture }
        let policies = try laneAVerifiedPolicySet(baseline: fixture.baseline)
        return try ReviewSemanticIngress.verifyRegister(
            bytes: CanonicalJSON.encode(register),
            baseline: fixture.baseline,
            inventories: inventories,
            policies: policies,
            dispositionEvidence: laneAFixtureDispositionEvidence(
                register: register,
                baseline: fixture.baseline,
                policies: policies
            )
        )
    }
}

private struct LaneAFixtureReplayInput {
    let wireInventory: ReviewerFindingInventory
    let assignment: ReviewerAssignment
    let submission: ReviewerFindingSubmission
}

func laneASubmission(
    from inventory: ReviewerFindingInventory,
    fixture: LaneABaselineFixture,
    assignment: ReviewerAssignment
) throws -> ReviewerFindingSubmission {
    let typed = try laneACapabilitySubmission(
        fixture: fixture,
        assignment: assignment,
        sanitizedEnvelopeDigest: inventory.redactionMetadata.sanitizedEnvelopeDigest,
        findings: inventory.findings
    )
    return try ReviewerFindingSubmission(
        baselineDigest: inventory.baselineDigest,
        roundID: inventory.roundID,
        rosterDigest: inventory.rosterDigest,
        assignmentID: inventory.assignmentID,
        checklistDigest: inventory.checklistDigest,
        redactionPolicy: inventory.redactionPolicy,
        redactionMetadata: inventory.redactionMetadata,
        actorID: inventory.actorID,
        principalID: inventory.principalID,
        role: inventory.role,
        envelope: ReviewerEnvelopeBinding(
            artifact: inventory.envelope.artifact,
            effectReceipt: typed.envelope.effectReceipt,
            domainReceipt: typed.envelope.domainReceipt,
            recordReceipt: typed.envelope.recordReceipt
        ),
        complete: inventory.complete,
        findings: inventory.findings
    )
}

private func laneAFixtureReplayCapabilityFixture(
    baseline: ReviewBaseline
) throws -> LaneABaselineFixture {
    LaneABaselineFixture(
        runID: baseline.runID,
        redactionPolicy: baseline.redactionPolicy,
        roster: baseline.roster,
        artifacts: baseline.artifactScopes,
        roundInput: try ReviewRoundInput.initial(
            gate: baseline.gate,
            cycleOrdinal: baseline.cycleOrdinal ?? 0,
            preFreezeEventHead: baseline.preCreationEventHead,
            redactionPolicy: baseline.redactionPolicy
        ),
        expectedCycleID: baseline.cycleID,
        expectedRoundID: baseline.roundID,
        baseline: baseline
    )
}

private func laneAEnvelopeReceiptInputs(
    submission: ReviewerFindingSubmission,
    baseline: ReviewBaseline
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
            independentContextDigest: laneADigest("1")
        )
        let write = try ReceiptTableWrite(kind: kind, id: reference.id, value: payload)
        guard write.payloadDigest == reference.digest else {
            throw LaneAProductionFixtureError.invalidFixture
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

func laneAFixtureDispositionEvidence(
    register: IssueRegister,
    baseline: ReviewBaseline,
    policies: VerifiedReviewPolicySet
) throws -> [VerifiedReviewDispositionEvidence] {
    try register.entries.map { entry in
        try laneAVerifiedDispositionEvidence(
            fingerprint: entry.fingerprint,
            severity: entry.severity,
            mustFix: entry.mustFix,
            baseline: baseline,
            policies: policies
        )
    }
}

private func expectLaneARemediationFixtureSemantics(
    _ fixture: LaneAProductionReviewFixture
) throws {
    guard let batch = fixture.remediationBatch else {
        #expect(fixture.resolvedTransitions.isEmpty)
        return
    }
    let register = try #require(fixture.register)
    let successor = try #require(fixture.successorBaseline)
    #expect(batch.sourceRegisterDigest == register.digest)
    #expect(batch.sourceBaselineDigest == fixture.baseline.digest)
    #expect(batch.successorBaselineDigest == successor.digest)
    #expect(batch.assignedFingerprints == register.acceptedCurrentScopeAssignments)
    #expect(batch.resolvedTransitions == fixture.resolvedTransitions)
    #expect(batch.changes.map { $0.fingerprint.failureFingerprint }
        == batch.assignedFingerprints)
    for (change, transition) in zip(batch.changes, batch.resolvedTransitions) {
        #expect(change.preChangeArtifact.id == change.postChangeArtifact.id)
        #expect(transition.evidenceDigests
            == change.evidence.map(\.receipt.digest).sorted { $0.rawValue < $1.rawValue })
    }
}

private func laneARehashedRegisterBytes(
    _ bytes: Data,
    mutate: (inout [String: Any]) throws -> Void
) throws -> Data {
    var object = try laneAJSONObject(bytes)
    try mutate(&object)
    object.removeValue(forKey: "register_digest")
    let digest = CanonicalTreeDigest.sha256(try laneACanonicalJSONObject(object))
    object["register_digest"] = digest.rawValue
    return try laneACanonicalJSONObject(object)
}

private func laneARequireObjects(_ value: Any?) throws -> [[String: Any]] {
    guard let objects = value as? [[String: Any]] else {
        throw LaneAProductionFixtureError.invalidFixture
    }
    return objects
}

private func laneAReissueDirectConvergenceReceipt(
    _ receipt: ConvergenceReceipt,
    baselineLineage: [HashDigest]? = nil,
    currentArtifactSetDigest: HashDigest? = nil
) throws -> ConvergenceReceipt {
    try ConvergenceReceipt.issue(
        payload: ConvergenceReceiptPayload(
            schemaVersion: receipt.schemaVersion,
            receiptID: receipt.receiptID,
            path: receipt.path,
            baselineLineage: baselineLineage ?? receipt.baselineLineage,
            registerDigests: receipt.registerDigests,
            remediationBatchDigests: receipt.remediationBatchDigests,
            confirmationReceiptDigest: receipt.confirmationReceiptDigest,
            exceptionProofDigests: receipt.exceptionProofDigests,
            currentArtifactSetDigest:
                currentArtifactSetDigest ?? receipt.currentArtifactSetDigest,
            currentApprovalSetDigest: receipt.currentApprovalSetDigest,
            authorityPolicyDigest: receipt.authorityPolicyDigest,
            publicationAnchorEventHead: receipt.publicationAnchorEventHead
        )
    )
}

private struct LaneAReviewSchemaContract: Sendable {
    let schemaID: String
    let propertyNames: Set<String>
    let requiredNames: Set<String>
    let contextualValidator: String
    let assertedFormats: [String: String]
}

private let laneAReviewSchemaFilenameLedger = [
    "issue-register.schema.json",
    "remediation-batch.schema.json",
    "review-baseline.schema.json",
    "review-confirmation-receipt.schema.json",
    "review-convergence-receipt.schema.json",
    "reviewer-finding-inventory.schema.json",
]

private let laneAReviewReceiptSchemaFilenames: Set<String> = [
    "review-confirmation-receipt.schema.json",
    "review-convergence-receipt.schema.json",
]

private let laneAReviewSchemaContracts: [String: LaneAReviewSchemaContract] = [
    "review-baseline.schema.json": LaneAReviewSchemaContract(
        schemaID: "urn:ifl:standards:schema:review-baseline:v1",
        propertyNames: [
            "active_profile_digest", "artifact_scopes", "assurance_policy_digest",
            "baseline_digest", "convergence_policy_digest", "cycle_id", "cycle_ordinal",
            "gate", "pre_creation_event_head", "predecessor_baseline_digest",
            "redaction_policy", "risk_policy_digest", "roster", "roster_digest",
            "round_id", "round_kind", "run_id", "schema_version", "semantic_ordinal",
        ],
        requiredNames: [
            "active_profile_digest", "artifact_scopes", "assurance_policy_digest",
            "baseline_digest", "convergence_policy_digest", "cycle_id", "gate",
            "pre_creation_event_head", "redaction_policy", "risk_policy_digest", "roster",
            "roster_digest", "round_id", "round_kind", "run_id", "schema_version",
            "semantic_ordinal",
        ],
        contextualValidator: "ReviewSemanticIngress.verifyBaseline/v1",
        assertedFormats: [
            "canonical_relative_path": "ifl-canonical-relative-path-v1",
        ]
    ),
    "reviewer-finding-inventory.schema.json": LaneAReviewSchemaContract(
        schemaID: "urn:ifl:standards:schema:reviewer-finding-inventory:v1",
        propertyNames: [
            "actor_id", "assignment_id", "baseline_digest", "checklist_digest", "complete",
            "envelope", "findings", "inventory_digest", "principal_id",
            "redaction_metadata", "redaction_policy", "role", "roster_digest", "round_id",
            "schema_version", "submission_digest",
        ],
        requiredNames: [
            "actor_id", "assignment_id", "baseline_digest", "checklist_digest", "complete",
            "envelope", "findings", "inventory_digest", "principal_id",
            "redaction_metadata", "redaction_policy", "role", "roster_digest", "round_id",
            "schema_version", "submission_digest",
        ],
        contextualValidator: "ReviewSemanticIngress.verifyInventory/v1",
        assertedFormats: [
            "canonical_relative_path": "ifl-canonical-relative-path-v1",
            "canonical_timestamp": "ifl-canonical-timestamp-v1",
        ]
    ),
    "issue-register.schema.json": LaneAReviewSchemaContract(
        schemaID: "urn:ifl:standards:schema:issue-register:v1",
        propertyNames: [
            "accepted_current_scope_assignments", "baseline_digest",
            "disposition_policy_digest", "dispositions", "entries", "finding_policy_digest",
            "inventory_digests", "path_decision", "register_digest", "roster_digest",
            "round_id", "schema_version",
        ],
        requiredNames: [
            "accepted_current_scope_assignments", "baseline_digest",
            "disposition_policy_digest", "dispositions", "entries", "finding_policy_digest",
            "inventory_digests", "path_decision", "register_digest", "roster_digest",
            "round_id", "schema_version",
        ],
        contextualValidator: "ReviewSemanticIngress.verifyRegister/v1",
        assertedFormats: [:]
    ),
    "remediation-batch.schema.json": LaneAReviewSchemaContract(
        schemaID: "urn:ifl:standards:schema:remediation-batch:v1",
        propertyNames: [
            "assigned_fingerprints", "batch_digest", "changes", "implementing_actor_id",
            "resolved_transitions", "schema_version", "source_baseline_digest",
            "source_register_digest", "successor_baseline_digest",
        ],
        requiredNames: [
            "assigned_fingerprints", "batch_digest", "changes", "implementing_actor_id",
            "resolved_transitions", "schema_version", "source_baseline_digest",
            "source_register_digest", "successor_baseline_digest",
        ],
        contextualValidator: "ReviewSemanticIngress.verifyRemediationBatch/v1",
        assertedFormats: [
            "canonical_relative_path": "ifl-canonical-relative-path-v1",
        ]
    ),
    "review-confirmation-receipt.schema.json": LaneAReviewSchemaContract(
        schemaID: "urn:ifl:standards:schema:review-confirmation-receipt:v2",
        propertyNames: [
            "authority_policy_digest", "confirmation_digest", "confirmation_register_digest",
            "current_approval_set_digest", "current_artifact_set_digest",
            "publication_anchor_event_head",
            "receipt_id", "remediation_batch_digest", "roster_digest", "round_id",
            "schema_version", "successor_baseline_digest",
        ],
        requiredNames: [
            "authority_policy_digest", "confirmation_digest", "confirmation_register_digest",
            "current_approval_set_digest", "current_artifact_set_digest",
            "publication_anchor_event_head",
            "receipt_id", "remediation_batch_digest", "roster_digest", "round_id",
            "schema_version", "successor_baseline_digest",
        ],
        contextualValidator: "ReviewSemanticIngress.verifyConfirmationReceipt/v2",
        assertedFormats: [:]
    ),
    "review-convergence-receipt.schema.json": LaneAReviewSchemaContract(
        schemaID: "urn:ifl:standards:schema:review-convergence-receipt:v2",
        propertyNames: [
            "authority_policy_digest", "baseline_lineage", "confirmation_receipt_digest",
            "current_approval_set_digest", "current_artifact_set_digest",
            "exception_proof_digests", "path_kind", "publication_anchor_event_head", "receipt_id",
            "register_digests", "remediation_batch_digests", "schema_version",
        ],
        requiredNames: [
            "authority_policy_digest", "baseline_lineage", "current_approval_set_digest",
            "current_artifact_set_digest", "exception_proof_digests",
            "publication_anchor_event_head",
            "path_kind", "receipt_id", "register_digests", "remediation_batch_digests",
            "schema_version",
        ],
        contextualValidator: "ReviewSemanticIngress.verifyConvergenceReceipt/v2",
        assertedFormats: [:]
    ),
]

private func laneAAssertClosedSchemaObjects(_ value: Any, path: String) {
    if let object = value as? [String: Any] {
        if object["type"] as? String == "object" {
            #expect(
                object["additionalProperties"] as? Bool == false,
                "open object schema at \(path)"
            )
        }
        for (key, child) in object {
            laneAAssertClosedSchemaObjects(child, path: "\(path).\(key)")
        }
    } else if let array = value as? [Any] {
        for (index, child) in array.enumerated() {
            laneAAssertClosedSchemaObjects(child, path: "\(path)[\(index)]")
        }
    }
}

private func laneAAssertHardEOFPatterns(_ value: Any, path: String) {
    if let object = value as? [String: Any] {
        if let pattern = object["pattern"] as? String {
            #expect(
                pattern.hasSuffix(#"(?![\s\S])"#),
                "soft-EOF pattern at \(path)"
            )
        }
        for (key, child) in object {
            laneAAssertHardEOFPatterns(child, path: "\(path).\(key)")
        }
    } else if let array = value as? [Any] {
        for (index, child) in array.enumerated() {
            laneAAssertHardEOFPatterns(child, path: "\(path)[\(index)]")
        }
    }
}

private func laneAAssertFormatsAreAsserted(_ value: Any, path: String) {
    if let object = value as? [String: Any] {
        if object["format"] is String {
            #expect(
                object["x-ifl-format-assertion-required"] as? Bool == true,
                "unasserted format at \(path)"
            )
        }
        for (key, child) in object {
            laneAAssertFormatsAreAsserted(child, path: "\(path).\(key)")
        }
    } else if let array = value as? [Any] {
        for (index, child) in array.enumerated() {
            laneAAssertFormatsAreAsserted(child, path: "\(path)[\(index)]")
        }
    }
}
