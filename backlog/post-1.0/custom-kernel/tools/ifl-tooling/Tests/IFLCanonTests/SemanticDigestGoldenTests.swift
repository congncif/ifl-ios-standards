import Foundation
@testable import IFLCanon
import Testing

@Suite("SemanticDigestGoldenTests")
struct SemanticDigestGoldenTests {
    @Test("Rule base preimage and SHA are pinned")
    func ruleBaseVector() throws {
        let rule = try CanonTestFixture.rule()

        #expect(String(decoding: try RuleSemanticDigest.preimage(rule), as: UTF8.self) == Self.ruleBase)
        #expect(try RuleSemanticDigest.digest(rule).rawValue == "10bef04ab4c1eccada91d9fff28c88d672363bf7a769a54bf738723286279f2d")
    }

    @Test("Rule optional-present and ordered preimages are pinned")
    func ruleOptionalAndOrderVectors() throws {
        let optional = try CanonTestFixture.rule {
            $0["lifecycle"] = "retired"
            $0["replacement_id"] = "CAN-MINIMAL-002"
        }
        let ordered = try CanonTestFixture.rule {
            $0["scope"] = ["canon-fixture", "semantic-digest"]
        }

        #expect(String(decoding: try RuleSemanticDigest.preimage(optional), as: UTF8.self) == Self.ruleOptional)
        #expect(try RuleSemanticDigest.digest(optional).rawValue == "21f73a45b8fce479ac15c2c75c67a3b2398234411bf0667c3b20c15f451f1b20")
        #expect(String(decoding: try RuleSemanticDigest.preimage(ordered), as: UTF8.self) == Self.ruleOrdered)
        #expect(try RuleSemanticDigest.digest(ordered).rawValue == "e0b9bdae819a5a08b065f380781d46834f04bd6671e6e4cbb9f80b81131fdd78")
    }

    @Test("Profile base and ordered preimages are pinned")
    func profileVectors() throws {
        let base = try CanonTestFixture.profile()
        let ordered = try CanonTestFixture.profile {
            $0["rule_ids"] = ["CAN-MINIMAL-001", "CAN-MINIMAL-002"]
        }

        #expect(String(decoding: try ProfileSemanticDigest.preimage(base), as: UTF8.self) == Self.profileBase)
        #expect(try ProfileSemanticDigest.digest(base).rawValue == "4d8293233c20c3a323813a2e4a87aab493d590613aaf5dd3fb10a1456a58ba87")
        #expect(String(decoding: try ProfileSemanticDigest.preimage(ordered), as: UTF8.self) == Self.profileOrdered)
        #expect(try ProfileSemanticDigest.digest(ordered).rawValue == "1d76e189f722b0ec8d2c8a5bb4b566a472137a93853b8eada4e7d5b97eb54e7e")
    }

    @Test("ADR base and optional-present preimages are pinned")
    func adrBaseAndOptionalVectors() throws {
        let markdown = try CanonTestFixture.adrMarkdown()
        let base = try CanonTestFixture.adr()
        let optional = try CanonTestFixture.adr {
            $0["status"] = "superseded"
            $0["superseded_by"] = "ADR-9998"
        }

        #expect(String(decoding: try ADRSemanticDigest.preimage(metadata: base, markdown: markdown), as: UTF8.self) == Self.adrBase)
        #expect(try ADRSemanticDigest.digest(metadata: base, markdown: markdown).rawValue == "4a3999da7809e376b4fec4812ef6a83044feafe39da50d82b4e24e196df2b71d")
        #expect(String(decoding: try ADRSemanticDigest.preimage(metadata: optional, markdown: markdown), as: UTF8.self) == Self.adrOptional)
        #expect(try ADRSemanticDigest.digest(metadata: optional, markdown: markdown).rawValue == "a58acf2079ba5673f06b7a137ec75fdd1ba4ba2bcae30d791c2076350ef62a3a")
    }

    @Test("ADR ordered and CRLF-normalized preimages are pinned")
    func adrOrderAndNormalizationVectors() throws {
        let markdown = try CanonTestFixture.adrMarkdown()
        let ordered = try CanonTestFixture.adr {
            $0["affected_rule_ids"] = ["CAN-MINIMAL-001", "CAN-MINIMAL-002"]
        }
        let crlf = markdown.replacingOccurrences(of: "\n", with: "\r\n")
        let crlfMetadata = try CanonTestFixture.adr(matchingMarkdown: crlf)

        #expect(String(decoding: try ADRSemanticDigest.preimage(metadata: ordered, markdown: markdown), as: UTF8.self) == Self.adrOrdered)
        #expect(try ADRSemanticDigest.digest(metadata: ordered, markdown: markdown).rawValue == "8176008d4a33b6cb5973128b77a30d64e0bd3c1675eef5bc9c468e73f4dbc8a8")
        #expect(String(decoding: try ADRSemanticDigest.preimage(metadata: crlfMetadata, markdown: crlf), as: UTF8.self) == Self.adrCRLF)
        #expect(try ADRSemanticDigest.digest(metadata: crlfMetadata, markdown: crlf).rawValue == "1e642aff5f9e9d9cae70b7c2b3bc690eeaf54026f948131c34db393496765670")
    }

    private static let ruleBase = #"{"compliant_example_ids":[],"enforcement":"script","evidence":["deterministic contract fixture"],"examples_required":false,"exception_policy":"No exceptions apply to this test-only fixture.","id":"CAN-MINIMAL-001","introduced_in":"1.0.0-rc.1","level":"must","non_compliant_example_ids":[],"profile_ids":["core"],"rationale_adrs":["ADR-9999"],"risk_class":"low","schema_version":1,"scope":["canon-fixture"],"severity":"low","statement":"The minimal Canon fixture must remain deterministic."}"#
    private static let ruleOptional = #"{"compliant_example_ids":[],"enforcement":"script","evidence":["deterministic contract fixture"],"examples_required":false,"exception_policy":"No exceptions apply to this test-only fixture.","id":"CAN-MINIMAL-001","introduced_in":"1.0.0-rc.1","level":"must","non_compliant_example_ids":[],"profile_ids":["core"],"rationale_adrs":["ADR-9999"],"replacement_id":"CAN-MINIMAL-002","risk_class":"low","schema_version":1,"scope":["canon-fixture"],"severity":"low","statement":"The minimal Canon fixture must remain deterministic."}"#
    private static let ruleOrdered = #"{"compliant_example_ids":[],"enforcement":"script","evidence":["deterministic contract fixture"],"examples_required":false,"exception_policy":"No exceptions apply to this test-only fixture.","id":"CAN-MINIMAL-001","introduced_in":"1.0.0-rc.1","level":"must","non_compliant_example_ids":[],"profile_ids":["core"],"rationale_adrs":["ADR-9999"],"risk_class":"low","schema_version":1,"scope":["canon-fixture","semantic-digest"],"severity":"low","statement":"The minimal Canon fixture must remain deterministic."}"#
    private static let profileBase = #"{"applicability":["contract-fixture"],"description":"Minimal profile for deterministic Canon contract tests.","display_name":"Minimal Canon","id":"core","inherits_profile_ids":[],"owner_role_id":"Canon Maintainer","rule_ids":["CAN-MINIMAL-001"],"schema_version":1}"#
    private static let profileOrdered = #"{"applicability":["contract-fixture"],"description":"Minimal profile for deterministic Canon contract tests.","display_name":"Minimal Canon","id":"core","inherits_profile_ids":[],"owner_role_id":"Canon Maintainer","rule_ids":["CAN-MINIMAL-001","CAN-MINIMAL-002"],"schema_version":1}"#
    private static let adrBase = #"{"affected_profile_ids":["core"],"affected_rule_ids":["CAN-MINIMAL-001"],"alternatives":["Keep the fixture indexes empty."],"check_ids":["CHK-CAN-MINIMAL-001"],"consequences":["The fixture remains small and exercises accepted ADR integrity."],"context":"The Canon loader needs one deterministic accepted ADR in its minimal fixture.","decision":"Bind the minimal rule and core profile through one complete atomic mapping.","decision_date":"2026-07-10","fixture_ids":["FIX-CAN-MINIMAL-001-FAIL-001","FIX-CAN-MINIMAL-001-FAIL-002","FIX-CAN-MINIMAL-001-FAIL-003","FIX-CAN-MINIMAL-001-FAIL-004","FIX-CAN-MINIMAL-001-FAIL-005"],"id":"ADR-9999","markdown_decision":"Bind the minimal rule and core profile through one complete atomic mapping.","markdown_digest":"636a09cf6c52903ee772794f2080fd22b7c1804dfe1e979172601ff401ce9460","migration":["No migration is required for this test-only fixture."],"migration_ids":["MIG-CAN-MINIMAL-001"],"owner_role_id":"Canon Maintainer","reference_artifact_ids":["adrs/ADR-9999-minimal-test.md"],"schema_version":1,"supersedes_adr_ids":[],"title":"Minimal Canon Fixture","verification_impact":["Decode the complete index-first root and validate every declared digest."]}"#
    private static let adrOptional = #"{"affected_profile_ids":["core"],"affected_rule_ids":["CAN-MINIMAL-001"],"alternatives":["Keep the fixture indexes empty."],"check_ids":["CHK-CAN-MINIMAL-001"],"consequences":["The fixture remains small and exercises accepted ADR integrity."],"context":"The Canon loader needs one deterministic accepted ADR in its minimal fixture.","decision":"Bind the minimal rule and core profile through one complete atomic mapping.","decision_date":"2026-07-10","fixture_ids":["FIX-CAN-MINIMAL-001-FAIL-001","FIX-CAN-MINIMAL-001-FAIL-002","FIX-CAN-MINIMAL-001-FAIL-003","FIX-CAN-MINIMAL-001-FAIL-004","FIX-CAN-MINIMAL-001-FAIL-005"],"id":"ADR-9999","markdown_decision":"Bind the minimal rule and core profile through one complete atomic mapping.","markdown_digest":"636a09cf6c52903ee772794f2080fd22b7c1804dfe1e979172601ff401ce9460","migration":["No migration is required for this test-only fixture."],"migration_ids":["MIG-CAN-MINIMAL-001"],"owner_role_id":"Canon Maintainer","reference_artifact_ids":["adrs/ADR-9999-minimal-test.md"],"schema_version":1,"superseded_by":"ADR-9998","supersedes_adr_ids":[],"title":"Minimal Canon Fixture","verification_impact":["Decode the complete index-first root and validate every declared digest."]}"#
    private static let adrOrdered = #"{"affected_profile_ids":["core"],"affected_rule_ids":["CAN-MINIMAL-001","CAN-MINIMAL-002"],"alternatives":["Keep the fixture indexes empty."],"check_ids":["CHK-CAN-MINIMAL-001"],"consequences":["The fixture remains small and exercises accepted ADR integrity."],"context":"The Canon loader needs one deterministic accepted ADR in its minimal fixture.","decision":"Bind the minimal rule and core profile through one complete atomic mapping.","decision_date":"2026-07-10","fixture_ids":["FIX-CAN-MINIMAL-001-FAIL-001","FIX-CAN-MINIMAL-001-FAIL-002","FIX-CAN-MINIMAL-001-FAIL-003","FIX-CAN-MINIMAL-001-FAIL-004","FIX-CAN-MINIMAL-001-FAIL-005"],"id":"ADR-9999","markdown_decision":"Bind the minimal rule and core profile through one complete atomic mapping.","markdown_digest":"636a09cf6c52903ee772794f2080fd22b7c1804dfe1e979172601ff401ce9460","migration":["No migration is required for this test-only fixture."],"migration_ids":["MIG-CAN-MINIMAL-001"],"owner_role_id":"Canon Maintainer","reference_artifact_ids":["adrs/ADR-9999-minimal-test.md"],"schema_version":1,"supersedes_adr_ids":[],"title":"Minimal Canon Fixture","verification_impact":["Decode the complete index-first root and validate every declared digest."]}"#
    private static let adrCRLF = #"{"affected_profile_ids":["core"],"affected_rule_ids":["CAN-MINIMAL-001"],"alternatives":["Keep the fixture indexes empty."],"check_ids":["CHK-CAN-MINIMAL-001"],"consequences":["The fixture remains small and exercises accepted ADR integrity."],"context":"The Canon loader needs one deterministic accepted ADR in its minimal fixture.","decision":"Bind the minimal rule and core profile through one complete atomic mapping.","decision_date":"2026-07-10","fixture_ids":["FIX-CAN-MINIMAL-001-FAIL-001","FIX-CAN-MINIMAL-001-FAIL-002","FIX-CAN-MINIMAL-001-FAIL-003","FIX-CAN-MINIMAL-001-FAIL-004","FIX-CAN-MINIMAL-001-FAIL-005"],"id":"ADR-9999","markdown_decision":"Bind the minimal rule and core profile through one complete atomic mapping.","markdown_digest":"3f787122e5f9f849f79ea605e2bb2cbb0c80c02920927e9e08b90600a8cfc251","migration":["No migration is required for this test-only fixture."],"migration_ids":["MIG-CAN-MINIMAL-001"],"owner_role_id":"Canon Maintainer","reference_artifact_ids":["adrs/ADR-9999-minimal-test.md"],"schema_version":1,"supersedes_adr_ids":[],"title":"Minimal Canon Fixture","verification_impact":["Decode the complete index-first root and validate every declared digest."]}"#
}
