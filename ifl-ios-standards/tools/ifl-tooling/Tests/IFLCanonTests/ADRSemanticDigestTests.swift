import Foundation
@testable import IFLCanon
import IFLContracts
import Testing

@Suite("ADRSemanticDigestTests")
struct ADRSemanticDigestTests {
    @Test("ADR digest excludes status and accepted_at only")
    func exactActivationExclusions() throws {
        let metadata = try CanonTestFixture.adr()
        let markdown = try CanonTestFixture.adrMarkdown()
        let baseDigest = try ADRSemanticDigest.digest(metadata: metadata, markdown: markdown)

        let changedAcceptanceTimestamp = try CanonTestFixture.adr {
            $0["accepted_at"] = "2026-07-11T00:00:00.000Z"
        }
        #expect(
            try ADRSemanticDigest.digest(
                metadata: changedAcceptanceTimestamp,
                markdown: markdown
            ) == baseDigest
        )

        let inReview = try CanonTestFixture.adr {
            $0["status"] = "in_review"
            $0.removeValue(forKey: "accepted_at")
        }
        #expect(
            try ADRSemanticDigest.digest(metadata: inReview, markdown: markdown) == baseDigest
        )

        let superseded = try CanonTestFixture.adr {
            $0["status"] = "superseded"
            $0["superseded_by"] = "ADR-9998"
        }
        #expect(
            try ADRSemanticDigest.digest(metadata: superseded, markdown: markdown) != baseDigest
        )
    }

    @Test("raw UTF-8 Markdown digest is verified before Decision parsing")
    func rawMarkdownDigestIsVerifiedFirst() throws {
        let metadata = try CanonTestFixture.adr()
        let markdown = try CanonTestFixture.adrMarkdown()
        let variants = [
            markdown.replacingOccurrences(of: "\n", with: "\r\n"),
            markdown.replacingOccurrences(
                of: "The Canon loader needs one deterministic accepted ADR in its minimal fixture.",
                with: "A non-decision section changed."
            ),
            "# ADR without a Decision section\n",
        ]

        for changed in variants {
            let actual = CanonTestFixture.markdownDigest(changed)
            let error = contractError {
                _ = try ADRSemanticDigest.digest(metadata: metadata, markdown: changed)
            }
            #expect(
                error == .digestMismatch(
                    kind: "ADR Markdown",
                    expected: metadata.markdownDigest.rawValue,
                    actual: actual.rawValue
                )
            )
        }
    }

    @Test("updated Markdown digest binds CRLF and non-Decision edits")
    func updatedMarkdownBytesRemainSemantic() throws {
        let markdown = try CanonTestFixture.adrMarkdown()
        let base = try ADRSemanticDigest.digest(
            metadata: CanonTestFixture.adr(),
            markdown: markdown
        )
        let variants = [
            markdown.replacingOccurrences(of: "\n", with: "\r\n"),
            markdown.replacingOccurrences(
                of: "The Canon loader needs one deterministic accepted ADR in its minimal fixture.",
                with: "A non-decision section changed."
            ),
            markdown.replacingOccurrences(
                of: "Bind the minimal rule and core profile through one complete atomic mapping.",
                with: "Bind a materially different decision."
            ),
        ]

        for changed in variants {
            let metadata = try CanonTestFixture.adr(matchingMarkdown: changed)
            #expect(try ADRSemanticDigest.digest(metadata: metadata, markdown: changed) != base)
        }
    }

    @Test("missing duplicate and empty Decision sections have stable public errors")
    func stableDecisionErrors() throws {
        let missing = "# ADR-9999\n\n## Context\n\nNo decision.\n"
        let duplicate = "# ADR-9999\n\n## Decision\n\nFirst.\n\n## Decision\n\nSecond.\n"
        let empty = "# ADR-9999\n\n## Decision\n\n   \n\n## Consequences\n\nNone.\n"

        try expectDecisionError(
            markdown: missing,
            reason: "missing unfenced ## Decision section"
        )
        try expectDecisionError(
            markdown: duplicate,
            reason: "multiple unfenced ## Decision sections"
        )
        try expectDecisionError(
            markdown: empty,
            reason: "unfenced ## Decision section must not be empty"
        )
    }

    @Test("fenced headings do not create or terminate ADR sections")
    func fencedHeadingsAreIgnored() throws {
        let markdown = """
        # ADR-9999

        ```markdown
        ## Decision
        Fenced decoy.
        ```

        ## Decision

        Real decision.
        ~~~markdown
        ## Consequences
        Still part of the decision.
        ~~~
        Final decision line.

        ## Consequences

        Real boundary.
        """ + "\n"
        let metadata = try CanonTestFixture.adr(matchingMarkdown: markdown)
        let preimage = try ADRSemanticDigest.preimage(metadata: metadata, markdown: markdown)
        let object = try #require(
            try JSONSerialization.jsonObject(with: preimage) as? [String: Any]
        )

        #expect(
            object["markdown_decision"] as? String
                == """
                Real decision.
                ~~~markdown
                ## Consequences
                Still part of the decision.
                ~~~
                Final decision line.
                """
        )
    }

    @Test("ADR digest binds every author-controlled metadata field")
    func semanticBindings() throws {
        let metadata = try CanonTestFixture.adr()
        let markdown = try CanonTestFixture.adrMarkdown()
        let baseDigest = try ADRSemanticDigest.digest(metadata: metadata, markdown: markdown)
        let mutations: [(String, CanonTestFixture.JSONMutation)] = [
            ("id", { $0["id"] = "ADR-9998" }),
            ("title", { $0["title"] = "Changed Canon Fixture" }),
            ("owner_role_id", { $0["owner_role_id"] = "Alternate Canon Maintainer" }),
            ("decision_date", { $0["decision_date"] = "2026-07-11" }),
            ("context", { $0["context"] = "Changed sidecar context." }),
            ("decision", { $0["decision"] = "Bind a changed sidecar decision." }),
            ("alternatives", { $0["alternatives"] = ["Keep indexes empty.", "Use a generated fixture."] }),
            ("consequences", { $0["consequences"] = ["The semantic consequence changed."] }),
            ("migration", { $0["migration"] = ["Run a deterministic migration."] }),
            ("affected_rule_ids", { $0["affected_rule_ids"] = ["CAN-MINIMAL-001", "CAN-MINIMAL-002"] }),
            ("affected_profile_ids", { $0["affected_profile_ids"] = ["core", "enterprise"] }),
            ("verification_impact", { $0["verification_impact"] = ["Verify the changed semantic mapping."] }),
            ("check_ids", { $0["check_ids"] = ["CHK-CAN-MINIMAL-001", "CHK-CAN-MINIMAL-002"] }),
            ("fixture_ids", { $0["fixture_ids"] = ["FIX-CAN-MINIMAL-001-FAIL-001", "FIX-CAN-MINIMAL-001-FAIL-006"] }),
            ("reference_artifact_ids", { $0["reference_artifact_ids"] = ["adrs/ADR-9999-minimal-test.md", "adrs/ADR-9998-follow-up.md"] }),
            ("migration_ids", { $0["migration_ids"] = ["MIG-CAN-MINIMAL-001", "MIG-CAN-MINIMAL-002"] }),
            ("supersedes_adr_ids", { $0["supersedes_adr_ids"] = ["ADR-9998"] }),
        ]

        for (field, mutation) in mutations {
            let changed = try CanonTestFixture.adr(mutation)
            #expect(
                try ADRSemanticDigest.digest(metadata: changed, markdown: markdown) != baseDigest,
                "ADR semantic digest must bind \(field)"
            )
        }
    }

    @Test("ADR digest preserves canonical order for every metadata collection")
    func orderedCollectionBindings() throws {
        let markdown = try CanonTestFixture.adrMarkdown()
        let orderedCollections: [(String, [String])] = [
            ("alternatives", ["Keep indexes empty.", "Use a generated fixture."]),
            ("consequences", ["First consequence.", "Second consequence."]),
            ("migration", ["Run first migration.", "Run second migration."]),
            ("affected_rule_ids", ["CAN-MINIMAL-001", "CAN-MINIMAL-002"]),
            ("affected_profile_ids", ["core", "enterprise"]),
            ("verification_impact", ["Verify first mapping.", "Verify second mapping."]),
            ("check_ids", ["CHK-CAN-MINIMAL-001", "CHK-CAN-MINIMAL-002"]),
            ("fixture_ids", ["FIX-CAN-MINIMAL-001-FAIL-001", "FIX-CAN-MINIMAL-001-FAIL-002"]),
            ("reference_artifact_ids", ["adrs/ADR-9999-minimal-test.md", "adrs/ADR-9998-follow-up.md"]),
            ("migration_ids", ["MIG-CAN-MINIMAL-001", "MIG-CAN-MINIMAL-002"]),
            ("supersedes_adr_ids", ["ADR-9998", "ADR-9997"]),
        ]

        for (field, values) in orderedCollections {
            let forward = try CanonTestFixture.adr { $0[field] = values }
            let reversed = try CanonTestFixture.adr {
                $0[field] = Array(values.reversed())
            }
            #expect(
                try ADRSemanticDigest.digest(metadata: forward, markdown: markdown)
                    != ADRSemanticDigest.digest(metadata: reversed, markdown: markdown),
                "ADR semantic digest must preserve ordered \(field)"
            )
        }
    }

    private func expectDecisionError(markdown: String, reason: String) throws {
        let metadata = try CanonTestFixture.adr(matchingMarkdown: markdown)
        let error = contractError {
            _ = try ADRSemanticDigest.digest(metadata: metadata, markdown: markdown)
        }
        #expect(error == .invalidContract(kind: "adr_markdown", reason: reason))
    }

    private func contractError(_ operation: () throws -> Void) -> ContractError? {
        do {
            try operation()
            Issue.record("Expected ContractError but operation succeeded")
            return nil
        } catch let error as ContractError {
            return error
        } catch {
            Issue.record("Expected ContractError but received \(error)")
            return nil
        }
    }
}
