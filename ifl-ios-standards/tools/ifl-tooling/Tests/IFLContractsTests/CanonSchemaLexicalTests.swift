import Testing

extension CanonSchemaFileTests {
    @Test("canonical strings, paths, dates, and timestamps expose enforced lexical contracts")
    func canonicalStringAndFormatMarkersAreExplicit() throws {
        for expectation in schemaExpectations {
            guard let schema = try loadIfPresent(expectation.filename) else { continue }
            if let definitions = schema["$defs"] as? [String: Any],
               let nonBlank = definitions["non_blank"] as? [String: Any]
            {
                let pattern = try #require(nonBlank["pattern"] as? String)
                #expect(matches(pattern: pattern, "Owner"))
                let invalid = ["", " ", "Owner ", "A\u{007F}B", "A\u{0085}B", "A\u{009F}B"]
                let acceptedInvalid = invalid.filter { matches(pattern: pattern, $0) }
                #expect(
                    acceptedInvalid.isEmpty,
                    "\(expectation.filename) non_blank accepted \(acceptedInvalid.map(\.debugDescription))"
                )
            }

            for named in namedSchemaNodes(in: schema) {
                guard named.schema["type"] as? String == "string" else { continue }
                if isCanonicalPathNode(named.name) {
                    assertFormatMarker(
                        named.schema,
                        format: "ifl-canonical-relative-path-v1",
                        context: "\(expectation.filename):\(named.path)"
                    )
                    let pattern = try #require(named.schema["pattern"] as? String)
                    let acceptedInvalid = invalidCanonicalPaths.filter { matches(pattern: pattern, $0) }
                    #expect(
                        acceptedInvalid.isEmpty,
                        "\(expectation.filename):\(named.path) accepted invalid paths \(acceptedInvalid.map(\.debugDescription))"
                    )
                } else if isCanonicalTimestampNode(named.name) {
                    assertFormatMarker(
                        named.schema,
                        format: "ifl-canonical-timestamp-v1",
                        context: "\(expectation.filename):\(named.path)"
                    )
                    let pattern = try #require(named.schema["pattern"] as? String)
                    #expect(matches(pattern: pattern, "2026-07-11T23:59:58.123Z"))
                    let acceptedInvalid = invalidCanonicalTimestamps.filter { matches(pattern: pattern, $0) }
                    #expect(
                        acceptedInvalid.isEmpty,
                        "\(expectation.filename):\(named.path) accepted invalid timestamps \(acceptedInvalid)"
                    )
                } else if isCanonicalDateNode(named.name) {
                    assertFormatMarker(
                        named.schema,
                        format: "ifl-canonical-date-v1",
                        context: "\(expectation.filename):\(named.path)"
                    )
                    let pattern = try #require(named.schema["pattern"] as? String)
                    #expect(matches(pattern: pattern, "2026-07-11"))
                    let acceptedInvalid = invalidCanonicalDates.filter { matches(pattern: pattern, $0) }
                    #expect(
                        acceptedInvalid.isEmpty,
                        "\(expectation.filename):\(named.path) accepted invalid dates \(acceptedInvalid)"
                    )
                }
            }
        }
    }

    @Test("record schemas exactly mirror committed Codable top-level fields")
    func codableRecordPropertyParity() throws {
        for shape in recordShapes {
            guard let schema = try loadIfPresent(shape.filename) else { continue }
            let properties = try #require(schema["properties"] as? [String: Any])
            let required = try #require(requiredNames(in: schema))
            let expectedProperties = shape.required.union(shape.optional)

            #expect(Set(properties.keys) == expectedProperties, "\(shape.filename) property keys drifted from Codable")
            #expect(Set(required) == shape.required, "\(shape.filename) required keys drifted from Codable optionality")
            #expect(required.count == Set(required).count, "\(shape.filename) repeats a required key")
            #expect(Set(required).isDisjoint(with: shape.optional), "\(shape.filename) marks an optional Codable field as required")
        }
    }
}

struct RecordShape {
    let filename: String
    let required: Set<String>
    let optional: Set<String>
}

let invalidCanonicalPaths = [
    "",
    "/absolute",
    "registry//a.json",
    "registry/./a.json",
    "registry/../a.json",
    "registry\\a.json",
    "registry/a\u{0000}.json",
    "registry/a\u{0085}.json",
    "registry/a\u{009F}.json",
    "registry/a\u{2028}.json",
    "registry/a\u{2029}.json",
    "activations/a\u{0085}.approval.json",
    "activations/a\u{2028}.approval.json",
]

let invalidCanonicalTimestamps = [
    "2026-00-11T23:59:58.123Z",
    "2026-13-11T23:59:58.123Z",
    "2026-07-00T23:59:58.123Z",
    "2026-07-32T23:59:58.123Z",
    "2026-07-11T24:59:58.123Z",
    "2026-07-11T23:60:58.123Z",
    "2026-07-11T23:59:60.123Z",
    "2026-07-11T23:59:58Z",
    "2026-07-11T23:59:58.1234Z",
    "2026-07-11T23:59:58.123+00:00",
    "2026-07-11T23:59:58.123Z\n",
]

let invalidCanonicalDates = [
    "2026-00-11",
    "2026-13-11",
    "2026-07-00",
    "2026-07-32",
    "2026-7-11",
    "2026-07-11T00:00:00.000Z",
    "2026-07-11\n",
]

let recordShapes: [RecordShape] = [
    .init(
        filename: "candidate-component-bundle.schema.json",
        required: [
            "schema_version", "schema_identity", "schema_digest", "component_id", "component_kind",
            "accountable_owner_role_id", "bundle_relative_path", "artifacts", "publications",
            "target_directories",
        ],
        optional: []
    ),
    .init(
        filename: "rule.schema.json",
        required: [
            "schema_version", "id", "level", "statement", "scope", "profile_ids", "severity",
            "risk_class", "rationale_adrs", "evidence", "enforcement", "exception_policy", "lifecycle",
            "introduced_in", "effective_in", "examples_required", "compliant_example_ids",
            "non_compliant_example_ids",
        ],
        optional: ["replacement_id"]
    ),
    .init(
        filename: "profile.schema.json",
        required: [
            "schema_version", "id", "display_name", "description", "owner_role_id", "applicability",
            "inherits_profile_ids", "rule_ids",
        ],
        optional: []
    ),
    .init(
        filename: "adr-metadata.schema.json",
        required: [
            "schema_version", "id", "title", "status", "owner_role_id", "decision_date", "markdown_digest",
            "context", "decision", "alternatives", "consequences", "migration", "affected_rule_ids",
            "affected_profile_ids", "verification_impact", "check_ids", "fixture_ids", "reference_artifact_ids",
            "migration_ids", "supersedes_adr_ids",
        ],
        optional: ["superseded_by", "accepted_at"]
    ),
    .init(
        filename: "chapter.schema.json",
        required: [
            "schema_version", "id", "requirement_id", "title", "owner_role_id", "rationale", "applicability",
            "rule_ids", "rationale_adr_ids", "compliant_example_ids", "non_compliant_example_ids", "check_ids",
            "positive_fixture_ids", "negative_fixture_ids", "required_evidence_kinds", "review_checklist_ids",
            "exception_policy", "review_cadence", "required_rule_dependencies",
        ],
        optional: []
    ),
    .init(
        filename: "traceability.schema.json",
        required: ["schema_version", "requirements", "traceability"],
        optional: []
    ),
    .init(
        filename: "candidate-overlay.schema.json",
        required: [
            "schema_version", "overlay_id", "target_canon_version", "target_product_version",
            "base_snapshot_content_digest", "activation_transform_identity", "activation_transform_digest",
            "reviewed_components", "rules", "profiles", "adrs", "chapters", "requirement_registry",
            "checks", "fixtures", "migrations", "indexes", "derived_registration_deltas",
            "activation_transform_set",
        ],
        optional: []
    ),
    .init(
        filename: "activation-receipt.schema.json",
        required: [
            "schema_version", "activation_id", "transaction_id", "target_canon_version", "target_product_version",
            "overlay_id", "overlay_digest", "integration_approval", "approval_source_artifact_id",
            "approval_source_artifact_digest", "approval_sidecar_relative_path", "approval_sidecar_digest",
            "approval_timestamp", "activation_transform_identity", "activation_transform_digest",
            "resolved_activation_digest", "base_snapshot_content_digest", "base_plugin_inventory_digest",
            "resolved_plugin_inventory_digest", "published_snapshot_content_digest", "digest_transitions",
        ],
        optional: []
    ),
    .init(
        filename: "exception.schema.json",
        required: [
            "schema_version", "id", "rule_id", "exact_scope", "reason", "risk_class", "compensating_controls",
            "owner_principal_id", "owner_actor_id", "owner_role_id", "approver_principal_id", "approver_actor_id",
            "approver_role_id", "expires_at", "affected_artifact_digest", "removal_plan",
        ],
        optional: []
    ),
    .init(
        filename: "derived-registration-delta.schema.json",
        required: [
            "schema_version", "delta_id", "owner_role_id", "base_snapshot_content_digest", "entries", "delta_digest",
        ],
        optional: []
    ),
]
