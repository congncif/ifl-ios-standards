import Foundation
@testable import IFLCanon
import Testing

@Suite("CanonChapterDependencyTests", .serialized)
struct CanonChapterDependencyTests {
    @Test("a nonempty chapter resolves an active rule with its registered owner")
    func validProductionDependency() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try installChapter(
                requiredRuleID: "CAN-MINIMAL-001",
                expectedOwnerRoleID: "Canon Maintainer",
                in: root
            )

            let snapshot = try load(root)
            #expect(snapshot.chapters.map(\.id) == ["minimal"])
            #expect(snapshot.chapters[0].requiredRuleDependencies.count == 1)
        }
    }

    @Test("a nonempty chapter rejects a missing required rule")
    func missingProductionDependency() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try installChapter(
                requiredRuleID: "CAN-MISSING-001",
                expectedOwnerRoleID: "Canon Maintainer",
                in: root
            )

            let error = CanonRepositoryFixture.contractError { _ = try load(root) }
            #expect(error?.code == "unresolved_reference")
        }
    }

    @Test("a nonempty chapter rejects an indexed rule that is not active")
    func inactiveProductionDependency() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try installChapter(
                requiredRuleID: "CAN-MINIMAL-001",
                expectedOwnerRoleID: "Canon Maintainer",
                in: root
            )
            try CanonRepositoryFixture.mutateObject(
                at: "rules/core/minimal.rules.json",
                in: root
            ) { rule in
                rule["lifecycle"] = "accepted"
            }
            try CanonRepositoryFixture.updateRecordDigest(
                for: "rules/core/minimal.rules.json",
                in: "rules.index.json",
                root: root
            )

            let error = CanonRepositoryFixture.contractError { _ = try load(root) }
            #expect(error?.code == "unresolved_reference")
        }
    }

    @Test("a nonempty chapter rejects a wrong expected owner")
    func wrongProductionDependencyOwner() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try installChapter(
                requiredRuleID: "CAN-MINIMAL-001",
                expectedOwnerRoleID: "Alternate Canon Owner",
                in: root
            )

            let error = CanonRepositoryFixture.contractError { _ = try load(root) }
            #expect(error?.code == "invalid_contract")
        }
    }

    @Test("a nonempty chapter rejects conflicting owners registered for one active rule")
    func conflictingProductionDependencyOwners() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try installChapter(
                requiredRuleID: "CAN-MINIMAL-001",
                expectedOwnerRoleID: "Canon Maintainer",
                in: root
            )
            try CanonRepositoryFixture.mutateObject(
                at: "registry/requirements.v1.json",
                in: root
            ) { registry in
                var traceability = try #require(
                    registry["traceability"] as? [CanonRepositoryFixture.JSONObject]
                )
                traceability.append([
                    "accountable_owner_role_id": "iOS Profile Owner",
                    "fixture_mappings": [[
                        "check_id": "CHK-BOARDY-CONFLICT-001",
                        "negative_fixture_ids": ["FIX-BOARDY-CONFLICT-001-FAIL-001"],
                        "positive_fixture_ids": ["FIX-BOARDY-CONFLICT-001-PASS"],
                    ]],
                    "fixture_namespace": "FIX-BOARDY-*",
                    "internal_check_ids": ["CHK-BOARDY-CONFLICT-001"],
                    "internal_check_namespace": "CHK-BOARDY-*",
                    "public_check_ids": [],
                    "required_evidence_kinds": ["contract_test"],
                    "requirement_id": "REQ-BOARDY",
                    "rule_bindings": [[
                        "owner_role_id": "Alternate Canon Owner",
                        "rule_id": "CAN-MINIMAL-001",
                    ]],
                    "schema_version": 1,
                ])
                traceability.sort {
                    (($0["requirement_id"] as? String) ?? "")
                        < (($1["requirement_id"] as? String) ?? "")
                }
                registry["traceability"] = traceability
            }

            let error = CanonRepositoryFixture.contractError { _ = try load(root) }
            #expect(error?.code == "invalid_contract")
            guard case let .invalidContract(_, reason)? = error else { return }
            #expect(reason.contains("conflicting owners"))
        }
    }

    private func installChapter(
        requiredRuleID: String,
        expectedOwnerRoleID: String,
        in root: URL
    ) throws {
        let relativePath = "chapters/minimal.chapter.json"
        try CanonRepositoryFixture.writeCanonicalJSONObject(
            [
                "applicability": ["canon-fixture"],
                "check_ids": ["CHK-CAN-CHAPTER-001"],
                "compliant_example_ids": ["FIX-CAN-CHAPTER-001-PASS"],
                "exception_policy": "No exceptions apply to this fixture chapter.",
                "id": "minimal",
                "negative_fixture_ids": ["FIX-CAN-CHAPTER-001-FAIL-001"],
                "non_compliant_example_ids": ["FIX-CAN-CHAPTER-002-FAIL-001"],
                "owner_role_id": "Canon Maintainer",
                "positive_fixture_ids": ["FIX-CAN-CHAPTER-002-PASS"],
                "rationale": "Exercise production chapter dependency resolution.",
                "rationale_adr_ids": ["ADR-9999"],
                "required_evidence_kinds": ["contract_test"],
                "required_rule_dependencies": [[
                    "expected_owner_role_id": expectedOwnerRoleID,
                    "required_rule_id": requiredRuleID,
                ]],
                "requirement_id": "REQ-CANON",
                "review_cadence": "per_release",
                "review_checklist_ids": ["CAN-CHAPTER-REVIEW-001"],
                "rule_ids": ["CAN-MINIMAL-001"],
                "schema_version": 1,
                "title": "Minimal Canon chapter",
            ],
            to: relativePath,
            in: root
        )
        try CanonRepositoryFixture.addRecordIndexEntry(
            id: "minimal",
            relativePath: relativePath,
            indexFilename: "chapters.index.json",
            root: root
        )
    }

    private func load(_ root: URL) throws -> CanonSnapshot {
        try FileCanonRepository(root: root).snapshot(
            profiles: [CanonRepositoryFixture.coreProfileID()]
        )
    }
}
