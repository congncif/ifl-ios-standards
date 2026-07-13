import Testing

extension CanonSchemaFileTests {
    @Test("derived artifact identifiers mirror Swift validators and artifact kinds are closed")
    func derivedArtifactIdentifiersAndKindsAreClosed() throws {
        let schema = try #require(try loadIfPresent("derived-artifact.schema.json"))
        let definitions = try #require(schema["$defs"] as? [String: Any])

        for corpus in derivedIdentifierCorpora {
            let definition = definitions[corpus.definition] as? [String: Any]
            #expect(definition != nil, "derived artifact schema must define \(corpus.definition)")
            guard let definition else { continue }
            let pattern = try #require(definition["pattern"] as? String)
            let rejectedValid = corpus.accepted.filter { !matches(pattern: pattern, $0) }
            let acceptedInvalid = corpus.rejected.filter { matches(pattern: pattern, $0) }
            #expect(rejectedValid.isEmpty, "\(corpus.definition) rejected Swift-valid witnesses \(rejectedValid)")
            #expect(acceptedInvalid.isEmpty, "\(corpus.definition) accepted Swift-invalid witnesses \(acceptedInvalid)")
        }

        let sourceBinding = definitions["source_semantic_binding"] as? [String: Any]
        #expect(sourceBinding != nil)
        if let sourceBinding {
            for corpus in derivedIdentifierCorpora {
                let sourceKind = try #require(corpus.sourceKind)
                let rejectedValid = corpus.accepted.filter { sourceID in
                    let witness: [String: Any] = [
                        "source_kind": sourceKind,
                        "source_id": sourceID,
                        "digest": String(repeating: "0", count: 64),
                    ]
                    return !schemaAccepts(witness, against: sourceBinding, root: schema)
                }
                let acceptedInvalid = corpus.rejected.filter { sourceID in
                    let witness: [String: Any] = [
                        "source_kind": sourceKind,
                        "source_id": sourceID,
                        "digest": String(repeating: "0", count: 64),
                    ]
                    return schemaAccepts(witness, against: sourceBinding, root: schema)
                }
                #expect(rejectedValid.isEmpty, "source binding rejected Swift-valid \(corpus.definition) witnesses \(rejectedValid)")
                #expect(acceptedInvalid.isEmpty, "source binding accepted Swift-invalid \(corpus.definition) witnesses \(acceptedInvalid)")
            }
        }

        if let entry = definitions["derived_registration_entry"] as? [String: Any],
           let entryProperties = entry["properties"] as? [String: Any],
           let artifactKind = entryProperties["artifact_kind"] as? [String: Any]
        {
            #expect(Set(artifactKind["enum"] as? [String] ?? []) == artifactKinds)
        } else {
            Issue.record("derived artifact schema must type derived_registration_entry.artifact_kind")
        }
    }
}

struct IdentifierCorpus {
    let definition: String
    let sourceKind: String?
    let accepted: [String]
    let rejected: [String]
}

let derivedIdentifierCorpora: [IdentifierCorpus] = [
    .init(
        definition: "rule_id",
        sourceKind: "rule",
        accepted: ["TEST-CANON-001", "1-2-999"],
        rejected: ["TEST-001", "TEST-CANON-01", "test-CANON-001", "TEST--001", "TEST-CANON-001\n"]
    ),
    .init(
        definition: "profile_id",
        sourceKind: "profile",
        accepted: ["minimal", "boardy-vip", "swift6"],
        rejected: ["Minimal", "boardy--vip", "1minimal", "minimal\n"]
    ),
    .init(
        definition: "adr_id",
        sourceKind: "adr",
        accepted: ["ADR-0001", "ADR-9999"],
        rejected: ["ADR-1", "ADR-00001", "adr-0001", "ADR-0001\n"]
    ),
    .init(
        definition: "requirement_id",
        sourceKind: "requirement",
        accepted: ["P0-1", "P3-42", "ENT-CONCURRENCY", "REQ-CONVERGENCE"],
        rejected: ["P4-1", "P0-0", "P0-01", "ENT-", "REQ--CANON", "req-canon", "REQ-CANON\n"]
    ),
    .init(
        definition: "slug",
        sourceKind: "chapter",
        accepted: ["security", "swiftui-production", "1chapter"],
        rejected: ["Chapter", "chapter--x", "_chapter", "chapter\n"]
    ),
]

let artifactKinds: Set<String> = [
    "constitution",
    "rulebook",
    "specification",
    "compact_reference",
    "checklist",
    "guide",
    "skill",
    "agent",
    "template",
    "scaffold",
    "wrapper",
    "process_contract",
    "example",
    "migration_guide",
]
