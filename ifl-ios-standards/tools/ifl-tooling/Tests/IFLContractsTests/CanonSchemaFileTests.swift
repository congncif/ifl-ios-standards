import Foundation
import Testing

@Suite("CanonSchemaFileTests")
struct CanonSchemaFileTests {
    @Test("the twelve required v1 schemas have exact filenames and stable identities")
    func requiredFilesAndStableIdentities() throws {
        var topLevelIDs: [String] = []
        var everyDeclaredID: [String] = []

        for expectation in schemaExpectations {
            let url = schemaURL(for: expectation.filename)
            let exists = FileManager.default.fileExists(atPath: url.path)
            #expect(exists, "Missing required Canon schema: \(expectation.filename)")
            guard exists else { continue }

            let schema = try decodeObject(at: url)
            #expect(schema["$schema"] as? String == "https://json-schema.org/draft/2020-12/schema")
            #expect(schema["$id"] as? String == expectation.id)

            if let id = schema["$id"] as? String {
                topLevelIDs.append(id)
            }
            everyDeclaredID.append(contentsOf: declaredSchemaIDs(in: schema))
        }

        #expect(topLevelIDs.count == Set(topLevelIDs).count)
        #expect(everyDeclaredID.count == Set(everyDeclaredID).count)
    }

    @Test("every v1 schema has a closed version-one object envelope")
    func closedVersionedObjectEnvelopes() throws {
        for expectation in schemaExpectations {
            guard let schema = try loadIfPresent(expectation.filename) else { continue }
            let properties = schema["properties"] as? [String: Any]
            let schemaVersion = properties?["schema_version"] as? [String: Any]

            #expect(schema["type"] as? String == "object", "\(expectation.filename) must be an object")
            #expect(schema["additionalProperties"] as? Bool == false, "\(expectation.filename) must reject unknown keys")
            #expect(isInteger(schemaVersion?["const"], equalTo: 1), "\(expectation.filename) must pin schema_version to 1")
            #expect(requiredNames(in: schema)?.contains("schema_version") == true)
        }
    }

    @Test("all twelve schemas use canonical sorted compact JSON with one trailing LF")
    func canonicalSchemaBytes() throws {
        for expectation in schemaExpectations {
            let url = schemaURL(for: expectation.filename)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }

            let actual = try Data(contentsOf: url)
            let value = try JSONSerialization.jsonObject(with: actual)
            var canonical = try JSONSerialization.data(
                withJSONObject: value,
                options: [.sortedKeys, .withoutEscapingSlashes]
            )
            canonical.append(0x0A)

            let isCanonical = actual == canonical
            #expect(
                isCanonical,
                "\(expectation.filename) must equal sorted/minified JSON bytes followed by exactly one LF"
            )
        }
    }

    @Test("standalone contracts expose only their approved top-level fields")
    func standaloneTopLevelShapesAreExact() throws {
        for shape in standaloneShapes {
            guard let schema = try loadIfPresent(shape.filename) else { continue }
            let properties = try #require(schema["properties"] as? [String: Any])
            let required = try #require(requiredNames(in: schema))

            #expect(Set(properties.keys) == shape.fields, "\(shape.filename) has an unapproved top-level property")
            #expect(Set(required) == shape.fields, "\(shape.filename) must require every top-level property")
            #expect(required.count == Set(required).count, "\(shape.filename) repeats a required property")
        }
    }

    var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func schemaURL(for filename: String) -> URL {
        pluginRoot.appendingPathComponent("standards/canon/schemas/v1/\(filename)")
    }

    func loadIfPresent(_ filename: String) throws -> [String: Any]? {
        let url = schemaURL(for: filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decodeObject(at: url)
    }

    func decodeObject(at url: URL) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
            "Schema must contain one JSON object: \(url.lastPathComponent)"
        )
    }
}

struct SchemaExpectation {
    let filename: String
    let id: String
}

struct StandaloneShape {
    let filename: String
    let fields: Set<String>
}

let schemaExpectations: [SchemaExpectation] = [
    .init(filename: "rule.schema.json", id: "urn:ifl:standards:schema:rule:v1"),
    .init(filename: "profile.schema.json", id: "urn:ifl:standards:schema:profile:v1"),
    .init(filename: "adr-metadata.schema.json", id: "urn:ifl:standards:schema:adr-metadata:v1"),
    .init(filename: "chapter.schema.json", id: "urn:ifl:standards:schema:chapter:v1"),
    .init(filename: "candidate-overlay.schema.json", id: "urn:ifl:standards:schema:candidate-overlay:v1"),
    .init(filename: "activation-receipt.schema.json", id: "urn:ifl:standards:schema:activation-receipt:v1"),
    .init(filename: "exception.schema.json", id: "urn:ifl:standards:schema:exception:v1"),
    .init(filename: "fixture.schema.json", id: "urn:ifl:standards:schema:fixture:v1"),
    .init(filename: "derived-artifact.schema.json", id: "urn:ifl:standards:schema:derived-artifact:v1"),
    .init(filename: "derived-registration-delta.schema.json", id: "urn:ifl:standards:schema:derived-registration-delta:v1"),
    .init(filename: "traceability.schema.json", id: "urn:ifl:standards:schema:traceability:v1"),
    .init(filename: "compatibility-matrix.schema.json", id: "urn:ifl:standards:schema:compatibility-matrix:v1"),
]

let standaloneShapes: [StandaloneShape] = [
    .init(
        filename: "fixture.schema.json",
        fields: ["schema_version", "fixture_id", "base_fixture", "mutations", "expected"]
    ),
    .init(
        filename: "derived-artifact.schema.json",
        fields: ["schema_version", "id", "entries"]
    ),
    .init(
        filename: "compatibility-matrix.schema.json",
        fields: ["schema_version", "product_version", "canon_version", "unmatched_version_status", "rows"]
    ),
]
