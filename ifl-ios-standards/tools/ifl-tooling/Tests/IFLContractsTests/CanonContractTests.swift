import Foundation
@testable import IFLContracts
import Testing

@Suite("CanonContractTests")
struct CanonContractTests {
    @Test("requirement identities cover the approved priority, enterprise, and requirement families")
    func requirementIdentityFamilies() throws {
        for value in ["P0-1", "P3-42", "ENT-CONCURRENCY", "REQ-CONVERGENCE"] {
            #expect(try RequirementID(validating: value).rawValue == value)
        }

        for value in ["P4-1", "P0-0", "P0-01", "ENT-", "REQ--CANON", "req-canon"] {
            #expect(throws: ContractError.self) {
                try RequirementID(validating: value)
            }
        }
    }

    @Test("unchecked string identifiers cannot encode invalid raw values")
    func uncheckedIdentifierEncoding() {
        #expect(throws: ContractError.self) {
            _ = try CanonicalJSON.encode(RequirementID(rawValue: "P0-0"))
        }
        #expect(throws: ContractError.self) {
            _ = try CanonicalJSON.encode(RuleID(rawValue: "TEST-*"))
        }
        #expect(throws: ContractError.self) {
            _ = try CanonicalJSON.encode(ProfileID(rawValue: "Minimal"))
        }
        #expect(throws: ContractError.self) {
            _ = try CanonicalJSON.encode(ADRIdentifier(rawValue: "ADR-7"))
        }
    }

    @Test("contract error codes are stable and unique")
    func uniqueContractErrorCodes() {
        let errors: [ContractError] = [
            .invalidIdentifier(kind: "rule", value: "bad"),
            .invalidRunIDFilesystemComponent("bad"),
            .invalidCandidateGeneration(0),
            .candidateGenerationOverflow,
            .invalidSHA256("bad"),
            .unsupportedSchemaVersion(kind: "rule", value: 2),
            .invalidCanonVersion("bad"),
            .duplicateIdentifier(kind: "rule", id: "ID"),
            .reusedIdentifier(kind: "rule", id: "ID"),
            .unresolvedReference(kind: "rule", id: "ID"),
            .invalidContract(kind: "rule", reason: "bad"),
            .digestMismatch(kind: "rule", expected: "a", actual: "b"),
            .unexpectedKeys(kind: "rule", keys: ["bad"]),
        ]
        let codes = errors.map(\.code)

        #expect(codes == [
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
        ])
        #expect(Set(codes).count == codes.count)
    }

    @Test("rule, risk, enforcement, lifecycle, and ADR enums have stable v1 wire values")
    func stableEnumWireValues() {
        #expect(NormativeLevel.allCases.map(\.rawValue) == ["must", "must_not", "should", "may"])
        #expect(RiskClass.allCases.map(\.rawValue) == ["low", "medium", "high", "critical"])
        #expect(EnforcementMode.allCases.map(\.rawValue) == ["script", "independent_review", "both"])
        #expect(RuleLifecycle.allCases.map(\.rawValue) == ["proposed", "accepted", "active", "deprecated", "retired"])
        #expect(ADRStatus.allCases.map(\.rawValue) == ["draft", "in_review", "accepted", "superseded", "rejected"])
    }

    @Test("rule records round-trip and distinguish finding severity from risk")
    func ruleRoundTripAndIndependentSeverity() throws {
        let rule = try validRule(severity: .critical, riskClass: .low)
        let decoded = try CanonicalJSON.decode(
            RuleRecord.self,
            from: CanonicalJSON.encode(rule)
        )

        #expect(decoded == rule)
        #expect(decoded.severity == .critical)
        #expect(decoded.riskClass == .low)
        #expect(throws: ContractError.self) {
            try validRule(nonCompliantExampleIDs: [])
        }
        #expect(throws: ContractError.self) {
            try validRule(schemaVersion: 2)
        }

        var object = try jsonObject(rule)
        object["unexpected"] = true
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(RuleRecord.self, from: jsonData(object))
        }
        object.removeValue(forKey: "unexpected")
        object["schema_version"] = 2
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(RuleRecord.self, from: jsonData(object))
        }
    }

    @Test("rule replacement uses absent optional wire form and the approved lifecycle matrix")
    func ruleReplacementWireAndLifecycle() throws {
        let active = try validRule()
        let activeObject = try jsonObject(active)
        #expect(Set(activeObject.keys) == Self.ruleKeysWithoutReplacement)
        #expect(try CanonicalJSON.decode(
            RuleRecord.self,
            from: CanonicalJSON.encode(active)
        ) == active)

        var explicitNull = activeObject
        explicitNull["replacement_id"] = NSNull()
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(RuleRecord.self, from: jsonData(explicitNull))
        }

        let replacement = try RuleID(validating: "TEST-CANON-002")
        let deprecated = try validRule(lifecycle: .deprecated, replacementID: replacement)
        #expect(try Set(jsonObject(deprecated).keys) == Self.ruleKeysWithoutReplacement.union(["replacement_id"]))
        #expect(throws: ContractError.self) {
            try validRule(lifecycle: .deprecated, replacementID: nil)
        }

        let retiredWithoutReplacement = try validRule(lifecycle: .retired)
        #expect(retiredWithoutReplacement.replacementID == nil)
        #expect(try Set(jsonObject(retiredWithoutReplacement).keys) == Self.ruleKeysWithoutReplacement)
        #expect(try validRule(lifecycle: .retired, replacementID: replacement).replacementID == replacement)

        for lifecycle in RuleLifecycle.allCases {
            #expect(throws: ContractError.self) {
                try validRule(
                    lifecycle: lifecycle,
                    replacementID: RuleID(validating: "TEST-CANON-001")
                )
            }
        }
        for lifecycle in [RuleLifecycle.proposed, .accepted, .active] {
            #expect(throws: ContractError.self) {
                try validRule(lifecycle: lifecycle, replacementID: replacement)
            }
        }
    }

    @Test("rule versions use exact SemVer precedence")
    func ruleSemVerValidation() throws {
        #expect(try validRule(
            introducedIn: "1.0.0-rc.1",
            effectiveIn: "1.0.0"
        ).effectiveIn == "1.0.0")
        #expect(try validRule(
            introducedIn: "1.0.0+build.9",
            effectiveIn: "1.0.0+build.1"
        ).effectiveIn == "1.0.0+build.1")

        for invalid in [
            "1.0",
            "01.0.0",
            "1.00.0",
            "1.0.00",
            "1.0.0 ",
            "1.0.0-01",
            "1.0.0-",
            "1.0.0+build..1",
        ] {
            #expect(throws: ContractError.self) {
                try validRule(introducedIn: invalid)
            }
        }
        #expect(throws: ContractError.self) {
            try validRule(introducedIn: "2.0.0", effectiveIn: "1.9.9")
        }
        #expect(throws: ContractError.self) {
            try validRule(introducedIn: "1.0.0-rc.10", effectiveIn: "1.0.0-rc.2")
        }
    }

    @Test("profile records reject aliases and round-trip through canonical JSON")
    func profileContractValidation() throws {
        let profile = try validProfile()
        let decoded = try CanonicalJSON.decode(
            ProfileRecord.self,
            from: CanonicalJSON.encode(profile)
        )
        #expect(decoded == profile)

        let ruleID = try RuleID(validating: "TEST-CANON-001")
        #expect(throws: ContractError.self) {
            try ProfileRecord.validating(ruleIDs: [RuleID(rawValue: "TEST-*")])
        }
        #expect(throws: ContractError.self) {
            try ProfileRecord.validating(ruleIDs: [ruleID, ruleID])
        }
        #expect(throws: ContractError.self) {
            try validProfile(schemaVersion: 2)
        }

        var object = try jsonObject(profile)
        object["unexpected"] = true
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(ProfileRecord.self, from: jsonData(object))
        }
        object.removeValue(forKey: "unexpected")
        object["schema_version"] = 2
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(ProfileRecord.self, from: jsonData(object))
        }
    }

    @Test("ADR metadata round-trips and rejects unknown keys and schema versions")
    func adrRoundTripAndStructuralValidation() throws {
        let acceptedAt = Date(timeIntervalSince1970: 1_783_315_200.123)
        let adr = try validADR(status: .accepted, acceptedAt: acceptedAt)
        let decoded = try CanonicalJSON.decode(
            ADRMetadata.self,
            from: CanonicalJSON.encode(adr)
        )
        #expect(decoded == adr)
        #expect(throws: ContractError.self) {
            try validADR(status: .accepted, acceptedAt: acceptedAt, checkIDs: [])
        }
        #expect(throws: ContractError.self) {
            try validADR(schemaVersion: 2, status: .accepted, acceptedAt: acceptedAt)
        }

        var object = try jsonObject(adr)
        object["unexpected"] = true
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(ADRMetadata.self, from: jsonData(object))
        }
        object.removeValue(forKey: "unexpected")
        object["schema_version"] = 2
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(ADRMetadata.self, from: jsonData(object))
        }
    }

    @Test("ADR lifecycle optionals use absent wire form and reject explicit null")
    func adrOptionalWireRepresentation() throws {
        let acceptedAt = Date(timeIntervalSince1970: 1_783_315_200)
        let draft = try validADR(status: .draft, acceptedAt: nil)
        let draftObject = try jsonObject(draft)
        #expect(Set(draftObject.keys) == Self.adrKeysWithoutLifecycleOptionals)
        #expect(try CanonicalJSON.decode(
            ADRMetadata.self,
            from: CanonicalJSON.encode(draft)
        ) == draft)

        var nullAcceptedAt = draftObject
        nullAcceptedAt["accepted_at"] = NSNull()
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(ADRMetadata.self, from: jsonData(nullAcceptedAt))
        }
        var nullSupersededBy = draftObject
        nullSupersededBy["superseded_by"] = NSNull()
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(ADRMetadata.self, from: jsonData(nullSupersededBy))
        }

        let accepted = try validADR(status: .accepted, acceptedAt: acceptedAt)
        let acceptedObject = try jsonObject(accepted)
        #expect(Set(acceptedObject.keys) == Self.adrKeysWithoutLifecycleOptionals.union(["accepted_at"]))
        var missingAcceptedAt = acceptedObject
        missingAcceptedAt.removeValue(forKey: "accepted_at")
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(ADRMetadata.self, from: jsonData(missingAcceptedAt))
        }
        var acceptedNullSupersededBy = acceptedObject
        acceptedNullSupersededBy["superseded_by"] = NSNull()
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(ADRMetadata.self, from: jsonData(acceptedNullSupersededBy))
        }

        let supersededBy = try ADRIdentifier(validating: "ADR-9998")
        let superseded = try validADR(
            status: .superseded,
            acceptedAt: acceptedAt,
            supersededBy: supersededBy
        )
        #expect(try Set(jsonObject(superseded).keys) == Self.adrKeysWithoutLifecycleOptionals.union([
            "accepted_at",
            "superseded_by",
        ]))
        #expect(throws: ContractError.self) {
            try validADR(status: .superseded, acceptedAt: acceptedAt, supersededBy: nil)
        }
    }

    @Test("accepted ADR timestamps must exactly round-trip through canonical milliseconds")
    func adrAcceptedAtValidation() throws {
        let millisecondDate = Date(timeIntervalSince1970: 1_783_315_200.123)
        #expect(try validADR(
            status: .accepted,
            acceptedAt: millisecondDate
        ).acceptedAt == millisecondDate)

        #expect(throws: ContractError.self) {
            try validADR(
                status: .accepted,
                acceptedAt: Date(timeIntervalSince1970: 1_783_315_200.123_4)
            )
        }
        for interval in [Double.nan, Double.infinity, -Double.infinity] {
            #expect(throws: ContractError.self) {
                try validADR(
                    status: .accepted,
                    acceptedAt: Date(timeIntervalSince1970: interval)
                )
            }
        }
    }

    @Test("accepted ADR wire timestamps require exact canonical spelling")
    func adrAcceptedAtWireCanonicality() throws {
        let adr = try validADR(
            status: .accepted,
            acceptedAt: Date(timeIntervalSince1970: 0.123)
        )
        var object = try jsonObject(adr)
        #expect(
            try #require(object["accepted_at"] as? String)
                == "1970-01-01T00:00:00.123Z"
        )

        for noncanonical in [
            "1970-01-01T00:00:00.123+00:00",
            "1970-01-01T00:00:00.1230Z",
        ] {
            object["accepted_at"] = noncanonical
            #expect(throws: ContractError.self) {
                try CanonicalJSON.decode(ADRMetadata.self, from: jsonData(object))
            }
        }
    }

    @Test("accepted ADR mappings require concrete IDs and canonical relative paths")
    func adrMappingIdentifierValidation() throws {
        let acceptedAt = Date(timeIntervalSince1970: 1_783_315_200)

        for invalid in ["CHK-", "CHK-*", "CHK-test-001", "CHK-TEST-001?"] {
            #expect(throws: ContractError.self) {
                try validADR(status: .accepted, acceptedAt: acceptedAt, checkIDs: [invalid])
            }
        }
        for invalid in ["FIX-", "FIX-*", "FIX-test-001", "FIX-TEST-001["] {
            #expect(throws: ContractError.self) {
                try validADR(status: .accepted, acceptedAt: acceptedAt, fixtureIDs: [invalid])
            }
        }
        for invalid in ["MIG-", "MIG-*", "MIG-test-001", "MIG-TEST-001?"] {
            #expect(throws: ContractError.self) {
                try validADR(status: .accepted, acceptedAt: acceptedAt, migrationIDs: [invalid])
            }
        }
        for invalid in [
            "",
            "/absolute",
            "../escape",
            "standards//VERSION",
            "standards/*.json",
            "standards/canon/VERSION ",
        ] {
            #expect(throws: ContractError.self) {
                try validADR(
                    status: .accepted,
                    acceptedAt: acceptedAt,
                    referenceArtifactIDs: [invalid]
                )
            }
        }
    }

    @Test("semantic strings reject outer whitespace and control characters")
    func canonicalSemanticStrings() throws {
        let acceptedAt = Date(timeIntervalSince1970: 1_783_315_200)

        #expect(throws: ContractError.self) {
            try validRule(statement: " Leading space")
        }
        #expect(throws: ContractError.self) {
            try validRule(scope: ["can\u{0007}on"])
        }
        #expect(throws: ContractError.self) {
            try validProfile(displayName: "Minimal ")
        }
        #expect(throws: ContractError.self) {
            try validProfile(applicability: ["contract\ntests"])
        }
        #expect(throws: ContractError.self) {
            try validADR(status: .accepted, acceptedAt: acceptedAt, title: " Minimal")
        }
        #expect(throws: ContractError.self) {
            try validADR(
                status: .accepted,
                acceptedAt: acceptedAt,
                alternatives: ["Control\u{0007}character"]
            )
        }
    }
}

private extension CanonContractTests {
    static let ruleKeysWithoutReplacement: Set<String> = [
        "schema_version",
        "id",
        "level",
        "statement",
        "scope",
        "profile_ids",
        "severity",
        "risk_class",
        "rationale_adrs",
        "evidence",
        "enforcement",
        "exception_policy",
        "lifecycle",
        "introduced_in",
        "effective_in",
        "examples_required",
        "compliant_example_ids",
        "non_compliant_example_ids",
    ]

    static let adrKeysWithoutLifecycleOptionals: Set<String> = [
        "schema_version",
        "id",
        "title",
        "status",
        "owner_role_id",
        "decision_date",
        "markdown_digest",
        "context",
        "decision",
        "alternatives",
        "consequences",
        "migration",
        "affected_rule_ids",
        "affected_profile_ids",
        "verification_impact",
        "check_ids",
        "fixture_ids",
        "reference_artifact_ids",
        "migration_ids",
        "supersedes_adr_ids",
    ]

    func validRule(
        schemaVersion: Int = 1,
        lifecycle: RuleLifecycle = .active,
        replacementID: RuleID? = nil,
        severity: FindingSeverity = .high,
        riskClass: RiskClass = .high,
        statement: String = "The Canon contract must remain deterministic.",
        scope: [String] = ["canon"],
        introducedIn: String = "1.0.0-rc.1",
        effectiveIn: String = "1.0.0",
        nonCompliantExampleIDs: [String] = ["FIX-TEST-CANON-001-FAIL-001"]
    ) throws -> RuleRecord {
        try RuleRecord(
            schemaVersion: schemaVersion,
            id: RuleID(validating: "TEST-CANON-001"),
            level: .must,
            statement: statement,
            scope: scope,
            profileIDs: [ProfileID(validating: "minimal")],
            severity: severity,
            riskClass: riskClass,
            rationaleADRs: [ADRIdentifier(validating: "ADR-9999")],
            evidence: ["contract_test"],
            enforcement: .both,
            exceptionPolicy: "time_bound_independent_approval",
            lifecycle: lifecycle,
            introducedIn: introducedIn,
            effectiveIn: effectiveIn,
            replacementID: replacementID,
            examplesRequired: true,
            compliantExampleIDs: ["FIX-TEST-CANON-001-PASS"],
            nonCompliantExampleIDs: nonCompliantExampleIDs
        )
    }

    func validProfile(
        schemaVersion: Int = 1,
        displayName: String = "Minimal",
        applicability: [String] = ["contract-tests"]
    ) throws -> ProfileRecord {
        try ProfileRecord(
            schemaVersion: schemaVersion,
            id: ProfileID(validating: "minimal"),
            displayName: displayName,
            description: "Minimal contract profile",
            ownerRoleID: "Canon Maintainer",
            applicability: applicability,
            inheritsProfileIDs: [],
            ruleIDs: [RuleID(validating: "TEST-CANON-001")]
        )
    }

    func validADR(
        schemaVersion: Int = 1,
        status: ADRStatus,
        acceptedAt: Date?,
        title: String = "Minimal Canon contract",
        alternatives: [String] = ["Unversioned records"],
        checkIDs: [String] = ["CHK-TEST-CANON-001"],
        fixtureIDs: [String] = [
            "FIX-TEST-CANON-001-PASS",
            "FIX-TEST-CANON-001-FAIL-001",
        ],
        referenceArtifactIDs: [String] = ["standards/canon/VERSION"],
        migrationIDs: [String] = ["MIG-CANON-BOOTSTRAP"],
        supersededBy: ADRIdentifier? = nil
    ) throws -> ADRMetadata {
        try ADRMetadata(
            schemaVersion: schemaVersion,
            id: ADRIdentifier(validating: "ADR-9999"),
            title: title,
            status: status,
            ownerRoleID: "Canon Maintainer",
            decisionDate: "2026-07-10",
            markdownDigest: digest("a"),
            context: "A deterministic fixture needs a decision record.",
            decision: "Use versioned immutable Canon records.",
            alternatives: alternatives,
            consequences: ["Schema migrations are explicit"],
            migration: ["No prior record exists"],
            affectedRuleIDs: [RuleID(validating: "TEST-CANON-001")],
            affectedProfileIDs: [ProfileID(validating: "minimal")],
            verificationImpact: ["Contract tests"],
            checkIDs: checkIDs,
            fixtureIDs: fixtureIDs,
            referenceArtifactIDs: referenceArtifactIDs,
            migrationIDs: migrationIDs,
            supersedesADRIDs: [],
            supersededBy: supersededBy,
            acceptedAt: acceptedAt
        )
    }

    func digest(_ character: Character) throws -> HashDigest {
        try HashDigest(validating: String(repeating: String(character), count: 64))
    }

    func jsonObject(_ value: some Encodable) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: CanonicalJSON.encode(value))
        return try #require(object as? [String: Any])
    }

    func jsonData(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
