import Foundation
import Testing

extension CanonSchemaFileTests {
    @Test("fixture schema can express every Task 2 negative with exact operation and error vocabularies")
    func fixtureVocabularyIsCompleteAndCausal() throws {
        let schema = try #require(try loadIfPresent("fixture.schema.json"))
        let definitions = try #require(schema["$defs"] as? [String: Any])
        let mutation = try #require(definitions["mutation"] as? [String: Any])
        let branches = try #require(mutation["oneOf"] as? [[String: Any]])

        var operationSchemas: [String: [String: Any]] = [:]
        for branch in branches {
            let resolved = try #require(resolvedSchema(branch, root: schema))
            let operations = stringConstants(for: "operation", in: resolved, root: schema)
            let operation = try #require(operations.count == 1 ? operations[0] : nil)
            operationSchemas[operation] = resolved
        }
        #expect(Set(operationSchemas.keys) == Set(fixtureOperationFields.keys))

        for (operation, expectedFields) in fixtureOperationFields {
            let operationSchema = operationSchemas[operation]
            #expect(operationSchema != nil, "missing fixture mutation operation \(operation)")
            guard let operationSchema else { continue }
            let properties = try #require(operationSchema["properties"] as? [String: Any])
            let required = try #require(requiredNames(in: operationSchema))
            #expect(Set(properties.keys) == expectedFields)
            #expect(Set(required) == expectedFields)
        }

        for operation in ["json_add", "json_replace"] {
            guard let operationSchema = operationSchemas[operation] else { continue }
            for value: Any in [NSNull(), ["id": "REQ-CANON"], [1, 2, 3]] {
                let witness: [String: Any] = [
                    "operation": operation,
                    "relative_path": "registry/requirements.v1.json",
                    "json_pointer": "/requirements/0",
                    "value": value,
                ]
                let acceptedWitness = schemaAccepts(witness, against: operationSchema, root: schema)
                #expect(
                    acceptedWitness,
                    "\(operation) must carry any JSON value, including null/object/array"
                )
            }
        }

        let declaredErrorCodes = findStringEnum(named: "contract_error_code", in: schema)
        #expect(declaredErrorCodes != nil, "fixture expected contract must declare contract_error_code")
        let expectedErrorCodes = Set(declaredErrorCodes ?? [])
        #expect(expectedErrorCodes == contractErrorCodes)
        let missingOperations = task2NegativeCapabilities.filter { operationSchemas[$0.operation] == nil }
            .map { "\($0.fixture):\($0.operation)" }
        let missingErrorCodes = task2NegativeCapabilities.filter { !expectedErrorCodes.contains($0.errorCode) }
            .map { "\($0.fixture):\($0.errorCode)" }
        #expect(missingOperations.isEmpty, "Task 2 negatives lack operations \(missingOperations)")
        #expect(missingErrorCodes.isEmpty, "Task 2 negatives lack error codes \(missingErrorCodes)")
    }

    @Test("fixture base locator names the exact positive minimal root")
    func fixtureBaseLocatorIsExactAndCausal() throws {
        let schema = try #require(try loadIfPresent("fixture.schema.json"))
        let properties = try #require(schema["properties"] as? [String: Any])
        let baseFixture = try #require(properties["base_fixture"] as? [String: Any])

        #expect(schemaAccepts("positive/minimal", against: baseFixture, root: schema))
        #expect(!schemaAccepts("positive", against: baseFixture, root: schema))
        #expect(!schemaAccepts("minimal", against: baseFixture, root: schema))
        #expect(Set(baseFixture["enum"] as? [String] ?? []) == ["positive/minimal"])
    }
}

struct NegativeFixtureCapability {
    let fixture: String
    let operation: String
    let errorCode: String
}

let fixtureOperationFields: [String: Set<String>] = [
    "json_add": ["operation", "relative_path", "json_pointer", "value"],
    "json_replace": ["operation", "relative_path", "json_pointer", "value"],
    "json_remove": ["operation", "relative_path", "json_pointer"],
    "write_utf8": ["operation", "relative_path", "utf8_content"],
    "remove_file": ["operation", "relative_path"],
]

let contractErrorCodes: Set<String> = [
    "invalid_identifier",
    "invalid_run_id_filesystem_component",
    "invalid_candidate_generation",
    "candidate_generation_overflow",
    "invalid_sha256",
    "unsupported_schema_version",
    "invalid_canon_version",
    "duplicate_identifier",
    "reused_identifier",
    "unresolved_reference",
    "invalid_contract",
    "digest_mismatch",
    "unexpected_keys",
]

let task2NegativeCapabilities: [NegativeFixtureCapability] = [
    .init(fixture: "duplicate-id", operation: "json_add", errorCode: "duplicate_identifier"),
    .init(fixture: "unknown-version", operation: "json_replace", errorCode: "unsupported_schema_version"),
    .init(fixture: "reused-id", operation: "json_replace", errorCode: "reused_identifier"),
    .init(fixture: "orphan-requirement", operation: "json_replace", errorCode: "unresolved_reference"),
    .init(fixture: "missing-convergence-traceability", operation: "json_remove", errorCode: "unresolved_reference"),
    .init(fixture: "accepted-adr-incomplete", operation: "json_remove", errorCode: "invalid_contract"),
]
