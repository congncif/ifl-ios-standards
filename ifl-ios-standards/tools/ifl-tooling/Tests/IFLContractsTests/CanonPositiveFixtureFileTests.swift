import Foundation
@testable import IFLContracts
import Testing

@Suite("CanonPositiveFixtureFileTests")
struct CanonPositiveFixtureFileTests {
    @Test("minimal fixture topology and tree digest are pinned")
    func canonicalTopologyAndDigest() throws {
        let inventory = try fixtureCanonicalTreeInventory(at: positiveRoot)
        let expectedPolicy = try CanonicalTreePolicy(excludedRoots: [])
        let expectedEntries = try Self.expectedEntries()
        let directoryEntries = inventory.entries.filter {
            $0.kind == CanonicalTreeEntry.Kind.directory
        }
        let regularFileEntries = inventory.entries.filter {
            $0.kind == CanonicalTreeEntry.Kind.regularFile
        }
        let actualTreeDigest = try CanonicalTreeDigest.digest(inventory).rawValue

        #expect(inventory.schemaVersion == 1)
        #expect(inventory.policy == expectedPolicy)
        #expect(inventory.rootMode == 0o755)
        #expect(inventory.entries == expectedEntries)
        #expect(directoryEntries.allSatisfy { $0.mode == 0o755 })
        #expect(directoryEntries.allSatisfy { $0.contentSHA256 == nil })
        #expect(regularFileEntries.allSatisfy { $0.mode == 0o644 })
        #expect(regularFileEntries.allSatisfy { $0.contentSHA256 != nil })
        #expect(actualTreeDigest == Self.pinnedTreeDigest)
    }

    @Test("registry indexes are an exact digest-bound bijection with records")
    func registryIndexRecordDigestBijection() throws {
        let inventory = try fixtureCanonicalTreeInventory(at: positiveRoot)
        let treeEntries: [String: CanonicalTreeEntry] = Dictionary(
            uniqueKeysWithValues: inventory.entries.map { ($0.relativePath, $0) }
        )
        var indexedRecordPaths = Set<String>()

        for descriptor in Self.indexDescriptors {
            let data = try fixtureData("registry/\(descriptor.filename)")
            let object = try JSONSerialization.jsonObject(with: data)
            #expect(try data == fixtureCanonicalJSONObjectData(object))

            let index = try CanonicalJSON.decode(FixtureRecordIndex.self, from: data)
            #expect(index.schemaVersion == 1)
            #expect(index.id == descriptor.id)
            #expect(index.entries.map(\.id) == descriptor.records.map(\.id))
            #expect(
                index.entries.map(\.relativePath.rawValue)
                    == descriptor.records.map(\.relativePath)
            )
            #expect(
                index.entries.map(\.recordDigest.rawValue)
                    == descriptor.records.map(\.recordDigest)
            )

            for (entry, expected) in zip(index.entries, descriptor.records) {
                let treeEntry = try #require(treeEntries[expected.relativePath])
                #expect(treeEntry.kind == CanonicalTreeEntry.Kind.regularFile)
                #expect(treeEntry.contentSHA256 == entry.recordDigest)
                let recordData = try fixtureData(expected.relativePath)
                #expect(CanonicalTreeDigest.sha256(recordData) == entry.recordDigest)
                #expect(indexedRecordPaths.insert(expected.relativePath).inserted)
            }
        }

        let actualRecordPaths = Set(
            inventory.entries.compactMap { entry -> String? in
                guard entry.kind == CanonicalTreeEntry.Kind.regularFile else { return nil }
                let path = entry.relativePath
                if path.hasPrefix("rules/") {
                    return path
                }
                if path.hasPrefix("profiles/"), path.hasSuffix(".json") {
                    return path
                }
                if path.hasPrefix("adrs/"), path.hasSuffix(".json") {
                    return path
                }
                return nil
            }
        )
        #expect(indexedRecordPaths == actualRecordPaths)
    }

    @Test("records preserve semantic linkage and fixture identifier grammar")
    func semanticLinkageAndFixtureIdentifierGrammar() throws {
        #expect(try fixtureData("VERSION") == Data([0x31, 0x0A]))

        let requirementsData = try fixtureData("registry/requirements.v1.json")
        let requirements = try CanonicalJSON.decode(RequirementRegistry.self, from: requirementsData)
        let productionRequirements = try CanonicalJSON.decode(
            RequirementRegistry.self,
            from: Data(contentsOf: productionCanonRoot.appendingPathComponent(
                "registry/requirements.v1.json"
            ))
        )
        #expect(requirements.requirements.count == 26)
        #expect(requirements.requirements == productionRequirements.requirements)
        #expect(requirements.traceability.map(\.requirementID.rawValue) == [
            "REQ-CANON",
            "REQ-CONVERGENCE",
        ])
        #expect(Array(requirements.traceability.dropFirst()) == productionRequirements.traceability)
        #expect(try requirementsData == fixtureCanonicalFileData(requirements))

        let canonTraceability = try #require(requirements.traceability.first)
        #expect(canonTraceability.accountableOwnerRoleID == "Canon Maintainer")
        #expect(canonTraceability.ruleBindings.map(\.ruleID.rawValue) == ["CAN-MINIMAL-001"])
        #expect(canonTraceability.ruleBindings.map(\.ownerRoleID) == ["Canon Maintainer"])
        #expect(canonTraceability.internalCheckIDs == ["CHK-CAN-MINIMAL-001"])

        let fixtureMapping = try #require(canonTraceability.fixtureMappings.first)
        #expect(canonTraceability.fixtureMappings.count == 1)
        #expect(fixtureMapping.checkID == "CHK-CAN-MINIMAL-001")
        #expect(fixtureMapping.positiveFixtureIDs == [Self.positiveFixtureID])
        #expect(fixtureMapping.negativeFixtureIDs == Self.negativeFixtureIDs)

        let convergenceTraceability = try #require(
            requirements.traceability.first {
                $0.requirementID.rawValue == "REQ-CONVERGENCE"
            }
        )
        let convergenceNegativeFixtureIDs = convergenceTraceability.fixtureMappings
            .flatMap(\.negativeFixtureIDs)
        #expect(convergenceNegativeFixtureIDs.contains(Self.convergenceNegativeFixtureID))
        #expect(!fixtureMapping.negativeFixtureIDs.contains(Self.convergenceNegativeFixtureID))

        let ruleData = try fixtureData("rules/core/minimal.rules.json")
        let profileData = try fixtureData("profiles/minimal.profile.json")
        let adrData = try fixtureData("adrs/ADR-9999-minimal-test.json")
        let rule = try CanonicalJSON.decode(RuleRecord.self, from: ruleData)
        let profile = try CanonicalJSON.decode(ProfileRecord.self, from: profileData)
        let adr = try CanonicalJSON.decode(ADRMetadata.self, from: adrData)
        #expect(try ruleData == fixtureCanonicalFileData(rule))
        #expect(try profileData == fixtureCanonicalFileData(profile))
        #expect(try adrData == fixtureCanonicalFileData(adr))

        #expect(rule.id.rawValue == "CAN-MINIMAL-001")
        #expect(rule.lifecycle == .active)
        #expect(rule.profileIDs == [profile.id])
        #expect(rule.rationaleADRs == [adr.id])
        #expect(profile.id.rawValue == "core")
        #expect(profile.inheritsProfileIDs.isEmpty)
        #expect(profile.ruleIDs == [rule.id])
        #expect(adr.id.rawValue == "ADR-9999")
        #expect(adr.status == .accepted)
        #expect(adr.acceptedAt != nil)
        #expect(adr.affectedRuleIDs == [rule.id])
        #expect(adr.affectedProfileIDs == [profile.id])
        #expect(adr.checkIDs == [fixtureMapping.checkID])
        #expect(adr.fixtureIDs == fixtureMapping.negativeFixtureIDs)
        #expect(adr.migrationIDs == ["MIG-CAN-MINIMAL-001"])

        let allFixtureIDs = fixtureMapping.positiveFixtureIDs + fixtureMapping.negativeFixtureIDs
        #expect(
            allFixtureIDs == [Self.positiveFixtureID] + Self.negativeFixtureIDs
        )
        for fixtureID in allFixtureIDs {
            #expect(fixtureIdentifier(fixtureID, belongsToRuleID: rule.id.rawValue))
        }

        let markdownData = try fixtureData("adrs/ADR-9999-minimal-test.md")
        #expect(adr.markdownDigest == CanonicalTreeDigest.sha256(markdownData))
    }

    @Test("namespace ownership resolves by the longest matching prefix")
    func namespaceLongestPrefixOwnership() throws {
        let data = try fixtureData("registry/namespaces.v1.json")
        let productionData = try Data(
            contentsOf: productionCanonRoot.appendingPathComponent(
                "registry/namespaces.v1.json"
            )
        )
        #expect(data == productionData)
        let registry = try CanonicalJSON.decode(StrictNamespaceRegistry.self, from: data)
        #expect(registry.schemaVersion == 1)
        #expect(registry.resolutionPolicy == "longest_prefix")
        #expect(try data == fixtureCanonicalFileData(registry))

        let rule = try CanonicalJSON.decode(
            RuleRecord.self,
            from: fixtureData("rules/core/minimal.rules.json")
        )
        let profile = try CanonicalJSON.decode(
            ProfileRecord.self,
            from: fixtureData("profiles/minimal.profile.json")
        )
        let adr = try CanonicalJSON.decode(
            ADRMetadata.self,
            from: fixtureData("adrs/ADR-9999-minimal-test.json")
        )
        let requirements = try CanonicalJSON.decode(
            RequirementRegistry.self,
            from: fixtureData("registry/requirements.v1.json")
        )
        let canonTraceability = try #require(
            requirements.traceability.first(where: { $0.requirementID.rawValue == "REQ-CANON" })
        )
        let checkID = try #require(canonTraceability.internalCheckIDs.first)
        let fixtureMapping = try #require(canonTraceability.fixtureMappings.first)
        let migrationID = try #require(adr.migrationIDs.first)

        let recordProjections = [
            NamespaceProjection(
                identityKind: "rule",
                id: rule.id.rawValue,
                expectedPattern: "CAN-*",
                expectedStewardRoleID: "Canon Maintainer"
            ),
            NamespaceProjection(
                identityKind: "profile",
                id: profile.id.rawValue,
                expectedPattern: "core",
                expectedStewardRoleID: "Canon Maintainer"
            ),
            NamespaceProjection(
                identityKind: "adr",
                id: adr.id.rawValue,
                expectedPattern: "ADR-*",
                expectedStewardRoleID: "Canon Maintainer"
            ),
            NamespaceProjection(
                identityKind: "requirement",
                id: canonTraceability.requirementID.rawValue,
                expectedPattern: "REQ-*",
                expectedStewardRoleID: "Canon Maintainer"
            ),
            NamespaceProjection(
                identityKind: "check",
                id: checkID,
                expectedPattern: "CHK-*",
                expectedStewardRoleID: "Verification Owner"
            ),
            NamespaceProjection(
                identityKind: "migration",
                id: migrationID,
                expectedPattern: "MIG-*",
                expectedStewardRoleID: "Release Steward"
            ),
        ]
        let decodedFixtureIDs = fixtureMapping.positiveFixtureIDs
            + fixtureMapping.negativeFixtureIDs
        let fixtureProjections = decodedFixtureIDs.map {
            NamespaceProjection(
                identityKind: "fixture",
                id: $0,
                expectedPattern: "FIX-*",
                expectedStewardRoleID: "Verification Owner"
            )
        }
        let projections = recordProjections + fixtureProjections

        for projection in projections {
            let allocations = registry.mostSpecificAllocations(for: projection)
            #expect(allocations.count == 1)
            #expect(allocations.first?.pattern == projection.expectedPattern)
            #expect(allocations.first?.stewardRoleID == projection.expectedStewardRoleID)
        }
    }

    private static let positiveFixtureID = "FIX-CAN-MINIMAL-001-PASS"
    private static let negativeFixtureIDs = [
        "FIX-CAN-MINIMAL-001-FAIL-001",
        "FIX-CAN-MINIMAL-001-FAIL-002",
        "FIX-CAN-MINIMAL-001-FAIL-003",
        "FIX-CAN-MINIMAL-001-FAIL-004",
        "FIX-CAN-MINIMAL-001-FAIL-005",
    ]
    private static let convergenceNegativeFixtureID =
        "FIX-WF-CONV-INVENTORY-001-FAIL-001"
    private static let pinnedTreeDigest =
        "a6811088c1859e048d75982df086b9b05aea7a4d2a8f1e012090dd9452865553"

    private static let indexDescriptors = [
        FixtureIndexDescriptor(
            filename: "adrs.index.json",
            id: "adrs",
            records: [
                FixtureIndexedRecordExpectation(
                    id: "ADR-9999",
                    relativePath: "adrs/ADR-9999-minimal-test.json",
                    recordDigest: "60ef1231ab1f7ff50bf6c3d3c2edf1d174a6a50ba7eb1abf798e78cf35cac829"
                ),
            ]
        ),
        FixtureIndexDescriptor(filename: "chapters.index.json", id: "chapters", records: []),
        FixtureIndexDescriptor(
            filename: "derived-artifacts.index.json",
            id: "derived-artifacts",
            records: []
        ),
        FixtureIndexDescriptor(
            filename: "profiles.index.json",
            id: "profiles",
            records: [
                FixtureIndexedRecordExpectation(
                    id: "core",
                    relativePath: "profiles/minimal.profile.json",
                    recordDigest: "20f1a41e951bcd3b199b1a2794bc3b79342718b876617b35364feb292c156e80"
                ),
            ]
        ),
        FixtureIndexDescriptor(
            filename: "rules.index.json",
            id: "rules",
            records: [
                FixtureIndexedRecordExpectation(
                    id: "CAN-MINIMAL-001",
                    relativePath: "rules/core/minimal.rules.json",
                    recordDigest: "963e5f02faf0df9d688ed21a982a6b70173b43b7a7ae916d0f70772f787e78c2"
                ),
            ]
        ),
    ]

    private static func expectedEntries() throws -> [CanonicalTreeEntry] {
        try [
            file("VERSION", sha256: "4355a46b19d348dc2f57c046f8ef63d4538ebb936000f3c9ee954a27460dd865"),
            directory("adrs"),
            file(
                "adrs/ADR-9999-minimal-test.json",
                sha256: "60ef1231ab1f7ff50bf6c3d3c2edf1d174a6a50ba7eb1abf798e78cf35cac829"
            ),
            file(
                "adrs/ADR-9999-minimal-test.md",
                sha256: "636a09cf6c52903ee772794f2080fd22b7c1804dfe1e979172601ff401ce9460"
            ),
            directory("profiles"),
            file(
                "profiles/minimal.profile.json",
                sha256: "20f1a41e951bcd3b199b1a2794bc3b79342718b876617b35364feb292c156e80"
            ),
            directory("registry"),
            file(
                "registry/adrs.index.json",
                sha256: "5793d7dd451b58ade5727fc4ee8a0e0a4269bc6cf8571510a3373838ef1452ed"
            ),
            file(
                "registry/chapters.index.json",
                sha256: "6b3f3a4fb43d412db9c13d30bdebf38b3dbc67a565c5904f630c048422ae26f3"
            ),
            file(
                "registry/derived-artifacts.index.json",
                sha256: "d77820732d1f58acbbc65d17e21a48ba1325d6420cb3b165e52337c7b2c322ab"
            ),
            file(
                "registry/namespaces.v1.json",
                sha256: "e979c0cf5588f45aa585f673f716b6cd97c161c8ba2388b0736cf6fa6c1ad138"
            ),
            file(
                "registry/profiles.index.json",
                sha256: "f25e6d70ebb2529bec0c6017c39b3aaecce4a2459f5561678378226a231bc9c0"
            ),
            file(
                "registry/requirements.v1.json",
                sha256: "ef2e346a91e5bb3586643d336670b192bac8d27bc49aeb5e4fc64faca3a1e647"
            ),
            file(
                "registry/rules.index.json",
                sha256: "a8233529816c97b4c36ba36a1a2c773d8a8d73289622ca85e57122f2ace3a497"
            ),
            directory("rules"),
            directory("rules/core"),
            file(
                "rules/core/minimal.rules.json",
                sha256: "963e5f02faf0df9d688ed21a982a6b70173b43b7a7ae916d0f70772f787e78c2"
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

    private var productionCanonRoot: URL {
        pluginRoot.appendingPathComponent("standards/canon")
    }

    private var positiveRoot: URL {
        pluginRoot.appendingPathComponent("verification/fixtures/canon/positive/minimal")
    }

    private func fixtureData(_ relativePath: String) throws -> Data {
        try Data(contentsOf: positiveRoot.appendingPathComponent(relativePath))
    }
}

private struct FixtureIndexDescriptor {
    let filename: String
    let id: String
    let records: [FixtureIndexedRecordExpectation]
}

private struct FixtureIndexedRecordExpectation {
    let id: String
    let relativePath: String
    let recordDigest: String
}
