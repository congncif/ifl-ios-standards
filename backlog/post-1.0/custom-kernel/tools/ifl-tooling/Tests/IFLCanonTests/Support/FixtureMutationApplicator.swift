import Foundation
import IFLContracts

extension FixtureCanon {
    static func apply(_ manifest: FixtureManifest, to root: URL) throws {
        for mutation in manifest.mutations {
            try apply(mutation, to: root)
        }
        let touchedPaths = Set(manifest.mutations.map(\.relativePath.rawValue))
        for relativePath in touchedPaths.sorted() {
            try rebuildAffectedIndexDigest(for: relativePath, in: root)
        }
    }

    private static func apply(_ mutation: FixtureMutation, to root: URL) throws {
        let target = try containedTarget(for: mutation.relativePath, in: root)

        switch mutation.operation {
        case .jsonAdd, .jsonReplace, .jsonRemove:
            let source = try JSONSerialization.jsonObject(
                with: Data(contentsOf: target),
                options: [.fragmentsAllowed]
            )
            let tokens = try decodeJSONPointer(mutation.jsonPointer ?? "")
            if tokens.isEmpty, mutation.operation == .jsonRemove {
                try FileManager.default.removeItem(at: target)
                return
            }

            let mutated: Any = if tokens.isEmpty {
                try require(
                    mutation.value?.foundationValue,
                    "root json_add/json_replace requires a value"
                )
            } else {
                try mutate(
                    source,
                    tokens: ArraySlice(tokens),
                    operation: mutation.operation,
                    replacement: mutation.value?.foundationValue
                )
            }
            try fixtureCanonicalJSONFileData(mutated).write(to: target, options: .atomic)

        case .writeUTF8:
            let content = try require(
                mutation.utf8Content,
                "write_utf8 requires utf8_content"
            )
            try Data(content.utf8).write(to: target, options: .atomic)

        case .removeFile:
            try FileManager.default.removeItem(at: target)
        }
    }

    private static func containedTarget(
        for relativePath: CanonicalRelativePath,
        in root: URL
    ) throws -> URL {
        let standardizedRoot = root.standardizedFileURL
        let target = standardizedRoot
            .appendingPathComponent(relativePath.rawValue)
            .standardizedFileURL
        guard target.path.hasPrefix(standardizedRoot.path + "/") else {
            throw fixtureContract("mutation path escapes fixture root")
        }

        let resolvedRoot = standardizedRoot.resolvingSymlinksInPath()
        let fileManager = FileManager.default
        let anchor = fileManager.fileExists(atPath: target.path)
            ? target
            : target.deletingLastPathComponent()
        let resolvedAnchor = anchor.resolvingSymlinksInPath()
        guard resolvedAnchor.path == resolvedRoot.path
            || resolvedAnchor.path.hasPrefix(resolvedRoot.path + "/")
        else {
            throw fixtureContract("mutation path resolves outside fixture root")
        }
        return target
    }

    private static func rebuildAffectedIndexDigest(
        for relativePath: String,
        in root: URL
    ) throws {
        let recordURL = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: recordURL.path) else { return }

        let recordDigest = try CanonicalTreeDigest.sha256(Data(contentsOf: recordURL)).rawValue
        let registry = root.appendingPathComponent("registry", isDirectory: true)
        let indexNames = try FileManager.default.contentsOfDirectory(atPath: registry.path)
            .filter { $0.hasSuffix(".index.json") }
            .sorted()

        for indexName in indexNames {
            let indexURL = registry.appendingPathComponent(indexName)
            let data = try Data(contentsOf: indexURL)
            guard var index = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  var entries = index["entries"] as? [[String: Any]]
            else {
                throw fixtureContract("record index has an invalid shape")
            }

            var changed = false
            for entryIndex in entries.indices
                where entries[entryIndex]["relative_path"] as? String == relativePath
            {
                entries[entryIndex]["record_digest"] = recordDigest
                changed = true
            }
            if changed {
                index["entries"] = entries
                try fixtureCanonicalJSONFileData(index).write(to: indexURL, options: .atomic)
            }
        }
    }

    private static func mutate(
        _ node: Any,
        tokens: ArraySlice<String>,
        operation: FixtureMutation.Operation,
        replacement: Any?
    ) throws -> Any {
        let token = try require(tokens.first, "JSON mutation pointer has no target")
        let remaining = tokens.dropFirst()

        if var object = node as? [String: Any] {
            if remaining.isEmpty {
                switch operation {
                case .jsonAdd:
                    object[token] = try require(replacement, "json_add requires a value")
                case .jsonReplace:
                    guard object[token] != nil else {
                        throw fixtureContract("json_replace target does not exist")
                    }
                    object[token] = try require(replacement, "json_replace requires a value")
                case .jsonRemove:
                    guard object.removeValue(forKey: token) != nil else {
                        throw fixtureContract("json_remove target does not exist")
                    }
                case .writeUTF8, .removeFile:
                    throw fixtureContract("non-JSON operation reached JSON mutation engine")
                }
                return object
            }
            let child = try require(
                object[token],
                "JSON mutation object target does not exist"
            )
            object[token] = try mutate(
                child,
                tokens: remaining,
                operation: operation,
                replacement: replacement
            )
            return object
        }

        if var array = node as? [Any] {
            if remaining.isEmpty {
                switch operation {
                case .jsonAdd:
                    let value = try require(replacement, "json_add requires a value")
                    if token == "-" {
                        array.append(value)
                        return array
                    }
                    guard let index = Int(token), index >= 0, index <= array.count else {
                        throw fixtureContract("json_add array target does not exist")
                    }
                    array.insert(value, at: index)
                case .jsonReplace:
                    guard let index = Int(token), array.indices.contains(index) else {
                        throw fixtureContract("json_replace array target does not exist")
                    }
                    array[index] = try require(replacement, "json_replace requires a value")
                case .jsonRemove:
                    guard let index = Int(token), array.indices.contains(index) else {
                        throw fixtureContract("json_remove array target does not exist")
                    }
                    array.remove(at: index)
                case .writeUTF8, .removeFile:
                    throw fixtureContract("non-JSON operation reached JSON mutation engine")
                }
                return array
            }
            guard let index = Int(token), array.indices.contains(index) else {
                throw fixtureContract("JSON mutation array target does not exist")
            }
            array[index] = try mutate(
                array[index],
                tokens: remaining,
                operation: operation,
                replacement: replacement
            )
            return array
        }

        throw fixtureContract("JSON mutation traverses a scalar")
    }

    private static func require<T>(_ value: T?, _ reason: String) throws -> T {
        guard let value else { throw fixtureContract(reason) }
        return value
    }
}
