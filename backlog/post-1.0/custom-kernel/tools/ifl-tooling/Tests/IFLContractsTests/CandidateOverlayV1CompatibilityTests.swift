import Foundation
@testable import IFLContracts
import Testing

@Suite("CandidateOverlayV1CompatibilityTests")
struct CandidateOverlayV1CompatibilityTests {
    @Test("frozen pre-amendment schema independently accepts its exact witness and provenance")
    func frozenSchemaAcceptsFrozenWitness() throws {
        let schemaData = try Data(contentsOf: frozenSchemaURL)
        let witnessData = try Data(contentsOf: frozenWitnessURL)
        try expectCanonicalJSONFile(schemaData)
        try expectCanonicalJSONFile(witnessData)

        let schema = try object(from: schemaData)
        let witness = try object(from: witnessData)
        #expect(schemaAccepts(witness, against: schema, root: schema))

        let provenanceData = try Data(contentsOf: provenanceURL)
        try expectCanonicalJSONFile(provenanceData)
        let provenance = try object(from: provenanceData)
        #expect(provenance["source_commit"] as? String == "90d7257d029df74defd766008271a3fcbb9bfeb7")
        #expect(provenance["schema_sha256"] as? String == CanonicalTreeDigest.sha256(schemaData).rawValue)
        #expect(provenance["witness_sha256"] as? String == CanonicalTreeDigest.sha256(witnessData).rawValue)
        let byteRules = try #require(provenance["byte_rules"] as? [String: Any])
        #expect(byteRules["canonical_json"] as? String == "UTF-8 sorted compact JSON")
        #expect(integerValue(byteRules["terminal_lf_count"]) == 1)
        let governance = try #require(provenance["governance"] as? [String: Any])
        #expect(
            governance["approved_design_sha256"] as? String
                == "ecdfe58ecca7807038ca0afc7b5b983200a7a185fab61efd1a56ecb40928fd4c"
        )
        #expect(
            governance["authority_appendix_sha256"] as? String
                == "c036bd062b80a8dc632f479a4ae172fc455d4d47bc02ed987c53c6d267413dd9"
        )
        let authorityDigest = try CanonicalTreeDigest.sha256(Data(contentsOf: authorityFixtureURL))
        #expect(governance["authority_fixture_sha256"] as? String == authorityDigest.rawValue)
        #expect(governance["authority_map_digest"] as? String == CandidatePublicationAuthorityMap.v1.digest.rawValue)
        #expect(integerValue(governance["authority_row_count"]) == 142)
    }

    @Test("amended v1 rejects the exact old bytes in schema and Swift")
    func amendedV1RejectsFrozenOldWitness() throws {
        let oldWitnessData = try Data(contentsOf: frozenWitnessURL)
        let oldWitness = try object(from: oldWitnessData)
        let amendedSchemaData = try Data(contentsOf: amendedSchemaURL)
        let amendedSchema = try object(from: amendedSchemaData)

        #expect(!schemaAccepts(oldWitness, against: amendedSchema, root: amendedSchema))
        #expect(throws: (any Error).self) {
            try CanonicalJSON.decode(CandidateOverlayManifest.self, from: oldWitnessData)
        }
    }

    @Test("amended witness canonical-round-trips byte-identically and freezes overlay digest")
    func amendedWitnessRoundTrips() throws {
        let data = try Data(contentsOf: amendedWitnessURL)
        try expectCanonicalJSONFile(data)
        let amendedSchema = try object(from: Data(contentsOf: amendedSchemaURL))
        #expect(
            try schemaAccepts(
                JSONSerialization.jsonObject(with: data),
                against: amendedSchema,
                root: amendedSchema
            )
        )
        let manifest = try CanonicalJSON.decode(CandidateOverlayManifest.self, from: data)
        var encoded = try CanonicalJSON.encode(manifest)
        encoded.append(0x0A)
        #expect(encoded == data)

        var payload = Data("ifl.candidate-overlay.manifest/v1\0".utf8)
        payload.append(data)
        #expect(
            try CandidateOverlayManifest.overlayDigest(forCanonicalFileData: data)
                == CanonicalTreeDigest.sha256(payload)
        )
    }

    @Test("removed output, ambiguous-path, pointer, and generic activation fields fail closed")
    func removedFieldMutationMatrix() throws {
        let base = try object(from: Data(contentsOf: amendedWitnessURL))

        for key in ["activation_fields", "expected_published_snapshot_content_digest"] {
            var mutation = base
            mutation[key] = key == "activation_fields" ? [] : String(repeating: "e", count: 64)
            try expectAmendedRejected(mutation)
        }

        var rule = base
        var rules = try #require(rule["rules"] as? [[String: Any]])
        rules[0]["relative_path"] = "rules/core/test.rules.json"
        rules[0]["expected_activated_full_digest"] = String(repeating: "e", count: 64)
        rule["rules"] = rules
        try expectAmendedRejected(rule)

        var requirement = base
        var registry = try #require(requirement["requirement_registry"] as? [String: Any])
        var records = try #require(registry["records"] as? [[String: Any]])
        records[0]["requirement_json_pointer"] = "/requirements/0/status"
        records[0]["expected_activated_requirement_digest"] = String(repeating: "e", count: 64)
        registry["records"] = records
        requirement["requirement_registry"] = registry
        try expectAmendedRejected(requirement)

        var index = base
        var indexes = try #require(index["indexes"] as? [[String: Any]])
        var entries = try #require(indexes[0]["entries"] as? [[String: Any]])
        entries[0]["expected_record_digest"] = String(repeating: "e", count: 64)
        indexes[0]["entries"] = entries
        indexes[0]["expected_activated_full_digest"] = String(repeating: "e", count: 64)
        index["indexes"] = indexes
        try expectAmendedRejected(index)

        var derived = base
        var deltas = try #require(derived["derived_registration_deltas"] as? [[String: Any]])
        var targets = try #require(deltas[0]["targets"] as? [[String: Any]])
        targets[0]["expected_file_digest"] = String(repeating: "e", count: 64)
        deltas[0]["targets"] = targets
        derived["derived_registration_deltas"] = deltas
        try expectAmendedRejected(derived)
    }

    @Test("nested unknown, null, and missing fields fail for one exact cause")
    func nestedClosedWorldMutationMatrix() throws {
        let base = try object(from: Data(contentsOf: amendedWitnessURL))

        var unknown = base
        var unknownDeltas = try #require(unknown["derived_registration_deltas"] as? [[String: Any]])
        var unknownTargets = try #require(unknownDeltas[0]["targets"] as? [[String: Any]])
        unknownTargets[0]["legacy_pointer"] = "/derived/0"
        unknownDeltas[0]["targets"] = unknownTargets
        unknown["derived_registration_deltas"] = unknownDeltas
        try expectSchemaRejected(unknown)
        try expectContractError(
            .unexpectedKeys(kind: "derived_target_binding", keys: ["legacy_pointer"]),
            from: unknown
        )

        var explicitNull = base
        var nullRules = try #require(explicitNull["rules"] as? [[String: Any]])
        nullRules[0]["before_full_digest"] = NSNull()
        explicitNull["rules"] = nullRules
        try expectSchemaRejected(explicitNull)
        try expectContractError(
            .invalidContract(
                kind: "rule_overlay_binding",
                reason: "before_full_digest must be absent rather than null when there is no before state"
            ),
            from: explicitNull
        )

        var missing = base
        var missingDeltas = try #require(missing["derived_registration_deltas"] as? [[String: Any]])
        var missingTargets = try #require(missingDeltas[0]["targets"] as? [[String: Any]])
        missingTargets[0].removeValue(forKey: "bundle_artifact_id")
        missingDeltas[0]["targets"] = missingTargets
        missing["derived_registration_deltas"] = missingDeltas
        try expectSchemaRejected(missing)
        do {
            _ = try CanonicalJSON.decode(
                CandidateOverlayManifest.self,
                from: canonicalFileData(missing)
            )
            Issue.record("expected nested bundle_artifact_id to be required")
        } catch let DecodingError.keyNotFound(key, _) {
            #expect(key.stringValue == "bundle_artifact_id")
        } catch {
            Issue.record("expected DecodingError.keyNotFound, received \(error)")
        }
    }
}

private extension CandidateOverlayV1CompatibilityTests {
    var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    var contractsRoot: URL {
        pluginRoot.appendingPathComponent("verification/fixtures/canon/candidate-overlay/contracts")
    }

    var frozenSchemaURL: URL {
        contractsRoot.appendingPathComponent("pre-amendment-v1/candidate-overlay.schema.json")
    }

    var frozenWitnessURL: URL {
        contractsRoot.appendingPathComponent("pre-amendment-v1/accepted-overlay.json")
    }

    var provenanceURL: URL {
        contractsRoot.appendingPathComponent("pre-amendment-v1/provenance.json")
    }

    var amendedWitnessURL: URL {
        contractsRoot.appendingPathComponent("amended-v1/accepted-overlay.json")
    }

    var authorityFixtureURL: URL {
        contractsRoot.appendingPathComponent(
            "amended-v1/candidate-publication-authority-map.json"
        )
    }

    var amendedSchemaURL: URL {
        pluginRoot.appendingPathComponent("standards/canon/schemas/v1/candidate-overlay.schema.json")
    }

    func object(from data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func canonicalFileData(_ object: Any) throws -> Data {
        var data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0A)
        return data
    }

    func expectCanonicalJSONFile(_ data: Data) throws {
        #expect(try canonicalFileData(JSONSerialization.jsonObject(with: data)) == data)
    }

    func expectAmendedRejected(_ instance: [String: Any]) throws {
        try expectSchemaRejected(instance)
        #expect(throws: (any Error).self) {
            try CanonicalJSON.decode(
                CandidateOverlayManifest.self,
                from: canonicalFileData(instance)
            )
        }
    }

    func expectSchemaRejected(_ instance: [String: Any]) throws {
        let schema = try object(from: Data(contentsOf: amendedSchemaURL))
        #expect(!schemaAccepts(instance, against: schema, root: schema))
    }

    func expectContractError(_ expected: ContractError, from instance: [String: Any]) throws {
        do {
            _ = try CanonicalJSON.decode(
                CandidateOverlayManifest.self,
                from: canonicalFileData(instance)
            )
            Issue.record("expected \(expected)")
        } catch let error as ContractError {
            #expect(error == expected)
        } catch {
            Issue.record("expected ContractError, received \(error)")
        }
    }
}
