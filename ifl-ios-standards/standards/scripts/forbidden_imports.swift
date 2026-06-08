#!/usr/bin/env swift
import Foundation

// forbidden_imports.swift — enforces inward-only dependency rule.
//
// Rules:
//   1. Domain layer (Sources/Services/Domain/**) must not import:
//      UIKit, Boardy, SwiftUI, Alamofire, Moya, FirebaseAnalytics, GoogleSignIn,
//      RxSwift, Resolver
//   2. Business Application layer (Sources/Microboards/**, Sources/Services/Application/**)
//      must not import vendor SDKs (Alamofire, Moya, GoogleSignIn, GoogleMobileAds,
//      FirebaseAnalytics, etc.) — only architecture pins (Boardy, SiFUtilities, Resolver).
//   3. Any module's Sources/** must not `import {OtherModule}Plugins`.
//      Cross-module access flows through `{OtherModule}` (IO) only.
//
// Usage:
//   swift forbidden_imports.swift <module-root>
//
// Exit codes:
//   0 — no violations
//   1 — violations found (printed to stdout)
//   2 — usage / IO error

let domainForbidden: Set<String> = [
    "UIKit", "Boardy", "SwiftUI",
    "Alamofire", "Moya",
    "FirebaseAnalytics", "GoogleSignIn", "GoogleMobileAds",
    "RxSwift", "Resolver",
]

let applicationForbidden: Set<String> = [
    "Alamofire", "Moya",
    "GoogleSignIn", "GoogleMobileAds",
    "FirebaseAnalytics",
]

struct Violation {
    let file: String
    let line: Int
    let imported: String
    let reason: String
}

func eprint(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    eprint("usage: forbidden_imports.swift <module-root>")
    exit(2)
}

let rootPath = args[1]
let rootURL = URL(fileURLWithPath: rootPath)
let fm = FileManager.default

var isDir: ObjCBool = false
guard fm.fileExists(atPath: rootURL.path, isDirectory: &isDir), isDir.boolValue else {
    eprint("not a directory: \(rootURL.path)")
    exit(2)
}

// Discover modules: child dirs that contain IO/ or Sources/.
let children = (try? fm.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
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

let moduleNames = Set(modules.map { $0.lastPathComponent })
let siblingPluginsByModule: [String: Set<String>] = Dictionary(uniqueKeysWithValues: modules.map { mod in
    let myName = mod.lastPathComponent
    let forbidden = moduleNames.subtracting([myName]).map { "\($0)Plugins" }
    return (myName, Set(forbidden))
})

func swiftFiles(under dir: URL) -> [URL] {
    guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
    var out: [URL] = []
    for case let url as URL in enumerator where url.pathExtension == "swift" {
        out.append(url)
    }
    return out
}

func importsInFile(_ url: URL) -> [(line: Int, module: String)] {
    guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
    var out: [(Int, String)] = []
    for (idx, raw) in content.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
        let line = raw.trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("import ") else { continue }
        // strip `import` + leading space, possible attributes like `@testable`
        let after = line.dropFirst("import ".count).trimmingCharacters(in: .whitespaces)
        // Take first identifier segment (no dots, no spaces).
        let first = after.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" }).first.map(String.init) ?? ""
        guard !first.isEmpty else { continue }
        out.append((idx + 1, first))
    }
    return out
}

func classifyLayer(_ relPath: String) -> String? {
    // returns: "domain" / "application" / "sources" / nil (not under Sources/)
    if relPath.contains("/Sources/Services/Domain/") { return "domain" }
    if relPath.contains("/Sources/Microboards/")
        || relPath.contains("/Sources/Services/Application/") { return "application" }
    if relPath.contains("/Sources/") { return "sources" }
    return nil
}

var violations: [Violation] = []
var scanned = 0

for mod in modules {
    let modName = mod.lastPathComponent
    let pluginsForbidden = siblingPluginsByModule[modName] ?? []
    let files = swiftFiles(under: mod)
    for file in files {
        scanned += 1
        let rel = file.path.replacingOccurrences(of: rootURL.path, with: "")
        guard let layer = classifyLayer(rel) else { continue }
        for (lineNo, imp) in importsInFile(file) {
            // Rule 3 — cross-module Plugins import
            if pluginsForbidden.contains(imp) {
                violations.append(.init(
                    file: file.path, line: lineNo, imported: imp,
                    reason: "cross-module Plugins import — use IO target `\(imp.replacingOccurrences(of: "Plugins", with: ""))`"
                ))
            }
            // Rule 1 — Domain forbidden
            if layer == "domain", domainForbidden.contains(imp) {
                violations.append(.init(
                    file: file.path, line: lineNo, imported: imp,
                    reason: "Domain layer must not import \(imp)"
                ))
            }
            // Rule 2 — Application forbidden vendor SDKs
            if layer == "application", applicationForbidden.contains(imp) {
                violations.append(.init(
                    file: file.path, line: lineNo, imported: imp,
                    reason: "Business/Application layer must not import vendor SDK `\(imp)` — adapt via Infra"
                ))
            }
        }
    }
}

if violations.isEmpty {
    print("OK — forbidden_imports clean (\(modules.count) module(s), \(scanned) file(s) scanned)")
    exit(0)
}

print("FAIL — forbidden_imports: \(violations.count) violation(s) in \(modules.count) module(s) (\(scanned) file(s) scanned):\n")
for v in violations.sorted(by: { ($0.file, $0.line) < ($1.file, $1.line) }) {
    print("  · \(v.file):\(v.line)")
    print("      import \(v.imported) — \(v.reason)")
}
exit(1)
