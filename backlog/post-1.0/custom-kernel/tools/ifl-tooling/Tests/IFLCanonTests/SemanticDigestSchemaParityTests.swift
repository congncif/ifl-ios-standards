@testable import IFLCanon
import IFLContracts
import Testing

@Suite("SemanticDigestSchemaParityTests")
struct SemanticDigestSchemaParityTests {
    @Test("semantic exclusions are the exact versioned activation allowlists")
    func exactExclusionAllowlists() {
        #expect(RuleSemanticDigest.excludedKeysV1 == ["effective_in", "lifecycle"])
        #expect(ProfileSemanticDigest.excludedKeysV1.isEmpty)
        #expect(ADRSemanticDigest.excludedKeysV1 == ["accepted_at", "status"])
    }

    @Test("record Codable property sets cover every schema property")
    func recordPropertiesMatchSchemas() throws {
        let ruleWithOptional = try CanonTestFixture.rule {
            $0["lifecycle"] = "retired"
            $0["replacement_id"] = "CAN-MINIMAL-002"
        }
        let adrWithOptional = try CanonTestFixture.adr {
            $0["status"] = "superseded"
            $0["superseded_by"] = "ADR-9998"
        }

        #expect(
            try CanonTestFixture.encodedPropertyNames(CanonTestFixture.rule())
                .union(CanonTestFixture.encodedPropertyNames(ruleWithOptional))
                == CanonTestFixture.schemaPropertyNames("rule.schema.json")
        )
        #expect(
            try CanonTestFixture.encodedPropertyNames(CanonTestFixture.profile())
                == CanonTestFixture.schemaPropertyNames("profile.schema.json")
        )
        #expect(
            try CanonTestFixture.encodedPropertyNames(CanonTestFixture.adr())
                .union(CanonTestFixture.encodedPropertyNames(adrWithOptional))
                == CanonTestFixture.schemaPropertyNames("adr-metadata.schema.json")
        )
    }

    @Test("whole-record projection binds fields unknown to hand-written projections")
    func futureFieldsRemainBound() throws {
        let preimage = try SemanticJSONProjection.preimage(
            of: FutureRecord(
                schemaVersion: 1,
                stableValue: "stable",
                activationOwned: "excluded",
                futureValue: "must-remain-bound"
            ),
            excludingKeys: ["activation_owned"],
            additionalFields: [:],
            kind: "future_record_semantic_digest"
        )

        #expect(
            String(decoding: preimage, as: UTF8.self)
                == #"{"future_value":"must-remain-bound","schema_version":1,"stable_value":"stable"}"#
        )
    }
}

private struct FutureRecord: Encodable {
    let schemaVersion: Int
    let stableValue: String
    let activationOwned: String
    let futureValue: String

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case stableValue = "stable_value"
        case activationOwned = "activation_owned"
        case futureValue = "future_value"
    }
}
