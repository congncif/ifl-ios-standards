import Foundation
@testable import IFLContracts
import Testing

@Suite("DerivedArtifactContractTests")
struct DerivedArtifactContractTests {
    @Test("runtime and both schemas share the exact closed derived artifact vocabulary")
    func closedArtifactKindVocabulary() throws {
        let runtimeKinds = DerivedArtifactKind.allCases.map(\.rawValue)
        #expect(runtimeKinds == Self.artifactKinds)

        for artifactKind in Self.artifactKinds {
            let entry = try derivedEntry(artifactKind: artifactKind)
            #expect(entry.indexKey == "derived.test")
        }

        #expect(throws: ContractError.self) {
            try derivedEntry(artifactKind: "unregistered_kind")
        }

        for filename in [
            "derived-artifact.schema.json",
            "derived-registration-delta.schema.json",
        ] {
            let schema = try schema(filename)
            let definitions = try #require(schema["$defs"] as? [String: Any])
            let entry = try #require(definitions["derived_registration_entry"] as? [String: Any])
            let properties = try #require(entry["properties"] as? [String: Any])
            let artifactKind = try #require(properties["artifact_kind"] as? [String: Any])
            let declaredKinds = try #require(artifactKind["enum"] as? [String])
            #expect(declaredKinds == runtimeKinds)
            #expect(artifactKind["type"] as? String == "string")
        }
    }

    @Test("publication entries and compatibility rows reject duplicate JSON values")
    func uniquePublicationAndCompatibilityRows() throws {
        let publication = try schema("derived-artifact.schema.json")
        let publicationProperties = try #require(publication["properties"] as? [String: Any])
        let entries = try #require(publicationProperties["entries"] as? [String: Any])

        let compatibility = try schema("compatibility-matrix.schema.json")
        let compatibilityProperties = try #require(compatibility["properties"] as? [String: Any])
        let rows = try #require(compatibilityProperties["rows"] as? [String: Any])

        for arraySchema in [entries, rows] {
            let first: [String: Any] = ["id": "first"]
            let second: [String: Any] = ["id": "second"]
            #expect(uniqueItemsKeywordAccepts([first, second], against: arraySchema))
            #expect(!uniqueItemsKeywordAccepts([first, first], against: arraySchema))
        }
    }
}

private extension DerivedArtifactContractTests {
    static let artifactKinds = [
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

    var schemaRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("standards/canon/schemas/v1")
    }

    func schema(_ filename: String) throws -> [String: Any] {
        let data = try Data(contentsOf: schemaRoot.appendingPathComponent(filename))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func derivedEntry(artifactKind: String) throws -> DerivedRegistrationEntry {
        try DerivedRegistrationEntry(
            indexKey: "derived.test",
            targetPath: "derived/test.md",
            artifactKind: artifactKind,
            fileDigest: HashDigest(validating: String(repeating: "a", count: 64)),
            citedRuleIDs: [],
            citedADRIDs: [],
            sourceSemanticBindings: [
                SourceSemanticBinding(
                    sourceKind: "chapter",
                    sourceID: "test",
                    digest: HashDigest(validating: String(repeating: "b", count: 64))
                ),
            ]
        )
    }

    func uniqueItemsKeywordAccepts(_ values: [Any], against schema: [String: Any]) -> Bool {
        guard schema["type"] as? String == "array" else { return false }
        guard schema["uniqueItems"] as? Bool == true else { return true }

        for left in values.indices {
            for right in values.indices where right > left {
                if jsonEquivalent(values[left], values[right]) {
                    return false
                }
            }
        }
        return true
    }

    func jsonEquivalent(_ lhs: Any, _ rhs: Any) -> Bool {
        guard JSONSerialization.isValidJSONObject([lhs]),
              JSONSerialization.isValidJSONObject([rhs]),
              let left = try? JSONSerialization.data(withJSONObject: [lhs], options: [.sortedKeys]),
              let right = try? JSONSerialization.data(withJSONObject: [rhs], options: [.sortedKeys])
        else {
            return false
        }
        return left == right
    }
}
