import Foundation
@testable import IFLContracts
import Testing

@Suite("CanonNegativeFixtureFileTests")
struct CanonNegativeFixtureFileTests {
    @Test("negative matrix has exact canonical manifests and unique fixture IDs")
    func exactCanonicalManifestMatrix() throws {
        let names = try FileManager.default
            .contentsOfDirectory(atPath: negativeRoot.path)
            .sorted()
        #expect(names == Self.manifests.map(\.directory).sorted())
        #expect(Set(Self.manifests.map(\.fixtureID)).count == Self.manifests.count)

        for manifest in Self.manifests {
            let data = try negativeFixtureData(manifest.directory)
            #expect(data == Data((manifest.canonicalJSON + "\n").utf8))

            let identity = try CanonicalJSON.decode(
                NegativeFixtureIdentity.self,
                from: data
            )
            #expect(identity.schemaVersion == 1)
            #expect(identity.fixtureID == manifest.fixtureID)
        }
    }

    @Test("negative tree has exact inventory, modes, hashes, and pinned digest")
    func canonicalTopologyAndDigest() throws {
        let inventory = try fixtureCanonicalTreeInventory(at: negativeRoot)
        let expectedPolicy = try CanonicalTreePolicy(excludedRoots: [])
        let expectedEntries = try Self.expectedEntries()
        let directories = inventory.entries.filter {
            $0.kind == CanonicalTreeEntry.Kind.directory
        }
        let regularFiles = inventory.entries.filter {
            $0.kind == CanonicalTreeEntry.Kind.regularFile
        }
        let actualTreeDigest = try CanonicalTreeDigest.digest(inventory).rawValue

        #expect(inventory.schemaVersion == 1)
        #expect(inventory.policy == expectedPolicy)
        #expect(inventory.rootMode == 0o755)
        #expect(inventory.entries == expectedEntries)
        #expect(directories.count == 6)
        #expect(regularFiles.count == 6)
        #expect(directories.allSatisfy { $0.mode == 0o755 && $0.contentSHA256 == nil })
        #expect(regularFiles.allSatisfy { $0.mode == 0o644 && $0.contentSHA256 != nil })
        #expect(actualTreeDigest == Self.pinnedTreeDigest)
    }

    @Test("unknown rule schema version directly yields unsupported_schema_version")
    func unknownRuleVersionCodableWitness() throws {
        var rule = try positiveFixtureObject("rules/core/minimal.rules.json")
        rule["schema_version"] = 2

        let error = fixtureContractError {
            _ = try CanonicalJSON.decode(
                RuleRecord.self,
                from: canonicalData(rule)
            )
        }
        #expect(error?.code == "unsupported_schema_version")
    }

    @Test("self-inheriting profile directly yields reused_identifier")
    func reusedProfileIDCodableWitness() throws {
        var profile = try positiveFixtureObject("profiles/minimal.profile.json")
        profile["inherits_profile_ids"] = ["core"]

        let error = fixtureContractError {
            _ = try CanonicalJSON.decode(
                ProfileRecord.self,
                from: canonicalData(profile)
            )
        }
        #expect(error?.code == "reused_identifier")
    }

    @Test("orphan traceability requirement directly yields unresolved_reference")
    func orphanRequirementCodableWitness() throws {
        var registry = try positiveFixtureObject("registry/requirements.v1.json")
        var traceability = try #require(registry["traceability"] as? [[String: Any]])
        traceability[0]["requirement_id"] = "REQ-ABSENT"
        registry["traceability"] = traceability

        let error = fixtureContractError {
            _ = try CanonicalJSON.decode(
                RequirementRegistry.self,
                from: canonicalData(registry)
            )
        }
        #expect(error?.code == "unresolved_reference")
    }

    @Test("missing convergence check directly yields unresolved_reference")
    func missingConvergenceCheckCodableWitness() throws {
        var registry = try positiveFixtureObject("registry/requirements.v1.json")
        var traceability = try #require(registry["traceability"] as? [[String: Any]])
        var internalCheckIDs = try #require(
            traceability[1]["internal_check_ids"] as? [String]
        )
        internalCheckIDs.removeFirst()
        traceability[1]["internal_check_ids"] = internalCheckIDs
        registry["traceability"] = traceability

        let error = fixtureContractError {
            _ = try CanonicalJSON.decode(
                RequirementRegistry.self,
                from: canonicalData(registry)
            )
        }
        #expect(error?.code == "unresolved_reference")
    }

    @Test("accepted ADR without migration evidence directly yields invalid_contract")
    func incompleteAcceptedADRCodableWitness() throws {
        var adr = try positiveFixtureObject("adrs/ADR-9999-minimal-test.json")
        adr["migration_ids"] = [String]()

        let error = fixtureContractError {
            _ = try CanonicalJSON.decode(
                ADRMetadata.self,
                from: canonicalData(adr)
            )
        }
        #expect(error?.code == "invalid_contract")
    }

    @Test(
        "duplicate index is statically causal; repository execution is deferred to Task3 FixtureCanon"
    )
    func duplicateIndexStaticCausalityOnly() throws {
        let manifest = try CanonicalJSON.decode(
            DuplicateIndexFixtureProjection.self,
            from: negativeFixtureData("duplicate-id")
        )
        let index = try CanonicalJSON.decode(
            StaticRuleIndexProjection.self,
            from: positiveFixtureData("registry/rules.index.json")
        )
        let mutation = try #require(manifest.mutations.first)

        #expect(manifest.mutations.count == 1)
        #expect(manifest.expected.kind == "contract_error")
        #expect(manifest.expected.contractErrorCode == "duplicate_identifier")
        #expect(mutation.operation == "json_add")
        #expect(mutation.relativePath == "registry/rules.index.json")
        #expect(mutation.jsonPointer == "/entries/-")
        #expect(index.entries.count(where: { $0 == mutation.value }) == 1)
        #expect(Set(index.entries.map(\.id)).count == index.entries.count)

        // Task3's sole FixtureCanon owns copy, reindex, load, and the runtime error assertion.
        // This Task2 test proves only that the declared append necessarily creates a duplicate.
    }

    private static let pinnedTreeDigest =
        "bef236f70f2041df6ef6edf873755f1aa6564bd72782014d0eab42ebc13e3faf"

    private static let manifests = [
        NegativeManifestExpectation(
            directory: "accepted-adr-incomplete",
            fixtureID: "FIX-CAN-MINIMAL-001-FAIL-005",
            canonicalJSON: #"{"base_fixture":"positive/minimal","expected":{"contract_error_code":"invalid_contract","kind":"contract_error"},"fixture_id":"FIX-CAN-MINIMAL-001-FAIL-005","mutations":[{"json_pointer":"/migration_ids/0","operation":"json_remove","relative_path":"adrs/ADR-9999-minimal-test.json"}],"schema_version":1}"#
        ),
        NegativeManifestExpectation(
            directory: "duplicate-id",
            fixtureID: "FIX-CAN-MINIMAL-001-FAIL-001",
            canonicalJSON: #"{"base_fixture":"positive/minimal","expected":{"contract_error_code":"duplicate_identifier","kind":"contract_error"},"fixture_id":"FIX-CAN-MINIMAL-001-FAIL-001","mutations":[{"json_pointer":"/entries/-","operation":"json_add","relative_path":"registry/rules.index.json","value":{"id":"CAN-MINIMAL-001","record_digest":"963e5f02faf0df9d688ed21a982a6b70173b43b7a7ae916d0f70772f787e78c2","relative_path":"rules/core/minimal.rules.json"}}],"schema_version":1}"#
        ),
        NegativeManifestExpectation(
            directory: "missing-convergence-traceability",
            fixtureID: "FIX-WF-CONV-INVENTORY-001-FAIL-001",
            canonicalJSON: #"{"base_fixture":"positive/minimal","expected":{"contract_error_code":"unresolved_reference","kind":"contract_error"},"fixture_id":"FIX-WF-CONV-INVENTORY-001-FAIL-001","mutations":[{"json_pointer":"/traceability/1/internal_check_ids/0","operation":"json_remove","relative_path":"registry/requirements.v1.json"}],"schema_version":1}"#
        ),
        NegativeManifestExpectation(
            directory: "orphan-requirement",
            fixtureID: "FIX-CAN-MINIMAL-001-FAIL-004",
            canonicalJSON: #"{"base_fixture":"positive/minimal","expected":{"contract_error_code":"unresolved_reference","kind":"contract_error"},"fixture_id":"FIX-CAN-MINIMAL-001-FAIL-004","mutations":[{"json_pointer":"/traceability/0/requirement_id","operation":"json_replace","relative_path":"registry/requirements.v1.json","value":"REQ-ABSENT"}],"schema_version":1}"#
        ),
        NegativeManifestExpectation(
            directory: "reused-id",
            fixtureID: "FIX-CAN-MINIMAL-001-FAIL-003",
            canonicalJSON: #"{"base_fixture":"positive/minimal","expected":{"contract_error_code":"reused_identifier","kind":"contract_error"},"fixture_id":"FIX-CAN-MINIMAL-001-FAIL-003","mutations":[{"json_pointer":"/inherits_profile_ids","operation":"json_replace","relative_path":"profiles/minimal.profile.json","value":["core"]}],"schema_version":1}"#
        ),
        NegativeManifestExpectation(
            directory: "unknown-version",
            fixtureID: "FIX-CAN-MINIMAL-001-FAIL-002",
            canonicalJSON: #"{"base_fixture":"positive/minimal","expected":{"contract_error_code":"unsupported_schema_version","kind":"contract_error"},"fixture_id":"FIX-CAN-MINIMAL-001-FAIL-002","mutations":[{"json_pointer":"/schema_version","operation":"json_replace","relative_path":"rules/core/minimal.rules.json","value":2}],"schema_version":1}"#
        ),
    ]

    private static func expectedEntries() throws -> [CanonicalTreeEntry] {
        try [
            directory("accepted-adr-incomplete"),
            file(
                "accepted-adr-incomplete/fixture.json",
                sha256: "fcf97d6234884773b03e2ef835c1073b8493a893576f3698ec0c81b912b71dd2"
            ),
            directory("duplicate-id"),
            file(
                "duplicate-id/fixture.json",
                sha256: "5117a89c4d7c5c1c27735ede221bea0d766c8ef0c34d666180d8529238adc57b"
            ),
            directory("missing-convergence-traceability"),
            file(
                "missing-convergence-traceability/fixture.json",
                sha256: "15ddaa054ed9fe5fcb820bc57959a681a9251675bffb1305c33c7ad6605ca735"
            ),
            directory("orphan-requirement"),
            file(
                "orphan-requirement/fixture.json",
                sha256: "7caba5c75d352c3bee527e273bab1f2b9549796b343968751ebab910aac046c5"
            ),
            directory("reused-id"),
            file(
                "reused-id/fixture.json",
                sha256: "d6cdf93fa7a2f82dd1d88cd5ed60b5c60d47f1c6932bf57a910ac637402ecbf9"
            ),
            directory("unknown-version"),
            file(
                "unknown-version/fixture.json",
                sha256: "8d7ba248a5765499c1939614d02e43288d1b5d2326e5d1de772ba4e9b4bcbf5f"
            ),
        ]
    }

    private static func directory(_ relativePath: String) throws -> CanonicalTreeEntry {
        try CanonicalTreeEntry(
            relativePath: relativePath,
            kind: .directory,
            contentSHA256: nil,
            mode: 0o755
        )
    }

    private static func file(_ relativePath: String, sha256: String) throws -> CanonicalTreeEntry {
        try CanonicalTreeEntry(
            relativePath: relativePath,
            kind: .regularFile,
            contentSHA256: HashDigest(validating: sha256),
            mode: 0o644
        )
    }

    private var pluginRoot: URL {
        fixturePluginRoot(filePath: #filePath)
    }

    private var positiveRoot: URL {
        pluginRoot.appendingPathComponent("verification/fixtures/canon/positive/minimal")
    }

    private var negativeRoot: URL {
        pluginRoot.appendingPathComponent("verification/fixtures/canon/negative")
    }

    private func positiveFixtureData(_ relativePath: String) throws -> Data {
        try Data(contentsOf: positiveRoot.appendingPathComponent(relativePath))
    }

    private func negativeFixtureData(_ directory: String) throws -> Data {
        try Data(
            contentsOf: negativeRoot
                .appendingPathComponent(directory)
                .appendingPathComponent("fixture.json")
        )
    }

    private func positiveFixtureObject(_ relativePath: String) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(
            with: positiveFixtureData(relativePath)
        )
        return try #require(object as? [String: Any])
    }

    private func canonicalData(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }
}

private struct NegativeManifestExpectation {
    let directory: String
    let fixtureID: String
    let canonicalJSON: String
}

private struct NegativeFixtureIdentity: Decodable {
    let schemaVersion: Int
    let fixtureID: String

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case fixtureID = "fixture_id"
    }
}

private struct DuplicateIndexFixtureProjection: Decodable {
    let mutations: [DuplicateIndexMutationProjection]
    let expected: ContractErrorExpectationProjection
}

private struct DuplicateIndexMutationProjection: Decodable {
    let operation: String
    let relativePath: String
    let jsonPointer: String
    let value: StaticIndexEntryProjection

    private enum CodingKeys: String, CodingKey {
        case operation
        case relativePath = "relative_path"
        case jsonPointer = "json_pointer"
        case value
    }
}

private struct ContractErrorExpectationProjection: Decodable {
    let kind: String
    let contractErrorCode: String

    private enum CodingKeys: String, CodingKey {
        case kind
        case contractErrorCode = "contract_error_code"
    }
}

private struct StaticRuleIndexProjection: Decodable {
    let entries: [StaticIndexEntryProjection]
}

private struct StaticIndexEntryProjection: Decodable, Equatable {
    let id: String
    let relativePath: String
    let recordDigest: String

    private enum CodingKeys: String, CodingKey {
        case id
        case relativePath = "relative_path"
        case recordDigest = "record_digest"
    }
}
