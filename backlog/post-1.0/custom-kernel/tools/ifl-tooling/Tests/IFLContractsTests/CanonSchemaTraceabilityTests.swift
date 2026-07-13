import Testing

extension CanonSchemaFileTests {
    @Test("traceability schema pins the approved ordered twenty-six-requirement registry")
    func traceabilityPinsApprovedRegistry() throws {
        let schema = try #require(try loadIfPresent("traceability.schema.json"))
        let properties = try #require(schema["properties"] as? [String: Any])
        let requirements = try #require(properties["requirements"] as? [String: Any])

        #expect(integerValue(requirements["minItems"]) == approvedRequirements.count)
        #expect(integerValue(requirements["maxItems"]) == approvedRequirements.count)
        #expect(requirements["items"] as? Bool == false)
        let requirementSlots = requirements["prefixItems"] as? [[String: Any]]
        #expect(requirementSlots != nil, "requirements must declare ordered prefixItems")
        guard let requirementSlots else { return }
        #expect(requirementSlots.count == approvedRequirements.count)
        guard requirementSlots.count == approvedRequirements.count else { return }

        let requirementWitnesses: [[String: Any]] = approvedRequirements.map {
            [
                "schema_version": 1,
                "id": $0.id,
                "accountable_owner_role_id": $0.owner,
                "status": "planned",
            ]
        }
        #expect(schemaAccepts(requirementWitnesses, against: requirements, root: schema))

        for index in approvedRequirements.indices {
            let expected = approvedRequirements[index]
            #expect(
                stringConstants(for: "id", in: requirementSlots[index], root: schema) == [expected.id],
                "requirements prefixItems[\(index)] must pin \(expected.id)"
            )
            #expect(
                stringConstants(for: "accountable_owner_role_id", in: requirementSlots[index], root: schema) == [expected.owner],
                "requirements prefixItems[\(index)] must pin owner \(expected.owner)"
            )

            var wrongOwner = requirementWitnesses
            wrongOwner[index]["accountable_owner_role_id"] = "Wrong Owner"
            let acceptedWrongOwner = schemaAccepts(wrongOwner, against: requirements, root: schema)
            #expect(!acceptedWrongOwner, "requirements accepted wrong owner at prefixItems[\(index)]")
        }

        var wrongOrder = requirementWitnesses
        wrongOrder.swapAt(0, 1)
        #expect(!schemaAccepts(wrongOrder, against: requirements, root: schema))
        #expect(!schemaAccepts(Array(requirementWitnesses.dropLast()), against: requirements, root: schema))
        #expect(!schemaAccepts(requirementWitnesses + [requirementWitnesses[0]], against: requirements, root: schema))
    }

    @Test("traceability schema requires exactly one complete REQ-CONVERGENCE row")
    func traceabilityPinsCompleteConvergenceAllocation() throws {
        let schema = try #require(try loadIfPresent("traceability.schema.json"))
        let properties = try #require(schema["properties"] as? [String: Any])
        let traceability = try #require(properties["traceability"] as? [String: Any])

        let convergenceWitness = makeConvergenceTraceabilityWitness()
        #expect(integerValue(traceability["minContains"]) == 1)
        #expect(integerValue(traceability["maxContains"]) == 1)
        let convergenceConstraint = traceability["contains"] as? [String: Any]
        #expect(convergenceConstraint != nil, "traceability must declare a REQ-CONVERGENCE contains constraint")
        guard let convergenceConstraint else { return }
        #expect(schemaAccepts(convergenceWitness, against: convergenceConstraint, root: schema))
        #expect(schemaAccepts([convergenceWitness], against: traceability, root: schema))
        #expect(!schemaAccepts(
            [convergenceWitness, convergenceWitness],
            against: traceability,
            root: schema
        ))

        for mutation in makeIncompleteConvergenceWitnesses() {
            let acceptedIncomplete = schemaAccepts(mutation.value, against: convergenceConstraint, root: schema)
            #expect(
                !acceptedIncomplete,
                "REQ-CONVERGENCE contains constraint did not reject incomplete field \(mutation.field)"
            )
        }
    }
}

struct RequirementOwner {
    let id: String
    let owner: String
}

let approvedRequirements: [RequirementOwner] = [
    .init(id: "ENT-ACCESSIBILITY", owner: "Accessibility Owner"),
    .init(id: "ENT-CONCURRENCY", owner: "Concurrency Chapter Owner"),
    .init(id: "ENT-DATA", owner: "Data Lifecycle Owner"),
    .init(id: "ENT-OBSERVABILITY", owner: "Operability Owner"),
    .init(id: "ENT-PERFORMANCE", owner: "Performance Owner"),
    .init(id: "ENT-PRIVACY", owner: "Privacy Owner"),
    .init(id: "ENT-SECURITY", owner: "Security Owner"),
    .init(id: "ENT-SUPPLY", owner: "Security/Legal Owner"),
    .init(id: "ENT-SWIFTUI", owner: "SwiftUI Profile Owner"),
    .init(id: "ENT-TESTING", owner: "Testing Owner"),
    .init(id: "P0-1", owner: "Workflow Maintainer"),
    .init(id: "P0-2", owner: "Runtime/Agent Owner"),
    .init(id: "P0-3", owner: "Verification Owner"),
    .init(id: "P0-4", owner: "Canon Maintainer"),
    .init(id: "P0-5", owner: "Scaffolding Owner"),
    .init(id: "P0-6", owner: "Workflow Maintainer"),
    .init(id: "P0-7", owner: "Security/Compliance Owner"),
    .init(id: "REQ-AGENTS", owner: "Runtime/Agent Owner"),
    .init(id: "REQ-BOARDY", owner: "iOS Profile Owner"),
    .init(id: "REQ-CANON", owner: "Canon Maintainer"),
    .init(id: "REQ-CONVERGENCE", owner: "Workflow Maintainer"),
    .init(id: "REQ-EFFECTS", owner: "Workflow Maintainer"),
    .init(id: "REQ-MIGRATION", owner: "Release Steward"),
    .init(id: "REQ-RC", owner: "Release Steward"),
    .init(id: "REQ-RUNTIME", owner: "Runtime/Agent Owner"),
    .init(id: "REQ-VERIFY", owner: "Verification Owner"),
]

let convergenceInternalChecks = [
    "CHK-WF-CONV-BASELINE-001",
    "CHK-WF-CONV-INVENTORY-001",
    "CHK-WF-CONV-REGISTER-001",
    "CHK-WF-CONV-DISPOSITION-001",
    "CHK-WF-CONV-REMEDIATION-001",
    "CHK-WF-CONV-CONFIRMATION-001",
    "CHK-WF-CONV-EXCEPTION-001",
    "CHK-WF-CONV-INVALIDATION-001",
]

let convergencePublicChecks = [
    "CHK-FLOW-CONVERGENCE",
    "CHK-AGENT-CONVERGENCE",
    "CHK-EVIDENCE-CONVERGENCE",
    "CHK-RUN-CONVERGENCE",
    "CHK-RELEASE-CONVERGENCE",
]

func makeConvergenceFixtureMappings() -> [[String: Any]] {
    (convergenceInternalChecks + convergencePublicChecks).map { checkID in
        let suffix = if checkID.hasPrefix("CHK-WF-CONV-") {
            String(checkID.dropFirst("CHK-WF-CONV-".count))
        } else {
            String(checkID.dropFirst("CHK-".count))
        }
        return [
            "check_id": checkID,
            "positive_fixture_ids": ["FIX-WF-CONV-\(suffix)-PASS"],
            "negative_fixture_ids": ["FIX-WF-CONV-\(suffix)-FAIL-001"],
        ]
    }
}

func makeConvergenceTraceabilityWitness() -> [String: Any] {
    [
        "schema_version": 1,
        "requirement_id": "REQ-CONVERGENCE",
        "accountable_owner_role_id": "Workflow Maintainer",
        "rule_bindings": [],
        "internal_check_namespace": "CHK-WF-CONV-*",
        "internal_check_ids": convergenceInternalChecks,
        "public_check_ids": convergencePublicChecks,
        "fixture_namespace": "FIX-WF-CONV-*",
        "fixture_mappings": makeConvergenceFixtureMappings(),
        "required_evidence_kinds": [
            "review_confirmation_receipt/v1",
            "review_convergence_receipt/v1",
        ],
    ]
}

func makeIncompleteConvergenceWitnesses() -> [(field: String, value: [String: Any])] {
    let mutations: [(String, Any)] = [
        ("schema_version", 2),
        ("requirement_id", "REQ-CANON"),
        ("accountable_owner_role_id", "Wrong Owner"),
        ("rule_bindings", [["rule_id": "WF-CONV-001", "owner_role_id": "Workflow Maintainer"]]),
        ("internal_check_namespace", "CHK-WF-OTHER-*"),
        ("internal_check_ids", Array(convergenceInternalChecks.dropLast())),
        ("public_check_ids", Array(convergencePublicChecks.reversed())),
        ("fixture_namespace", "FIX-WF-OTHER-*"),
        ("fixture_mappings", Array(makeConvergenceFixtureMappings().dropLast())),
        ("required_evidence_kinds", ["review_confirmation_receipt/v1"]),
    ]
    return mutations.map { field, replacement in
        var value = makeConvergenceTraceabilityWitness()
        value[field] = replacement
        return (field, value)
    }
}
