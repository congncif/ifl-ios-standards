import Foundation
import Testing

@Suite("FixtureSchemaParityTests")
struct FixtureSchemaParityTests {
    @Test("fixture schema vocabulary and exact object shapes match the typed harness")
    func vocabularyAndShapesMatchHarness() throws {
        let schema = try loadSchema()
        let definitions = try definitions(in: schema)
        let topLevelProperties = try properties(in: schema)

        #expect(Set(topLevelProperties.keys) == FixtureManifestContract.manifestKeys)
        #expect(requiredKeys(in: schema) == FixtureManifestContract.manifestKeys)
        #expect(schema["additionalProperties"] as? Bool == false)

        let mutationUnion = try definition("mutation", in: definitions)
        let mutationBranches = try #require(mutationUnion["oneOf"] as? [[String: Any]])
        var discoveredOperations: Set<FixtureMutation.Operation> = []
        for branch in mutationBranches {
            let operationSchema = try resolve(branch, in: schema)
            let operationProperties = try properties(in: operationSchema)
            let operationNode = try #require(operationProperties["operation"] as? [String: Any])
            let operationName = try #require(operationNode["const"] as? String)
            let operation = try #require(FixtureMutation.Operation(rawValue: operationName))

            discoveredOperations.insert(operation)
            #expect(Set(operationProperties.keys) == operation.requiredKeys)
            #expect(requiredKeys(in: operationSchema) == operation.requiredKeys)
            #expect(operationSchema["additionalProperties"] as? Bool == false)
        }
        #expect(discoveredOperations == Set(FixtureMutation.Operation.allCases))

        let contractExpected = try definition("expected_contract_error", in: definitions)
        let contractProperties = try properties(in: contractExpected)
        let errorCode = try #require(
            contractProperties["contract_error_code"] as? [String: Any]
        )
        #expect(
            Set(errorCode["enum"] as? [String] ?? [])
                == FixtureManifestContract.contractErrorCodes
        )
        #expect(Set(contractProperties.keys) == FixtureManifestContract.contractExpectedKeys)
        #expect(requiredKeys(in: contractExpected) == FixtureManifestContract.contractExpectedKeys)
        #expect(contractExpected["additionalProperties"] as? Bool == false)

        let findingsExpected = try definition("expected_findings", in: definitions)
        let findingsProperties = try properties(in: findingsExpected)
        #expect(Set(findingsProperties.keys) == FixtureManifestContract.findingsExpectedKeys)
        #expect(requiredKeys(in: findingsExpected) == FixtureManifestContract.findingsExpectedKeys)
        #expect(findingsExpected["additionalProperties"] as? Bool == false)
    }

    @Test("fixture schema patterns and scalar limits match the typed harness")
    func patternsAndLimitsMatchHarness() throws {
        let schema = try loadSchema()
        let definitions = try definitions(in: schema)
        let topLevelProperties = try properties(in: schema)
        let fixtureID = try #require(topLevelProperties["fixture_id"] as? [String: Any])
        #expect(fixtureID["pattern"] as? String == FixtureManifestContract.fixtureIDPattern)

        let findings = try definition("expected_findings", in: definitions)
        let findingsProperties = try properties(in: findings)
        let checkIDs = try #require(findingsProperties["check_ids"] as? [String: Any])
        let checkIDItems = try #require(checkIDs["items"] as? [String: Any])
        #expect(checkIDItems["pattern"] as? String == FixtureManifestContract.checkIDPattern)

        let path = try definition("exact_relative_path", in: definitions)
        #expect(path["pattern"] as? String == FixtureManifestContract.relativePathPattern)
        #expect(path["format"] as? String == "ifl-canonical-relative-path-v1")
        #expect(path["x-ifl-format-assertion-required"] as? Bool == true)

        for name in ["json_add_mutation", "json_replace_mutation", "json_remove_mutation"] {
            let mutation = try definition(name, in: definitions)
            let mutationProperties = try properties(in: mutation)
            let pointer = try #require(mutationProperties["json_pointer"] as? [String: Any])
            #expect(pointer["pattern"] as? String == FixtureManifestContract.jsonPointerPattern)
        }

        let writeUTF8 = try definition("write_utf8_mutation", in: definitions)
        let writeProperties = try properties(in: writeUTF8)
        let content = try #require(writeProperties["utf8_content"] as? [String: Any])
        #expect(
            integerText(content["maxLength"])
                == String(FixtureManifestContract.maximumUTF8ContentScalars)
        )
    }

    @Test("fixture JSON value schema is recursive and limited to signed 64-bit integers")
    func recursiveJSONValueDomainMatchesHarness() throws {
        let schema = try loadSchema()
        let definitions = try definitions(in: schema)
        let value = try definition("fixture_json_value", in: definitions)
        let branches = try #require(value["oneOf"] as? [[String: Any]])
        let byType = Dictionary(uniqueKeysWithValues: try branches.map { branch in
            (try #require(branch["type"] as? String), branch)
        })

        #expect(Set(byType.keys) == FixtureManifestContract.jsonValueTypes)

        let integer = try #require(byType["integer"])
        #expect(integerText(integer["minimum"]) == String(Int64.min))
        #expect(integerText(integer["maximum"]) == String(Int64.max))

        let array = try #require(byType["array"])
        let arrayItems = try #require(array["items"] as? [String: Any])
        #expect(arrayItems["$ref"] as? String == "#/$defs/fixture_json_value")

        let object = try #require(byType["object"])
        let additionalProperties = try #require(
            object["additionalProperties"] as? [String: Any]
        )
        #expect(additionalProperties["$ref"] as? String == "#/$defs/fixture_json_value")

        for name in ["json_add_mutation", "json_replace_mutation"] {
            let mutation = try definition(name, in: definitions)
            let mutationProperties = try properties(in: mutation)
            let valueProperty = try #require(mutationProperties["value"] as? [String: Any])
            #expect(valueProperty["$ref"] as? String == "#/$defs/fixture_json_value")
        }
    }

    @Test("signed 64-bit fixture integers retain exact bytes and reject numbers outside the domain")
    func integerBoundaryAndExactness() throws {
        let schema = try loadSchema()
        let definitions = try definitions(in: schema)
        let value = try definition("fixture_json_value", in: definitions)
        let branches = try #require(value["oneOf"] as? [[String: Any]])
        let integerSchema = try #require(
            branches.first { $0["type"] as? String == "integer" }
        )

        let accepted: [(token: String, value: Int64)] = [
            ("9007199254740993", 9_007_199_254_740_993),
            ("9223372036854775807", Int64.max),
            ("-9223372036854775808", Int64.min),
        ]
        for example in accepted {
            #expect(schemaIntegerAccepts(example.token, schema: integerSchema))
            let manifest = try FixtureCanon.decodeManifest(numericManifestData(example.token))
            let value = try #require(manifest.mutations.first?.value)
            #expect(value == .integer(example.value))
            #expect(
                try fixtureCanonicalJSONFileData(value.foundationValue)
                    == Data((example.token + "\n").utf8)
            )
        }

        let nested = #"{"nested":[9007199254740993,-9223372036854775808]}"#
        let nestedManifest = try FixtureCanon.decodeManifest(numericManifestData(nested))
        let nestedValue = try #require(nestedManifest.mutations.first?.value)
        #expect(
            try fixtureCanonicalJSONFileData(nestedValue.foundationValue)
                == Data((nested + "\n").utf8)
        )

        for token in [
            "9223372036854775808",
            "-9223372036854775809",
            "1.5",
            "1e100",
        ] {
            #expect(!schemaIntegerAccepts(token, schema: integerSchema))
            #expect(throws: FixtureCanon.SupportError.self) {
                _ = try FixtureCanon.decodeManifest(numericManifestData(token))
            }
        }

        for token in [
            "[1.5]",
            #"{"nested":9223372036854775808}"#,
        ] {
            #expect(throws: FixtureCanon.SupportError.self) {
                _ = try FixtureCanon.decodeManifest(numericManifestData(token))
            }
        }
    }

    private func loadSchema() throws -> [String: Any] {
        let url = pluginRoot
            .appendingPathComponent("standards/canon/schemas/v1/fixture.schema.json")
        return try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
    }

    private var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func definitions(in schema: [String: Any]) throws -> [String: Any] {
        try #require(schema["$defs"] as? [String: Any])
    }

    private func definition(
        _ name: String,
        in definitions: [String: Any]
    ) throws -> [String: Any] {
        try #require(definitions[name] as? [String: Any])
    }

    private func properties(in schema: [String: Any]) throws -> [String: Any] {
        try #require(schema["properties"] as? [String: Any])
    }

    private func requiredKeys(in schema: [String: Any]) -> Set<String> {
        Set(schema["required"] as? [String] ?? [])
    }

    private func resolve(
        _ schema: [String: Any],
        in root: [String: Any]
    ) throws -> [String: Any] {
        guard let reference = schema["$ref"] as? String else { return schema }
        let name = try #require(reference.split(separator: "/").last.map(String.init))
        return try definition(name, in: try definitions(in: root))
    }

    private func integerText(_ value: Any?) -> String? {
        (value as? NSNumber)?.stringValue
    }

    private func schemaIntegerAccepts(
        _ token: String,
        schema: [String: Any]
    ) -> Bool {
        guard schema["type"] as? String == "integer",
              let candidate = Decimal(string: token, locale: Locale(identifier: "en_US_POSIX")),
              let minimumText = integerText(schema["minimum"]),
              let minimum = Decimal(string: minimumText, locale: Locale(identifier: "en_US_POSIX")),
              let maximumText = integerText(schema["maximum"]),
              let maximum = Decimal(string: maximumText, locale: Locale(identifier: "en_US_POSIX"))
        else { return false }

        var rounded = Decimal()
        var source = candidate
        NSDecimalRound(&rounded, &source, 0, .plain)
        return candidate == rounded && candidate >= minimum && candidate <= maximum
    }

    private func numericManifestData(_ token: String) -> Data {
        Data(
            (#"{"base_fixture":"positive/minimal","expected":{"contract_error_code":"invalid_contract","kind":"contract_error"},"fixture_id":"FIX-NUMERIC-001","mutations":[{"json_pointer":"/value","operation":"json_add","relative_path":"scratch.json","value":PLACEHOLDER}],"schema_version":1}"#
                .replacingOccurrences(of: "PLACEHOLDER", with: token) + "\n").utf8
        )
    }
}
