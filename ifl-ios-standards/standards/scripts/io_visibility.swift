#!/usr/bin/env swift
import Foundation

// io_visibility.swift — enforces top-level visibility under IO/ vs Sources/.
//
// Rules:
//   1. Top-level type declarations under {Module}/IO/** MUST be `public` (or `open`).
//      Targets: class, struct, enum, protocol, actor, typealias.
//      `extension` blocks are skipped — their inner members carry their own access
//      modifiers (e.g. `extension MotherboardType { public func ioX() }` is valid).
//      `public extension X` IS checked under rule 2 because it exports members.
//   2. Top-level declarations under {Module}/Sources/** MUST NOT be `public`/`open`,
//      EXCEPT under {Module}/Sources/Plugins/** which is the public-export zone
//      (LauncherPlugin + ModulePlugin + their construction wiring — provider
//      configurations, options structs, marker protocols consumed by App when
//      instantiating the LauncherPlugin). Rationale: Interface module exposes
//      DOMAIN MEANING only; construction wiring is registration-time plumbing
//      and lives next to the LauncherPlugin that consumes it.
//      Additional exemption:
//        - Modules WITHOUT an `IO/` subdir are treated as shared library modules
//          (e.g. DesignSystem) and exempted from this rule.
//
// "Top-level" = declared at brace depth 0 in the source file. Nested types are
// not checked here (their visibility is inferred from the enclosing decl).
//
// Declaration kinds covered: class, struct, enum, protocol, actor, extension,
// typealias, func, var, let, init.
//
// Skipped: imports, comments, #if/#else/#endif, blank lines, attribute-only
// lines (`@available(...)` etc — modifier is read from the decl keyword line).
//
// Usage:
//   swift io_visibility.swift <module-root>
//
// Exit codes:
//   0 — clean
//   1 — at least one visibility violation
//   2 — usage / IO error

struct Violation {
    let file: String
    let line: Int
    let kind: String
    let snippet: String
}

func eprint(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    eprint("usage: io_visibility.swift <module-root>")
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

// Strip line comments and double-quoted strings so they don't pollute brace counting.
func sanitize(_ line: String) -> String {
    var s = line
    if let r = s.range(of: "//") { s = String(s[..<r.lowerBound]) }
    var out = ""
    var inStr = false
    for ch in s {
        if ch == "\"" { inStr.toggle(); continue }
        if !inStr { out.append(ch) }
    }
    return out
}

let declKeywords: Set<String> = ["class","struct","enum","protocol","actor","extension","typealias","func","var","let","init"]
let modifierOnlyKeywords: Set<String> = ["internal","fileprivate","private","final","static","weak","unowned","lazy","mutating","nonmutating","override","required","convenience","dynamic","indirect","optional","prefix","postfix","infix"]

struct Anchor {
    let modifier: String?   // "public" / "open" / nil
    let kind: String        // decl keyword
    let name: String?       // type/func name when extractable
}

// Find a top-level declaration anchor on a line. Returns nil if line isn't a decl.
func declAnchor(in sanitized: String) -> Anchor? {
    let trimmed = sanitized.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return nil }
    if trimmed.hasPrefix("import ") { return nil }
    if trimmed.hasPrefix("#") { return nil }
    // Strip leading @attribute(...) chunks.
    var s = trimmed
    while s.hasPrefix("@") {
        var depth = 0
        var endIdx = s.endIndex
        for i in s.indices {
            let ch = s[i]
            if ch == "(" { depth += 1 }
            else if ch == ")" { depth -= 1 }
            else if (ch == " " || ch == "\t") && depth == 0 && i > s.startIndex {
                endIdx = i; break
            }
        }
        if endIdx == s.endIndex { return nil }
        s = String(s[endIdx...]).trimmingCharacters(in: .whitespaces)
    }
    // Tokenize on whitespace; stop after first decl keyword.
    let parts = s.split(whereSeparator: { $0 == " " || $0 == "\t" }).map { String($0) }
    if parts.isEmpty { return nil }
    var modifier: String? = nil
    for (i, t) in parts.enumerated() {
        if t == "public" || t == "open" { modifier = t; continue }
        if modifierOnlyKeywords.contains(t) { continue }
        if declKeywords.contains(t) {
            // Extract name (next token, stripped of `:`, `<`, `(`, `{`).
            var name: String? = nil
            if i + 1 < parts.count {
                let raw = parts[i + 1]
                let cut = raw.firstIndex(where: { ":<({,".contains($0) }) ?? raw.endIndex
                name = String(raw[..<cut])
            }
            return Anchor(modifier: modifier, kind: t, name: name)
        }
        return nil
    }
    return nil
}

func classify(_ relPath: String) -> String? {
    if relPath.contains("/IO/") { return "IO" }
    if relPath.contains("/Sources/") { return "Sources" }
    return nil
}

var violations: [Violation] = []
var scanned = 0
var anchorsChecked = 0

for mod in modules {
    let hasIODir = fm.fileExists(atPath: mod.appendingPathComponent("IO").path)
    let files = swiftFiles(under: mod)
    for file in files {
        let rel = file.path
        guard let zone = classify(rel) else { continue }
        guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
        scanned += 1
        var depth = 0
        for (idx, raw) in content.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let lineNo = idx + 1
            let s = String(raw)
            let san = sanitize(s)
            let depthBefore = depth
            for ch in san {
                if ch == "{" { depth += 1 }
                else if ch == "}" { depth = max(0, depth - 1) }
            }
            if depthBefore != 0 { continue }
            guard let anchor = declAnchor(in: san) else { continue }
            anchorsChecked += 1
            let snippet = s.trimmingCharacters(in: .whitespaces)
            switch zone {
            case "IO":
                // Extensions can host individually-marked public members; their own
                // keyword line is exempt from the must-be-public check.
                if anchor.kind == "extension" { continue }
                if anchor.modifier == nil {
                    violations.append(.init(file: file.path, line: lineNo,
                                            kind: "IO-missing-public", snippet: snippet))
                }
            case "Sources":
                // Shared library modules (no IO/ subdir) legitimately export public types.
                if !hasIODir { continue }
                // Sources/Plugins/** is the public-export zone for LauncherPlugin
                // + construction wiring (provider configs, options). Inputs to the
                // LauncherPlugin constructor are registration-time plumbing, not
                // domain — they live next to the LauncherPlugin, not in IO/.
                if rel.contains("/Sources/Plugins/") { continue }
                if anchor.modifier != nil {
                    violations.append(.init(file: file.path, line: lineNo,
                                            kind: "Sources-has-public", snippet: snippet))
                }
            default: break
            }
        }
    }
}

if violations.isEmpty {
    print("OK — io_visibility clean (\(modules.count) module(s), \(scanned) file(s) scanned, \(anchorsChecked) top-level anchor(s) checked)")
    exit(0)
}

print("FAIL — io_visibility: \(violations.count) violation(s) in \(modules.count) module(s):\n")
for v in violations.sorted(by: { ($0.file, $0.line) < ($1.file, $1.line) }) {
    print("  · \(v.file):\(v.line)  [\(v.kind)]")
    print("      \(v.snippet)")
}
exit(1)
