import Foundation
import IFLContracts
import Testing

@Suite("FixtureMutationApplicatorTests")
struct FixtureMutationApplicatorTests {
    @Test("root JSON add replace and remove accept null and object values")
    func rootMutationMatrix() throws {
        try withTemporaryRoot { root in
            let path = "root.json"
            try writeJSON(["before": true], to: path, in: root)

            try FixtureCanon.apply(try manifest(mutations: [[
                "json_pointer": "",
                "operation": "json_add",
                "relative_path": path,
                "value": NSNull(),
            ]]), to: root)
            #expect(try data(at: path, in: root) == Data("null\n".utf8))

            try FixtureCanon.apply(try manifest(mutations: [[
                "json_pointer": "",
                "operation": "json_replace",
                "relative_path": path,
                "value": ["items": [1, 2]],
            ]]), to: root)
            #expect(try data(at: path, in: root) == Data("{\"items\":[1,2]}\n".utf8))

            try FixtureCanon.apply(try manifest(mutations: [[
                "json_pointer": "",
                "operation": "json_replace",
                "relative_path": path,
                "value": ["array", NSNull()],
            ]]), to: root)
            #expect(try data(at: path, in: root) == Data("[\"array\",null]\n".utf8))

            try FixtureCanon.apply(try manifest(mutations: [[
                "json_pointer": "",
                "operation": "json_remove",
                "relative_path": path,
            ]]), to: root)
            #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }
    }

    @Test("object JSON add replace and remove execute against the requested members")
    func objectMutationMatrix() throws {
        try withTemporaryRoot { root in
            let path = "object.json"
            try writeJSON(
                ["keep": "yes", "remove": "gone", "replace": "old"],
                to: path,
                in: root
            )

            let mutations: [[String: Any]] = [
                [
                    "json_pointer": "/added",
                    "operation": "json_add",
                    "relative_path": path,
                    "value": NSNull(),
                ],
                [
                    "json_pointer": "/replace",
                    "operation": "json_replace",
                    "relative_path": path,
                    "value": ["nested": [1, 2]],
                ],
                [
                    "json_pointer": "/remove",
                    "operation": "json_remove",
                    "relative_path": path,
                ],
            ]
            try FixtureCanon.apply(try manifest(mutations: mutations), to: root)

            #expect(
                try data(at: path, in: root)
                    == Data("{\"added\":null,\"keep\":\"yes\",\"replace\":{\"nested\":[1,2]}}\n".utf8)
            )
        }
    }

    @Test("array JSON add replace and remove preserve RFC 6902 order")
    func arrayMutationMatrix() throws {
        try withTemporaryRoot { root in
            let path = "array.json"
            try writeJSON(["first", "second", "third"], to: path, in: root)

            let mutations: [[String: Any]] = [
                [
                    "json_pointer": "/1",
                    "operation": "json_add",
                    "relative_path": path,
                    "value": "inserted",
                ],
                [
                    "json_pointer": "/2",
                    "operation": "json_replace",
                    "relative_path": path,
                    "value": "replaced",
                ],
                [
                    "json_pointer": "/0",
                    "operation": "json_remove",
                    "relative_path": path,
                ],
                [
                    "json_pointer": "/-",
                    "operation": "json_add",
                    "relative_path": path,
                    "value": "tail",
                ],
            ]
            try FixtureCanon.apply(try manifest(mutations: mutations), to: root)

            #expect(
                try data(at: path, in: root)
                    == Data("[\"inserted\",\"replaced\",\"third\",\"tail\"]\n".utf8)
            )
        }
    }

    @Test("write_utf8 creates a file and replaces its bytes")
    func writeUTF8CreateAndReplace() throws {
        try withTemporaryRoot { root in
            let path = "notes.txt"
            try FixtureCanon.apply(try manifest(mutations: [[
                "operation": "write_utf8",
                "relative_path": path,
                "utf8_content": "created",
            ]]), to: root)
            #expect(try data(at: path, in: root) == Data("created".utf8))

            try FixtureCanon.apply(try manifest(mutations: [[
                "operation": "write_utf8",
                "relative_path": path,
                "utf8_content": "replaced",
            ]]), to: root)
            #expect(try data(at: path, in: root) == Data("replaced".utf8))
        }
    }

    @Test("remove_file removes the selected file")
    func removeFile() throws {
        try withTemporaryRoot { root in
            let path = "obsolete.txt"
            try Data("obsolete".utf8).write(to: root.appendingPathComponent(path))

            try FixtureCanon.apply(try manifest(mutations: [[
                "operation": "remove_file",
                "relative_path": path,
            ]]), to: root)

            #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }
    }

    @Test("multiple mutations execute in declared order")
    func mutationOrder() throws {
        try withTemporaryRoot { root in
            let path = "ordered.json"
            try writeJSON(["state": 0], to: path, in: root)

            let mutations: [[String: Any]] = [
                jsonMutation("json_replace", path: path, pointer: "/state", value: 1),
                jsonMutation("json_replace", path: path, pointer: "/state", value: 2),
                [
                    "json_pointer": "/state",
                    "operation": "json_remove",
                    "relative_path": path,
                ],
                jsonMutation("json_add", path: path, pointer: "/state", value: 3),
            ]
            try FixtureCanon.apply(try manifest(mutations: mutations), to: root)

            #expect(try data(at: path, in: root) == Data("{\"state\":3}\n".utf8))
        }
    }

    @Test("record mutation rebuilds every matching record-index digest")
    func affectedRecordIndexDigestIsRebuilt() throws {
        try withTemporaryRoot { root in
            let recordPath = "rules/sample.json"
            let indexPath = "registry/rules.index.json"
            try writeJSON(["value": 1], to: recordPath, in: root)
            try writeJSON(
                [
                    "entries": [[
                        "record_digest": String(repeating: "0", count: 64),
                        "relative_path": recordPath,
                    ]],
                    "schema_version": 1,
                ],
                to: indexPath,
                in: root
            )

            try FixtureCanon.apply(try manifest(mutations: [
                jsonMutation("json_replace", path: recordPath, pointer: "/value", value: 2),
            ]), to: root)

            let recordData = try data(at: recordPath, in: root)
            let expectedDigest = CanonicalTreeDigest.sha256(recordData).rawValue
            let index = try #require(
                JSONSerialization.jsonObject(with: try data(at: indexPath, in: root))
                    as? [String: Any]
            )
            let entries = try #require(index["entries"] as? [[String: Any]])
            #expect(entries.first?["record_digest"] as? String == expectedDigest)
        }
    }

    private func withTemporaryRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ifl-fixture-applicator-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("registry", isDirectory: true),
            withIntermediateDirectories: false
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func manifest(mutations: [[String: Any]]) throws -> FixtureManifest {
        try FixtureCanon.decodeManifest(fixtureCanonicalJSONFileData([
            "base_fixture": "positive/minimal",
            "expected": [
                "contract_error_code": "invalid_contract",
                "kind": "contract_error",
            ],
            "fixture_id": "FIX-APPLICATOR-001",
            "mutations": mutations,
            "schema_version": 1,
        ]))
    }

    private func jsonMutation(
        _ operation: String,
        path: String,
        pointer: String,
        value: Any
    ) -> [String: Any] {
        [
            "json_pointer": pointer,
            "operation": operation,
            "relative_path": path,
            "value": value,
        ]
    }

    private func writeJSON(_ object: Any, to relativePath: String, in root: URL) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fixtureCanonicalJSONFileData(object).write(to: url)
    }

    private func data(at relativePath: String, in root: URL) throws -> Data {
        try Data(contentsOf: root.appendingPathComponent(relativePath))
    }
}
