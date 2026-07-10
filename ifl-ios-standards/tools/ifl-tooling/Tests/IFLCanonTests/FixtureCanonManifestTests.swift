import Foundation
@testable import IFLCanon
import Testing

@Suite("FixtureCanonManifestTests")
struct FixtureCanonManifestTests {
    @Test("fixture manifest accepts the complete v1 mutation and findings vocabulary")
    func completeVocabularyIsAccepted() throws {
        let manifest = try FixtureCanon.decodeManifest(
            canonicalData(completeVocabularyManifest())
        )

        #expect(manifest.fixtureID == "FIX-FUTURE-001")
        #expect(manifest.baseFixture == "positive/minimal")
        #expect(manifest.mutations.map(\.operation) == [
            .jsonAdd,
            .jsonReplace,
            .jsonRemove,
            .writeUTF8,
            .removeFile,
        ])
        #expect(manifest.mutations[1].jsonPointer == "")
        #expect(
            manifest.expected
                == .findings(checkIDs: ["CHK-FUTURE-001", "CHK-FUTURE-002"])
        )
    }

    @Test("fixture manifest rejects noncanonical JSON bytes")
    func noncanonicalBytesAreRejected() throws {
        var data = try canonicalData(completeVocabularyManifest())
        #expect(data.last == 0x0A)
        data.removeLast()

        #expect(throws: FixtureCanon.SupportError.self) {
            _ = try FixtureCanon.decodeManifest(data)
        }
    }

    @Test("fixture manifest enforces exact v1 identifiers, shapes, and keys")
    func invalidSchemaShapesAreRejected() throws {
        var invalidFixtureID = baseManifest()
        invalidFixtureID["fixture_id"] = "FIX-lower-001"

        var invalidBase = baseManifest()
        invalidBase["base_fixture"] = "positive/other"

        var invalidVersion = baseManifest()
        invalidVersion["schema_version"] = 2

        var emptyMutations = baseManifest()
        emptyMutations["mutations"] = [Any]()

        var invalidCode = baseManifest()
        invalidCode["expected"] = [
            "contract_error_code": "unknown_code",
            "kind": "contract_error",
        ]

        var invalidCheckID = baseManifest(
            expected: ["check_ids": ["CHK-lower-001"], "kind": "findings"]
        )
        invalidCheckID["fixture_id"] = "FIX-FUTURE-002"

        let duplicateChecks = baseManifest(
            expected: [
                "check_ids": ["CHK-FUTURE-001", "CHK-FUTURE-001"],
                "kind": "findings",
            ]
        )
        let emptyChecks = baseManifest(
            expected: ["check_ids": [String](), "kind": "findings"]
        )
        let invalidPath = baseManifest(mutations: [[
            "json_pointer": "/schema_version",
            "operation": "json_replace",
            "relative_path": "../outside.json",
            "value": 2,
        ]])
        let invalidPointer = baseManifest(mutations: [[
            "json_pointer": "/bad~2escape",
            "operation": "json_replace",
            "relative_path": "rules/core/minimal.rules.json",
            "value": 2,
        ]])
        let missingValue = baseManifest(mutations: [[
            "json_pointer": "/schema_version",
            "operation": "json_replace",
            "relative_path": "rules/core/minimal.rules.json",
        ]])

        var unexpectedTopLevel = baseManifest()
        unexpectedTopLevel["unexpected"] = true

        var unexpectedMutation = jsonReplaceMutation()
        unexpectedMutation["unexpected"] = true

        var unexpectedExpected = baseManifest()
        unexpectedExpected["expected"] = [
            "contract_error_code": "invalid_contract",
            "kind": "contract_error",
            "unexpected": true,
        ]

        let removeWithValue = baseManifest(mutations: [[
            "json_pointer": "/scope/0",
            "operation": "json_remove",
            "relative_path": "rules/core/minimal.rules.json",
            "value": "forbidden",
        ]])

        let cases = [
            InvalidManifestCase("fixture_id pattern", invalidFixtureID),
            InvalidManifestCase("base_fixture enum", invalidBase),
            InvalidManifestCase("schema_version const", invalidVersion),
            InvalidManifestCase("mutations minItems", emptyMutations),
            InvalidManifestCase("contract_error_code enum", invalidCode),
            InvalidManifestCase("check_id pattern", invalidCheckID),
            InvalidManifestCase("check_ids uniqueItems", duplicateChecks),
            InvalidManifestCase("check_ids minItems", emptyChecks),
            InvalidManifestCase("canonical relative path", invalidPath),
            InvalidManifestCase("JSON pointer pattern", invalidPointer),
            InvalidManifestCase("required mutation value", missingValue),
            InvalidManifestCase("top-level additionalProperties", unexpectedTopLevel),
            InvalidManifestCase(
                "mutation additionalProperties",
                baseManifest(mutations: [unexpectedMutation])
            ),
            InvalidManifestCase("expected additionalProperties", unexpectedExpected),
            InvalidManifestCase("operation-specific exact keys", removeWithValue),
        ]

        for testCase in cases {
            try expectRejected(testCase)
        }
    }

    @Test("write_utf8 maxLength counts exact Unicode scalar values")
    func writeUTF8MaximumLengthIsExact() throws {
        let maximum = String(
            repeating: "a",
            count: FixtureMutation.maximumUTF8ContentScalars
        )
        let atLimit = baseManifest(mutations: [[
            "operation": "write_utf8",
            "relative_path": "notes/future.txt",
            "utf8_content": maximum,
        ]])
        _ = try FixtureCanon.decodeManifest(canonicalData(atLimit))

        let overLimit = baseManifest(mutations: [[
            "operation": "write_utf8",
            "relative_path": "notes/future.txt",
            "utf8_content": maximum + "a",
        ]])
        try expectRejected(InvalidManifestCase("utf8_content maxLength", overLimit))
    }

    private func completeVocabularyManifest() -> [String: Any] {
        baseManifest(
            mutations: [
                [
                    "json_pointer": "/entries/-",
                    "operation": "json_add",
                    "relative_path": "registry/rules.index.json",
                    "value": NSNull(),
                ],
                [
                    "json_pointer": "",
                    "operation": "json_replace",
                    "relative_path": "rules/core/minimal.rules.json",
                    "value": ["schema_version": 1],
                ],
                [
                    "json_pointer": "/scope/0",
                    "operation": "json_remove",
                    "relative_path": "rules/core/minimal.rules.json",
                ],
                [
                    "operation": "write_utf8",
                    "relative_path": "notes/future.txt",
                    "utf8_content": "future fixture content",
                ],
                [
                    "operation": "remove_file",
                    "relative_path": "notes/obsolete.txt",
                ],
            ],
            expected: [
                "check_ids": ["CHK-FUTURE-001", "CHK-FUTURE-002"],
                "kind": "findings",
            ]
        )
    }

    private func baseManifest(
        mutations: [[String: Any]]? = nil,
        expected: [String: Any]? = nil
    ) -> [String: Any] {
        [
            "base_fixture": "positive/minimal",
            "expected": expected ?? [
                "contract_error_code": "invalid_contract",
                "kind": "contract_error",
            ],
            "fixture_id": "FIX-FUTURE-001",
            "mutations": mutations ?? [jsonReplaceMutation()],
            "schema_version": 1,
        ]
    }

    private func jsonReplaceMutation() -> [String: Any] {
        [
            "json_pointer": "/schema_version",
            "operation": "json_replace",
            "relative_path": "rules/core/minimal.rules.json",
            "value": 2,
        ]
    }

    private func canonicalData(_ object: Any) throws -> Data {
        var data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0A)
        return data
    }

    private func expectRejected(_ testCase: InvalidManifestCase) throws {
        let data = try canonicalData(testCase.object)
        do {
            _ = try FixtureCanon.decodeManifest(data)
            Issue.record("Expected rejection for \(testCase.name)")
        } catch is FixtureCanon.SupportError {
            return
        } catch {
            Issue.record("\(testCase.name) escaped as non-harness error: \(error)")
        }
    }
}

private struct InvalidManifestCase {
    let name: String
    let object: [String: Any]

    init(_ name: String, _ object: [String: Any]) {
        self.name = name
        self.object = object
    }
}
