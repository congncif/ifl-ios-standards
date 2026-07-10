import Foundation
@testable import IFLContracts
import Testing

@Suite("CanonRegistryFileTests")
struct CanonRegistryFileTests {
    @Test("production Canon VERSION is the exact snapshot major bytes")
    func canonVersionBytes() throws {
        let data = try Data(contentsOf: canonRoot.appendingPathComponent("VERSION"))
        #expect(data == Data([0x31, 0x0A]))
    }

    @Test("production registry directory has the exact bootstrap filename set")
    func exactRegistryFilenames() throws {
        let filenames = try FileManager.default
            .contentsOfDirectory(atPath: registryRoot.path)
            .sorted()
        #expect(filenames == Self.registryFilenames)
    }

    @Test("production requirement registry is the exact approved canonical bootstrap")
    func requirementRegistryBootstrap() throws {
        let data = try registryData("requirements.v1.json")
        let registry = try CanonicalJSON.decode(RequirementRegistry.self, from: data)

        #expect(registry.schemaVersion == 1)
        #expect(registry.requirements.map(\.id.rawValue) == Self.approvedRequirementIDs)
        #expect(registry.requirements.allSatisfy { $0.status == .planned })
        #expect(
            Dictionary(uniqueKeysWithValues: registry.requirements.map {
                ($0.id.rawValue, $0.accountableOwnerRoleID)
            }) == Self.approvedRequirementOwners
        )

        #expect(registry.traceability.map(\.requirementID.rawValue) == ["REQ-CONVERGENCE"])
        let convergence = try #require(registry.traceability.first)
        #expect(convergence.accountableOwnerRoleID == "Workflow Maintainer")
        #expect(convergence.ruleBindings.isEmpty)
        #expect(convergence.internalCheckNamespace == "CHK-WF-CONV-*")
        #expect(convergence.internalCheckIDs == Self.internalConvergenceChecks)
        #expect(convergence.publicCheckIDs == Self.publicConvergenceChecks)
        #expect(convergence.allCheckIDs.count == 13)
        #expect(convergence.fixtureNamespace == "FIX-WF-CONV-*")
        #expect(convergence.fixtureMappings.count == 13)
        #expect(convergence.fixtureMappings.map(\.checkID) == Self.allConvergenceChecks)
        for mapping in convergence.fixtureMappings {
            let stem = mapping.checkID
                .replacingOccurrences(of: "CHK-WF-CONV-", with: "")
                .replacingOccurrences(of: "CHK-", with: "")
            #expect(mapping.positiveFixtureIDs == ["FIX-WF-CONV-\(stem)-PASS"])
            #expect(mapping.negativeFixtureIDs == ["FIX-WF-CONV-\(stem)-FAIL-001"])
        }
        #expect(convergence.requiredEvidenceKinds == [
            "review_confirmation_receipt/v1",
            "review_convergence_receipt/v1",
        ])

        let canonicalData = try canonicalFileData(registry)
        #expect(data == canonicalData)
        let object = try JSONSerialization.jsonObject(with: data)
        let keys = recursiveKeys(in: object)
        #expect(keys.isDisjoint(with: Self.forbiddenWorkflowKeys))
    }

    @Test("namespace registry is strict, canonical, and resolves by longest prefix")
    func namespaceRegistryBootstrap() throws {
        let data = try registryData("namespaces.v1.json")
        let registry = try CanonicalJSON.decode(StrictNamespaceRegistry.self, from: data)

        #expect(registry.schemaVersion == 1)
        #expect(registry.resolutionPolicy == "longest_prefix")
        #expect(registry.allocations == Self.namespaceAllocations)
        let allocationKeys = registry.allocations.map { $0.identityKind + "\u{0}" + $0.pattern }
        #expect(allocationKeys == allocationKeys.sorted())
        let canonicalData = try canonicalFileData(registry)
        #expect(data == canonicalData)

        for allocation in registry.allocations {
            let wildcardCount = allocation.pattern.count(where: { $0 == "*" })
            #expect(wildcardCount == 0 || (wildcardCount == 1 && allocation.pattern.hasSuffix("*")))
            #expect(!allocation.stewardRoleID.isEmpty)
            #expect(
                allocation.stewardRoleID
                    == allocation.stewardRoleID.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        #expect(Set(allocationKeys).count == allocationKeys.count)

        for projection in Self.namespaceProjections {
            let mostSpecific = registry.mostSpecificAllocations(for: projection)
            #expect(mostSpecific.count == 1, "\(projection.id) must resolve without a longest-prefix tie")
            let resolved = try #require(mostSpecific.first)
            #expect(resolved.pattern == projection.expectedPattern)
            #expect(resolved.stewardRoleID == projection.expectedStewardRoleID)
        }
    }

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

private extension CanonRegistryFileTests {
    static let approvedRequirementOwners = [
        "ENT-ACCESSIBILITY": "Accessibility Owner",
        "ENT-CONCURRENCY": "Concurrency Chapter Owner",
        "ENT-DATA": "Data Lifecycle Owner",
        "ENT-OBSERVABILITY": "Operability Owner",
        "ENT-PERFORMANCE": "Performance Owner",
        "ENT-PRIVACY": "Privacy Owner",
        "ENT-SECURITY": "Security Owner",
        "ENT-SUPPLY": "Security/Legal Owner",
        "ENT-SWIFTUI": "SwiftUI Profile Owner",
        "ENT-TESTING": "Testing Owner",
        "P0-1": "Workflow Maintainer",
        "P0-2": "Runtime/Agent Owner",
        "P0-3": "Verification Owner",
        "P0-4": "Canon Maintainer",
        "P0-5": "Scaffolding Owner",
        "P0-6": "Workflow Maintainer",
        "P0-7": "Security/Compliance Owner",
        "REQ-AGENTS": "Runtime/Agent Owner",
        "REQ-BOARDY": "iOS Profile Owner",
        "REQ-CANON": "Canon Maintainer",
        "REQ-CONVERGENCE": "Workflow Maintainer",
        "REQ-EFFECTS": "Workflow Maintainer",
        "REQ-MIGRATION": "Release Steward",
        "REQ-RC": "Release Steward",
        "REQ-RUNTIME": "Runtime/Agent Owner",
        "REQ-VERIFY": "Verification Owner",
    ]

    static let approvedRequirementIDs = approvedRequirementOwners.keys.sorted()

    static let internalConvergenceChecks = [
        "CHK-WF-CONV-BASELINE-001",
        "CHK-WF-CONV-INVENTORY-001",
        "CHK-WF-CONV-REGISTER-001",
        "CHK-WF-CONV-DISPOSITION-001",
        "CHK-WF-CONV-REMEDIATION-001",
        "CHK-WF-CONV-CONFIRMATION-001",
        "CHK-WF-CONV-EXCEPTION-001",
        "CHK-WF-CONV-INVALIDATION-001",
    ]

    static let publicConvergenceChecks = [
        "CHK-FLOW-CONVERGENCE",
        "CHK-AGENT-CONVERGENCE",
        "CHK-EVIDENCE-CONVERGENCE",
        "CHK-RUN-CONVERGENCE",
        "CHK-RELEASE-CONVERGENCE",
    ]

    static let allConvergenceChecks = internalConvergenceChecks + publicConvergenceChecks

    static let registryFilenames = [
        "adrs.index.json",
        "chapters.index.json",
        "derived-artifacts.index.json",
        "namespaces.v1.json",
        "profiles.index.json",
        "requirements.v1.json",
        "rules.index.json",
    ]

    static let digestA = String(repeating: "a", count: 64)
    static let digestB = String(repeating: "b", count: 64)
    static let digestC = String(repeating: "c", count: 64)

    static let syntheticRecordIndexData = Data(
        """
        {"entries":[{"id":"CAN-AUTH-001","record_digest":"\(digestA)","relative_path":"rules/core/canon.rules.json"}],"id":"rules","schema_version":1}
        """.utf8
    )

    static let syntheticDerivedArtifactIndexData = Data(
        """
        {"entries":[{"artifact_kind":"skill","cited_adr_ids":["ADR-0001"],"cited_rule_ids":["CAN-DERIVED-001"],"file_digest":"\(digestA)","index_key":"standards.brain","source_semantic_bindings":[{"digest":"\(digestB)","source_id":"ADR-0001","source_kind":"adr"},{"digest":"\(digestC)","source_id":"CAN-DERIVED-001","source_kind":"rule"}],"target_path":"skills/brain-flow/SKILL.md"}],"id":"derived-artifacts","schema_version":1}
        """.utf8
    )

    static let namespaceAllocations = [
        StrictNamespaceAllocation(
            identityKind: "adr",
            pattern: "ADR-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "accessibility-global-readiness",
            stewardRoleID: "Accessibility Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "data-lifecycle",
            stewardRoleID: "Data Lifecycle Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "mobile-security",
            stewardRoleID: "Security Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "modern-testing",
            stewardRoleID: "Testing Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "observability-operability",
            stewardRoleID: "Operability Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "performance-resilience",
            stewardRoleID: "Performance Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "privacy-compliance",
            stewardRoleID: "Privacy Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "supply-chain-legal",
            stewardRoleID: "Security/Legal Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "swift-6-concurrency",
            stewardRoleID: "Concurrency Chapter Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "swiftui-production",
            stewardRoleID: "SwiftUI Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "check",
            pattern: "CHK-*",
            stewardRoleID: "Verification Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "check",
            pattern: "CHK-AGENT-CONVERGENCE",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "check",
            pattern: "CHK-EVIDENCE-CONVERGENCE",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "check",
            pattern: "CHK-FLOW-CONVERGENCE",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "check",
            pattern: "CHK-RELEASE-CONVERGENCE",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "check",
            pattern: "CHK-RUN-CONVERGENCE",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "check",
            pattern: "CHK-WF-CONV-*",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "derived_artifact",
            pattern: "enterprise-routing.*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "derived_artifact",
            pattern: "runtime-agents.*",
            stewardRoleID: "Runtime/Agent Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "derived_artifact",
            pattern: "scaffolds.*",
            stewardRoleID: "Scaffolding Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "derived_artifact",
            pattern: "standards.*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "fixture",
            pattern: "FIX-*",
            stewardRoleID: "Verification Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "migration",
            pattern: "MIG-*",
            stewardRoleID: "Release Steward"
        ),
        StrictNamespaceAllocation(
            identityKind: "profile",
            pattern: "assurance-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "profile",
            pattern: "boardy-vip",
            stewardRoleID: "iOS Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "profile",
            pattern: "build-*",
            stewardRoleID: "Scaffolding Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "profile",
            pattern: "core",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "profile",
            pattern: "swiftui",
            stewardRoleID: "SwiftUI Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "profile",
            pattern: "uikit",
            stewardRoleID: "iOS Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "requirement",
            pattern: "ENT-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "requirement",
            pattern: "P0-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "requirement",
            pattern: "P1-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "requirement",
            pattern: "P2-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "requirement",
            pattern: "P3-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "requirement",
            pattern: "REQ-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "A11Y-*",
            stewardRoleID: "Accessibility Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "ADP-*",
            stewardRoleID: "Runtime/Agent Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "ADR-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "AGT-CAP-*",
            stewardRoleID: "Runtime/Agent Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "AGT-ROLE-*",
            stewardRoleID: "Runtime/Agent Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "AGT-SOD-*",
            stewardRoleID: "Runtime/Agent Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "BRD-*",
            stewardRoleID: "iOS Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "CAN-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "CAN-AUTH-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "CAN-CONSIST-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "CONC-*",
            stewardRoleID: "Concurrency Chapter Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "CORE-*",
            stewardRoleID: "Chief Architecture Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "DATA-*",
            stewardRoleID: "Data Lifecycle Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "EFF-*",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "EVD-CMD-*",
            stewardRoleID: "Runtime/Agent Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "EVD-TRUST-*",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "I18N-*",
            stewardRoleID: "Accessibility Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "LEGAL-*",
            stewardRoleID: "Security/Legal Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "MIG-*",
            stewardRoleID: "Release Steward"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "MSEC-*",
            stewardRoleID: "Security Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "OBS-*",
            stewardRoleID: "Operability Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "PERF-*",
            stewardRoleID: "Performance Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "PRIV-*",
            stewardRoleID: "Privacy Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "REL-*",
            stewardRoleID: "Release Steward"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "RES-*",
            stewardRoleID: "Performance Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "SCF-SAFE-*",
            stewardRoleID: "Scaffolding Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "SEC-*",
            stewardRoleID: "Security/Compliance Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "SUP-*",
            stewardRoleID: "Security/Legal Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "SWUI-*",
            stewardRoleID: "SwiftUI Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "TEST-*",
            stewardRoleID: "Testing Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "UI-*",
            stewardRoleID: "iOS Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "UI-HUMBLE-*",
            stewardRoleID: "iOS Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "UIKIT-*",
            stewardRoleID: "iOS Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "VER-*",
            stewardRoleID: "Verification Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "VER-IOS-*",
            stewardRoleID: "Verification Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "VER-VERSION-*",
            stewardRoleID: "Release Steward"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "WF-BYPASS-*",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "WF-FSM-*",
            stewardRoleID: "Workflow Maintainer"
        ),
    ]

    static let namespaceProjections = [
        NamespaceProjection(
            identityKind: "rule",
            id: "WF-BYPASS-ROUTE-001",
            expectedPattern: "WF-BYPASS-*",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "AGT-CAP-EXEC-001",
            expectedPattern: "AGT-CAP-*",
            expectedStewardRoleID: "Runtime/Agent Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "EVD-CMD-AUTH-001",
            expectedPattern: "EVD-CMD-*",
            expectedStewardRoleID: "Runtime/Agent Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "VER-IOS-CONTENT-001",
            expectedPattern: "VER-IOS-*",
            expectedStewardRoleID: "Verification Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "CAN-CONSIST-SNAPSHOT-001",
            expectedPattern: "CAN-CONSIST-*",
            expectedStewardRoleID: "Canon Maintainer"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "SCF-SAFE-PATH-001",
            expectedPattern: "SCF-SAFE-*",
            expectedStewardRoleID: "Scaffolding Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "WF-FSM-RESUME-001",
            expectedPattern: "WF-FSM-*",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "SEC-TRUST-001",
            expectedPattern: "SEC-*",
            expectedStewardRoleID: "Security/Compliance Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "LEGAL-LICENSE-001",
            expectedPattern: "LEGAL-*",
            expectedStewardRoleID: "Security/Legal Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "SUP-PROVENANCE-001",
            expectedPattern: "SUP-*",
            expectedStewardRoleID: "Security/Legal Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "CAN-AUTH-REGISTRY-001",
            expectedPattern: "CAN-AUTH-*",
            expectedStewardRoleID: "Canon Maintainer"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "UI-HUMBLE-VIEW-001",
            expectedPattern: "UI-HUMBLE-*",
            expectedStewardRoleID: "iOS Profile Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "ADP-CLAUDE-001",
            expectedPattern: "ADP-*",
            expectedStewardRoleID: "Runtime/Agent Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "AGT-ROLE-OWNER-001",
            expectedPattern: "AGT-ROLE-*",
            expectedStewardRoleID: "Runtime/Agent Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "AGT-SOD-APPROVAL-001",
            expectedPattern: "AGT-SOD-*",
            expectedStewardRoleID: "Runtime/Agent Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "EFF-FENCE-001",
            expectedPattern: "EFF-*",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "EVD-TRUST-SIGNATURE-001",
            expectedPattern: "EVD-TRUST-*",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "VER-CLI-001",
            expectedPattern: "VER-*",
            expectedStewardRoleID: "Verification Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "VER-VERSION-MIGRATION-001",
            expectedPattern: "VER-VERSION-*",
            expectedStewardRoleID: "Release Steward"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "MIG-LEGACY-001",
            expectedPattern: "MIG-*",
            expectedStewardRoleID: "Release Steward"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "REL-MANIFEST-001",
            expectedPattern: "REL-*",
            expectedStewardRoleID: "Release Steward"
        ),
        NamespaceProjection(
            identityKind: "check",
            id: "CHK-CAN-AUTH-001",
            expectedPattern: "CHK-*",
            expectedStewardRoleID: "Verification Owner"
        ),
        NamespaceProjection(
            identityKind: "check",
            id: "CHK-WF-CONV-BASELINE-001",
            expectedPattern: "CHK-WF-CONV-*",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "check",
            id: "CHK-FLOW-CONVERGENCE",
            expectedPattern: "CHK-FLOW-CONVERGENCE",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "check",
            id: "CHK-AGENT-CONVERGENCE",
            expectedPattern: "CHK-AGENT-CONVERGENCE",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "check",
            id: "CHK-EVIDENCE-CONVERGENCE",
            expectedPattern: "CHK-EVIDENCE-CONVERGENCE",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "check",
            id: "CHK-RUN-CONVERGENCE",
            expectedPattern: "CHK-RUN-CONVERGENCE",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "check",
            id: "CHK-RELEASE-CONVERGENCE",
            expectedPattern: "CHK-RELEASE-CONVERGENCE",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
    ]

    static let indexDescriptors = [
        IndexDescriptor(filename: "adrs.index.json", id: "adrs", entryKind: .record),
        IndexDescriptor(filename: "chapters.index.json", id: "chapters", entryKind: .record),
        IndexDescriptor(filename: "derived-artifacts.index.json", id: "derived-artifacts", entryKind: .derivedArtifact),
        IndexDescriptor(filename: "profiles.index.json", id: "profiles", entryKind: .record),
        IndexDescriptor(filename: "rules.index.json", id: "rules", entryKind: .record),
    ]

    static let forbiddenWorkflowKeys: Set<String> = [
        "approval_record",
        "review_baseline",
        "review_cycle",
        "review_round",
        "run_id",
        "stage_submission",
        "transition_receipt",
        "workflow_state",
    ]

    var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    var canonRoot: URL {
        pluginRoot.appendingPathComponent("standards/canon")
    }

    var registryRoot: URL {
        canonRoot.appendingPathComponent("registry")
    }

    func registryData(_ filename: String) throws -> Data {
        try Data(contentsOf: registryRoot.appendingPathComponent(filename))
    }

    func canonicalFileData(_ value: some Encodable) throws -> Data {
        var data = try CanonicalJSON.encode(value)
        data.append(0x0A)
        return data
    }

    func recursiveKeys(in value: Any) -> Set<String> {
        if let object = value as? [String: Any] {
            return object.reduce(into: Set(object.keys)) { result, element in
                result.formUnion(recursiveKeys(in: element.value))
            }
        }
        if let array = value as? [Any] {
            return array.reduce(into: []) { result, element in
                result.formUnion(recursiveKeys(in: element))
            }
        }
        return []
    }
}

private struct IndexDescriptor {
    let filename: String
    let id: String
    let entryKind: IndexEntryKind
}

private struct NamespaceProjection {
    let identityKind: String
    let id: String
    let expectedPattern: String
    let expectedStewardRoleID: String
}

private enum IndexEntryKind {
    case record
    case derivedArtifact
}

private struct StrictRecordIndex: Codable, Equatable {
    let schemaVersion: Int
    let id: String
    let entries: [StrictRecordIndexEntry]

    init(from decoder: any Decoder) throws {
        try rejectAdditionalKeys(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        id = try container.decode(String.self, forKey: .id)
        entries = try container.decode([StrictRecordIndexEntry].self, forKey: .entries)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case id
        case entries
    }
}

private struct StrictRecordIndexEntry: Codable, Equatable {
    let id: String
    let relativePath: CanonicalRelativePath
    let recordDigest: HashDigest

    init(from decoder: any Decoder) throws {
        try rejectAdditionalKeys(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        relativePath = try container.decode(CanonicalRelativePath.self, forKey: .relativePath)
        recordDigest = try container.decode(HashDigest.self, forKey: .recordDigest)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case relativePath = "relative_path"
        case recordDigest = "record_digest"
    }
}

private struct StrictDerivedArtifactIndex: Codable, Equatable {
    let schemaVersion: Int
    let id: String
    let entries: [DerivedRegistrationEntry]

    init(from decoder: any Decoder) throws {
        try rejectAdditionalKeys(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        id = try container.decode(String.self, forKey: .id)
        entries = try container.decode([DerivedRegistrationEntry].self, forKey: .entries)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case id
        case entries
    }
}

private struct StrictNamespaceRegistry: Codable, Equatable {
    let schemaVersion: Int
    let resolutionPolicy: String
    let allocations: [StrictNamespaceAllocation]

    init(from decoder: any Decoder) throws {
        try rejectAdditionalKeys(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        resolutionPolicy = try container.decode(String.self, forKey: .resolutionPolicy)
        allocations = try container.decode([StrictNamespaceAllocation].self, forKey: .allocations)
    }

    func mostSpecificAllocations(for projection: NamespaceProjection) -> [StrictNamespaceAllocation] {
        let matching = allocations.compactMap { allocation -> (StrictNamespaceAllocation, Int)? in
            guard allocation.identityKind == projection.identityKind,
                  let specificity = allocation.matchSpecificity(for: projection.id)
            else { return nil }
            return (allocation, specificity)
        }
        guard let maximumSpecificity = matching.map(\.1).max() else { return [] }
        return matching
            .filter { $0.1 == maximumSpecificity }
            .map(\.0)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case resolutionPolicy = "resolution_policy"
        case allocations
    }
}

private struct StrictNamespaceAllocation: Codable, Equatable {
    let identityKind: String
    let pattern: String
    let stewardRoleID: String

    init(
        identityKind: String,
        pattern: String,
        stewardRoleID: String
    ) {
        self.identityKind = identityKind
        self.pattern = pattern
        self.stewardRoleID = stewardRoleID
    }

    init(from decoder: any Decoder) throws {
        try rejectAdditionalKeys(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identityKind = try container.decode(String.self, forKey: .identityKind)
        pattern = try container.decode(String.self, forKey: .pattern)
        stewardRoleID = try container.decode(String.self, forKey: .stewardRoleID)
    }

    func matchSpecificity(for id: String) -> Int? {
        if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast())
            return id.hasPrefix(prefix) ? prefix.utf8.count : nil
        }
        return id == pattern ? pattern.utf8.count : nil
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case identityKind = "identifier_kind"
        case pattern
        case stewardRoleID = "steward_role_id"
    }
}

private struct StrictRegistryCodingKey: CodingKey {
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

private func rejectAdditionalKeys(
    from decoder: any Decoder,
    allowed: Set<String>
) throws {
    let container = try decoder.container(keyedBy: StrictRegistryCodingKey.self)
    let additional = container.allKeys
        .map(\.stringValue)
        .filter { !allowed.contains($0) }
        .sorted()
    guard additional.isEmpty else {
        throw DecodingError.dataCorrupted(.init(
            codingPath: decoder.codingPath,
            debugDescription: "Unexpected bootstrap registry keys: \(additional)"
        ))
    }
}
