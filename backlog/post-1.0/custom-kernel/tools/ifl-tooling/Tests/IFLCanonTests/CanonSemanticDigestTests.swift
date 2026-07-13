import Foundation
@testable import IFLCanon
import IFLContracts
import Testing

@Suite("CanonSemanticDigestTests")
struct CanonSemanticDigestTests {
    @Test("rule digest excludes lifecycle and effective version only")
    func ruleDigestActivationExclusions() throws {
        let base = try CanonTestFixture.rule()
        let baseDigest = try RuleSemanticDigest.digest(base)

        for lifecycle in ["proposed", "accepted", "retired"] {
            let changed = try CanonTestFixture.rule {
                $0["lifecycle"] = lifecycle
            }
            #expect(try RuleSemanticDigest.digest(changed) == baseDigest)
        }

        let changedEffectiveVersion = try CanonTestFixture.rule {
            $0["effective_in"] = "1.0.0"
        }
        #expect(try RuleSemanticDigest.digest(changedEffectiveVersion) == baseDigest)

        let deprecated = try CanonTestFixture.rule {
            $0["lifecycle"] = "deprecated"
            $0["replacement_id"] = "CAN-MINIMAL-002"
        }
        let retiredWithSameReplacement = try CanonTestFixture.rule {
            $0["lifecycle"] = "retired"
            $0["replacement_id"] = "CAN-MINIMAL-002"
        }
        #expect(
            try RuleSemanticDigest.digest(deprecated)
                == RuleSemanticDigest.digest(retiredWithSameReplacement)
        )
    }

    @Test("rule digest preserves canonical order for every collection field")
    func ruleDigestOrderedCollectionBindings() throws {
        let orderedCollections: [(String, [String])] = [
            ("scope", ["canon-fixture", "semantic-digest"]),
            ("profile_ids", ["core", "enterprise"]),
            ("rationale_adrs", ["ADR-9999", "ADR-9998"]),
            ("evidence", ["deterministic contract fixture", "independent review receipt"]),
            ("compliant_example_ids", ["EX-CAN-PASS-001", "EX-CAN-PASS-002"]),
            ("non_compliant_example_ids", ["EX-CAN-FAIL-001", "EX-CAN-FAIL-002"]),
        ]

        for (field, values) in orderedCollections {
            let forward = try CanonTestFixture.rule { $0[field] = values }
            let reversed = try CanonTestFixture.rule {
                $0[field] = Array(values.reversed())
            }
            #expect(
                try RuleSemanticDigest.digest(forward)
                    != RuleSemanticDigest.digest(reversed),
                "rule semantic digest must preserve ordered \(field)"
            )
        }
    }

    @Test("rule digest binds every author-controlled semantic field")
    func ruleDigestSemanticBindings() throws {
        let base = try CanonTestFixture.rule()
        let baseDigest = try RuleSemanticDigest.digest(base)
        let mutations: [(String, CanonTestFixture.JSONMutation)] = [
            ("id", { $0["id"] = "CAN-MINIMAL-002" }),
            ("level", { $0["level"] = "should" }),
            ("statement", { $0["statement"] = "The changed rule remains deterministic." }),
            ("scope", { $0["scope"] = ["canon-fixture", "semantic-digest"] }),
            ("profile_ids", { $0["profile_ids"] = ["core", "enterprise"] }),
            ("severity", { $0["severity"] = "medium" }),
            ("risk_class", { $0["risk_class"] = "medium" }),
            ("rationale_adrs", { $0["rationale_adrs"] = ["ADR-9999", "ADR-9998"] }),
            (
                "evidence",
                { $0["evidence"] = ["deterministic contract fixture", "review receipt"] }
            ),
            ("enforcement", { $0["enforcement"] = "both" }),
            ("exception_policy", { $0["exception_policy"] = "A changed exception policy." }),
            ("introduced_in", { $0["introduced_in"] = "0.9.0" }),
            ("compliant_example_ids", { $0["compliant_example_ids"] = ["EX-CAN-PASS-001"] }),
            (
                "non_compliant_example_ids",
                { $0["non_compliant_example_ids"] = ["EX-CAN-FAIL-001"] }
            ),
        ]

        for (field, mutation) in mutations {
            let changed = try CanonTestFixture.rule(mutation)
            #expect(
                try RuleSemanticDigest.digest(changed) != baseDigest,
                "rule semantic digest must bind \(field)"
            )
        }

        let retired = try CanonTestFixture.rule {
            $0["lifecycle"] = "retired"
        }
        let retiredWithReplacement = try CanonTestFixture.rule {
            $0["lifecycle"] = "retired"
            $0["replacement_id"] = "CAN-MINIMAL-002"
        }
        #expect(
            try RuleSemanticDigest.digest(retiredWithReplacement)
                != RuleSemanticDigest.digest(retired)
        )

        let optionalExamples = try CanonTestFixture.rule {
            $0["compliant_example_ids"] = ["EX-CAN-PASS-001"]
            $0["non_compliant_example_ids"] = ["EX-CAN-FAIL-001"]
        }
        let requiredExamples = try CanonTestFixture.rule {
            $0["examples_required"] = true
            $0["compliant_example_ids"] = ["EX-CAN-PASS-001"]
            $0["non_compliant_example_ids"] = ["EX-CAN-FAIL-001"]
        }
        #expect(
            try RuleSemanticDigest.digest(requiredExamples)
                != RuleSemanticDigest.digest(optionalExamples)
        )
    }

    @Test("profile digest binds scalars and ordered semantic collections")
    func profileDigestSemanticBindingsAndOrder() throws {
        let base = try CanonTestFixture.profile()
        let baseDigest = try ProfileSemanticDigest.digest(base)
        let scalarMutations: [(String, CanonTestFixture.JSONMutation)] = [
            ("id", { $0["id"] = "core-next" }),
            ("display_name", { $0["display_name"] = "Changed Canon" }),
            ("description", { $0["description"] = "Changed deterministic profile." }),
            ("owner_role_id", { $0["owner_role_id"] = "Alternate Canon Maintainer" }),
        ]

        for (field, mutation) in scalarMutations {
            let changed = try CanonTestFixture.profile(mutation)
            #expect(
                try ProfileSemanticDigest.digest(changed) != baseDigest,
                "profile semantic digest must bind \(field)"
            )
        }

        let orderedPairs: [(String, String, [String])] = [
            ("rule_ids", "rule IDs", ["CAN-MINIMAL-001", "CAN-MINIMAL-002"]),
            ("applicability", "applicability", ["contract-fixture", "enterprise"]),
            ("inherits_profile_ids", "profile inheritance", ["base", "enterprise"]),
        ]
        for (field, label, values) in orderedPairs {
            let forward = try CanonTestFixture.profile { $0[field] = values }
            let reversed = try CanonTestFixture.profile {
                $0[field] = Array(values.reversed())
            }
            #expect(
                try ProfileSemanticDigest.digest(forward)
                    != ProfileSemanticDigest.digest(reversed),
                "profile semantic digest must preserve ordered \(label)"
            )
        }
    }
}
