import Foundation
@testable import IFLCanon
import IFLContracts
import Testing

@Suite("CanonIndexModelTests", .serialized)
struct CanonIndexModelTests {
    @Test("repository loads a nonempty inline derived registration without following target_path")
    func inlineDerivedRegistrationDoesNotFollowTarget() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            let entry = derivedEntry(
                indexKey: "standards.brain",
                targetPath: "generated/not-present.md"
            )
            try CanonRepositoryFixture.writeCanonicalJSONObject(
                derivedIndex(entries: [entry]),
                to: "registry/derived-artifacts.index.json",
                in: root
            )

            let snapshot = try FileCanonRepository(root: root).snapshot(
                profiles: [CanonRepositoryFixture.coreProfileID()]
            )
            #expect(snapshot.derivedArtifacts.map(\.indexKey) == ["standards.brain"])
            #expect(snapshot.derivedArtifacts.map(\.targetPath) == ["generated/not-present.md"])
            #expect(
                !FileManager.default.fileExists(
                    atPath: root.appendingPathComponent("generated/not-present.md").path
                )
            )
        }
    }

    @Test("derived index rejects duplicate index keys")
    func duplicateDerivedIndexKey() throws {
        let object = derivedIndex(entries: [
            derivedEntry(indexKey: "standards.brain", targetPath: "generated/a.md"),
            derivedEntry(indexKey: "standards.brain", targetPath: "generated/b.md"),
        ])
        #expect(throws: ContractError.self) {
            _ = try decodeDerivedIndex(object)
        }
    }

    @Test("derived index rejects duplicate target paths")
    func duplicateDerivedTargetPath() throws {
        let object = derivedIndex(entries: [
            derivedEntry(indexKey: "standards.a", targetPath: "generated/a.md"),
            derivedEntry(indexKey: "standards.b", targetPath: "generated/a.md"),
        ])
        #expect(throws: ContractError.self) {
            _ = try decodeDerivedIndex(object)
        }
    }

    @Test("derived index requires canonical target_path order")
    func derivedTargetPathOrder() throws {
        let object = derivedIndex(entries: [
            derivedEntry(indexKey: "standards.z", targetPath: "generated/z.md"),
            derivedEntry(indexKey: "standards.a", targetPath: "generated/a.md"),
        ])
        #expect(throws: ContractError.self) {
            _ = try decodeDerivedIndex(object)
        }
    }

    private func derivedIndex(
        entries: [CanonRepositoryFixture.JSONObject]
    ) -> CanonRepositoryFixture.JSONObject {
        [
            "entries": entries,
            "id": "derived-artifacts",
            "schema_version": 1,
        ]
    }

    private func derivedEntry(
        indexKey: String,
        targetPath: String
    ) -> CanonRepositoryFixture.JSONObject {
        [
            "artifact_kind": "skill",
            "cited_adr_ids": ["ADR-9999"],
            "cited_rule_ids": ["CAN-MINIMAL-001"],
            "file_digest": String(repeating: "a", count: 64),
            "index_key": indexKey,
            "source_semantic_bindings": [
                [
                    "digest": String(repeating: "b", count: 64),
                    "source_id": "ADR-9999",
                    "source_kind": "adr",
                ],
                [
                    "digest": String(repeating: "c", count: 64),
                    "source_id": "CAN-MINIMAL-001",
                    "source_kind": "rule",
                ],
            ],
            "target_path": targetPath,
        ]
    }

    private func decodeDerivedIndex(
        _ object: CanonRepositoryFixture.JSONObject
    ) throws -> CanonDerivedArtifactIndex {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return try CanonicalJSON.decode(CanonDerivedArtifactIndex.self, from: data)
    }
}
