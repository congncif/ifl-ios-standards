import Foundation
import IFLContracts
import Testing

enum CanonRepositoryFixture {
    typealias JSONObject = [String: Any]

    static let positiveRoot = pluginRoot
        .appendingPathComponent("verification/fixtures/canon/positive/minimal")

    static func withPositiveRoot<T>(_ body: (URL) throws -> T) throws -> T {
        let fileManager = FileManager.default
        let workspace = fileManager.temporaryDirectory
            .appendingPathComponent("ifl-canon-repository-\(UUID().uuidString)", isDirectory: true)
        let root = workspace.appendingPathComponent("canon", isDirectory: true)
        try fileManager.createDirectory(at: workspace, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: workspace) }
        try fileManager.copyItem(at: positiveRoot, to: root)
        return try body(root)
    }

    static func coreProfileID() throws -> ProfileID {
        try ProfileID(validating: "core")
    }

    static func object(at relativePath: String, in root: URL) throws -> JSONObject {
        let value = try JSONSerialization.jsonObject(
            with: Data(contentsOf: root.appendingPathComponent(relativePath)),
            options: [.fragmentsAllowed]
        )
        return try #require(value as? JSONObject)
    }

    static func mutateObject(
        at relativePath: String,
        in root: URL,
        _ mutation: (inout JSONObject) throws -> Void
    ) throws {
        var value = try object(at: relativePath, in: root)
        try mutation(&value)
        try writeCanonicalJSONObject(value, to: relativePath, in: root)
    }

    static func writeCanonicalJSONObject(
        _ value: JSONObject,
        to relativePath: String,
        in root: URL
    ) throws {
        var data = try JSONSerialization.data(
            withJSONObject: value,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0A)
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        try setPermissions(0o644, at: url)
        try setPermissions(0o755, at: url.deletingLastPathComponent())
    }

    static func updateRecordDigest(
        for relativePath: String,
        in indexFilename: String,
        root: URL
    ) throws {
        let recordData = try Data(contentsOf: root.appendingPathComponent(relativePath))
        let digest = CanonicalTreeDigest.sha256(recordData).rawValue
        try mutateObject(at: "registry/\(indexFilename)", in: root) { index in
            var entries = try #require(index["entries"] as? [JSONObject])
            let entryIndex = try #require(
                entries.firstIndex { $0["relative_path"] as? String == relativePath }
            )
            entries[entryIndex]["record_digest"] = digest
            index["entries"] = entries
        }
    }

    static func addRecordIndexEntry(
        id: String,
        relativePath: String,
        indexFilename: String,
        root: URL
    ) throws {
        let digest = try CanonicalTreeDigest.sha256(
            Data(contentsOf: root.appendingPathComponent(relativePath))
        ).rawValue
        try mutateObject(at: "registry/\(indexFilename)", in: root) { index in
            var entries = try #require(index["entries"] as? [JSONObject])
            entries.append([
                "id": id,
                "record_digest": digest,
                "relative_path": relativePath,
            ])
            entries.sort {
                (($0["id"] as? String) ?? "").utf8.lexicographicallyPrecedes(
                    (($1["id"] as? String) ?? "").utf8
                )
            }
            index["entries"] = entries
        }
    }

    static func contractError(_ operation: () throws -> Void) -> ContractError? {
        do {
            try operation()
            Issue.record("Expected ContractError but the operation succeeded")
            return nil
        } catch let error as ContractError {
            return error
        } catch {
            Issue.record("Expected ContractError but received \(error)")
            return nil
        }
    }

    static func setPermissions(_ permissions: Int, at url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: permissions],
            ofItemAtPath: url.path
        )
    }

    private static let pluginRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

final class CanonRepositoryMutationHook: @unchecked Sendable {
    private let lock = NSLock()
    private var hasRun = false
    private let mutation: () throws -> Void

    init(mutation: @escaping () throws -> Void) {
        self.mutation = mutation
    }

    func runOnce() throws {
        lock.lock()
        defer { lock.unlock() }
        guard !hasRun else { return }
        hasRun = true
        try mutation()
    }
}
