import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("ApprovalValidatorTests")
struct ApprovalValidatorTests {
    @Test("ApprovalRecord v1 is issued from verified bindings and has one exact canonical ingress")
    func canonicalApprovalRecordIngress() throws {
        let fixture = try issuedDesignApproval()
        let bytes = try CanonicalJSON.encode(fixture.record)
        let decoded = try ApprovalRecord.decodeCanonical(from: bytes)
        let object = try #require(
            JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        )
        let reviewedWire = try #require(object["reviewed_artifacts"] as? [String: Any])

        #expect(decoded.schemaVersion == 1)
        #expect(decoded.gate == .designGate)
        #expect(decoded.kind == .autoApproved)
        #expect(decoded.actorID == fixture.validator.actorID)
        #expect(decoded.principalID == fixture.validator.principalID)
        #expect(decoded.role == .designValidator)
        #expect(decoded.authorityPolicyDigest == fixture.setup.gatePolicy.policyDigest)
        #expect(decoded.policyBindingDigest == fixture.policyBinding.bindingDigest)
        #expect(decoded.reviewedSetDigest == fixture.reviewedSet.bindingDigest)
        #expect(decoded.reviewedArtifacts == fixture.reviewedSet.reviewedArtifacts)
        #expect(decoded.authoritySnapshot.actorID == fixture.validator.actorID)
        #expect(decoded.authoritySnapshot.roles == [.designValidator, .standardsValidator])
        #expect(decoded.authoritySnapshot.principalKind == .agent)
        #expect(Set(reviewedWire.keys) == ["artifact-architecture", "artifact-plan"])
        #expect(reviewedWire["artifact-architecture"] as? String == approvalDigest("a").rawValue)
        #expect(reviewedWire["artifact-plan"] as? String == approvalDigest("b").rawValue)
        #expect(try CanonicalJSON.encode(decoded) == bytes)
        let semantic = try ApprovalWireSemanticValidator.validate(bytes)
        #expect(try CanonicalJSON.encode(semantic) == bytes)
        #expect(try ApprovalValidator.validate(records: [decoded], context: fixture.context) == .current)
    }

    @Test("public ApprovalRecord has no generic Decodable bypass around exact canonical ingress")
    func publicApprovalRecordIsNotDecodable() {
        #expect(!approvalTypeIsDecodable(ApprovalRecord.self))
    }

    @Test("exact canonical ingress rejects duplicate keys order whitespace framing and parser differentials")
    func canonicalRawByteCorpus() throws {
        let fixture = try issuedDesignApproval()
        let canonical = try CanonicalJSON.encode(fixture.record)
        let text = try #require(String(data: canonical, encoding: .utf8))
        let actorField = "\"actor_id\":\"actor-design-validator\","
        let attestationField = "\"attestation_reference\":\"attestation-design-001\","
        let prefix = "{" + actorField + attestationField
        #expect(text.hasPrefix(prefix))
        let remainder = String(text.dropFirst(prefix.count))
        let a = approvalDigest("a").rawValue
        let b = approvalDigest("b").rawValue
        let canonicalReviewed =
            "\"reviewed_artifacts\":{\"artifact-architecture\":\"\(a)\",\"artifact-plan\":\"\(b)\"}"
        let unsortedReviewed =
            "\"reviewed_artifacts\":{\"artifact-plan\":\"\(b)\",\"artifact-architecture\":\"\(a)\"}"
        let duplicateReviewed =
            "\"reviewed_artifacts\":{\"artifact-architecture\":\"\(a)\",\"artifact-architecture\":\"\(b)\",\"artifact-plan\":\"\(b)\"}"
        #expect(text.contains(canonicalReviewed))

        var legacyArray = try approvalJSONObject(fixture.record)
        legacyArray["reviewed_artifacts"] = [
            ["artifact_id": "artifact-plan", "artifact_hash": b],
            ["artifact_id": "artifact-architecture", "artifact_hash": a],
        ]

        let corpus: [Data] = [
            Data(("{" + attestationField + actorField + remainder).utf8),
            Data(("{ " + String(text.dropFirst())).utf8),
            canonical + Data([0x0A]),
            Data([0x20]) + canonical,
            canonical + Data([0x20]),
            Data(("{" + actorField + actorField + attestationField + remainder).utf8),
            Data(text.replacingOccurrences(
                of: "actor-design-validator",
                with: #"actor-\u0064esign-validator"#
            ).utf8),
            Data(("{\"\\u0061ctor_id\":\"shadow\"," + String(text.dropFirst())).utf8),
            Data(text.replacingOccurrences(
                of: canonicalReviewed,
                with: unsortedReviewed
            ).utf8),
            Data(text.replacingOccurrences(
                of: canonicalReviewed,
                with: duplicateReviewed
            ).utf8),
            try canonicalData(legacyArray),
        ]

        for bytes in corpus {
            #expect(throws: (any Error).self) {
                try ApprovalRecord.decodeCanonical(from: bytes)
            }
            #expect(throws: (any Error).self) {
                try ApprovalWireSemanticValidator.validate(bytes)
            }
        }

        var unknown = try approvalJSONObject(fixture.record)
        unknown["unknown_field"] = true
        #expect(throws: (any Error).self) {
            try ApprovalRecord.decodeCanonical(from: canonicalData(unknown))
        }
    }

    @Test("verified attestation capability is bound to exact record event signature and trust facts")
    func attestationCapabilityBindsExactRecord() throws {
        let fixture = try issuedDesignApproval()
        #expect(try ApprovalValidator.validate(records: [fixture.record], context: fixture.context) == .current)

        let changedRecord = try ApprovalRecord.issue(
            gate: .designGate,
            kind: .autoApproved,
            role: .designValidator,
            authorityFact: fixture.validator,
            policyBinding: fixture.policyBinding,
            reviewedSet: fixture.reviewedSet,
            timestamp: Date(timeIntervalSince1970: 1.123),
            attestationReference: "attestation-design-001"
        )
        let oldCapabilityContext = try approvalValidationContext(
            graph: fixture.graph,
            setup: fixture.setup,
            gate: .designGate,
            author: fixture.author,
            validators: [fixture.validator],
            attestations: [fixture.attestation]
        )
        #expect(
            try ApprovalValidator.validate(records: [changedRecord], context: oldCapabilityContext)
                == .rejected
        )

        let missingCapability = try approvalValidationContext(
            graph: fixture.graph,
            setup: fixture.setup,
            gate: .designGate,
            author: fixture.author,
            validators: [fixture.validator],
            attestations: []
        )
        #expect(
            try ApprovalValidator.validate(records: [fixture.record], context: missingCapability)
                == .rejected
        )
        #expect(fixture.attestation.recordDigest == approvalRecordDigest(fixture.record))
        #expect(fixture.attestation.authenticatedEventDigest == approvalDigest("5"))
        #expect(fixture.attestation.signatureDigest == approvalDigest("6"))
        #expect(fixture.attestation.trustPolicyDigest == approvalDigest("7"))
    }

    @Test("attestation verifier consumes three independently sealed boundary capabilities")
    func attestationVerifierRequiresSealedBoundaryCapabilities() throws {
        let fixture = try issuedDesignApproval()
        let capabilities = try approvalAttestationCapabilities(
            record: fixture.record,
            suffix: "8"
        )
        let verifierSource = try approvalSourceSlice(
            filename: "ApprovalValidator.swift",
            from: "enum ApprovalAttestationVerifier",
            until: "struct ApprovalValidationContext"
        )
        let attestation = try ApprovalAttestationVerifier.verify(
            record: fixture.record,
            authenticatedEvent: capabilities.authenticatedEvent,
            signature: capabilities.signature,
            trustPolicy: capabilities.trustPolicy
        )

        #expect(attestation.recordDigest == approvalRecordDigest(fixture.record))
        #expect(attestation.authenticatedEventDigest == approvalDigest("8"))
        #expect(attestation.signatureDigest == approvalDigest("6"))
        #expect(attestation.trustPolicyDigest == approvalDigest("7"))
        let changedRecord = try ApprovalRecord.issue(
            gate: .designGate,
            kind: .autoApproved,
            role: .designValidator,
            authorityFact: fixture.validator,
            policyBinding: fixture.policyBinding,
            reviewedSet: fixture.reviewedSet,
            timestamp: Date(timeIntervalSince1970: 2.123),
            attestationReference: "attestation-design-001"
        )
        #expect(throws: (any Error).self) {
            try ApprovalAttestationVerifier.verify(
                record: changedRecord,
                authenticatedEvent: capabilities.authenticatedEvent,
                signature: capabilities.signature,
                trustPolicy: capabilities.trustPolicy
            )
        }
        #expect(!verifierSource.contains("authenticatedEventDigest: HashDigest"))
        #expect(!verifierSource.contains("signatureDigest: HashDigest"))
        #expect(!verifierSource.contains("trustPolicyDigest: HashDigest"))
    }

    @Test("reviewed set is graph-derived and a caller-selected subset cannot stay fresh")
    func reviewedSetCompletenessIsGraphDerived() throws {
        let fixture = try issuedDesignApproval()
        #expect(fixture.record.reviewedArtifacts.map(\.artifactID) == fixture.graph.artifacts.map(\.id))

        var subsetObject = try approvalJSONObject(fixture.record)
        var reviewed = try #require(subsetObject["reviewed_artifacts"] as? [String: Any])
        reviewed.removeValue(forKey: "artifact-plan")
        subsetObject["reviewed_artifacts"] = reviewed
        subsetObject["reviewed_set_digest"] = approvalDigest("8").rawValue
        let subset = try ApprovalRecord.decodeCanonical(from: canonicalData(subsetObject))
        #expect(try ApprovalValidator.validate(records: [subset], context: fixture.context) == .stale)

        let expandedGraph = try approvalGraph(includeSource: true)
        let expandedContext = try approvalValidationContext(
            graph: expandedGraph,
            setup: fixture.setup,
            gate: .designGate,
            author: fixture.author,
            validators: [fixture.validator],
            attestations: [fixture.attestation]
        )
        #expect(
            try ApprovalValidator.validate(records: [fixture.record], context: expandedContext)
                == .stale
        )
    }

    @Test("every resolved role contributes exactly one independently attested approval")
    func multiRoleGateRequiresCanonicalApprovalSet() throws {
        let graph = try approvalGraph()
        let setup = try approvalAuthoritySetup(policyDigest: "3")
        let author = try approvalAuthorityFact("plan-author", roles: [.author], context: "1", kind: .agent)
        let plan = try approvalAuthorityFact("plan-validator", roles: [.planValidator], context: "2", kind: .agent)
        let strategist = try approvalAuthorityFact("test-strategist", roles: [.testStrategist], context: "4", kind: .agent)
        let reviewed = try VerifiedReviewedArtifactSet.derive(graph: graph, gate: .planGate)
        let policy = try VerifiedApprovalPolicyBinding.derive(
            gatePolicy: setup.gatePolicy,
            gate: .planGate,
            mode: .auto,
            policyContext: setup.context,
            escalationFlags: [],
            author: author
        )
        let planRecord = try approvalRecord(
            gate: .planGate,
            role: .planValidator,
            fact: plan,
            policy: policy,
            reviewed: reviewed,
            reference: "attestation-plan"
        )
        let strategistRecord = try approvalRecord(
            gate: .planGate,
            role: .testStrategist,
            fact: strategist,
            policy: policy,
            reviewed: reviewed,
            reference: "attestation-strategist"
        )
        let planAttestation = try approvalAttestation(planRecord, suffix: "2")
        let strategistAttestation = try approvalAttestation(strategistRecord, suffix: "4")
        let context = try approvalValidationContext(
            graph: graph,
            setup: setup,
            gate: .planGate,
            author: author,
            validators: [plan, strategist],
            attestations: [planAttestation, strategistAttestation]
        )

        #expect(
            try ApprovalValidator.validate(
                records: [strategistRecord, planRecord],
                context: context
            ) == .current
        )
        #expect(try ApprovalValidator.validate(records: [planRecord], context: context) == .rejected)
        #expect(
            try ApprovalValidator.validate(
                records: [planRecord, planRecord, strategistRecord],
                context: context
            ) == .rejected
        )
        let oneAttestationContext = try approvalValidationContext(
            graph: graph,
            setup: setup,
            gate: .planGate,
            author: author,
            validators: [plan, strategist],
            attestations: [planAttestation]
        )
        #expect(
            try ApprovalValidator.validate(
                records: [planRecord, strategistRecord],
                context: oneAttestationContext
            ) == .rejected
        )
    }

    @Test("full selected-authority snapshot drift invalidates the record")
    func fullAuthoritySnapshotFreshness() throws {
        let fixture = try issuedDesignApproval()
        let drifts = try [
            approvalAuthorityFact(
                "replacement-design-validator",
                roles: [.designValidator, .standardsValidator],
                context: "2",
                kind: .agent
            ),
            approvalAuthorityFact(
                "design-validator",
                roles: [.designValidator, .standardsValidator],
                context: "2",
                kind: .agent,
                principalID: "principal-replacement"
            ),
            approvalAuthorityFact(
                "design-validator",
                roles: [.designValidator, .standardsValidator, .securityPrivacyReviewer],
                context: "2",
                kind: .agent
            ),
            approvalAuthorityFact(
                "design-validator",
                roles: [.designValidator, .standardsValidator],
                context: "4",
                kind: .agent
            ),
            approvalAuthorityFact(
                "design-validator",
                roles: [.designValidator, .standardsValidator],
                context: "2",
                kind: .kernel
            ),
            approvalAuthorityFact(
                "design-validator",
                roles: [.designValidator, .standardsValidator],
                context: "2",
                kind: .agent,
                hasAuthorshipEdge: true
            ),
            approvalAuthorityFact(
                "design-validator",
                roles: [.designValidator, .standardsValidator],
                context: "2",
                kind: .agent,
                hasSourceWriteCapability: true
            ),
        ]

        for drift in drifts {
            let context = try approvalValidationContext(
                graph: fixture.graph,
                setup: fixture.setup,
                gate: .designGate,
                author: fixture.author,
                validators: [drift],
                attestations: [fixture.attestation]
            )
            #expect(
                try ApprovalValidator.validate(records: [fixture.record], context: context)
                    != .current
            )
        }
    }

    @Test("verified policy binding detects semantic drift beneath the same declared digest")
    func semanticPolicyBindingFreshness() throws {
        let graph = try approvalGraph()
        let strict = try approvalAuthoritySetup(policyDigest: "3", distinctPrincipals: .strict)
        let relaxed = try approvalAuthoritySetup(policyDigest: "3", distinctPrincipals: .notRequired)
        let author = try approvalAuthorityFact("policy-author", roles: [.author], context: "1", kind: .agent)
        let validator = try approvalAuthorityFact("design-validator", roles: [.designValidator], context: "2", kind: .agent)
        let reviewed = try VerifiedReviewedArtifactSet.derive(graph: graph, gate: .designGate)
        let strictBinding = try VerifiedApprovalPolicyBinding.derive(
            gatePolicy: strict.gatePolicy,
            gate: .designGate,
            mode: .auto,
            policyContext: strict.context,
            escalationFlags: [],
            author: author
        )
        let relaxedBinding = try VerifiedApprovalPolicyBinding.derive(
            gatePolicy: relaxed.gatePolicy,
            gate: .designGate,
            mode: .auto,
            policyContext: relaxed.context,
            escalationFlags: [],
            author: author
        )
        #expect(strict.gatePolicy.policyDigest == relaxed.gatePolicy.policyDigest)
        #expect(strictBinding.semanticPolicyDigest != relaxedBinding.semanticPolicyDigest)
        #expect(strictBinding.bindingDigest != relaxedBinding.bindingDigest)

        let record = try approvalRecord(
            gate: .designGate,
            role: .designValidator,
            fact: validator,
            policy: strictBinding,
            reviewed: reviewed,
            reference: "attestation-policy"
        )
        let attestation = try approvalAttestation(record, suffix: "2")
        let relaxedContext = try approvalValidationContext(
            graph: graph,
            setup: relaxed,
            gate: .designGate,
            author: author,
            validators: [validator],
            attestations: [attestation]
        )
        #expect(try ApprovalValidator.validate(records: [record], context: relaxedContext) == .stale)
    }

    @Test("approval invalidation consumes only a sealed graph-bound invalidation record")
    func sealedInvalidationAuthority() throws {
        let graphFixture = try approvalInvalidationGraph()
        let mutation = try ArtifactMutationVerifier.verify(
            graph: graphFixture.graph,
            artifactID: graphFixture.requirement.id,
            storedBytes: graphFixture.storedBytes,
            currentBytes: Data("requirement-v2".utf8),
            changedScopes: [graphFixture.scope],
            sectionManifestDigest: approvalDigest("9"),
            verifierID: ActorID(validating: "actor-kernel")
        )
        let invalidation = try ArtifactInvalidator().invalidate(
            mutation: mutation,
            in: graphFixture.graph
        )
        #expect(invalidation.changedArtifactID == graphFixture.requirement.id)
        #expect(invalidation.staleArtifactIDs == [graphFixture.design.id])

        let affected = try issuedDesignApproval(graph: graphFixture.graph)
        let unrelated = try issuedDesignApproval(graph: approvalGraph())
        let selected = try ApprovalValidator.invalidatedApprovals(
            approvals: [unrelated.record, affected.record],
            by: invalidation
        )
        #expect(selected.count == 1)
        #expect(selected[0].reviewedSetDigest == affected.record.reviewedSetDigest)
    }

    @Test("approval schema mandates the normative semantic validator and hard-EOF wire contracts")
    func approvalSchemaContract() throws {
        let schema = try workflowSchemaObject("approval.schema.json")
        #expect(schema["$schema"] as? String == "https://json-schema.org/draft/2020-12/schema")
        #expect(schema["$id"] as? String == "urn:ifl:standards:schema:approval:v1")
        #expect(schema["type"] as? String == "object")
        #expect(schema["additionalProperties"] as? Bool == false)
        #expect(
            schema["x-ifl-semantic-validator"] as? String
                == "ApprovalRecord.decodeCanonical/v1"
        )
        #expect(Set(schema["required"] as? [String] ?? []) == [
            "schema_version", "gate", "kind", "actor_id", "principal_id", "role",
            "authority_policy_digest", "policy_binding_digest", "reviewed_artifacts",
            "reviewed_set_digest", "authority_snapshot", "timestamp",
            "attestation_reference",
        ])

        let properties = try #require(schema["properties"] as? [String: Any])
        let reviewed = try #require(properties["reviewed_artifacts"] as? [String: Any])
        #expect(reviewed["type"] as? String == "object")
        #expect(reviewed["minProperties"] as? Int == 1)
        #expect(reviewed["items"] == nil)
        let propertyNames = try #require(reviewed["propertyNames"] as? [String: Any])
        #expect(
            propertyNames["pattern"] as? String
                == "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*(?![\\s\\S])"
        )
        let artifactHash = try #require(reviewed["additionalProperties"] as? [String: Any])
        #expect(artifactHash["type"] as? String == "string")
        #expect(artifactHash["pattern"] as? String == "^[0-9a-f]{64}(?![\\s\\S])")
        let snapshot = try #require(properties["authority_snapshot"] as? [String: Any])
        #expect(snapshot["$ref"] as? String == "#/$defs/authority_snapshot")

        let definitions = try #require(schema["$defs"] as? [String: Any])
        let authoritySnapshot = try #require(definitions["authority_snapshot"] as? [String: Any])
        #expect(authoritySnapshot["additionalProperties"] as? Bool == false)
        #expect(Set(authoritySnapshot["required"] as? [String] ?? []) == [
            "schema_version", "actor_id", "principal_id", "roles", "principal_kind",
            "independent_context_digest", "has_authorship_edge",
            "has_source_write_capability", "snapshot_digest",
        ])

        for key in [
            "actor_id", "principal_id", "attestation_reference", "authority_policy_digest",
            "policy_binding_digest", "reviewed_set_digest",
        ] {
            let property = try #require(properties[key] as? [String: Any])
            let pattern = try #require(property["pattern"] as? String)
            #expect(pattern.hasSuffix("(?![\\s\\S])"))
        }

        let bytes = try Data(contentsOf: workflowSchemaURL("approval.schema.json"))
        var canonical = try JSONSerialization.data(
            withJSONObject: JSONSerialization.jsonObject(with: bytes),
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        canonical.append(0x0A)
        #expect(bytes == canonical)
    }
}

private struct IssuedDesignApproval {
    let graph: ArtifactGraph
    let setup: ApprovalAuthoritySetup
    let author: VerifiedAuthorityFact
    let validator: VerifiedAuthorityFact
    let reviewedSet: VerifiedReviewedArtifactSet
    let policyBinding: VerifiedApprovalPolicyBinding
    let record: ApprovalRecord
    let attestation: VerifiedApprovalAttestation
    let context: ApprovalValidationContext
}

private struct ApprovalAuthoritySetup {
    let context: ActivePolicyContext
    let gatePolicy: GatePolicy
}

private struct ApprovalInvalidationGraph {
    let graph: ArtifactGraph
    let requirement: ArtifactReference
    let design: ArtifactReference
    let scope: ArtifactScope
    let storedBytes: Data
}

private func issuedDesignApproval(graph: ArtifactGraph? = nil) throws -> IssuedDesignApproval {
    let graph = try graph ?? approvalGraph()
    let setup = try approvalAuthoritySetup(policyDigest: "3")
    let author = try approvalAuthorityFact(
        "approval-author",
        roles: [.author],
        context: "1",
        kind: .agent
    )
    let validator = try approvalAuthorityFact(
        "design-validator",
        roles: [.designValidator, .standardsValidator],
        context: "2",
        kind: .agent
    )
    let reviewed = try VerifiedReviewedArtifactSet.derive(graph: graph, gate: .designGate)
    let policy = try VerifiedApprovalPolicyBinding.derive(
        gatePolicy: setup.gatePolicy,
        gate: .designGate,
        mode: .auto,
        policyContext: setup.context,
        escalationFlags: [],
        author: author
    )
    let record = try approvalRecord(
        gate: .designGate,
        role: .designValidator,
        fact: validator,
        policy: policy,
        reviewed: reviewed,
        reference: "attestation-design-001"
    )
    let attestation = try approvalAttestation(record, suffix: "5")
    let context = try approvalValidationContext(
        graph: graph,
        setup: setup,
        gate: .designGate,
        author: author,
        validators: [validator],
        attestations: [attestation]
    )
    return IssuedDesignApproval(
        graph: graph,
        setup: setup,
        author: author,
        validator: validator,
        reviewedSet: reviewed,
        policyBinding: policy,
        record: record,
        attestation: attestation,
        context: context
    )
}

private func approvalRecord(
    gate: WorkflowStage,
    role: AuthorityRole,
    fact: VerifiedAuthorityFact,
    policy: VerifiedApprovalPolicyBinding,
    reviewed: VerifiedReviewedArtifactSet,
    reference: String
) throws -> ApprovalRecord {
    try ApprovalRecord.issue(
        gate: gate,
        kind: .autoApproved,
        role: role,
        authorityFact: fact,
        policyBinding: policy,
        reviewedSet: reviewed,
        timestamp: Date(timeIntervalSince1970: 0.123),
        attestationReference: reference
    )
}

private func approvalAttestation(
    _ record: ApprovalRecord,
    suffix: Character
) throws -> VerifiedApprovalAttestation {
    let capabilities = try approvalAttestationCapabilities(record: record, suffix: suffix)
    return try ApprovalAttestationVerifier.verify(
        record: record,
        authenticatedEvent: capabilities.authenticatedEvent,
        signature: capabilities.signature,
        trustPolicy: capabilities.trustPolicy
    )
}

private func approvalAttestationCapabilities(
    record: ApprovalRecord,
    suffix: Character
) throws -> ApprovalAttestationTestCapabilities {
    try ApprovalAttestationTestCapabilities.make(
        recordDigest: approvalRecordDigest(record),
        authenticatedEventDigest: approvalDigest(suffix),
        signatureDigest: approvalDigest("6"),
        trustPolicyDigest: approvalDigest("7")
    )
}

private func approvalValidationContext(
    graph: ArtifactGraph,
    setup: ApprovalAuthoritySetup,
    gate: WorkflowStage,
    mode: WorkflowMode = .auto,
    author: VerifiedAuthorityFact?,
    validators: [VerifiedAuthorityFact],
    escalationFlags: Set<AuthorityEscalationFlag> = [],
    attestations: [VerifiedApprovalAttestation]
) throws -> ApprovalValidationContext {
    try ApprovalValidationContext(
        graph: graph,
        currentGate: gate,
        gatePolicy: setup.gatePolicy,
        mode: mode,
        policyContext: setup.context,
        escalationFlags: escalationFlags,
        authorityEvidence: AuthorityEvidence(author: author, validators: validators),
        attestations: attestations
    )
}

private func approvalAuthoritySetup(
    policyDigest: Character,
    distinctPrincipals: DistinctPrincipalPolicy = .strict
) throws -> ApprovalAuthoritySetup {
    let profileID = try ProfileID(validating: "approval-profile")
    let profileDigest = approvalDigest("9")
    return try ApprovalAuthoritySetup(
        context: ActivePolicyContext(
            profileID: profileID,
            profileDigest: profileDigest,
            riskClass: .medium
        ),
        gatePolicy: GatePolicy.standard(
            profileID: profileID,
            profileDigest: profileDigest,
            policyDigest: approvalDigest(policyDigest),
            distinctPrincipalPolicy: distinctPrincipals,
            specialistReviewersByRisk: [
                .high: [.securityPrivacyReviewer],
                .critical: [.securityPrivacyReviewer, .dataIntegrityReviewer],
            ]
        )
    )
}

private func approvalAuthorityFact(
    _ name: String,
    roles: Set<AuthorityRole>,
    context: Character,
    kind: VerifiedPrincipalKind,
    principalID: String? = nil,
    hasAuthorshipEdge: Bool = false,
    hasSourceWriteCapability: Bool = false
) throws -> VerifiedAuthorityFact {
    VerifiedAuthorityFact(
        actorID: try ActorID(validating: "actor-\(name)"),
        principalID: try PrincipalID(validating: principalID ?? "principal-\(name)"),
        roles: roles,
        principalKind: kind,
        independentContextDigest: approvalDigest(context),
        hasAuthorshipEdge: hasAuthorshipEdge,
        hasSourceWriteCapability: hasSourceWriteCapability
    )
}

private func approvalGraph(includeSource: Bool = false) throws -> ArtifactGraph {
    let scope = try ArtifactScope(kind: .semanticSelector, value: "workflow")
    var artifacts = try [
        ArtifactReference(
            id: ArtifactID(validating: "artifact-architecture"),
            type: .architecture,
            scope: scope,
            contentHash: approvalDigest("a")
        ),
        ArtifactReference(
            id: ArtifactID(validating: "artifact-plan"),
            type: .plan,
            scope: scope,
            contentHash: approvalDigest("b")
        ),
    ]
    if includeSource {
        artifacts.append(
            try ArtifactReference(
                id: ArtifactID(validating: "artifact-source"),
                type: .source,
                scope: scope,
                contentHash: approvalDigest("c")
            )
        )
    }
    let roots = try artifacts.map {
        try ArtifactIndependentRoot(artifactID: $0.id, artifactHash: $0.contentHash)
    }
    let authority = try VerifiedArtifactTraceAuthority.testing(
        policyID: "approval-trace-policy-v1",
        policyDigest: approvalDigest("0"),
        requiredObligations: [],
        permittedIndependentRoots: roots
    )
    return try ArtifactGraph(
        artifacts: artifacts,
        dependencies: [],
        dependencyObligations: [],
        independentRoots: roots,
        authority: authority
    )
}

private func approvalInvalidationGraph() throws -> ApprovalInvalidationGraph {
    let scope = try ArtifactScope(kind: .semanticSelector, value: "workflow")
    let storedBytes = Data("requirement-v1".utf8)
    let requirement = try ArtifactReference(
        id: ArtifactID(validating: "artifact-requirement"),
        type: .requirement,
        scope: scope,
        contentHash: CanonicalTreeDigest.sha256(storedBytes)
    )
    let design = try ArtifactReference(
        id: ArtifactID(validating: "artifact-design"),
        type: .design,
        scope: scope,
        contentHash: CanonicalTreeDigest.sha256(Data("design-v1".utf8))
    )
    let dependency = try ArtifactDependency(
        upstreamArtifactID: requirement.id,
        upstreamHash: requirement.contentHash,
        downstreamArtifactID: design.id,
        downstreamHash: design.contentHash,
        relation: .derives,
        affectedScope: scope,
        requirementIDs: [RequirementID(validating: "REQ-WORKFLOW-001")],
        ruleIDs: [RuleID(validating: "IFL-WORKFLOW-001")]
    )
    let obligation = ArtifactDependencyObligation(dependency: dependency)
    let root = try ArtifactIndependentRoot(
        artifactID: requirement.id,
        artifactHash: requirement.contentHash
    )
    let authority = try VerifiedArtifactTraceAuthority.testing(
        policyID: "approval-trace-policy-v1",
        policyDigest: approvalDigest("0"),
        requiredObligations: [obligation],
        permittedIndependentRoots: [root]
    )
    let graph = try ArtifactGraph(
        artifacts: [requirement, design],
        dependencies: [dependency],
        dependencyObligations: [obligation],
        independentRoots: [root],
        authority: authority
    )
    return ApprovalInvalidationGraph(
        graph: graph,
        requirement: requirement,
        design: design,
        scope: scope,
        storedBytes: storedBytes
    )
}

private func approvalDigest(_ character: Character) -> HashDigest {
    try! HashDigest(validating: String(repeating: String(character), count: 64))
}

private func approvalRecordDigest(_ record: ApprovalRecord) -> HashDigest {
    CanonicalTreeDigest.sha256(try! CanonicalJSON.encode(record))
}

private func approvalJSONObject(_ record: ApprovalRecord) throws -> [String: Any] {
    try #require(
        JSONSerialization.jsonObject(with: CanonicalJSON.encode(record)) as? [String: Any]
    )
}

private func canonicalData(_ object: [String: Any]) throws -> Data {
    try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

private func approvalTypeIsDecodable(_ type: Any.Type) -> Bool {
    type is any Decodable.Type
}

private func approvalSourceSlice(
    filename: String,
    from startMarker: String,
    until endMarker: String
) throws -> Substring {
    var root = URL(fileURLWithPath: #filePath)
    while root.lastPathComponent != "ifl-ios-standards", root.path != "/" {
        root.deleteLastPathComponent()
    }
    let source = try String(
        contentsOf: root
            .appendingPathComponent("tools/ifl-tooling/Sources/IFLWorkflow/Artifacts")
            .appendingPathComponent(filename),
        encoding: .utf8
    )
    let start = try #require(source.range(of: startMarker)?.lowerBound)
    let end = try #require(
        source.range(of: endMarker, range: start ..< source.endIndex)?.lowerBound
    )
    return source[start ..< end]
}
