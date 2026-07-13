import Foundation

struct MarkdownLexicalLine {
    let number: Int
    let text: String
    let isInsideFence: Bool
}

enum MarkdownLexicalScanner {
    static func scan(_ markdown: String) -> [MarkdownLexicalLine] {
        let normalizedMarkdown = normalized(markdown)
        var lines = normalizedMarkdown.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ).map(String.init)
        if normalizedMarkdown.hasSuffix("\n") {
            lines.removeLast()
        }
        var openFence: Fence?

        return lines.enumerated().map { offset, text in
            if let fence = openFence {
                if isClosingFence(text, matching: fence) {
                    openFence = nil
                }
                return MarkdownLexicalLine(
                    number: offset + 1,
                    text: text,
                    isInsideFence: true
                )
            }

            if let fence = openingFence(text) {
                openFence = fence
                return MarkdownLexicalLine(
                    number: offset + 1,
                    text: text,
                    isInsideFence: true
                )
            }

            return MarkdownLexicalLine(
                number: offset + 1,
                text: text,
                isInsideFence: false
            )
        }
    }

    private static func normalized(_ markdown: String) -> String {
        markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .precomposedStringWithCanonicalMapping
    }

    private static func openingFence(_ line: String) -> Fence? {
        guard let content = containerContent(line),
              let delimiter = content.first,
              delimiter == "`" || delimiter == "~"
        else {
            return nil
        }
        let length = content.prefix { $0 == delimiter }.count
        guard length >= 3 else { return nil }

        let suffix = content.dropFirst(length)
        if delimiter == "`", suffix.contains("`") {
            return nil
        }
        return Fence(delimiter: delimiter, minimumLength: length)
    }

    private static func isClosingFence(_ line: String, matching fence: Fence) -> Bool {
        guard let content = containerContent(line),
              content.first == fence.delimiter
        else {
            return false
        }
        let length = content.prefix { $0 == fence.delimiter }.count
        guard length >= fence.minimumLength else { return false }
        return content.dropFirst(length).allSatisfy { $0 == " " || $0 == "\t" }
    }

    private static func containerContent(_ line: String) -> Substring? {
        var content = line[...]
        guard dropIndent(from: &content) else { return nil }

        while content.first == ">" {
            content = content.dropFirst()
            if content.first == " " {
                content = content.dropFirst()
            }
            guard dropIndent(from: &content) else { return nil }
        }
        return content
    }

    private static func dropIndent(from content: inout Substring) -> Bool {
        var count = 0
        while content.first == " ", count < 4 {
            content = content.dropFirst()
            count += 1
        }
        return count < 4
    }
}

private struct Fence {
    let delimiter: Character
    let minimumLength: Int
}
