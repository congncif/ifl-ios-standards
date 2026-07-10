import Foundation
@testable import IFLContracts
import Testing

@Suite("CanonicalRelativePathParityTests")
struct CanonicalRelativePathParityTests {
    @Test("schema format and Swift contracts accept the same canonical path corpus")
    func schemaAndSwiftContractParity() throws {
        let definitions = try schemaDefinitions()
        let normativePattern = try #require(definitions.first?.pattern)
        let validPaths = [
            "file.json",
            "nested/value.txt",
            "sp ace/é.json",
            "bracket].json",
        ]
        let invalidPaths = [
            "",
            "/absolute",
            "a//b",
            "a/",
            ".",
            "..",
            "./a",
            "a/.",
            "a/../b",
            "a\\b",
            "*.json",
            "a?.json",
            "a[bc].json",
            "nul\u{0000}byte",
            "c0\u{001F}control",
            "del\u{007F}control",
            "c1\u{0085}control",
            "line\u{2028}separator",
            "paragraph\u{2029}separator",
            "e\u{301}.json",
        ]

        for definition in definitions {
            #expect(
                definition.pattern == normativePattern,
                "\(definition.filename) does not publish the normative canonical relative-path pattern"
            )
            #expect(
                definition.format == "ifl-canonical-relative-path-v1",
                "\(definition.filename) does not bind the canonical relative-path format"
            )
            #expect(
                definition.assertsFormat,
                "\(definition.filename) does not require canonical relative-path format assertion"
            )
        }

        for path in validPaths {
            for definition in definitions {
                #expect(
                    try schemaAccepts(path, definition: definition),
                    "\(definition.filename) rejected valid path: \(path)"
                )
            }
            #expect(try CanonicalRelativePath(validating: path).rawValue == path)
            #expect(
                try IFLCanonContractSupport.exactRelativePath(
                    path,
                    kind: "path_parity_test",
                    field: "relative_path"
                ) == path
            )
        }

        for path in invalidPaths {
            for definition in definitions {
                #expect(
                    try !schemaAccepts(path, definition: definition),
                    "\(definition.filename) accepted invalid path: \(path)"
                )
            }
            #expect(throws: CanonicalTreeError.self) {
                try CanonicalRelativePath(validating: path)
            }
            #expect(throws: ContractError.self) {
                try IFLCanonContractSupport.exactRelativePath(
                    path,
                    kind: "path_parity_test",
                    field: "relative_path"
                )
            }
        }
    }
}

private extension CanonicalRelativePathParityTests {
    struct SchemaDefinition {
        let filename: String
        let pattern: String
        let format: String?
        let assertsFormat: Bool
    }

    var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func schemaDefinitions() throws -> [SchemaDefinition] {
        let schemas = [
            (filename: "candidate-overlay.schema.json", definition: "exact_relative_path"),
            (filename: "canonical-tree-inventory.schema.json", definition: "relative_path"),
            (filename: "derived-artifact.schema.json", definition: "exact_relative_path"),
            (filename: "derived-registration-delta.schema.json", definition: "exact_relative_path"),
            (filename: "exception.schema.json", definition: "exact_relative_path"),
            (filename: "fixture.schema.json", definition: "exact_relative_path"),
        ]

        return try schemas.map { schema in
            let url = pluginRoot.appendingPathComponent("standards/canon/schemas/v1/\(schema.filename)")
            let root = try #require(
                JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
            )
            let definitions = try #require(root["$defs"] as? [String: Any])
            let relativePath = try #require(definitions[schema.definition] as? [String: Any])
            return try SchemaDefinition(
                filename: schema.filename,
                pattern: #require(relativePath["pattern"] as? String),
                format: relativePath["format"] as? String,
                assertsFormat: relativePath["x-ifl-format-assertion-required"] as? Bool ?? false
            )
        }
    }

    func schemaAccepts(_ value: String, definition: SchemaDefinition) throws -> Bool {
        let expression = try NSRegularExpression(pattern: definition.pattern)
        let range = NSRange(value.startIndex ..< value.endIndex, in: value)
        guard expression.firstMatch(in: value, range: range)?.range == range else {
            return false
        }

        guard definition.format == "ifl-canonical-relative-path-v1",
              definition.assertsFormat
        else {
            return true
        }
        return value.utf8.elementsEqual(value.precomposedStringWithCanonicalMapping.utf8)
    }
}
