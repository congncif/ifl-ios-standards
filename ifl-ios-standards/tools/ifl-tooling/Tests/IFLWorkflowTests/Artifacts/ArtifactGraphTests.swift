import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("ArtifactGraphTests")
struct ArtifactGraphTests {
    @Test("artifact type, scope kind, and dependency relation are exact closed wire enums")
    func exactClosedWireValues() throws {
        let artifactTypes: [(ArtifactType, String)] = [
            (.requirement, "requirement"),
            (.design, "design"),
            (.architecture, "architecture"),
            (.plan, "plan"),
            (.source, "source"),
            (.commandEvidence, "command_evidence"),
            (.canon, "canon"),
        ]
        let scopeKinds: [(ArtifactScopeKind, String)] = [
            (.path, "path"),
            (.semanticSelector, "semantic_selector"),
        ]
        let relations: [(ArtifactRelation, String)] = [
            (.derives, "derives"),
            (.implements, "implements"),
            (.validates, "validates"),
            (.packages, "packages"),
        ]

        #expect(ArtifactType.allCases == artifactTypes.map(\.0))
        #expect(ArtifactScopeKind.allCases == scopeKinds.map(\.0))
        #expect(ArtifactRelation.allCases == relations.map(\.0))

        for (value, wire) in artifactTypes {
            try expectExactWire(value, wire: wire, as: ArtifactType.self)
        }
        for (value, wire) in scopeKinds {
            try expectExactWire(value, wire: wire, as: ArtifactScopeKind.self)
        }
        for (value, wire) in relations {
            try expectExactWire(value, wire: wire, as: ArtifactRelation.self)
        }
    }

    @Test("artifact identity and scope reject empty, noncanonical, and unsupported values")
    func identityAndScopeValidation() throws {
        for invalid in ["", " artifact", "artifact ", "artifact\nidentity", "artifact\0identity"] {
            #expect(throws: (any Error).self) {
                try ArtifactID(validating: invalid)
            }
        }

        for invalid in ["", " workflow", "workflow ", "workflow\nselector"] {
            #expect(throws: (any Error).self) {
                try ArtifactScope(kind: .semanticSelector, value: invalid)
            }
        }

        for invalid in ["", "/absolute", "a//b", ".", "..", "a/../b", "a\\b"] {
            #expect(throws: (any Error).self) {
                try ArtifactScope(kind: .path, value: invalid)
            }
        }

        #expect(
            try ArtifactScope(kind: .path, value: "Sources/Feature/File.swift").value
                == "Sources/Feature/File.swift"
        )
    }

    @Test("path and semantic scopes intersect only at complete canonical component boundaries")
    func closedComponentAwareScopeIntersection() throws {
        let pathParent = try ArtifactScope(kind: .path, value: "Sources/Feature")
        let pathChild = try ArtifactScope(kind: .path, value: "Sources/Feature/File.swift")
        let pathSibling = try ArtifactScope(kind: .path, value: "Sources/Other")
        let pathPrefixConfusion = try ArtifactScope(kind: .path, value: "Sources/FeatureFlags")

        #expect(pathParent.intersects(pathParent))
        #expect(pathParent.intersects(pathChild))
        #expect(pathChild.intersects(pathParent))
        #expect(!pathParent.intersects(pathSibling))
        #expect(!pathParent.intersects(pathPrefixConfusion))

        let semanticParent = try ArtifactScope(kind: .semanticSelector, value: "workflow")
        let semanticChild = try ArtifactScope(
            kind: .semanticSelector,
            value: "workflow.requirements"
        )
        let semanticSibling = try ArtifactScope(kind: .semanticSelector, value: "runtime")
        let semanticPrefixConfusion = try ArtifactScope(
            kind: .semanticSelector,
            value: "workflow-requirements"
        )

        #expect(semanticParent.intersects(semanticParent))
        #expect(semanticParent.intersects(semanticChild))
        #expect(semanticChild.intersects(semanticParent))
        #expect(!semanticParent.intersects(semanticSibling))
        #expect(!semanticChild.intersects(semanticPrefixConfusion))
        #expect(!semanticParent.intersects(pathParent))
    }

    @Test("every dependency scope must intersect both endpoint scopes")
    func dependencyScopeMustIntersectBothEndpoints() throws {
        let upstream = try ArtifactReference(
            id: ArtifactID(validating: "artifact-source"),
            type: .source,
            scope: ArtifactScope(kind: .path, value: "Sources/Feature"),
            contentHash: graphDigest("1")
        )
        let downstream = try ArtifactReference(
            id: ArtifactID(validating: "artifact-command-evidence"),
            type: .commandEvidence,
            scope: ArtifactScope(kind: .path, value: "Sources"),
            contentHash: graphDigest("c")
        )
        let valid = try ArtifactDependency(
            upstreamArtifactID: upstream.id,
            upstreamHash: upstream.contentHash,
            downstreamArtifactID: downstream.id,
            downstreamHash: downstream.contentHash,
            relation: .validates,
            affectedScope: ArtifactScope(kind: .path, value: "Sources/Feature/Models"),
            requirementIDs: [graphRequirementID],
            ruleIDs: [graphRuleID]
        )
        _ = try completeGraph(artifacts: [upstream, downstream], dependencies: [valid])

        let impossibleScopes = try [
            ArtifactScope(kind: .path, value: "Sources/FeatureFlags"),
            ArtifactScope(kind: .semanticSelector, value: "workflow"),
        ]
        for impossibleScope in impossibleScopes {
            let impossible = try ArtifactDependency(
                upstreamArtifactID: upstream.id,
                upstreamHash: upstream.contentHash,
                downstreamArtifactID: downstream.id,
                downstreamHash: downstream.contentHash,
                relation: .validates,
                affectedScope: impossibleScope,
                requirementIDs: [graphRequirementID],
                ruleIDs: [graphRuleID]
            )
            #expect(throws: (any Error).self) {
                try completeGraph(
                    artifacts: [upstream, downstream],
                    dependencies: [impossible]
                )
            }
        }
    }

    @Test("ArtifactReference v1 strictly decodes and canonically round-trips exact identity bytes")
    func artifactReferenceStrictCanonicalRoundTrip() throws {
        let reference = try graphArtifact(.requirement, hash: "f")
        let expected = #"{"artifact_id":"artifact-requirement","artifact_type":"requirement","content_hash":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","schema_version":1,"scope":{"kind":"semantic_selector","schema_version":1,"value":"workflow"}}"#

        let encoded = try CanonicalJSON.encode(reference)
        #expect(String(decoding: encoded, as: UTF8.self) == expected)
        #expect(try CanonicalJSON.decode(ArtifactReference.self, from: encoded) == reference)
        #expect(try CanonicalJSON.encode(CanonicalJSON.decode(ArtifactReference.self, from: encoded)) == encoded)

        let validObject = try jsonObject(reference)
        var mutations: [[String: Any]] = []

        var unknown = validObject
        unknown["unknown"] = true
        mutations.append(unknown)

        var unsupportedSchema = validObject
        unsupportedSchema["schema_version"] = 2
        mutations.append(unsupportedSchema)

        var unsupportedType = validObject
        unsupportedType["artifact_type"] = "binary"
        mutations.append(unsupportedType)

        var invalidHash = validObject
        invalidHash["content_hash"] = String(repeating: "F", count: 64)
        mutations.append(invalidHash)

        var missingIdentity = validObject
        missingIdentity.removeValue(forKey: "artifact_id")
        mutations.append(missingIdentity)

        var scopeUnknown = validObject
        var scope = try #require(scopeUnknown["scope"] as? [String: Any])
        scope["unknown"] = true
        scopeUnknown["scope"] = scope
        mutations.append(scopeUnknown)

        var scopeUnsupportedSchema = validObject
        scope = try #require(scopeUnsupportedSchema["scope"] as? [String: Any])
        scope["schema_version"] = 2
        scopeUnsupportedSchema["scope"] = scope
        mutations.append(scopeUnsupportedSchema)

        for mutation in mutations {
            #expect(throws: (any Error).self) {
                try decode(ArtifactReference.self, object: mutation)
            }
        }
    }

    @Test("one adversarial lexical corpus has exact Swift and normative artifact-schema parity")
    func artifactLexicalCorpusParity() throws {
        let definitions = try artifactLexicalSchemaDefinitions()

        for (kind, definition) in definitions {
            #expect(!definition.pattern.contains("$"), "\(kind) uses a soft end anchor")
            #expect(
                definition.pattern.hasSuffix(#"(?![\s\S])"#),
                "\(kind) does not assert hard end-of-input"
            )
            if kind == .path {
                #expect(definition.format == "ifl-canonical-relative-path-v1")
                #expect(definition.assertsFormat)
            }
        }

        for testCase in artifactLexicalCorpus {
            let swiftAccepted = artifactSwiftAccepts(testCase.value, as: testCase.kind)
            let schemaAccepted = try artifactSchemaAccepts(
                testCase.value,
                definition: #require(definitions[testCase.kind])
            )
            #expect(swiftAccepted == testCase.accepted, "Swift mismatch for \(testCase)")
            #expect(schemaAccepted == testCase.accepted, "schema mismatch for \(testCase)")
            #expect(swiftAccepted == schemaAccepted, "parity mismatch for \(testCase)")
        }
    }

    @Test("every relation requires exact nonempty duplicate-free requirement and rule traces")
    func dependencyTraceabilityIsRequiredForEveryRelation() throws {
        for relation in ArtifactRelation.allCases {
            #expect(throws: (any Error).self) {
                try graphDependency(
                    from: .requirement,
                    to: .design,
                    relation: relation,
                    requirementIDs: []
                )
            }
            #expect(throws: (any Error).self) {
                try graphDependency(
                    from: .requirement,
                    to: .design,
                    relation: relation,
                    ruleIDs: []
                )
            }
            #expect(throws: (any Error).self) {
                try graphDependency(
                    from: .requirement,
                    to: .design,
                    relation: relation,
                    requirementIDs: [graphRequirementID, graphRequirementID]
                )
            }
            #expect(throws: (any Error).self) {
                try graphDependency(
                    from: .requirement,
                    to: .design,
                    relation: relation,
                    ruleIDs: [graphRuleID, graphRuleID]
                )
            }
        }
    }

    @Test("ArtifactDependency v1 sorts traceability and rejects unknown fields, schemas, and relations")
    func dependencyStrictCanonicalRoundTrip() throws {
        let secondRequirement = try RequirementID(validating: "REQ-WORKFLOW-002")
        let secondRule = try RuleID(validating: "IFL-WORKFLOW-002")
        let dependency = try graphDependency(
            from: .requirement,
            to: .design,
            relation: .derives,
            requirementIDs: [secondRequirement, graphRequirementID],
            ruleIDs: [secondRule, graphRuleID]
        )
        #expect(dependency.requirementIDs.map(\.rawValue) == ["REQ-WORKFLOW-001", "REQ-WORKFLOW-002"])
        #expect(dependency.ruleIDs.map(\.rawValue) == ["IFL-WORKFLOW-001", "IFL-WORKFLOW-002"])

        let encoded = try CanonicalJSON.encode(dependency)
        let decoded = try CanonicalJSON.decode(ArtifactDependency.self, from: encoded)
        #expect(decoded == dependency)
        #expect(try CanonicalJSON.encode(decoded) == encoded)

        let validObject = try jsonObject(dependency)
        var unknown = validObject
        unknown["unknown"] = true
        var unsupportedSchema = validObject
        unsupportedSchema["schema_version"] = 2
        var unsupportedRelation = validObject
        unsupportedRelation["relation"] = "includes"
        var missingEndpoint = validObject
        missingEndpoint.removeValue(forKey: "upstream_artifact_id")

        for mutation in [unknown, unsupportedSchema, unsupportedRelation, missingEndpoint] {
            #expect(throws: (any Error).self) {
                try decode(ArtifactDependency.self, object: mutation)
            }
        }
    }

    @Test("graph rejects duplicate artifact identities and duplicate semantic edges with changed bytes")
    func duplicateIdentityAndSemanticEdgeRejection() throws {
        let requirement = try graphArtifact(.requirement, hash: "f")
        let design = try graphArtifact(.design, hash: "d")
        let edge = try graphDependency(from: .requirement, to: .design, relation: .derives)

        #expect(throws: (any Error).self) {
            try completeGraph(artifacts: [requirement, requirement], dependencies: [])
        }
        #expect(throws: (any Error).self) {
            try completeGraph(
                artifacts: [requirement, graphArtifact(.requirement, hash: "9")],
                dependencies: []
            )
        }
        #expect(throws: (any Error).self) {
            try completeGraph(artifacts: [requirement, design], dependencies: [edge, edge])
        }

        let changedBytes = try graphDependency(
            from: .requirement,
            to: .design,
            relation: .derives,
            requirementIDs: [RequirementID(validating: "REQ-WORKFLOW-002")]
        )
        #expect(throws: (any Error).self) {
            try completeGraph(
                artifacts: [requirement, design],
                dependencies: [edge, changedBytes]
            )
        }
    }

    @Test("graph rejects unknown artifacts and stale stored endpoint hashes")
    func endpointIntegrity() throws {
        let requirement = try graphArtifact(.requirement, hash: "f")
        let design = try graphArtifact(.design, hash: "d")

        let unknownEndpoint = try ArtifactDependency(
            upstreamArtifactID: requirement.id,
            upstreamHash: requirement.contentHash,
            downstreamArtifactID: ArtifactID(validating: "artifact-unknown"),
            downstreamHash: graphDigest("9"),
            relation: .derives,
            affectedScope: graphScope,
            requirementIDs: [graphRequirementID],
            ruleIDs: [graphRuleID]
        )
        #expect(throws: (any Error).self) {
            try completeGraph(artifacts: [requirement, design], dependencies: [unknownEndpoint])
        }

        for stale in try [
            ArtifactDependency(
                upstreamArtifactID: requirement.id,
                upstreamHash: graphDigest("9"),
                downstreamArtifactID: design.id,
                downstreamHash: design.contentHash,
                relation: .derives,
                affectedScope: graphScope,
                requirementIDs: [graphRequirementID],
                ruleIDs: [graphRuleID]
            ),
            ArtifactDependency(
                upstreamArtifactID: requirement.id,
                upstreamHash: requirement.contentHash,
                downstreamArtifactID: design.id,
                downstreamHash: graphDigest("9"),
                relation: .derives,
                affectedScope: graphScope,
                requirementIDs: [graphRequirementID],
                ruleIDs: [graphRuleID]
            ),
        ] {
            #expect(throws: (any Error).self) {
                try completeGraph(artifacts: [requirement, design], dependencies: [stale])
            }
        }
    }

    @Test("dependency obligations and independent roots form an exact hash-bound graph partition")
    func dependencyObligationAndRootCompleteness() throws {
        let requirement = try graphArtifact(.requirement, hash: "f")
        let design = try graphArtifact(.design, hash: "d")
        let edge = try graphDependency(from: .requirement, to: .design, relation: .derives)
        let obligation = try graphObligation(edge)
        let requirementRoot = try graphIndependentRoot(requirement)
        let authority = try graphTraceAuthority(
            requiredObligations: [obligation],
            permittedIndependentRoots: [requirementRoot]
        )

        let complete = try ArtifactGraph(
            artifacts: [design, requirement],
            dependencies: [edge],
            dependencyObligations: [obligation],
            independentRoots: [requirementRoot],
            authority: authority
        )
        #expect(complete.dependencyObligations == [obligation])
        #expect(complete.independentRoots == [requirementRoot])
        #expect(complete.tracePolicyID == graphTracePolicyID)
        #expect(complete.tracePolicyDigest == graphTracePolicyDigest)

        #expect(throws: (any Error).self) {
            try ArtifactGraph(
                artifacts: [requirement, design],
                dependencies: [edge],
                dependencyObligations: [],
                independentRoots: [requirementRoot],
                authority: authority
            )
        }
        #expect(throws: (any Error).self) {
            try ArtifactGraph(
                artifacts: [requirement, design],
                dependencies: [],
                dependencyObligations: [obligation],
                independentRoots: [requirementRoot],
                authority: authority
            )
        }

        let changedObligation = try ArtifactDependencyObligation(
            upstreamArtifactID: edge.upstreamArtifactID,
            upstreamHash: edge.upstreamHash,
            downstreamArtifactID: edge.downstreamArtifactID,
            downstreamHash: edge.downstreamHash,
            relation: edge.relation,
            affectedScope: edge.affectedScope,
            requirementIDs: [RequirementID(validating: "REQ-WORKFLOW-002")],
            ruleIDs: edge.ruleIDs
        )
        #expect(throws: (any Error).self) {
            try ArtifactGraph(
                artifacts: [requirement, design],
                dependencies: [edge],
                dependencyObligations: [changedObligation],
                independentRoots: [requirementRoot],
                authority: authority
            )
        }

        #expect(throws: (any Error).self) {
            try ArtifactGraph(
                artifacts: [requirement, design],
                dependencies: [],
                dependencyObligations: [],
                independentRoots: [requirementRoot],
                authority: authority
            )
        }
        let designRoot = try graphIndependentRoot(design)
        #expect(throws: (any Error).self) {
            try ArtifactGraph(
                artifacts: [requirement, design],
                dependencies: [],
                dependencyObligations: [],
                independentRoots: [designRoot, requirementRoot],
                authority: authority
            )
        }
        #expect(throws: (any Error).self) {
            try ArtifactGraph(
                artifacts: [requirement, design],
                dependencies: [edge],
                dependencyObligations: [obligation],
                independentRoots: [requirementRoot, designRoot],
                authority: authority
            )
        }

        let invalidRoots = try [
            ArtifactIndependentRoot(
                artifactID: ArtifactID(validating: "artifact-unknown"),
                artifactHash: graphDigest("9")
            ),
            ArtifactIndependentRoot(
                artifactID: requirement.id,
                artifactHash: graphDigest("9")
            ),
        ]
        for invalidRoot in invalidRoots {
            #expect(throws: (any Error).self) {
                try ArtifactGraph(
                    artifacts: [requirement, design],
                    dependencies: [edge],
                    dependencyObligations: [obligation],
                    independentRoots: [invalidRoot],
                    authority: authority
                )
            }
        }

        #expect(throws: (any Error).self) {
            try ArtifactGraph(
                artifacts: [requirement, design],
                dependencies: [edge],
                dependencyObligations: [obligation, obligation],
                independentRoots: [requirementRoot],
                authority: authority
            )
        }
        #expect(throws: (any Error).self) {
            try ArtifactGraph(
                artifacts: [requirement, design],
                dependencies: [edge],
                dependencyObligations: [obligation],
                independentRoots: [requirementRoot, requirementRoot],
                authority: authority
            )
        }
    }

    @Test("sealed trace authority is required for construction and canonical decode")
    func sealedTraceAuthorityRequiredAtEveryIngress() throws {
        let requirement = try graphArtifact(.requirement, hash: "f")
        let design = try graphArtifact(.design, hash: "d")
        let edge = try graphDependency(from: .requirement, to: .design, relation: .derives)
        let obligation = try graphObligation(edge)
        let requirementRoot = try graphIndependentRoot(requirement)
        let designRoot = try graphIndependentRoot(design)
        let authority = try graphTraceAuthority(
            requiredObligations: [obligation],
            permittedIndependentRoots: [requirementRoot]
        )

        #expect(throws: (any Error).self) {
            try VerifiedArtifactTraceAuthority.testing(
                policyID: "",
                policyDigest: graphTracePolicyDigest,
                requiredObligations: [obligation],
                permittedIndependentRoots: [requirementRoot]
            )
        }

        let graph = try ArtifactGraph(
            artifacts: [requirement, design],
            dependencies: [edge],
            dependencyObligations: [obligation],
            independentRoots: [requirementRoot],
            authority: authority
        )
        let encoded = try CanonicalJSON.encode(graph)
        let graphObject = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        #expect(graphObject["trace_policy_id"] as? String == graphTracePolicyID)
        #expect(graphObject["trace_policy_digest"] as? String == graphTracePolicyDigest.rawValue)
        #expect(graphObject["trace_authority"] == nil)
        #expect(!(VerifiedArtifactTraceAuthority.self is any Decodable.Type))
        #expect(!(ArtifactGraph.self is any Decodable.Type))

        let decoded = try ArtifactGraph.decodeCanonical(from: encoded, authority: authority)
        #expect(decoded == graph)
        #expect(try CanonicalJSON.encode(decoded) == encoded)

        #expect(throws: (any Error).self) {
            try ArtifactGraph.decodeCanonical(from: encoded, authority: nil)
        }

        let mismatchedPolicyID = try graphTraceAuthority(
            policyID: "other-trace-policy-v1",
            requiredObligations: [obligation],
            permittedIndependentRoots: [requirementRoot]
        )
        let mismatchedPolicyDigest = try graphTraceAuthority(
            policyDigest: graphDigest("8"),
            requiredObligations: [obligation],
            permittedIndependentRoots: [requirementRoot]
        )
        for mismatchedAuthority in [mismatchedPolicyID, mismatchedPolicyDigest] {
            #expect(throws: (any Error).self) {
                try ArtifactGraph.decodeCanonical(
                    from: encoded,
                    authority: mismatchedAuthority
                )
            }
        }

        let selfPromotedRootAuthority = try graphTraceAuthority(
            requiredObligations: [],
            permittedIndependentRoots: [requirementRoot, designRoot]
        )
        #expect(throws: (any Error).self) {
            try ArtifactGraph(
                artifacts: [requirement, design],
                dependencies: [edge],
                dependencyObligations: [obligation],
                independentRoots: [requirementRoot],
                authority: selfPromotedRootAuthority
            )
        }

        var injectedAuthority = graphObject
        injectedAuthority["trace_authority"] = [
            "policy_id": graphTracePolicyID,
            "policy_digest": graphTracePolicyDigest.rawValue,
        ]
        let injectedBytes = try JSONSerialization.data(
            withJSONObject: injectedAuthority,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        #expect(throws: (any Error).self) {
            try ArtifactGraph.decodeCanonical(from: injectedBytes, authority: authority)
        }
    }

    @Test("graph rejects self edges and every direct or indirect cycle")
    func cycleRejection() throws {
        let requirement = try graphArtifact(.requirement, hash: "f")
        let design = try graphArtifact(.design, hash: "d")
        let architecture = try graphArtifact(.architecture, hash: "a")

        #expect(throws: (any Error).self) {
            try ArtifactDependency(
                upstreamArtifactID: requirement.id,
                upstreamHash: requirement.contentHash,
                downstreamArtifactID: requirement.id,
                downstreamHash: requirement.contentHash,
                relation: .derives,
                affectedScope: graphScope,
                requirementIDs: [graphRequirementID],
                ruleIDs: [graphRuleID]
            )
        }

        let requirementToDesign = try graphDependency(from: .requirement, to: .design, relation: .derives)
        let designToRequirement = try graphDependency(from: .design, to: .requirement, relation: .derives)
        #expect(throws: (any Error).self) {
            try completeGraph(
                artifacts: [requirement, design],
                dependencies: [requirementToDesign, designToRequirement]
            )
        }

        let designToArchitecture = try graphDependency(from: .design, to: .architecture, relation: .derives)
        let architectureToRequirement = try graphDependency(from: .architecture, to: .requirement, relation: .validates)
        #expect(throws: (any Error).self) {
            try completeGraph(
                artifacts: [requirement, design, architecture],
                dependencies: [requirementToDesign, designToArchitecture, architectureToRequirement]
            )
        }
    }

    @Test("graph construction and canonical encoding are independent of artifact and edge input order")
    func orderIndependentConstructionAndEncoding() throws {
        let artifacts = try graphChainArtifacts()
        let dependencies = try graphChainDependencies()
        let first = try completeGraph(artifacts: artifacts, dependencies: dependencies)
        let second = try completeGraph(
            artifacts: Array(artifacts.reversed()),
            dependencies: [dependencies[3], dependencies[0], dependencies[4], dependencies[1], dependencies[2]]
        )

        #expect(first == second)
        #expect(first.artifacts.map(\.id.rawValue) == [
            "artifact-architecture",
            "artifact-command-evidence",
            "artifact-design",
            "artifact-plan",
            "artifact-requirement",
            "artifact-source",
        ])
        #expect(first.dependencyObligations.map(\.downstreamArtifactID.rawValue) == [
            "artifact-plan",
            "artifact-architecture",
            "artifact-source",
            "artifact-design",
            "artifact-command-evidence",
        ])
        #expect(first.independentRoots.map(\.artifactID.rawValue) == ["artifact-requirement"])
        #expect(try CanonicalJSON.encode(first) == CanonicalJSON.encode(second))

        let encoded = try CanonicalJSON.encode(first)
        let authority = try graphTraceAuthority(
            requiredObligations: first.dependencyObligations,
            permittedIndependentRoots: first.independentRoots
        )
        let decoded = try ArtifactGraph.decodeCanonical(from: encoded, authority: authority)
        #expect(decoded == first)
        #expect(try CanonicalJSON.encode(decoded) == encoded)

        var unknown = try jsonObject(first)
        unknown["unknown"] = true
        let unknownBytes = try JSONSerialization.data(
            withJSONObject: unknown,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        #expect(throws: (any Error).self) {
            try ArtifactGraph.decodeCanonical(from: unknownBytes, authority: authority)
        }
    }

    @Test("artifact schema is a closed canonical Draft 2020-12 graph contract with exact v1 definitions")
    func artifactSchemaContract() throws {
        let data = try Data(contentsOf: artifactSchemaURL())
        #expect(data.last == 0x0A)
        #expect(!data.dropLast().contains(0x0A))
        #expect(!data.contains(0x0D))

        let schema = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var canonical = try JSONSerialization.data(
            withJSONObject: schema,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        canonical.append(0x0A)
        #expect(canonical == data)

        #expect(schema["$schema"] as? String == "https://json-schema.org/draft/2020-12/schema")
        #expect(schema["$id"] as? String == "urn:ifl:standards:schema:artifact:v1")
        #expect(schema["type"] as? String == "object")
        #expect(schema["additionalProperties"] as? Bool == false)

        let rootProperties = try schemaDictionary(schema["properties"])
        #expect(Set(rootProperties.keys) == [
            "artifacts", "dependencies", "dependency_obligations", "independent_roots",
            "schema_version", "trace_policy_digest", "trace_policy_id",
        ])
        #expect(try schemaStringSet(schema["required"]) == [
            "artifacts", "dependencies", "dependency_obligations", "independent_roots",
            "schema_version", "trace_policy_digest", "trace_policy_id",
        ])
        #expect(try schemaDictionary(rootProperties["schema_version"])["const"] as? Int == 1)
        #expect(
            try schemaDictionary(rootProperties["trace_policy_id"])["$ref"] as? String
                == "#/$defs/trace_policy_id"
        )
        #expect(
            try schemaDictionary(rootProperties["trace_policy_digest"])["$ref"] as? String
                == "#/$defs/digest"
        )

        let artifacts = try schemaDictionary(rootProperties["artifacts"])
        let dependencies = try schemaDictionary(rootProperties["dependencies"])
        let obligations = try schemaDictionary(rootProperties["dependency_obligations"])
        let independentRoots = try schemaDictionary(rootProperties["independent_roots"])
        #expect(artifacts["type"] as? String == "array")
        #expect(artifacts["uniqueItems"] as? Bool == true)
        #expect(try schemaDictionary(artifacts["items"])["$ref"] as? String == "#/$defs/artifact")
        #expect(dependencies["type"] as? String == "array")
        #expect(dependencies["uniqueItems"] as? Bool == true)
        #expect(try schemaDictionary(dependencies["items"])["$ref"] as? String == "#/$defs/dependency")
        #expect(obligations["type"] as? String == "array")
        #expect(obligations["uniqueItems"] as? Bool == true)
        #expect(
            try schemaDictionary(obligations["items"])["$ref"] as? String
                == "#/$defs/dependency_obligation"
        )
        #expect(independentRoots["type"] as? String == "array")
        #expect(independentRoots["uniqueItems"] as? Bool == true)
        #expect(
            try schemaDictionary(independentRoots["items"])["$ref"] as? String
                == "#/$defs/independent_root"
        )

        let definitions = try schemaDictionary(schema["$defs"])
        #expect(Set(definitions.keys) == [
            "artifact", "artifact_id", "artifact_scope", "artifact_type",
            "canonical_relative_path", "dependency", "dependency_obligation", "digest",
            "independent_root", "invalidation_provenance", "invalidation_record", "relation",
            "requirement_id", "rule_id", "semantic_selector", "trace_policy_id",
        ])

        let artifact = try schemaDictionary(definitions["artifact"])
        #expect(artifact["additionalProperties"] as? Bool == false)
        #expect(try schemaStringSet(artifact["required"]) == [
            "artifact_id", "artifact_type", "content_hash", "schema_version", "scope",
        ])
        let artifactProperties = try schemaDictionary(artifact["properties"])
        #expect(Set(artifactProperties.keys) == [
            "artifact_id", "artifact_type", "content_hash", "schema_version", "scope",
        ])

        let scope = try schemaDictionary(definitions["artifact_scope"])
        #expect(scope["additionalProperties"] as? Bool == false)
        #expect(try schemaStringSet(scope["required"]) == ["kind", "schema_version", "value"])
        let scopeProperties = try schemaDictionary(scope["properties"])
        #expect(try schemaStringSet(schemaDictionary(scopeProperties["kind"])["enum"]) == [
            "path", "semantic_selector",
        ])
        #expect(try schemaDictionary(scopeProperties["schema_version"])["const"] as? Int == 1)
        let scopeBranches = try #require(scope["oneOf"] as? [[String: Any]])
        #expect(scopeBranches.count == 2)
        let scopeBindings = try Dictionary(uniqueKeysWithValues: scopeBranches.map { branch in
            let properties = try schemaDictionary(branch["properties"])
            let kind = try #require(schemaDictionary(properties["kind"])["const"] as? String)
            let reference = try #require(schemaDictionary(properties["value"])["$ref"] as? String)
            return (kind, reference)
        })
        #expect(scopeBindings == [
            "path": "#/$defs/canonical_relative_path",
            "semantic_selector": "#/$defs/semantic_selector",
        ])

        let dependency = try schemaDictionary(definitions["dependency"])
        #expect(dependency["additionalProperties"] as? Bool == false)
        #expect(try schemaStringSet(dependency["required"]) == [
            "affected_scope", "downstream_artifact_id", "downstream_hash", "relation",
            "requirement_ids", "rule_ids", "schema_version", "upstream_artifact_id",
            "upstream_hash",
        ])
        let dependencyProperties = try schemaDictionary(dependency["properties"])
        #expect(Set(dependencyProperties.keys) == [
            "affected_scope", "downstream_artifact_id", "downstream_hash", "relation",
            "requirement_ids", "rule_ids", "schema_version", "upstream_artifact_id",
            "upstream_hash",
        ])
        for traceKey in ["requirement_ids", "rule_ids"] {
            let trace = try schemaDictionary(dependencyProperties[traceKey])
            #expect(trace["type"] as? String == "array")
            #expect(trace["minItems"] as? Int == 1)
            #expect(trace["uniqueItems"] as? Bool == true)
        }

        let obligation = try schemaDictionary(definitions["dependency_obligation"])
        #expect(obligation["additionalProperties"] as? Bool == false)
        let dependencyRequired = try schemaStringSet(dependency["required"])
        #expect(try schemaStringSet(obligation["required"]) == dependencyRequired)
        let obligationProperties = try schemaDictionary(obligation["properties"])
        #expect(Set(obligationProperties.keys) == Set(dependencyProperties.keys))

        let independentRoot = try schemaDictionary(definitions["independent_root"])
        #expect(independentRoot["additionalProperties"] as? Bool == false)
        #expect(try schemaStringSet(independentRoot["required"]) == [
            "artifact_hash", "artifact_id", "schema_version",
        ])
        let independentRootProperties = try schemaDictionary(independentRoot["properties"])
        #expect(Set(independentRootProperties.keys) == [
            "artifact_hash", "artifact_id", "schema_version",
        ])

        let record = try schemaDictionary(definitions["invalidation_record"])
        #expect(record["additionalProperties"] as? Bool == false)
        let recordFields: Set = [
            "changed_artifact_id", "current_hash", "graph_digest",
            "mutation_digest", "provenance", "schema_version", "section_manifest_digest",
            "scope_digest", "stale_artifact_ids", "stored_hash", "verifier_id",
        ]
        #expect(try schemaStringSet(record["required"]) == recordFields)
        let recordProperties = try schemaDictionary(record["properties"])
        #expect(Set(recordProperties.keys) == recordFields)
        #expect(
            try schemaStringSet(schemaDictionary(definitions["invalidation_provenance"])["enum"])
                == ["verified_artifact_mutation"]
        )

        #expect(try schemaStringSet(schemaDictionary(definitions["artifact_type"])["enum"]) == [
            "architecture", "canon", "command_evidence", "design", "plan", "requirement", "source",
        ])
        #expect(try schemaStringSet(schemaDictionary(definitions["relation"])["enum"]) == [
            "derives", "implements", "packages", "validates",
        ])
        #expect(
            try schemaDictionary(definitions["digest"])["pattern"] as? String
                == #"^[0-9a-f]{64}(?![\s\S])"#
        )
        #expect(
            try schemaDictionary(definitions["requirement_id"])["pattern"] as? String
                == #"^(?:(?:REQ|ENT)-[A-Z0-9]+(?:-[A-Z0-9]+)*|P[0-3]-[1-9][0-9]*)(?![\s\S])"#
        )
        #expect(
            try schemaDictionary(definitions["rule_id"])["pattern"] as? String
                == #"^[A-Z0-9]+(?:-[A-Z0-9]+)+-[0-9]{3}(?![\s\S])"#
        )
        #expect(
            try schemaDictionary(definitions["trace_policy_id"])["pattern"] as? String
                == #"^[a-z][a-z0-9]*(?:-[a-z0-9]+)*(?![\s\S])"#
        )
    }
}

private let graphRequirementID = try! RequirementID(validating: "REQ-WORKFLOW-001")
private let graphRuleID = try! RuleID(validating: "IFL-WORKFLOW-001")
private let graphScope = try! ArtifactScope(kind: .semanticSelector, value: "workflow")
private let graphTracePolicyID = "workflow-trace-policy-v1"
private let graphTracePolicyDigest = try! HashDigest(
    validating: String(repeating: "7", count: 64)
)

private func graphDigest(_ character: Character) throws -> HashDigest {
    try HashDigest(validating: String(repeating: String(character), count: 64))
}

private func graphArtifact(_ type: ArtifactType, hash: Character) throws -> ArtifactReference {
    try ArtifactReference(
        id: ArtifactID(validating: "artifact-\(type.rawValue.replacingOccurrences(of: "_", with: "-"))"),
        type: type,
        scope: graphScope,
        contentHash: graphDigest(hash)
    )
}

private func graphDependency(
    from upstreamType: ArtifactType,
    to downstreamType: ArtifactType,
    relation: ArtifactRelation,
    affectedScope: ArtifactScope = graphScope,
    requirementIDs: [RequirementID] = [graphRequirementID],
    ruleIDs: [RuleID] = [graphRuleID]
) throws -> ArtifactDependency {
    let hashes: [ArtifactType: Character] = [
        .architecture: "a",
        .canon: "b",
        .commandEvidence: "c",
        .design: "d",
        .plan: "e",
        .requirement: "f",
        .source: "1",
    ]
    return try ArtifactDependency(
        upstreamArtifactID: graphArtifact(upstreamType, hash: hashes[upstreamType]!).id,
        upstreamHash: graphDigest(hashes[upstreamType]!),
        downstreamArtifactID: graphArtifact(downstreamType, hash: hashes[downstreamType]!).id,
        downstreamHash: graphDigest(hashes[downstreamType]!),
        relation: relation,
        affectedScope: affectedScope,
        requirementIDs: requirementIDs,
        ruleIDs: ruleIDs
    )
}

private func graphChainArtifacts() throws -> [ArtifactReference] {
    try [
        graphArtifact(.requirement, hash: "f"),
        graphArtifact(.design, hash: "d"),
        graphArtifact(.architecture, hash: "a"),
        graphArtifact(.plan, hash: "e"),
        graphArtifact(.source, hash: "1"),
        graphArtifact(.commandEvidence, hash: "c"),
    ]
}

private func graphChainDependencies() throws -> [ArtifactDependency] {
    try [
        graphDependency(from: .requirement, to: .design, relation: .derives),
        graphDependency(from: .design, to: .architecture, relation: .derives),
        graphDependency(from: .architecture, to: .plan, relation: .derives),
        graphDependency(from: .plan, to: .source, relation: .implements),
        graphDependency(from: .source, to: .commandEvidence, relation: .validates),
    ]
}

private func graphObligation(
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

private func graphIndependentRoot(
    _ artifact: ArtifactReference
) throws -> ArtifactIndependentRoot {
    try ArtifactIndependentRoot(
        artifactID: artifact.id,
        artifactHash: artifact.contentHash
    )
}

private func graphTraceAuthority(
    policyID: String = graphTracePolicyID,
    policyDigest: HashDigest = graphTracePolicyDigest,
    requiredObligations: [ArtifactDependencyObligation],
    permittedIndependentRoots: [ArtifactIndependentRoot]
) throws -> VerifiedArtifactTraceAuthority {
    try VerifiedArtifactTraceAuthority.testing(
        policyID: policyID,
        policyDigest: policyDigest,
        requiredObligations: requiredObligations,
        permittedIndependentRoots: permittedIndependentRoots
    )
}

private func completeGraph(
    artifacts: [ArtifactReference],
    dependencies: [ArtifactDependency]
) throws -> ArtifactGraph {
    let downstreamIDs = Set(dependencies.map(\.downstreamArtifactID))
    let obligations = try dependencies.map(graphObligation)
    let roots = try artifacts
        .filter { !downstreamIDs.contains($0.id) }
        .map(graphIndependentRoot)
    let authority = try graphTraceAuthority(
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

private func expectExactWire<Value: RawRepresentable & Codable & Equatable>(
    _ value: Value,
    wire: String,
    as type: Value.Type
) throws where Value.RawValue == String {
    let encoded = try CanonicalJSON.encode(value)
    #expect(String(decoding: encoded, as: UTF8.self) == "\"\(wire)\"")
    #expect(try CanonicalJSON.decode(type, from: encoded) == value)
    #expect(throws: (any Error).self) {
        try CanonicalJSON.decode(type, from: Data("\"\(wire.uppercased())-UNKNOWN\"".utf8))
    }
}

private func jsonObject(_ value: some Encodable) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: CanonicalJSON.encode(value)) as? [String: Any])
}

private func decode<Value: Decodable>(
    _ type: Value.Type,
    object: [String: Any]
) throws -> Value {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    return try CanonicalJSON.decode(type, from: data)
}

private func artifactSchemaURL() -> URL {
    var root = URL(fileURLWithPath: #filePath)
    while root.lastPathComponent != "ifl-ios-standards", root.path != "/" {
        root.deleteLastPathComponent()
    }
    return root.appendingPathComponent("standards/canon/schemas/v1/artifact.schema.json")
}

private func schemaDictionary(_ value: Any?) throws -> [String: Any] {
    try #require(value as? [String: Any])
}

private func schemaStringSet(_ value: Any?) throws -> Set<String> {
    try Set(#require(value as? [String]))
}

private enum ArtifactLexicalKind: String, CaseIterable, CustomStringConvertible, Hashable {
    case artifactID = "artifact_id"
    case path = "canonical_relative_path"
    case semanticSelector = "semantic_selector"

    var description: String {
        rawValue
    }
}

private struct ArtifactLexicalCase: CustomStringConvertible {
    let kind: ArtifactLexicalKind
    let value: String
    let accepted: Bool

    var description: String {
        "\(kind.rawValue):\(String(reflecting: value)) expected=\(accepted)"
    }
}

private struct ArtifactLexicalSchemaDefinition {
    let pattern: String
    let format: String?
    let assertsFormat: Bool
}

private let artifactLexicalCorpus: [ArtifactLexicalCase] = [
    .init(kind: .artifactID, value: "artifact-requirement", accepted: true),
    .init(kind: .artifactID, value: "artifact-01", accepted: true),
    .init(kind: .artifactID, value: "", accepted: false),
    .init(kind: .artifactID, value: "-artifact", accepted: false),
    .init(kind: .artifactID, value: "artifact-", accepted: false),
    .init(kind: .artifactID, value: "artifact--id", accepted: false),
    .init(kind: .artifactID, value: "Artifact", accepted: false),
    .init(kind: .artifactID, value: "artifact_id", accepted: false),
    .init(kind: .artifactID, value: "artifact/id", accepted: false),
    .init(kind: .artifactID, value: "artifact ", accepted: false),
    .init(kind: .artifactID, value: "artifact\n", accepted: false),
    .init(kind: .artifactID, value: "é", accepted: false),
    .init(kind: .artifactID, value: "e\u{301}", accepted: false),
    .init(kind: .path, value: "Sources/Feature/File.swift", accepted: true),
    .init(kind: .path, value: "sp ace/é.json", accepted: true),
    .init(kind: .path, value: "", accepted: false),
    .init(kind: .path, value: "/absolute", accepted: false),
    .init(kind: .path, value: "a//b", accepted: false),
    .init(kind: .path, value: "a/", accepted: false),
    .init(kind: .path, value: ".", accepted: false),
    .init(kind: .path, value: "..", accepted: false),
    .init(kind: .path, value: "./a", accepted: false),
    .init(kind: .path, value: "a/../b", accepted: false),
    .init(kind: .path, value: "a\\b", accepted: false),
    .init(kind: .path, value: "*.json", accepted: false),
    .init(kind: .path, value: "nul\u{0000}byte", accepted: false),
    .init(kind: .path, value: "line\u{2028}separator", accepted: false),
    .init(kind: .path, value: "file.json\n", accepted: false),
    .init(kind: .path, value: "e\u{301}.json", accepted: false),
    .init(kind: .semanticSelector, value: "workflow", accepted: true),
    .init(kind: .semanticSelector, value: "workflow.requirements", accepted: true),
    .init(kind: .semanticSelector, value: "source.feature-1", accepted: true),
    .init(kind: .semanticSelector, value: "", accepted: false),
    .init(kind: .semanticSelector, value: ".workflow", accepted: false),
    .init(kind: .semanticSelector, value: "workflow.", accepted: false),
    .init(kind: .semanticSelector, value: "workflow..requirements", accepted: false),
    .init(kind: .semanticSelector, value: "Workflow", accepted: false),
    .init(kind: .semanticSelector, value: "workflow_requirements", accepted: false),
    .init(kind: .semanticSelector, value: "workflow requirements", accepted: false),
    .init(kind: .semanticSelector, value: "workflow\n", accepted: false),
    .init(kind: .semanticSelector, value: "é", accepted: false),
    .init(kind: .semanticSelector, value: "e\u{301}", accepted: false),
]

private func artifactLexicalSchemaDefinitions() throws
    -> [ArtifactLexicalKind: ArtifactLexicalSchemaDefinition]
{
    let data = try Data(contentsOf: artifactSchemaURL())
    let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let definitions = try schemaDictionary(root["$defs"])
    let pairs = try ArtifactLexicalKind.allCases.map { kind in
        let definition = try schemaDictionary(definitions[kind.rawValue])
        let pattern = try #require(definition["pattern"] as? String)
        return (
            kind,
            ArtifactLexicalSchemaDefinition(
                pattern: pattern,
                format: definition["format"] as? String,
                assertsFormat: definition["x-ifl-format-assertion-required"] as? Bool ?? false
            )
        )
    }
    return Dictionary(uniqueKeysWithValues: pairs)
}

private func artifactSwiftAccepts(
    _ value: String,
    as kind: ArtifactLexicalKind
) -> Bool {
    do {
        switch kind {
        case .artifactID:
            _ = try ArtifactID(validating: value)
        case .path:
            _ = try ArtifactScope(kind: .path, value: value)
        case .semanticSelector:
            _ = try ArtifactScope(kind: .semanticSelector, value: value)
        }
        return true
    } catch {
        return false
    }
}

private func artifactSchemaAccepts(
    _ value: String,
    definition: ArtifactLexicalSchemaDefinition
) throws -> Bool {
    let expression = try NSRegularExpression(pattern: definition.pattern)
    let range = NSRange(value.startIndex ..< value.endIndex, in: value)
    guard expression.firstMatch(in: value, range: range)?.range == range else {
        return false
    }
    guard definition.format == "ifl-canonical-relative-path-v1",
          definition.assertsFormat
    else {
        return true
    }
    return value.utf8.elementsEqual(value.precomposedStringWithCanonicalMapping.utf8)
}
