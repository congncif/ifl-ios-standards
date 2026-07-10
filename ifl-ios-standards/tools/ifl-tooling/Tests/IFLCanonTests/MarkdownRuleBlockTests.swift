@testable import IFLCanon
import IFLContracts
import Testing

@Suite("MarkdownRuleBlockTests")
struct MarkdownRuleBlockTests {
    @Test("exact rule block parses a normalized quote statement and validates")
    func exactBlockParsesAndValidates() throws {
        let rule = try CanonTestFixture.rule()
        let markdown = exactBlock(id: rule.id.rawValue, statement: rule.statement)

        let blocks = try MarkdownRuleBlock.parse(markdown)

        #expect(blocks.count == 1)
        #expect(blocks.first?.ruleID == rule.id)
        #expect(blocks.first?.statement == rule.statement)
        try MarkdownRuleBlock.validate(blocks, against: [rule])
    }

    @Test("arbitrary prose containing ifl-rule is not a marker")
    func arbitraryProseIsAllowed() throws {
        let markdown = "This prose explains the `ifl-rule` convention without declaring one.\n"
        #expect(try MarkdownRuleBlock.parse(markdown).isEmpty)
    }

    @Test("backtick and tilde fences hide exact and malformed marker comments", arguments: [
        "```",
        "~~~~",
    ])
    func fencedMarkersAreIgnored(fence: String) throws {
        let markdown = """
        \(fence)markdown
        <!-- ifl-rule: CAN-FENCED-001 -->
        <!-- ifl-rule malformed -->
        <!-- /ifl-rule -->
        \(fence)
        """ + "\n"

        #expect(try MarkdownRuleBlock.parse(markdown).isEmpty)
    }

    @Test("quoted fences inside a rule body hide marker comments")
    func quotedFenceInsideRuleBody() throws {
        let markdown = """
        <!-- ifl-rule: CAN-MINIMAL-001 -->
        > Rule statement.
        > ```html
        > <!-- /ifl-rule -->
        > <!-- ifl-rule malformed -->
        > ```
        <!-- /ifl-rule -->
        """ + "\n"

        let block = try #require(MarkdownRuleBlock.parse(markdown).first)
        #expect(
            block.statement == """
            Rule statement.
            ```html
            <!-- /ifl-rule -->
            <!-- ifl-rule malformed -->
            ```
            """
        )
    }

    @Test("malformed marker comments have a stable public error", arguments: [
        "<!-- ifl-rule CAN-MINIMAL-001 -->\n",
        "prefix <!-- ifl-rule: CAN-MINIMAL-001 -->\n",
        "<!-- /ifl-rule: CAN-MINIMAL-001 -->\n",
    ])
    func malformedMarkerComments(markdown: String) {
        #expect(
            contractError { _ = try MarkdownRuleBlock.parse(markdown) }
                == .invalidContract(
                    kind: "markdown_rule_block",
                    reason: "line 1 contains a malformed ifl-rule marker comment"
                )
        )
    }

    @Test("invalid marker Rule ID preserves the identifier contract")
    func invalidMarkerRuleID() {
        let markdown = "<!-- ifl-rule: not-a-rule-id -->\n"
        #expect(
            contractError { _ = try MarkdownRuleBlock.parse(markdown) }
                == .invalidIdentifier(kind: "rule", value: "not-a-rule-id")
        )
    }

    @Test("duplicate rule blocks have a stable public error")
    func duplicateRuleIDs() throws {
        let rule = try CanonTestFixture.rule()
        let block = exactBlock(id: rule.id.rawValue, statement: rule.statement)

        #expect(
            contractError { _ = try MarkdownRuleBlock.parse(block + "\n" + block) }
                == .duplicateIdentifier(kind: "Markdown rule block", id: rule.id.rawValue)
        )
    }

    @Test("nested rule blocks have a stable public error")
    func nestedBlocks() {
        let markdown = """
        <!-- ifl-rule: CAN-MINIMAL-001 -->
        > Outer statement.
        <!-- ifl-rule: CAN-MINIMAL-002 -->
        > Nested statement.
        <!-- /ifl-rule -->
        <!-- /ifl-rule -->
        """ + "\n"

        #expect(
            contractError { _ = try MarkdownRuleBlock.parse(markdown) }
                == .invalidContract(
                    kind: "markdown_rule_block",
                    reason: "line 3 opens a nested ifl-rule block"
                )
        )
    }

    @Test("unexpected closing marker has a stable public error")
    func unexpectedClosingMarker() {
        #expect(
            contractError { _ = try MarkdownRuleBlock.parse("<!-- /ifl-rule -->\n") }
                == .invalidContract(
                    kind: "markdown_rule_block",
                    reason: "line 1 closes no open ifl-rule block"
                )
        )
    }

    @Test("unclosed rule block has a stable public error")
    func unclosedBlock() {
        let markdown = "<!-- ifl-rule: CAN-MINIMAL-001 -->\n> Unclosed statement.\n"
        #expect(
            contractError { _ = try MarkdownRuleBlock.parse(markdown) }
                == .invalidContract(
                    kind: "markdown_rule_block",
                    reason: "rule CAN-MINIMAL-001 block is not closed"
                )
        )
    }

    @Test("invalid and empty body lines have stable public errors")
    func invalidAndEmptyBodies() {
        let invalid = "<!-- ifl-rule: CAN-MINIMAL-001 -->\nStatement.\n<!-- /ifl-rule -->\n"
        let empty = "<!-- ifl-rule: CAN-MINIMAL-001 -->\n>    \n<!-- /ifl-rule -->\n"

        #expect(
            contractError { _ = try MarkdownRuleBlock.parse(invalid) }
                == .invalidContract(
                    kind: "markdown_rule_block",
                    reason: "line 2 in an open ifl-rule block must begin with > "
                )
        )
        #expect(
            contractError { _ = try MarkdownRuleBlock.parse(empty) }
                == .invalidContract(
                    kind: "markdown_rule_block",
                    reason: "rule CAN-MINIMAL-001 block statement must not be empty"
                )
        )
    }

    @Test("unknown Rule ID has a stable public error")
    func unknownRule() throws {
        let rule = try CanonTestFixture.rule()
        let blocks = try MarkdownRuleBlock.parse(
            exactBlock(id: "CAN-UNKNOWN-001", statement: rule.statement)
        )

        #expect(
            contractError { try MarkdownRuleBlock.validate(blocks, against: [rule]) }
                == .unresolvedReference(kind: "Markdown rule block", id: "CAN-UNKNOWN-001")
        )
    }

    @Test("statement drift has a stable public error")
    func statementDrift() throws {
        let rule = try CanonTestFixture.rule()
        let blocks = try MarkdownRuleBlock.parse(
            exactBlock(
                id: rule.id.rawValue,
                statement: "The derived statement has drifted from Canon."
            )
        )

        #expect(
            contractError { try MarkdownRuleBlock.validate(blocks, against: [rule]) }
                == .invalidContract(
                    kind: "markdown_rule_block",
                    reason: "rule CAN-MINIMAL-001 block statement does not match RuleRecord.statement"
                )
        )
    }

    @Test("outer statement whitespace is semantic drift, not normalization")
    func outerWhitespaceDrift() throws {
        let rule = try CanonTestFixture.rule()
        let blocks = try MarkdownRuleBlock.parse(
            exactBlock(id: rule.id.rawValue, statement: " \(rule.statement)")
        )

        #expect(
            contractError { try MarkdownRuleBlock.validate(blocks, against: [rule]) }
                == .invalidContract(
                    kind: "markdown_rule_block",
                    reason: "rule CAN-MINIMAL-001 block statement does not match RuleRecord.statement"
                )
        )
    }

    @Test("duplicate Rule records have a stable public error")
    func duplicateRuleRecords() throws {
        let rule = try CanonTestFixture.rule()
        let blocks = try MarkdownRuleBlock.parse(
            exactBlock(id: rule.id.rawValue, statement: rule.statement)
        )

        #expect(
            contractError { try MarkdownRuleBlock.validate(blocks, against: [rule, rule]) }
                == .duplicateIdentifier(kind: "rule record", id: rule.id.rawValue)
        )
    }

    private func exactBlock(id: String, statement: String) -> String {
        """
        <!-- ifl-rule: \(id) -->
        > \(statement)
        <!-- /ifl-rule -->
        """ + "\n"
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
