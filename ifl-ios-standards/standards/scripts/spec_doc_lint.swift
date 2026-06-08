#!/usr/bin/env swift
import Foundation

let requiredSections: [String] = [
    "## When to use",
    "## When NOT to use",
    "## Forces",
    "## Files",
    "## Naming",
    "## Communication",
    "## Concurrency",
    "## Composition",
    "## Lifecycle",
    "## Testing",
    "## Pitfalls",
    "## References",
]

let exemptExact: Set<String> = [
    "README.md",
    "ADOPTION.md",
    "CONVENTIONS.md",
    "EXAMPLES.md",
    "PACKAGE_MANAGER.md",
    "REVIEWER_CHECKLIST.md",
    "DECISION_TREES.md",
    "BROWNFIELD_MIGRATION.md",
    "TROUBLESHOOTING.md",
    "GREENFIELD_SETUP.md",
    "REVIEW_PLAYBOOK.md",
    "REFACTOR_PLAYBOOK.md",
]
let exemptPrefix = ["EXAMPLES_"]

struct Failure {
    let file: String
    let reason: String
}

func isExempt(_ name: String) -> Bool {
    if exemptExact.contains(name) { return true }
    for p in exemptPrefix where name.hasPrefix(p) { return true }
    return false
}

func lintFile(_ url: URL) -> Failure? {
    guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
        return Failure(file: url.path, reason: "unreadable")
    }
    let headings = raw.split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
        .filter { $0.hasPrefix("## ") }
        .map { $0.trimmingCharacters(in: .whitespaces) }

    var cursor = 0
    for h in headings {
        if cursor >= requiredSections.count { break }
        if h == requiredSections[cursor] { cursor += 1 }
    }
    if cursor < requiredSections.count {
        let missing = requiredSections[cursor]
        let foundList = headings.filter { requiredSections.contains($0) }
        return Failure(
            file: url.lastPathComponent,
            reason: "missing or out-of-order section: `\(missing)`. Found ordered: \(foundList.joined(separator: " → "))"
        )
    }
    return nil
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: spec_doc_lint.swift <specs-dir>\n".utf8))
    exit(2)
}

let dir = URL(fileURLWithPath: args[1])
guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
    FileHandle.standardError.write(Data("cannot read directory: \(dir.path)\n".utf8))
    exit(2)
}

let markdown = files
    .filter { $0.pathExtension == "md" }
    .filter { !isExempt($0.lastPathComponent) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

var failures: [Failure] = []
for f in markdown {
    if let fail = lintFile(f) { failures.append(fail) }
}

if failures.isEmpty {
    print("OK — \(markdown.count) spec(s) conform to SPEC_CONTRACT.md")
    exit(0)
}

print("FAIL — \(failures.count) of \(markdown.count) spec(s) non-conforming:\n")
for f in failures {
    print("  · \(f.file)")
    print("      \(f.reason)\n")
}
exit(1)
