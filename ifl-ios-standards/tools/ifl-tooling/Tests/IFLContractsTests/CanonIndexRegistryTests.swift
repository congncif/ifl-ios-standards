import Foundation
@testable import IFLContracts
import Testing

extension CanonRegistryFileTests {
    @Test("bootstrap indexes use exact unique filenames and IDs and start empty")
    func bootstrapIndexes() throws {
        #expect(Set(Self.indexDescriptors.map(\.filename)).count == Self.indexDescriptors.count)
        #expect(Set(Self.indexDescriptors.map(\.id)).count == Self.indexDescriptors.count)

        for descriptor in Self.indexDescriptors {
            let data = try registryData(descriptor.filename)
            switch descriptor.entryKind {
            case .record:
                let index = try CanonicalJSON.decode(StrictRecordIndex.self, from: data)
                #expect(index.schemaVersion == 1)
                #expect(index.id == descriptor.id)
                #expect(index.entries.isEmpty)
                #expect(try data == canonicalFileData(index))
            case .derivedArtifact:
                let index = try CanonicalJSON.decode(StrictDerivedArtifactIndex.self, from: data)
                #expect(index.schemaVersion == 1)
                #expect(index.id == descriptor.id)
                #expect(index.entries.isEmpty)
                #expect(try data == canonicalFileData(index))
            }
        }
    }

    @Test("nonempty synthetic indexes exercise strict committed nested contracts")
    func nonemptySyntheticIndexes() throws {
        let recordIndex = try CanonicalJSON.decode(
            StrictRecordIndex.self,
            from: Self.syntheticRecordIndexData
        )
        let record = try #require(recordIndex.entries.first)
        #expect(record.id == "CAN-AUTH-001")
        #expect(record.relativePath.rawValue == "rules/core/canon.rules.json")
        #expect(record.recordDigest.rawValue == Self.digestA)

        let derivedIndex = try CanonicalJSON.decode(
            StrictDerivedArtifactIndex.self,
            from: Self.syntheticDerivedArtifactIndexData
        )
        let derived = try #require(derivedIndex.entries.first)
        #expect(derived.indexKey == "standards.brain")
        #expect(derived.targetPath == "skills/brain-flow/SKILL.md")
        #expect(derived.fileDigest.rawValue == Self.digestA)
        #expect(derived.citedRuleIDs.map(\.rawValue) == ["CAN-DERIVED-001"])
        #expect(derived.citedADRIDs.map(\.rawValue) == ["ADR-0001"])
        #expect(derived.sourceSemanticBindings.map(\.sourceKind) == ["adr", "rule"])
    }

    @Test("test-only bootstrap decoders reject every additional key")
    func strictRawDecodersRejectAdditionalKeys() throws {
        let indexWithAdditionalKey = Data(
            #"{"entries":[],"id":"rules","schema_version":1,"workflow_state":"ready"}"#.utf8
        )
        #expect(throws: DecodingError.self) {
            try CanonicalJSON.decode(StrictRecordIndex.self, from: indexWithAdditionalKey)
        }

        let namespaceWithAdditionalKey = Data(
            #"{"allocations":[],"resolution_policy":"longest_prefix","review_cycle":"active","schema_version":1}"#.utf8
        )
        #expect(throws: DecodingError.self) {
            try CanonicalJSON.decode(StrictNamespaceRegistry.self, from: namespaceWithAdditionalKey)
        }

        let allocationWithAdditionalKey = Data(
            #"{"identifier_kind":"rule","pattern":"CAN-*","run_id":"forbidden","steward_role_id":"Canon Maintainer"}"#.utf8
        )
        #expect(throws: DecodingError.self) {
            try CanonicalJSON.decode(StrictNamespaceAllocation.self, from: allocationWithAdditionalKey)
        }

        var recordObject = try #require(
            JSONSerialization.jsonObject(with: Self.syntheticRecordIndexData) as? [String: Any]
        )
        var recordEntries = try #require(recordObject["entries"] as? [[String: Any]])
        recordEntries[0]["workflow_state"] = "forbidden"
        recordObject["entries"] = recordEntries
        #expect(throws: DecodingError.self) {
            try CanonicalJSON.decode(
                StrictRecordIndex.self,
                from: JSONSerialization.data(withJSONObject: recordObject)
            )
        }

        var derivedObject = try #require(
            JSONSerialization.jsonObject(with: Self.syntheticDerivedArtifactIndexData) as? [String: Any]
        )
        var derivedEntries = try #require(derivedObject["entries"] as? [[String: Any]])
        derivedEntries[0]["run_id"] = "forbidden"
        derivedObject["entries"] = derivedEntries
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(
                StrictDerivedArtifactIndex.self,
                from: JSONSerialization.data(withJSONObject: derivedObject)
            )
        }

        derivedObject = try #require(
            JSONSerialization.jsonObject(with: Self.syntheticDerivedArtifactIndexData) as? [String: Any]
        )
        derivedEntries = try #require(derivedObject["entries"] as? [[String: Any]])
        var sourceBindings = try #require(
            derivedEntries[0]["source_semantic_bindings"] as? [[String: Any]]
        )
        sourceBindings[0]["review_cycle"] = "forbidden"
        derivedEntries[0]["source_semantic_bindings"] = sourceBindings
        derivedObject["entries"] = derivedEntries
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(
                StrictDerivedArtifactIndex.self,
                from: JSONSerialization.data(withJSONObject: derivedObject)
            )
        }
    }

    @Test("strict index entries reject escaping paths and invalid digests")
    func strictIndexEntriesValidatePathsAndDigests() throws {
        var recordObject = try #require(
            JSONSerialization.jsonObject(with: Self.syntheticRecordIndexData) as? [String: Any]
        )
        var entries = try #require(recordObject["entries"] as? [[String: Any]])
        entries[0]["relative_path"] = "../escape.json"
        recordObject["entries"] = entries
        #expect(throws: CanonicalTreeError.self) {
            try CanonicalJSON.decode(
                StrictRecordIndex.self,
                from: JSONSerialization.data(withJSONObject: recordObject)
            )
        }

        recordObject = try #require(
            JSONSerialization.jsonObject(with: Self.syntheticRecordIndexData) as? [String: Any]
        )
        entries = try #require(recordObject["entries"] as? [[String: Any]])
        entries[0]["record_digest"] = "not-a-digest"
        recordObject["entries"] = entries
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(
                StrictRecordIndex.self,
                from: JSONSerialization.data(withJSONObject: recordObject)
            )
        }

        var derivedObject = try #require(
            JSONSerialization.jsonObject(with: Self.syntheticDerivedArtifactIndexData) as? [String: Any]
        )
        var derivedEntries = try #require(derivedObject["entries"] as? [[String: Any]])
        derivedEntries[0]["target_path"] = "../escape.md"
        derivedObject["entries"] = derivedEntries
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(
                StrictDerivedArtifactIndex.self,
                from: JSONSerialization.data(withJSONObject: derivedObject)
            )
        }
    }
}
