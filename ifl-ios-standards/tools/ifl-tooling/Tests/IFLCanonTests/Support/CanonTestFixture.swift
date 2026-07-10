import Foundation
import IFLContracts
import Testing

enum CanonTestFixture {
    typealias JSONMutation = (inout [String: Any]) throws -> Void

    static func rule(_ mutate: JSONMutation = { _ in }) throws -> RuleRecord {
        try record(
            RuleRecord.self,
            at: "rules/core/minimal.rules.json",
            mutate: mutate
        )
    }

    static func profile(_ mutate: JSONMutation = { _ in }) throws -> ProfileRecord {
        try record(
            ProfileRecord.self,
            at: "profiles/minimal.profile.json",
            mutate: mutate
        )
    }

    static func adr(_ mutate: JSONMutation = { _ in }) throws -> ADRMetadata {
        try record(
            ADRMetadata.self,
            at: "adrs/ADR-9999-minimal-test.json",
            mutate: mutate
        )
    }

    static func adr(
        matchingMarkdown markdown: String,
        _ mutate: JSONMutation = { _ in }
    ) throws -> ADRMetadata {
        try adr { object in
            object["markdown_digest"] = markdownDigest(markdown).rawValue
            try mutate(&object)
        }
    }

    static func adrMarkdown() throws -> String {
        let data = try fixtureData("adrs/ADR-9999-minimal-test.md")
        return String(decoding: data, as: UTF8.self)
    }

    static func markdownDigest(_ markdown: String) -> HashDigest {
        CanonicalTreeDigest.sha256(Data(markdown.utf8))
    }

    static func encodedPropertyNames(_ value: some Encodable) throws -> Set<String> {
        let object = try JSONSerialization.jsonObject(with: CanonicalJSON.encode(value))
        return Set(try #require((object as? [String: Any])?.keys))
    }

    static func schemaPropertyNames(_ filename: String) throws -> Set<String> {
        let data = try Data(
            contentsOf: pluginRoot
                .appendingPathComponent("standards/canon/schemas/v1")
                .appendingPathComponent(filename)
        )
        let root = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let properties = try #require(root["properties"] as? [String: Any])
        return Set(properties.keys)
    }

    private static var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static var positiveRoot: URL {
        pluginRoot.appendingPathComponent("verification/fixtures/canon/positive/minimal")
    }

    private static func record<Value: Decodable>(
        _ type: Value.Type,
        at relativePath: String,
        mutate: JSONMutation
    ) throws -> Value {
        let value = try JSONSerialization.jsonObject(
            with: fixtureData(relativePath)
        )
        var object = try #require(value as? [String: Any])
        try mutate(&object)
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return try CanonicalJSON.decode(type, from: data)
    }

    private static func fixtureData(_ relativePath: String) throws -> Data {
        try Data(contentsOf: positiveRoot.appendingPathComponent(relativePath))
    }
}
