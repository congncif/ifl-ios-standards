#!/usr/bin/env swift
import Foundation

// boardid_naming.swift — enforces BoardID string-literal naming conventions.
//
// Rules (per QUICK_REF.md):
//   1. Public BoardID literals (declared under {Module}/IO/**) follow:
//      "pub.mod.{Module}.{Board}"
//      (Interface module name = {Module}, no IO suffix; impl module = {Module}Plugins.)
//   2. Internal BoardID literals (declared under {Module}/Sources/Microboards/**) follow:
//      "mod.{Module}.{Board}"   (provider/unified IDs `mod.{Module}.{X}Provider`
//      are a subset of the same pattern.)
//
// What this lint does NOT check:
//   - Alias declarations like `static let modX: BoardID = .pubY` (no string literal).
//   - Literals declared outside an IO or Sources/Microboards path.
//
// Usage:
//   swift boardid_naming.swift <module-root>
//
// Exit codes:
//   0 — clean
//   1 — at least one naming violation
//   2 — usage / IO error

struct Violation {
    let file: String
    let line: Int
    let literal: String
    let expected: String
}

func eprint(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    eprint("usage: boardid_naming.swift <module-root>")
    exit(2)
}

let rootURL = URL(fileURLWithPath: args[1])
let fm = FileManager.default
var isDir: ObjCBool = false
guard fm.fileExists(atPath: rootURL.path, isDirectory: &isDir), isDir.boolValue else {
    eprint("not a directory: \(rootURL.path)")
    exit(2)
}

let children = (try? fm.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)) ?? []
let modules: [URL] = children.filter { child in
    var d: ObjCBool = false
    guard fm.fileExists(atPath: child.path, isDirectory: &d), d.boolValue else { return false }
    let hasIO = fm.fileExists(atPath: child.appendingPathComponent("IO").path)
    let hasSrc = fm.fileExists(atPath: child.appendingPathComponent("Sources").path)
    return hasIO || hasSrc
}.sorted { $0.lastPathComponent < $1.lastPathComponent }

guard !modules.isEmpty else {
    print("OK — no modules discovered under \(rootURL.path)")
    exit(0)
}

func swiftFiles(under dir: URL) -> [URL] {
    guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
    var out: [URL] = []
    for case let url as URL in enumerator where url.pathExtension == "swift" {
        out.append(url)
    }
    return out
}

// Match `static let NAME: BoardID = "LITERAL"`. Capture LITERAL. Anchored on a single line.
// Ignores aliases like `= .pubFoo` and assignments without `: BoardID` type annotation.
let pattern = #"static\s+let\s+\w+\s*:\s*BoardID\s*=\s*\"([^\"]+)\""#
let regex = try! NSRegularExpression(pattern: pattern)

func extractLiterals(from url: URL) -> [(line: Int, literal: String)] {
    guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
    var out: [(Int, String)] = []
    for (idx, raw) in content.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
        let s = String(raw)
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        if let m = regex.firstMatch(in: s, range: range), m.numberOfRanges >= 2 {
            if let r = Range(m.range(at: 1), in: s) {
                out.append((idx + 1, String(s[r])))
            }
        }
    }
    return out
}

func classify(_ relPath: String) -> (kind: String, expected: String)? {
    // returns nil if path is irrelevant (e.g. tests).
    if relPath.contains("/IO/") { return ("public", "pub.mod.{Module}.{Board}") }
    if relPath.contains("/Sources/Microboards/") { return ("internal", "mod.{Module}.{Board}") }
    return nil
}

let nameChars = CharacterSet(charactersIn: "_").union(.alphanumerics)

func isValidBoardSegment(_ s: String) -> Bool {
    guard !s.isEmpty else { return false }
    return s.unicodeScalars.allSatisfy { nameChars.contains($0) }
}

var violations: [Violation] = []
var scanned = 0
var literalsChecked = 0

for mod in modules {
    let modName = mod.lastPathComponent
    let pubPrefix = "pub.mod.\(modName)."
    let intPrefix = "mod.\(modName)."
    let files = swiftFiles(under: mod)
    for file in files {
        scanned += 1
        let rel = file.path
        guard let (kind, expected) = classify(rel) else { continue }
        for (lineNo, literal) in extractLiterals(from: file) {
            literalsChecked += 1
            let ok: Bool
            switch kind {
            case "public":
                if literal.hasPrefix(pubPrefix) {
                    let suffix = String(literal.dropFirst(pubPrefix.count))
                    ok = isValidBoardSegment(suffix)
                } else { ok = false }
            case "internal":
                if literal.hasPrefix(intPrefix) {
                    let suffix = String(literal.dropFirst(intPrefix.count))
                    ok = isValidBoardSegment(suffix)
                } else { ok = false }
            default:
                ok = true
            }
            if !ok {
                let exp: String
                switch kind {
                case "public":   exp = "\(pubPrefix){Board}"
                case "internal": exp = "\(intPrefix){Board}"
                default:         exp = expected
                }
                violations.append(.init(file: file.path, line: lineNo, literal: literal, expected: exp))
            }
        }
    }
}

if violations.isEmpty {
    print("OK — boardid_naming clean (\(modules.count) module(s), \(scanned) file(s) scanned, \(literalsChecked) literal(s) checked)")
    exit(0)
}

print("FAIL — boardid_naming: \(violations.count) violation(s) in \(modules.count) module(s):\n")
for v in violations.sorted(by: { ($0.file, $0.line) < ($1.file, $1.line) }) {
    print("  · \(v.file):\(v.line)")
    print("      literal \"\(v.literal)\"")
    print("      expected \"\(v.expected)\"")
}
exit(1)
