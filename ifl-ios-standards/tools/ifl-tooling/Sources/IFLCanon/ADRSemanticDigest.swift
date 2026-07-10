import Foundation
import IFLContracts

public enum ADRSemanticDigest {
    static let excludedKeysV1 = ["accepted_at", "status"]

    public static func digest(
        metadata: ADRMetadata,
        markdown: String
    ) throws -> HashDigest {
        CanonicalTreeDigest.sha256(try preimage(metadata: metadata, markdown: markdown))
    }

    static func preimage(
        metadata: ADRMetadata,
        markdown: String
    ) throws -> Data {
        let markdownData = Data(markdown.utf8)
        let actualDigest = CanonicalTreeDigest.sha256(markdownData)
        guard actualDigest == metadata.markdownDigest else {
            throw ContractError.digestMismatch(
                kind: "ADR Markdown",
                expected: metadata.markdownDigest.rawValue,
                actual: actualDigest.rawValue
            )
        }

        let decision = try ADRDecisionSection.parse(markdown)
        return try SemanticJSONProjection.preimage(
            of: metadata,
            excludingKeys: excludedKeysV1,
            additionalFields: ["markdown_decision": decision],
            kind: "adr_semantic_digest"
        )
    }
}

private enum ADRDecisionSection {
    private static let heading = "## Decision"

    static func parse(_ markdown: String) throws -> String {
        let lines = MarkdownLexicalScanner.scan(markdown)
        let headings = lines.indices.filter {
            !lines[$0].isInsideFence && lines[$0].text == heading
        }

        guard !headings.isEmpty else {
            throw ContractError.invalidContract(
                kind: "adr_markdown",
                reason: "missing unfenced ## Decision section"
            )
        }
        guard headings.count == 1 else {
            throw ContractError.invalidContract(
                kind: "adr_markdown",
                reason: "multiple unfenced ## Decision sections"
            )
        }

        let contentStart = headings[0] + 1
        let contentEnd = lines.indices.first { index in
            index >= contentStart
                && !lines[index].isInsideFence
                && isSectionBoundary(lines[index].text)
        } ?? lines.endIndex
        var content = lines[contentStart ..< contentEnd].map(\.text)
        trimBoundaryBlankLines(&content)

        let decision = content.joined(separator: "\n")
            .precomposedStringWithCanonicalMapping
        guard !decision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ContractError.invalidContract(
                kind: "adr_markdown",
                reason: "unfenced ## Decision section must not be empty"
            )
        }
        return decision
    }

    private static func isSectionBoundary(_ line: String) -> Bool {
        line.hasPrefix("# ") || line.hasPrefix("## ")
    }

    private static func trimBoundaryBlankLines(_ lines: inout [String]) {
        while lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            lines.removeFirst()
        }
        while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            lines.removeLast()
        }
    }
}
