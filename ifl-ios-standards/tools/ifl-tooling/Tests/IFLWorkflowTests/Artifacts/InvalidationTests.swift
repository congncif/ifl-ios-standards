import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("InvalidationTests")
struct InvalidationTests {
    @Test("six fixtures require authenticated mutation bytes and complete graph declarations")
    func fixturesRequireAuthenticatedCanonicalInputs() throws {
        for filename in invalidationFixtureNames {
            let data = try invalidationFixtureData(filename)
            #expect(data.last == 0x0A)
            #expect(!data.dropLast().contains(0x0A))
            #expect(!data.contains(0x0D))

            let fixture = try CanonicalJSON.decode(InvalidationFixture.self, from: data)
            var roundTrip = try CanonicalJSON.encode(fixture)
            roundTrip.append(0x0A)
            #expect(roundTrip == data)

            var unknown = try #require(
                JSONSerialization.jsonObject(with: data) as? [String: Any]
            )
            unknown["unknown"] = true
            #expect(throws: (any Error).self) {
                try CanonicalJSON.decode(
                    InvalidationFixture.self,
                    from: JSONSerialization.data(
                        withJSONObject: unknown,
                        options: [.sortedKeys, .withoutEscapingSlashes]
                    )
                )
            }
        }
    }

    @Test("fixtures freeze exact authenticated bytes, hashes, obligations, roots, and stale sets")
    func fixtureLiteralSemanticsAreFixed() throws {
        for filename in invalidationFixtureNames {
            let fixture = try invalidationFixture(filename)
            let scenario = try #require(invalidationScenarioExpectations[filename])

            #expect(fixture.artifacts.map(fixtureArtifactExpectation) == invalidationArtifactExpectations)
            #expect(
                fixture.dependencies.map(fixtureDependencyExpectation)
                    == invalidationDependencyExpectations
            )
            #expect(
                fixture.dependencyObligations.map(fixtureObligationExpectation)
                    == invalidationDependencyExpectations
            )
            #expect(fixture.independentRoots.map { root in
                FixtureRootExpectation(
                    artifactID: root.artifactID.rawValue,
                    artifactHash: root.artifactHash.rawValue
                )
            } == invalidationRootExpectations)
            #expect(fixture.traceAuthority.policyID == invalidationTracePolicyID)
            #expect(fixture.traceAuthority.policyDigest == invalidationTracePolicyDigest)
            #expect(
                fixture.traceAuthority.requiredObligations.map(fixtureObligationExpectation)
                    == invalidationDependencyExpectations
            )
            #expect(fixture.traceAuthority.permittedIndependentRoots == fixture.independentRoots)

            #expect(fixture.mutationInput.artifactID.rawValue == scenario.changedArtifactID)
            #expect(fixture.mutationInput.storedBytes == scenario.storedBytes)
            #expect(fixture.mutationInput.currentBytes == scenario.currentBytes)
            #expect(CanonicalTreeDigest.sha256(fixture.mutationInput.storedBytes).rawValue == scenario.storedHash)
            #expect(CanonicalTreeDigest.sha256(fixture.mutationInput.currentBytes).rawValue == scenario.currentHash)
            #expect(fixture.mutationInput.changedScopes == [invalidationWorkflowScope])
            #expect(fixture.mutationInput.sectionManifestDigest.rawValue == scenario.sectionManifestDigest)
            #expect(fixture.mutationInput.verifierID == invalidationVerifierID)
            #expect(fixture.expectedChangedArtifactID.rawValue == scenario.changedArtifactID)
            #expect(fixture.expectedStaleArtifactIDs.map(\.rawValue) == scenario.staleArtifactIDs)
        }
    }

    @Test("verified mutations produce only each literal exact downstream transitive closure")
    func exactVerifiedTransitiveClosures() throws {
        for filename in invalidationFixtureNames {
            let fixture = try invalidationFixture(filename)
            let scenario = try #require(invalidationScenarioExpectations[filename])
            let graph = try fixtureGraph(fixture)
            let mutation = try verifiedMutation(fixture.mutationInput, graph: graph)
            let record = try ArtifactInvalidator().invalidate(mutation: mutation, in: graph)
            let expectedGraphBytes = try CanonicalJSON.encode(graph)
            let expectedGraphDigest = CanonicalTreeDigest.sha256(expectedGraphBytes)

            #expect(record.schemaVersion == 1)
            #expect(record.graphDigest == expectedGraphDigest)
            #expect(record.mutationDigest == mutation.digest)
            #expect(record.sectionManifestDigest == mutation.sectionManifestDigest)
            #expect(record.scopeDigest == mutation.scopeDigest)
            #expect(record.storedHash.rawValue == scenario.storedHash)
            #expect(record.currentHash.rawValue == scenario.currentHash)
            #expect(record.verifierID == invalidationVerifierID)
            #expect(record.provenance == .verifiedArtifactMutation)
            #expect(record.changedArtifactID.rawValue == scenario.changedArtifactID)
            #expect(record.staleArtifactIDs.map(\.rawValue) == scenario.staleArtifactIDs)
            #expect(record.changedArtifactID == fixture.expectedChangedArtifactID)
            #expect(record.staleArtifactIDs == fixture.expectedStaleArtifactIDs)
            #expect(!record.staleArtifactIDs.contains(record.changedArtifactID))
            #expect(!record.staleArtifactIDs.contains(invalidationUnrelatedID))
        }
    }

    @Test("repeated verified invalidation is byte-identical and deterministically ordered")
    func repeatedVerifiedInvalidationIsIdempotent() throws {
        for filename in invalidationFixtureNames {
            let fixture = try invalidationFixture(filename)
            let graph = try fixtureGraph(fixture)
            let mutation = try verifiedMutation(fixture.mutationInput, graph: graph)
            let first = try ArtifactInvalidator().invalidate(mutation: mutation, in: graph)
            let second = try ArtifactInvalidator().invalidate(mutation: mutation, in: graph)

            #expect(first == second)
            #expect(first.canonicalWireBytes == second.canonicalWireBytes)
            #expect(first.staleArtifactIDs.map(\.rawValue) == first.staleArtifactIDs.map(\.rawValue).sorted())
        }
    }

    @Test("verified scoped-out bytes remain local without a caller relatedness assertion")
    func verifiedScopedOutMutationDoesNotOverInvalidate() throws {
        let broadScope = try ArtifactScope(kind: .path, value: "Sources")
        let changed = try invalidationArtifact(
            .requirement,
            id: "artifact-requirement",
            scope: broadScope,
            storedBytes: Data("artifact-requirement/v1".utf8)
        )
        let dependent = try invalidationArtifact(
            .design,
            id: "artifact-design",
            scope: broadScope,
            storedBytes: Data("artifact-design/v1".utf8)
        )
        let dependency = try invalidationDependency(
            upstream: changed,
            downstream: dependent,
            relation: .derives,
            scope: ArtifactScope(kind: .path, value: "Sources/Feature")
        )
        let graph = try completeInvalidationGraph(
            artifacts: [changed, dependent],
            dependencies: [dependency]
        )
        let mutation = try ArtifactMutationVerifier.verify(
            graph: graph,
            artifactID: changed.id,
            storedBytes: Data("artifact-requirement/v1".utf8),
            currentBytes: Data("artifact-requirement/v2".utf8),
            changedScopes: [ArtifactScope(kind: .path, value: "Sources/Other")],
            sectionManifestDigest: invalidationDigest("9"),
            verifierID: invalidationVerifierID
        )

        let record = try ArtifactInvalidator().invalidate(mutation: mutation, in: graph)
        #expect(record.changedArtifactID == changed.id)
        #expect(record.staleArtifactIDs.isEmpty)
    }

    @Test("verified scope intersects only the first hop and every stale descendant follows")
    func onlyFirstHopIsScopeGated() throws {
        let requirement = try invalidationArtifact(
            .requirement,
            id: "artifact-requirement",
            scope: invalidationWorkflowScope,
            storedBytes: Data("artifact-requirement/v1".utf8)
        )
        let design = try invalidationArtifact(
            .design,
            id: "artifact-design",
            scope: invalidationWorkflowScope,
            storedBytes: Data("artifact-design/v1".utf8)
        )
        let architecture = try invalidationArtifact(
            .architecture,
            id: "artifact-architecture",
            scope: invalidationWorkflowScope,
            storedBytes: Data("artifact-architecture/v1".utf8)
        )
        let graph = try completeInvalidationGraph(
            artifacts: [requirement, design, architecture],
            dependencies: [
                invalidationDependency(
                    upstream: requirement,
                    downstream: design,
                    relation: .derives,
                    scope: ArtifactScope(
                        kind: .semanticSelector,
                        value: "workflow.requirements"
                    )
                ),
                invalidationDependency(
                    upstream: design,
                    downstream: architecture,
                    relation: .derives,
                    scope: ArtifactScope(
                        kind: .semanticSelector,
                        value: "workflow.architecture"
                    )
                ),
            ]
        )
        let mutation = try ArtifactMutationVerifier.verify(
            graph: graph,
            artifactID: requirement.id,
            storedBytes: Data("artifact-requirement/v1".utf8),
            currentBytes: Data("artifact-requirement/v2".utf8),
            changedScopes: [
                ArtifactScope(kind: .semanticSelector, value: "workflow.requirements"),
            ],
            sectionManifestDigest: invalidationDigest("9"),
            verifierID: invalidationVerifierID
        )

        let record = try ArtifactInvalidator().invalidate(mutation: mutation, in: graph)
        #expect(record.staleArtifactIDs.map(\.rawValue) == [
            "artifact-architecture", "artifact-design",
        ])
    }

    @Test("mutation verifier fails closed on unknown, stale, unchanged, duplicate, and impossible facts")
    func mutationVerificationFailsClosed() throws {
        let fixture = try invalidationFixture("requirement-change.json")
        let graph = try fixtureGraph(fixture)
        let input = fixture.mutationInput

        #expect(throws: (any Error).self) {
            try ArtifactMutationVerifier.verify(
                graph: graph,
                artifactID: ArtifactID(validating: "artifact-unknown"),
                storedBytes: input.storedBytes,
                currentBytes: input.currentBytes,
                changedScopes: input.changedScopes,
                sectionManifestDigest: input.sectionManifestDigest,
                verifierID: input.verifierID
            )
        }
        #expect(throws: (any Error).self) {
            try ArtifactMutationVerifier.verify(
                graph: graph,
                artifactID: input.artifactID,
                storedBytes: Data("forged-stored-bytes".utf8),
                currentBytes: input.currentBytes,
                changedScopes: input.changedScopes,
                sectionManifestDigest: input.sectionManifestDigest,
                verifierID: input.verifierID
            )
        }
        #expect(throws: (any Error).self) {
            try ArtifactMutationVerifier.verify(
                graph: graph,
                artifactID: input.artifactID,
                storedBytes: input.storedBytes,
                currentBytes: input.storedBytes,
                changedScopes: input.changedScopes,
                sectionManifestDigest: input.sectionManifestDigest,
                verifierID: input.verifierID
            )
        }
        let runtimeScope = try ArtifactScope(kind: .semanticSelector, value: "runtime")
        for invalidScopes in [
            [],
            [invalidationWorkflowScope, invalidationWorkflowScope],
            [runtimeScope],
        ] {
            #expect(throws: (any Error).self) {
                try ArtifactMutationVerifier.verify(
                    graph: graph,
                    artifactID: input.artifactID,
                    storedBytes: input.storedBytes,
                    currentBytes: input.currentBytes,
                    changedScopes: invalidScopes,
                    sectionManifestDigest: input.sectionManifestDigest,
                    verifierID: input.verifierID
                )
            }
        }

        let sorted = try ArtifactMutationVerifier.verify(
            graph: graph,
            artifactID: input.artifactID,
            storedBytes: input.storedBytes,
            currentBytes: input.currentBytes,
            changedScopes: [
                ArtifactScope(kind: .semanticSelector, value: "workflow.requirements"),
                ArtifactScope(kind: .semanticSelector, value: "workflow.design"),
            ],
            sectionManifestDigest: input.sectionManifestDigest,
            verifierID: input.verifierID
        )
        #expect(sorted.changedScopes.map(\.value) == ["workflow.design", "workflow.requirements"])
    }

    @Test("invalidation record is sealed, versioned, canonical, and exactly replayable")
    func canonicalRecordReplay() throws {
        let (graph, mutation, record) = try invalidationRecordFixture()
        let bytes = record.canonicalWireBytes
        let wire = try ArtifactInvalidationWire.decodeCanonical(from: bytes)
        let replayed = try ArtifactInvalidator().replay(
            wire: wire,
            mutation: mutation,
            in: graph
        )

        #expect(replayed == record)
        #expect(replayed.canonicalWireBytes == bytes)
        #expect(wire.changedArtifactID == record.changedArtifactID)
        #expect(wire.staleArtifactIDs == record.staleArtifactIDs)
        let object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        #expect(Set(object.keys) == invalidationRecordWireKeys)
        #expect(object["schema_version"] as? Int == 1)
        #expect(object["provenance"] as? String == "verified_artifact_mutation")
    }

    @Test("decoded canonical invalidation wire is untrusted until exact replay seals it")
    func decodedWireCannotConferInvalidationAuthority() throws {
        let (graph, mutation, record) = try invalidationRecordFixture()
        let forgedBytes = try mutateCanonicalRecord(
            record.canonicalWireBytes
        ) { object in
            object["stale_artifact_ids"] = []
        }
        let untrusted = try ArtifactInvalidationWire.decodeCanonical(from: forgedBytes)
        let consumerSource = try invalidationSourceSlice(
            filename: "ApprovalValidator.swift",
            from: "static func invalidatedApprovals",
            until: nil
        )

        #expect(untrusted.staleArtifactIDs.isEmpty)
        #expect(!invalidationTypeIsDecodable(ValidatedArtifactInvalidation.self))
        #expect(consumerSource.contains("by invalidation: ValidatedArtifactInvalidation"))
        #expect(!consumerSource.contains("by invalidation: ArtifactInvalidationWire"))
        #expect(throws: (any Error).self) {
            try ArtifactInvalidator().replay(
                wire: untrusted,
                mutation: mutation,
                in: graph
            )
        }
    }

    @Test("record replay rejects noncanonical framing, parser differentials, forgery, and drift")
    func recordReplayRejectsForgeryAndDrift() throws {
        let (graph, mutation, record) = try invalidationRecordFixture()
        let invalidator = ArtifactInvalidator()
        let canonicalBytes = record.canonicalWireBytes
        let canonicalWire = try ArtifactInvalidationWire.decodeCanonical(from: canonicalBytes)
        let canonicalString = String(decoding: canonicalBytes, as: UTF8.self)

        var newline = canonicalBytes
        newline.append(0x0A)
        let leadingWhitespace = Data(" \(canonicalString)".utf8)
        let pretty = try JSONSerialization.data(
            withJSONObject: JSONSerialization.jsonObject(with: canonicalBytes),
            options: [.prettyPrinted, .sortedKeys]
        )
        let duplicateKey = Data(
            canonicalString.replacingOccurrences(
                of: #"{"changed_artifact_id":"#,
                with: #"{"changed_artifact_id":"artifact-forged","changed_artifact_id":"#
            ).utf8
        )

        for noncanonical in [newline, leadingWhitespace, pretty, duplicateKey] {
            #expect(throws: (any Error).self) {
                try ArtifactInvalidationWire.decodeCanonical(from: noncanonical)
            }
        }

        for structuralMutation in [
            { (object: inout [String: Any]) in object["unknown"] = true },
            { (object: inout [String: Any]) in object["schema_version"] = 2 },
            { (object: inout [String: Any]) in object["provenance"] = "caller_asserted" },
        ] {
            let forged = try mutateCanonicalRecord(canonicalBytes, mutation: structuralMutation)
            #expect(throws: (any Error).self) {
                try ArtifactInvalidationWire.decodeCanonical(from: forged)
            }
        }

        for semanticMutation in [
            { (object: inout [String: Any]) in
                object["graph_digest"] = String(repeating: "0", count: 64)
            },
            { (object: inout [String: Any]) in object["stale_artifact_ids"] = [] },
        ] {
            let forged = try mutateCanonicalRecord(canonicalBytes, mutation: semanticMutation)
            let forgedWire = try ArtifactInvalidationWire.decodeCanonical(from: forged)
            #expect(throws: (any Error).self) {
                try invalidator.replay(
                    wire: forgedWire,
                    mutation: mutation,
                    in: graph
                )
            }
        }

        let driftedGraph = try graphWithUnrelatedArtifactDrift(graph)
        #expect(throws: (any Error).self) {
            try invalidator.replay(
                wire: canonicalWire,
                mutation: mutation,
                in: driftedGraph
            )
        }

        let driftedMutation = try ArtifactMutationVerifier.verify(
            graph: graph,
            artifactID: mutation.artifactID,
            storedBytes: Data("artifact-requirement/v1".utf8),
            currentBytes: Data("artifact-requirement/v3".utf8),
            changedScopes: mutation.changedScopes,
            sectionManifestDigest: invalidationDigest("8"),
            verifierID: mutation.verifierID
        )
        #expect(throws: (any Error).self) {
            try invalidator.replay(
                wire: canonicalWire,
                mutation: driftedMutation,
                in: graph
            )
        }
    }
}

private struct InvalidationFixture: Codable {
    let schemaVersion: Int
    let artifacts: [ArtifactReference]
    let dependencies: [ArtifactDependency]
    let dependencyObligations: [ArtifactDependencyObligation]
    let independentRoots: [ArtifactIndependentRoot]
    let traceAuthority: ArtifactTraceAuthorityFixture
    let mutationInput: ArtifactMutationFixtureInput
    let expectedChangedArtifactID: ArtifactID
    let expectedStaleArtifactIDs: [ArtifactID]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case artifacts
        case dependencies
        case dependencyObligations = "dependency_obligations"
        case independentRoots = "independent_roots"
        case traceAuthority = "trace_authority"
        case mutationInput = "mutation_input"
        case expectedChangedArtifactID = "expected_changed_artifact_id"
        case expectedStaleArtifactIDs = "expected_stale_artifact_ids"
    }

    init(from decoder: any Decoder) throws {
        try rejectUnknownFixtureFields(decoder, allowed: CodingKeys.allCases.map(\.rawValue))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else { throw fixtureDecodingError(decoder, "Expected InvalidationFixture/v1") }
        artifacts = try container.decode([ArtifactReference].self, forKey: .artifacts)
        dependencies = try container.decode([ArtifactDependency].self, forKey: .dependencies)
        dependencyObligations = try container.decode(
            [ArtifactDependencyObligation].self,
            forKey: .dependencyObligations
        )
        independentRoots = try container.decode(
            [ArtifactIndependentRoot].self,
            forKey: .independentRoots
        )
        traceAuthority = try container.decode(
            ArtifactTraceAuthorityFixture.self,
            forKey: .traceAuthority
        )
        mutationInput = try container.decode(ArtifactMutationFixtureInput.self, forKey: .mutationInput)
        expectedChangedArtifactID = try container.decode(
            ArtifactID.self,
            forKey: .expectedChangedArtifactID
        )
        expectedStaleArtifactIDs = try container.decode(
            [ArtifactID].self,
            forKey: .expectedStaleArtifactIDs
        )
    }
}

private struct ArtifactTraceAuthorityFixture: Codable {
    let schemaVersion: Int
    let policyID: String
    let policyDigest: HashDigest
    let requiredObligations: [ArtifactDependencyObligation]
    let permittedIndependentRoots: [ArtifactIndependentRoot]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case policyID = "policy_id"
        case policyDigest = "policy_digest"
        case requiredObligations = "required_obligations"
        case permittedIndependentRoots = "permitted_independent_roots"
    }

    init(from decoder: any Decoder) throws {
        try rejectUnknownFixtureFields(decoder, allowed: CodingKeys.allCases.map(\.rawValue))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else {
            throw fixtureDecodingError(decoder, "Expected trace authority fixture v1")
        }
        policyID = try container.decode(String.self, forKey: .policyID)
        policyDigest = try container.decode(HashDigest.self, forKey: .policyDigest)
        requiredObligations = try container.decode(
            [ArtifactDependencyObligation].self,
            forKey: .requiredObligations
        )
        permittedIndependentRoots = try container.decode(
            [ArtifactIndependentRoot].self,
            forKey: .permittedIndependentRoots
        )
    }
}

private struct ArtifactMutationFixtureInput: Codable {
    let schemaVersion: Int
    let artifactID: ArtifactID
    let storedBytes: Data
    let currentBytes: Data
    let changedScopes: [ArtifactScope]
    let sectionManifestDigest: HashDigest
    let verifierID: ActorID

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case artifactID = "artifact_id"
        case storedBytes = "stored_bytes"
        case currentBytes = "current_bytes"
        case changedScopes = "changed_scopes"
        case sectionManifestDigest = "section_manifest_digest"
        case verifierID = "verifier_id"
    }

    init(from decoder: any Decoder) throws {
        try rejectUnknownFixtureFields(decoder, allowed: CodingKeys.allCases.map(\.rawValue))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else { throw fixtureDecodingError(decoder, "Expected mutation input v1") }
        artifactID = try container.decode(ArtifactID.self, forKey: .artifactID)
        storedBytes = try container.decode(Data.self, forKey: .storedBytes)
        currentBytes = try container.decode(Data.self, forKey: .currentBytes)
        changedScopes = try container.decode([ArtifactScope].self, forKey: .changedScopes)
        sectionManifestDigest = try container.decode(HashDigest.self, forKey: .sectionManifestDigest)
        verifierID = try container.decode(ActorID.self, forKey: .verifierID)
    }
}

private struct InvalidationFixtureCodingKey: CodingKey {
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

private struct FixtureArtifactExpectation: Equatable {
    let id: String
    let type: ArtifactType
    let hash: String
    let scopeKind: ArtifactScopeKind
    let scopeValue: String
}

private struct FixtureDependencyExpectation: Equatable {
    let upstreamID: String
    let upstreamHash: String
    let downstreamID: String
    let downstreamHash: String
    let relation: ArtifactRelation
    let scopeKind: ArtifactScopeKind
    let scopeValue: String
    let requirementIDs: [String]
    let ruleIDs: [String]
}

private struct FixtureRootExpectation: Equatable {
    let artifactID: String
    let artifactHash: String
}

private struct InvalidationScenarioExpectation {
    let changedArtifactID: String
    let storedBytes: Data
    let currentBytes: Data
    let storedHash: String
    let currentHash: String
    let sectionManifestDigest: String
    let staleArtifactIDs: [String]
}

private let invalidationFixtureNames = [
    "requirement-change.json",
    "design-change.json",
    "architecture-change.json",
    "plan-change.json",
    "source-change.json",
    "canon-change.json",
]

private let invalidationArtifactExpectations = [
    fixtureArtifact("artifact-architecture", .architecture, "216986dd658763af28928b5f8118a8e1b9915392a8933bfa0387d786468aa39e", "workflow"),
    fixtureArtifact("artifact-canon", .canon, "3335b0bf4ecacd9540156c05dc7e7b7022de7458283208d707e6528b62440b6f", "workflow"),
    fixtureArtifact("artifact-command-evidence", .commandEvidence, "5d61a1f0687e54a5acfc78106ca0fbfda4beff8915319e5b53f79df5ebf98c37", "workflow"),
    fixtureArtifact("artifact-design", .design, "2d20cf652f68f5d3227a26b63fbf14c140e8d3a61ce085ef31f2163e27261bd3", "workflow"),
    fixtureArtifact("artifact-plan", .plan, "76be81b81017d93613feb3dd47890bd06165bcd42e56bb9e115accb4aefa2c88", "workflow"),
    fixtureArtifact("artifact-requirement", .requirement, "1963ff054c0573fe17c251f969d0e956e3b3985f6edeb01c22c26f8f2e5690e9", "workflow"),
    fixtureArtifact("artifact-source", .source, "93c30e6f177f91417362e4c068008cabec0bb5fa4017d8e1370f971e265c0f46", "workflow"),
    fixtureArtifact("artifact-unrelated", .source, "a99766a31ac6c1eec27d6ffc750c253f4356da055dd5532f9cbc6e2bf6526870", "disconnected"),
]

private let invalidationDependencyExpectations = [
    fixtureDependency("artifact-architecture", 0, "artifact-plan", 4, .derives),
    fixtureDependency("artifact-canon", 1, "artifact-requirement", 5, .validates),
    fixtureDependency("artifact-design", 3, "artifact-architecture", 0, .derives),
    fixtureDependency("artifact-plan", 4, "artifact-source", 6, .implements),
    fixtureDependency("artifact-requirement", 5, "artifact-design", 3, .derives),
    fixtureDependency("artifact-source", 6, "artifact-command-evidence", 2, .validates),
]

private let invalidationRootExpectations = [
    FixtureRootExpectation(
        artifactID: "artifact-canon",
        artifactHash: "3335b0bf4ecacd9540156c05dc7e7b7022de7458283208d707e6528b62440b6f"
    ),
    FixtureRootExpectation(
        artifactID: "artifact-unrelated",
        artifactHash: "a99766a31ac6c1eec27d6ffc750c253f4356da055dd5532f9cbc6e2bf6526870"
    ),
]

private let invalidationScenarioExpectations: [String: InvalidationScenarioExpectation] = [
    "requirement-change.json": scenario(
        "requirement",
        "1963ff054c0573fe17c251f969d0e956e3b3985f6edeb01c22c26f8f2e5690e9",
        "ca260da64136ab5d43c98f2c90c807ef19d914e169538da53966e8eeaf315793",
        "6ade862f0f6e8963885bb363df93f45aab5d987d0e5dd87b00165fda31ece33e",
        ["artifact-architecture", "artifact-command-evidence", "artifact-design", "artifact-plan", "artifact-source"]
    ),
    "design-change.json": scenario(
        "design",
        "2d20cf652f68f5d3227a26b63fbf14c140e8d3a61ce085ef31f2163e27261bd3",
        "fa539763e27563ca66ec1d0e25fd1fa5bf027446acb9f98af5b4351b488925ea",
        "69ef2d4a2db0fae967ee080e6623c0b33798f89270702320b5a018e183fa9ace",
        ["artifact-architecture", "artifact-command-evidence", "artifact-plan", "artifact-source"]
    ),
    "architecture-change.json": scenario(
        "architecture",
        "216986dd658763af28928b5f8118a8e1b9915392a8933bfa0387d786468aa39e",
        "b34db627c1497260726b6bc1044839a8e883c07221cbabd251e8a9302f147bbf",
        "929d64bbd3c9916bc1eda41d6f18535147cc0c90e83afa28362fe960c4f84ebe",
        ["artifact-command-evidence", "artifact-plan", "artifact-source"]
    ),
    "plan-change.json": scenario(
        "plan",
        "76be81b81017d93613feb3dd47890bd06165bcd42e56bb9e115accb4aefa2c88",
        "e61f864d499022dd727b122976750e573c3749a54207f16552ad9d758eaf6ef8",
        "002c776b6cfef3cd985b917c3d8e3e9fbd0082387569fcb48b4ecfd13e1bc462",
        ["artifact-command-evidence", "artifact-source"]
    ),
    "source-change.json": scenario(
        "source",
        "93c30e6f177f91417362e4c068008cabec0bb5fa4017d8e1370f971e265c0f46",
        "1ba886bde3664554d425d12ecef1cb5ffff0edbbeb6935542ab781ad3c24eaf0",
        "dd75ab95cf64921496aa18f515f6df544aa8227cafb4ee13af8a7f36d7f538d6",
        ["artifact-command-evidence"]
    ),
    "canon-change.json": scenario(
        "canon",
        "3335b0bf4ecacd9540156c05dc7e7b7022de7458283208d707e6528b62440b6f",
        "c5668e0e43421380b0386530d2b81f7b4008a4338f3f3aadce3d9e6398084b83",
        "cd9fcf569c2981672288e8fe48fe661d6f55c33ac14418eb257ad34954cfa131",
        ["artifact-architecture", "artifact-command-evidence", "artifact-design", "artifact-plan", "artifact-requirement", "artifact-source"]
    ),
]

private let invalidationWorkflowScope = try! ArtifactScope(
    kind: .semanticSelector,
    value: "workflow"
)
private let invalidationRequirementID = try! RequirementID(validating: "REQ-WORKFLOW-001")
private let invalidationRuleID = try! RuleID(validating: "IFL-WORKFLOW-001")
private let invalidationVerifierID = try! ActorID(validating: "artifact-mutation-verifier")
private let invalidationTracePolicyID = "workflow-trace-policy-v1"
private let invalidationTracePolicyDigest = try! HashDigest(
    validating: String(repeating: "7", count: 64)
)
private let invalidationUnrelatedID = try! ArtifactID(validating: "artifact-unrelated")
private let invalidationRecordWireKeys: Set<String> = [
    "changed_artifact_id", "current_hash", "graph_digest", "mutation_digest", "provenance",
    "schema_version", "scope_digest", "section_manifest_digest", "stale_artifact_ids",
    "stored_hash", "verifier_id",
]

private func scenario(
    _ component: String,
    _ storedHash: String,
    _ currentHash: String,
    _ sectionManifestDigest: String,
    _ staleArtifactIDs: [String]
) -> InvalidationScenarioExpectation {
    InvalidationScenarioExpectation(
        changedArtifactID: "artifact-\(component)",
        storedBytes: Data("artifact-\(component)/v1".utf8),
        currentBytes: Data("artifact-\(component)/v2".utf8),
        storedHash: storedHash,
        currentHash: currentHash,
        sectionManifestDigest: sectionManifestDigest,
        staleArtifactIDs: staleArtifactIDs
    )
}

private func fixtureArtifact(
    _ id: String,
    _ type: ArtifactType,
    _ hash: String,
    _ scope: String
) -> FixtureArtifactExpectation {
    FixtureArtifactExpectation(
        id: id,
        type: type,
        hash: hash,
        scopeKind: .semanticSelector,
        scopeValue: scope
    )
}

private func fixtureDependency(
    _ upstreamID: String,
    _ upstreamIndex: Int,
    _ downstreamID: String,
    _ downstreamIndex: Int,
    _ relation: ArtifactRelation
) -> FixtureDependencyExpectation {
    FixtureDependencyExpectation(
        upstreamID: upstreamID,
        upstreamHash: invalidationArtifactExpectations[upstreamIndex].hash,
        downstreamID: downstreamID,
        downstreamHash: invalidationArtifactExpectations[downstreamIndex].hash,
        relation: relation,
        scopeKind: .semanticSelector,
        scopeValue: "workflow",
        requirementIDs: ["REQ-WORKFLOW-001"],
        ruleIDs: ["IFL-WORKFLOW-001"]
    )
}

private func fixtureArtifactExpectation(
    _ artifact: ArtifactReference
) -> FixtureArtifactExpectation {
    FixtureArtifactExpectation(
        id: artifact.id.rawValue,
        type: artifact.type,
        hash: artifact.contentHash.rawValue,
        scopeKind: artifact.scope.kind,
        scopeValue: artifact.scope.value
    )
}

private func fixtureDependencyExpectation(
    _ dependency: ArtifactDependency
) -> FixtureDependencyExpectation {
    FixtureDependencyExpectation(
        upstreamID: dependency.upstreamArtifactID.rawValue,
        upstreamHash: dependency.upstreamHash.rawValue,
        downstreamID: dependency.downstreamArtifactID.rawValue,
        downstreamHash: dependency.downstreamHash.rawValue,
        relation: dependency.relation,
        scopeKind: dependency.affectedScope.kind,
        scopeValue: dependency.affectedScope.value,
        requirementIDs: dependency.requirementIDs.map(\.rawValue),
        ruleIDs: dependency.ruleIDs.map(\.rawValue)
    )
}

private func fixtureObligationExpectation(
    _ obligation: ArtifactDependencyObligation
) -> FixtureDependencyExpectation {
    FixtureDependencyExpectation(
        upstreamID: obligation.upstreamArtifactID.rawValue,
        upstreamHash: obligation.upstreamHash.rawValue,
        downstreamID: obligation.downstreamArtifactID.rawValue,
        downstreamHash: obligation.downstreamHash.rawValue,
        relation: obligation.relation,
        scopeKind: obligation.affectedScope.kind,
        scopeValue: obligation.affectedScope.value,
        requirementIDs: obligation.requirementIDs.map(\.rawValue),
        ruleIDs: obligation.ruleIDs.map(\.rawValue)
    )
}

private func invalidationDigest(_ character: Character) throws -> HashDigest {
    try HashDigest(validating: String(repeating: String(character), count: 64))
}

private func invalidationArtifact(
    _ type: ArtifactType,
    id: String,
    scope: ArtifactScope,
    storedBytes: Data
) throws -> ArtifactReference {
    try ArtifactReference(
        id: ArtifactID(validating: id),
        type: type,
        scope: scope,
        contentHash: CanonicalTreeDigest.sha256(storedBytes)
    )
}

private func invalidationDependency(
    upstream: ArtifactReference,
    downstream: ArtifactReference,
    relation: ArtifactRelation,
    scope: ArtifactScope
) throws -> ArtifactDependency {
    try ArtifactDependency(
        upstreamArtifactID: upstream.id,
        upstreamHash: upstream.contentHash,
        downstreamArtifactID: downstream.id,
        downstreamHash: downstream.contentHash,
        relation: relation,
        affectedScope: scope,
        requirementIDs: [invalidationRequirementID],
        ruleIDs: [invalidationRuleID]
    )
}

private func invalidationObligation(
    _ dependency: ArtifactDependency
) throws -> ArtifactDependencyObligation {
    try ArtifactDependencyObligation(
        upstreamArtifactID: dependency.upstreamArtifactID,
        upstreamHash: dependency.upstreamHash,
        downstreamArtifactID: dependency.downstreamArtifactID,
        downstreamHash: dependency.downstreamHash,
        relation: dependency.relation,
        affectedScope: dependency.affectedScope,
        requirementIDs: dependency.requirementIDs,
        ruleIDs: dependency.ruleIDs
    )
}

private func invalidationRoot(
    _ artifact: ArtifactReference
) throws -> ArtifactIndependentRoot {
    try ArtifactIndependentRoot(
        artifactID: artifact.id,
        artifactHash: artifact.contentHash
    )
}

private func completeInvalidationGraph(
    artifacts: [ArtifactReference],
    dependencies: [ArtifactDependency]
) throws -> ArtifactGraph {
    let downstreamIDs = Set(dependencies.map(\.downstreamArtifactID))
    let obligations = try dependencies.map(invalidationObligation)
    let roots = try artifacts
        .filter { !downstreamIDs.contains($0.id) }
        .map(invalidationRoot)
    let authority = try VerifiedArtifactTraceAuthority.testing(
        policyID: invalidationTracePolicyID,
        policyDigest: invalidationTracePolicyDigest,
        requiredObligations: obligations,
        permittedIndependentRoots: roots
    )
    return try ArtifactGraph(
        artifacts: artifacts,
        dependencies: dependencies,
        dependencyObligations: obligations,
        independentRoots: roots,
        authority: authority
    )
}

private func fixtureGraph(_ fixture: InvalidationFixture) throws -> ArtifactGraph {
    let authority = try VerifiedArtifactTraceAuthority.testing(
        policyID: fixture.traceAuthority.policyID,
        policyDigest: fixture.traceAuthority.policyDigest,
        requiredObligations: fixture.traceAuthority.requiredObligations,
        permittedIndependentRoots: fixture.traceAuthority.permittedIndependentRoots
    )
    return try ArtifactGraph(
        artifacts: fixture.artifacts,
        dependencies: fixture.dependencies,
        dependencyObligations: fixture.dependencyObligations,
        independentRoots: fixture.independentRoots,
        authority: authority
    )
}

private func verifiedMutation(
    _ input: ArtifactMutationFixtureInput,
    graph: ArtifactGraph
) throws -> VerifiedArtifactMutation {
    try ArtifactMutationVerifier.verify(
        graph: graph,
        artifactID: input.artifactID,
        storedBytes: input.storedBytes,
        currentBytes: input.currentBytes,
        changedScopes: input.changedScopes,
        sectionManifestDigest: input.sectionManifestDigest,
        verifierID: input.verifierID
    )
}

private func invalidationRecordFixture() throws
    -> (ArtifactGraph, VerifiedArtifactMutation, ValidatedArtifactInvalidation)
{
    let fixture = try invalidationFixture("requirement-change.json")
    let graph = try fixtureGraph(fixture)
    let mutation = try verifiedMutation(fixture.mutationInput, graph: graph)
    let record = try ArtifactInvalidator().invalidate(mutation: mutation, in: graph)
    return (graph, mutation, record)
}

private func invalidationTypeIsDecodable(_ type: Any.Type) -> Bool {
    type is any Decodable.Type
}

private func invalidationSourceSlice(
    filename: String,
    from startMarker: String,
    until endMarker: String?
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
    let end: String.Index
    if let endMarker {
        end = try #require(
            source.range(of: endMarker, range: start ..< source.endIndex)?.lowerBound
        )
    } else {
        end = source.endIndex
    }
    return source[start ..< end]
}

private func mutateCanonicalRecord(
    _ data: Data,
    mutation: (inout [String: Any]) -> Void
) throws -> Data {
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    mutation(&object)
    return try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

private func graphWithUnrelatedArtifactDrift(_ graph: ArtifactGraph) throws -> ArtifactGraph {
    let driftedArtifacts = try graph.artifacts.map { artifact in
        guard artifact.id == invalidationUnrelatedID else { return artifact }
        return try ArtifactReference(
            id: artifact.id,
            type: artifact.type,
            scope: artifact.scope,
            contentHash: CanonicalTreeDigest.sha256(Data("artifact-unrelated/v2".utf8))
        )
    }
    let driftedRoots = try graph.independentRoots.map { root in
        guard root.artifactID == invalidationUnrelatedID else { return root }
        return try ArtifactIndependentRoot(
            artifactID: root.artifactID,
            artifactHash: CanonicalTreeDigest.sha256(Data("artifact-unrelated/v2".utf8))
        )
    }
    let authority = try VerifiedArtifactTraceAuthority.testing(
        policyID: graph.tracePolicyID,
        policyDigest: graph.tracePolicyDigest,
        requiredObligations: graph.dependencyObligations,
        permittedIndependentRoots: driftedRoots
    )
    return try ArtifactGraph(
        artifacts: driftedArtifacts,
        dependencies: graph.dependencies,
        dependencyObligations: graph.dependencyObligations,
        independentRoots: driftedRoots,
        authority: authority
    )
}

private func invalidationFixture(_ filename: String) throws -> InvalidationFixture {
    try CanonicalJSON.decode(
        InvalidationFixture.self,
        from: invalidationFixtureData(filename)
    )
}

private func invalidationFixtureData(_ filename: String) throws -> Data {
    var root = URL(fileURLWithPath: #filePath)
    while root.lastPathComponent != "ifl-ios-standards", root.path != "/" {
        root.deleteLastPathComponent()
    }
    return try Data(
        contentsOf: root
            .appendingPathComponent("verification/fixtures/workflow/invalidation")
            .appendingPathComponent(filename)
    )
}

private func rejectUnknownFixtureFields(
    _ decoder: any Decoder,
    allowed: [String]
) throws {
    let container = try decoder.container(keyedBy: InvalidationFixtureCodingKey.self)
    let allowedSet = Set(allowed)
    let unknown = container.allKeys.map(\.stringValue)
        .filter { !allowedSet.contains($0) }
        .sorted()
    guard unknown.isEmpty else {
        throw fixtureDecodingError(decoder, "Unexpected fixture keys: \(unknown)")
    }
}

private func fixtureDecodingError(
    _ decoder: any Decoder,
    _ description: String
) -> DecodingError {
    DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: description)
    )
}
