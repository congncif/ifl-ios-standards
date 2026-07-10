import Foundation
import IFLContracts

public struct MarkdownRuleBlock: Hashable, Sendable {
    public let ruleID: RuleID
    public let statement: String

    private init(ruleID: RuleID, statement: String) {
        self.ruleID = ruleID
        self.statement = statement
    }

    public static func parse(_ markdown: String) throws -> [MarkdownRuleBlock] {
        let lines = MarkdownLexicalScanner.scan(markdown)
        var blocks: [MarkdownRuleBlock] = []
        var seenRuleIDs = Set<RuleID>()
        var openBlock: OpenBlock?
        var markerCommentScanner = MarkerCommentScanner()

        for line in lines {
            if line.isInsideFence {
                if openBlock != nil {
                    try appendBodyLine(line, to: &openBlock)
                }
                continue
            }

            if line.text == closingMarker {
                guard let block = openBlock else {
                    throw invalidContract(
                        "line \(line.number) closes no open ifl-rule block"
                    )
                }
                let statement = normalizedStatement(block.body)
                guard !statement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw invalidContract(
                        "rule \(block.ruleID.rawValue) block statement must not be empty"
                    )
                }
                blocks.append(Self(ruleID: block.ruleID, statement: statement))
                openBlock = nil
                continue
            }

            if let ruleID = try openingRuleID(line.text) {
                guard openBlock == nil else {
                    throw invalidContract(
                        "line \(line.number) opens a nested ifl-rule block"
                    )
                }
                guard seenRuleIDs.insert(ruleID).inserted else {
                    throw ContractError.duplicateIdentifier(
                        kind: "Markdown rule block",
                        id: ruleID.rawValue
                    )
                }
                openBlock = OpenBlock(ruleID: ruleID, body: [])
                continue
            }

            if markerCommentScanner.containsRuleMarker(in: line.text) {
                throw invalidContract(
                    "line \(line.number) contains a malformed ifl-rule marker comment"
                )
            }

            if openBlock != nil {
                try appendBodyLine(line, to: &openBlock)
            }
        }

        if let openBlock {
            throw invalidContract(
                "rule \(openBlock.ruleID.rawValue) block is not closed"
            )
        }
        return blocks
    }

    public static func validate(
        _ blocks: [MarkdownRuleBlock],
        against rules: [RuleRecord]
    ) throws {
        var rulesByID: [RuleID: RuleRecord] = [:]
        for rule in rules {
            guard rulesByID.updateValue(rule, forKey: rule.id) == nil else {
                throw ContractError.duplicateIdentifier(
                    kind: "rule record",
                    id: rule.id.rawValue
                )
            }
        }

        var seenBlockIDs = Set<RuleID>()
        for block in blocks {
            guard seenBlockIDs.insert(block.ruleID).inserted else {
                throw ContractError.duplicateIdentifier(
                    kind: "Markdown rule block",
                    id: block.ruleID.rawValue
                )
            }
            guard let rule = rulesByID[block.ruleID] else {
                throw ContractError.unresolvedReference(
                    kind: "Markdown rule block",
                    id: block.ruleID.rawValue
                )
            }
            guard normalizedStatement([block.statement])
                == normalizedStatement([rule.statement])
            else {
                throw invalidContract(
                    "rule \(block.ruleID.rawValue) block statement does not match RuleRecord.statement"
                )
            }
        }
    }

    private static let openingPrefix = "<!-- ifl-rule: "
    private static let markerSuffix = " -->"
    private static let closingMarker = "<!-- /ifl-rule -->"
    private static let quotePrefix = "> "

    private static func openingRuleID(_ line: String) throws -> RuleID? {
        guard line.hasPrefix(openingPrefix), line.hasSuffix(markerSuffix) else {
            return nil
        }
        let start = line.index(line.startIndex, offsetBy: openingPrefix.count)
        let end = line.index(line.endIndex, offsetBy: -markerSuffix.count)
        return try RuleID(validating: String(line[start ..< end]))
    }

    private static func appendBodyLine(
        _ line: MarkdownLexicalLine,
        to openBlock: inout OpenBlock?
    ) throws {
        guard line.text.hasPrefix(quotePrefix) else {
            throw invalidContract(
                "line \(line.number) in an open ifl-rule block must begin with > "
            )
        }
        openBlock?.body.append(String(line.text.dropFirst(quotePrefix.count)))
    }

    private static func normalizedStatement(_ body: [String]) -> String {
        body.joined(separator: "\n")
            .precomposedStringWithCanonicalMapping
    }

    private static func invalidContract(_ reason: String) -> ContractError {
        .invalidContract(kind: "markdown_rule_block", reason: reason)
    }
}

private struct OpenBlock {
    let ruleID: RuleID
    var body: [String]
}

private struct MarkerCommentScanner {
    private var isInsideComment = false

    mutating func containsRuleMarker(in line: String) -> Bool {
        var remainder = line[...]

        while !remainder.isEmpty {
            if isInsideComment {
                if let close = remainder.range(of: "-->") {
                    if remainder[..<close.lowerBound].contains("ifl-rule") {
                        return true
                    }
                    remainder = remainder[close.upperBound...]
                    isInsideComment = false
                    continue
                }
                return remainder.contains("ifl-rule")
            }

            guard let open = remainder.range(of: "<!--") else {
                return false
            }
            remainder = remainder[open.upperBound...]
            isInsideComment = true
        }
        return false
    }
}
