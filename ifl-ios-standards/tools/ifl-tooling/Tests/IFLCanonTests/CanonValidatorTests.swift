import Foundation
@testable import IFLCanon
import IFLContracts
import Testing

@Suite("CanonValidatorTests", .serialized)
struct CanonValidatorTests {
    @Test("the positive minimal Canon has no semantic findings")
    func cleanBaseline() throws {
        #expect(try CanonValidator().validate(load(CanonRepositoryFixture.positiveRoot)).isEmpty)
    }

    @Test("missing Rule profile and ADR references are collected")
    func missingRuleReferences() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try mutateRule(in: root) { rule in
                rule["profile_ids"] = ["missing-profile"]
                rule["rationale_adrs"] = ["ADR-9998"]
            }

            let findings = try CanonValidator().validate(load(root))
            #expect(findings.count { $0.checkID == "CHK-CAN-REFERENCE-001" } == 2)
            #expect(findings.flatMap(\.evidenceReferences).contains("profile:missing-profile"))
            #expect(findings.flatMap(\.evidenceReferences).contains("adr:ADR-9998"))
        }
    }

    @Test("a missing Profile Rule also reports Rule Profile membership drift")
    func missingProfileRuleAndMembershipDrift() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try CanonRepositoryFixture.mutateObject(
                at: "profiles/minimal.profile.json",
                in: root
            ) { profile in
                profile["rule_ids"] = ["CAN-MISSING-001"]
            }
            try CanonRepositoryFixture.updateRecordDigest(
                for: "profiles/minimal.profile.json",
                in: "profiles.index.json",
                root: root
            )

            let findings = try CanonValidator().validate(load(root))
            #expect(findings.contains { finding in
                finding.checkID == "CHK-CAN-REFERENCE-001"
                    && finding.evidenceReferences.contains("rule:CAN-MISSING-001")
            })
            #expect(findings.contains { finding in
                finding.checkID == "CHK-CAN-PROFILE-001"
                    && finding.evidenceReferences.contains("rule:CAN-MINIMAL-001")
                    && finding.evidenceReferences.contains("profile:core")
            })
        }
    }

    @Test("a selected Profile cannot select a non-active Rule")
    func selectedProfileRuleMustBeActive() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try mutateRule(in: root) { rule in
                rule["lifecycle"] = "accepted"
            }

            let findings = try CanonValidator().validate(load(root))
            #expect(findings.contains { finding in
                finding.checkID == "CHK-CAN-PROFILE-001"
                    && finding.evidenceReferences == ["profile:core", "rule:CAN-MINIMAL-001"]
            })
        }
    }

    @Test("unresolved ADR mappings and decision drift are collected")
    func adrMappingAndDecisionDrift() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try CanonRepositoryFixture.mutateObject(
                at: "adrs/ADR-9999-minimal-test.json",
                in: root
            ) { adr in
                adr["affected_rule_ids"] = ["CAN-MISSING-001"]
                adr["affected_profile_ids"] = ["missing-profile"]
                adr["check_ids"] = ["CHK-CAN-MISSING-001"]
                adr["fixture_ids"] = ["FIX-CAN-MISSING-001-FAIL-001"]
                adr["decision"] = "A metadata decision that differs from Markdown."
            }
            try CanonRepositoryFixture.updateRecordDigest(
                for: "adrs/ADR-9999-minimal-test.json",
                in: "adrs.index.json",
                root: root
            )

            let findings = try CanonValidator().validate(load(root))
                .filter { $0.checkID == "CHK-ADR-LIFECYCLE-001" }
            let evidence = Set(findings.flatMap(\.evidenceReferences))
            #expect(evidence.contains("rule:CAN-MISSING-001"))
            #expect(evidence.contains("profile:missing-profile"))
            #expect(evidence.contains("check:CHK-CAN-MISSING-001"))
            #expect(evidence.contains("fixture:FIX-CAN-MISSING-001-FAIL-001"))
            #expect(findings.contains { $0.message.contains("Decision") })
        }
    }

    @Test("traceability reports a missing Rule binding and an unowned active Rule")
    func traceabilityRuleResolutionAndOwnership() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try CanonRepositoryFixture.mutateObject(
                at: "registry/requirements.v1.json",
                in: root
            ) { registry in
                var traceability = try #require(
                    registry["traceability"] as? [CanonRepositoryFixture.JSONObject]
                )
                let canonIndex = try #require(traceability.firstIndex {
                    $0["requirement_id"] as? String == "REQ-CANON"
                })
                traceability[canonIndex]["rule_bindings"] = [[
                    "owner_role_id": "Canon Maintainer",
                    "rule_id": "CAN-MISSING-001",
                ]]
                registry["traceability"] = traceability
            }

            let findings = try CanonValidator().validate(load(root))
                .filter { $0.checkID == "CHK-CAN-TRACEABILITY-001" }
            #expect(findings.contains { $0.evidenceReferences.contains("rule:CAN-MISSING-001") })
            #expect(findings.contains { $0.evidenceReferences.contains("rule:CAN-MINIMAL-001") })
        }
    }

    @Test("a structurally loadable Chapter validates references and accountable owner")
    func chapterReferencesAndOwner() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try installInvalidChapter(in: root)

            let findings = try CanonValidator().validate(load(root))
            #expect(findings.contains { finding in
                finding.checkID == "CHK-CAN-REFERENCE-001"
                    && finding.evidenceReferences == [
                        "chapter:minimal",
                        "requirement:REQ-CANON",
                        "rule:CAN-MISSING-001",
                    ]
            })
            #expect(findings.contains { finding in
                finding.checkID == "CHK-CAN-REFERENCE-001"
                    && finding.evidenceReferences == [
                        "adr:ADR-9998",
                        "chapter:minimal",
                        "requirement:REQ-CANON",
                    ]
            })
            #expect(findings.count { $0.checkID == "CHK-CAN-TRACEABILITY-001" } == 4)
        }
    }

    @Test("missing and stale derived semantic sources are collected")
    func derivedBindings() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try CanonRepositoryFixture.mutateObject(
                at: "registry/derived-artifacts.index.json",
                in: root
            ) { index in
                index["entries"] = [
                    derivedEntry(
                        key: "missing-source",
                        targetPath: "generated/missing.md",
                        ruleID: "CAN-MISSING-001"
                    ),
                    derivedEntry(
                        key: "stale-source",
                        targetPath: "generated/stale.md",
                        ruleID: "CAN-MINIMAL-001"
                    ),
                ]
            }

            let findings = try CanonValidator().validate(load(root))
                .filter { $0.checkID == "CHK-CAN-DERIVED-001" }
            #expect(findings.count == 2)
            #expect(findings.contains { $0.evidenceReferences.contains("rule:CAN-MISSING-001") })
            #expect(findings.contains { $0.evidenceReferences.contains("rule:CAN-MINIMAL-001") })
        }
    }

    @Test("validation collects all defects in canonical deterministic order")
    func collectAllDeterministicOrdering() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try mutateRule(in: root) { rule in
                rule["profile_ids"] = ["missing-profile"]
                rule["rationale_adrs"] = ["ADR-9998"]
            }
            try CanonRepositoryFixture.mutateObject(
                at: "registry/derived-artifacts.index.json",
                in: root
            ) { index in
                index["entries"] = [
                    derivedEntry(
                        key: "missing-source",
                        targetPath: "generated/missing.md",
                        ruleID: "CAN-MISSING-001"
                    ),
                    derivedEntry(
                        key: "stale-source",
                        targetPath: "generated/stale.md",
                        ruleID: "CAN-MINIMAL-001"
                    ),
                ]
            }

            let snapshot = try load(root)
            let first = CanonValidator().validate(snapshot)
            let permuted = CanonSnapshot(
                canonVersion: snapshot.canonVersion,
                rules: Array(snapshot.rules.reversed()),
                profiles: Array(snapshot.profiles.reversed()),
                selectedProfileIDs: Array(snapshot.selectedProfileIDs.reversed()),
                adrs: Array(snapshot.adrs.reversed()),
                adrMarkdownByID: snapshot.adrMarkdownByID,
                chapters: Array(snapshot.chapters.reversed()),
                requirementRegistry: snapshot.requirementRegistry,
                derivedArtifacts: Array(snapshot.derivedArtifacts.reversed()),
                snapshotContentDigest: snapshot.snapshotContentDigest
            )
            let expected = [
                CanonFinding(
                    checkID: "CHK-ADR-LIFECYCLE-001",
                    severity: .high,
                    message: "ADR ADR-9999 affects Rule CAN-MINIMAL-001, but the Rule does not cite the ADR as rationale.",
                    evidenceReferences: ["adr:ADR-9999", "rule:CAN-MINIMAL-001"]
                ),
                CanonFinding(
                    checkID: "CHK-CAN-DERIVED-001",
                    severity: .high,
                    message: "Derived artifact missing-source binds missing rule CAN-MISSING-001.",
                    evidenceReferences: ["derived:missing-source", "rule:CAN-MISSING-001"]
                ),
                CanonFinding(
                    checkID: "CHK-CAN-DERIVED-001",
                    severity: .high,
                    message: "Derived artifact stale-source has a stale semantic digest for rule CAN-MINIMAL-001.",
                    evidenceReferences: ["derived:stale-source", "rule:CAN-MINIMAL-001"]
                ),
                CanonFinding(
                    checkID: "CHK-CAN-PROFILE-001",
                    severity: .high,
                    message: "Rule CAN-MINIMAL-001 and Profile core membership is not reciprocal.",
                    evidenceReferences: ["profile:core", "rule:CAN-MINIMAL-001"]
                ),
                CanonFinding(
                    checkID: "CHK-CAN-REFERENCE-001",
                    severity: .high,
                    message: "Rule CAN-MINIMAL-001 references missing Profile missing-profile.",
                    evidenceReferences: ["profile:missing-profile", "rule:CAN-MINIMAL-001"]
                ),
                CanonFinding(
                    checkID: "CHK-CAN-REFERENCE-001",
                    severity: .high,
                    message: "Rule CAN-MINIMAL-001 references missing rationale ADR ADR-9998.",
                    evidenceReferences: ["adr:ADR-9998", "rule:CAN-MINIMAL-001"]
                ),
            ]

            #expect(first == expected)
            #expect(CanonValidator().validate(permuted) == expected)
        }
    }

    private func load(_ root: URL) throws -> CanonSnapshot {
        try FileCanonRepository(root: root).snapshot(
            profiles: [CanonRepositoryFixture.coreProfileID()]
        )
    }

    private func mutateRule(
        in root: URL,
        _ mutation: (inout CanonRepositoryFixture.JSONObject) throws -> Void
    ) throws {
        try CanonRepositoryFixture.mutateObject(
            at: "rules/core/minimal.rules.json",
            in: root,
            mutation
        )
        try CanonRepositoryFixture.updateRecordDigest(
            for: "rules/core/minimal.rules.json",
            in: "rules.index.json",
            root: root
        )
    }

    private func installInvalidChapter(in root: URL) throws {
        let relativePath = "chapters/minimal.chapter.json"
        try CanonRepositoryFixture.writeCanonicalJSONObject(
            [
                "applicability": ["canon-fixture"],
                "check_ids": ["CHK-CAN-MISSING-001"],
                "compliant_example_ids": ["FIX-CAN-EXAMPLE-001-PASS"],
                "exception_policy": "No exceptions apply to this fixture chapter.",
                "id": "minimal",
                "negative_fixture_ids": ["FIX-CAN-MISSING-001-FAIL-001"],
                "non_compliant_example_ids": ["FIX-CAN-EXAMPLE-001-FAIL-001"],
                "owner_role_id": "Alternate Canon Owner",
                "positive_fixture_ids": ["FIX-CAN-MISSING-001-PASS"],
                "rationale": "Exercise semantic chapter validation.",
                "rationale_adr_ids": ["ADR-9998"],
                "required_evidence_kinds": ["contract_test"],
                "required_rule_dependencies": [],
                "requirement_id": "REQ-CANON",
                "review_cadence": "per_release",
                "review_checklist_ids": ["CAN-CHAPTER-REVIEW-001"],
                "rule_ids": ["CAN-MISSING-001"],
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
}

private let staleDigest = String(repeating: "0", count: 64)

private func derivedEntry(
    key: String,
    targetPath: String,
    ruleID: String
) -> CanonRepositoryFixture.JSONObject {
    [
        "artifact_kind": "guide",
        "cited_adr_ids": [],
        "cited_rule_ids": [ruleID],
        "file_digest": staleDigest,
        "index_key": key,
        "source_semantic_bindings": [[
            "digest": staleDigest,
            "source_id": ruleID,
            "source_kind": "rule",
        ]],
        "target_path": targetPath,
    ]
}
