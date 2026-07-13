import Foundation
@testable import IFLContracts
import Testing

@Suite("CanonTraceabilityContractTests")
struct CanonTraceabilityContractTests {
    @Test("requirement status has stable v1 wire values")
    func stableRequirementStatusWireValues() {
        #expect(RequirementStatus.allCases.map(\.rawValue) == ["planned", "in_progress", "completed", "deferred", "blocked"])
    }

    @Test("chapter dependencies are pending only for exact declared candidate targets")
    func chapterDependencyResolution() throws {
        let ruleID = try RuleID(validating: "DATA-CLASS-001")
        let dependency = try ChapterDependency(
            requiredRuleID: ruleID,
            expectedOwnerRoleID: "Data Governance Owner"
        )

        #expect(try dependency.resolve(in: .candidate(
            activeRuleOwners: [:],
            declaredRuleOwners: [ruleID: "Data Governance Owner"]
        )) == .candidatePending)
        #expect(try dependency.resolve(in: .candidate(
            activeRuleOwners: [ruleID: "Data Governance Owner"],
            declaredRuleOwners: [:]
        )) == .resolved)
        #expect(try dependency.resolve(in: .candidate(
            activeRuleOwners: [ruleID: "Data Governance Owner"],
            declaredRuleOwners: [ruleID: "Data Governance Owner"]
        )) == .resolved)
        #expect(throws: ContractError.self) {
            try dependency.resolve(in: .candidate(
                activeRuleOwners: [ruleID: "Data Governance Owner"],
                declaredRuleOwners: [ruleID: "Data Lifecycle Owner"]
            ))
        }
        #expect(throws: ContractError.self) {
            try dependency.resolve(in: .candidate(
                activeRuleOwners: [:],
                declaredRuleOwners: [ruleID: "Data Lifecycle Owner"]
            ))
        }
        #expect(throws: ContractError.self) {
            try dependency.resolve(in: .production(activeRuleOwners: [:]))
        }
        #expect(throws: ContractError.self) {
            try dependency.resolve(in: .production(
                activeRuleOwners: [ruleID: "Data Lifecycle Owner"]
            ))
        }
    }

    @Test("the bootstrap registry is the exact approved twenty-six identity set")
    func exactBootstrapRequirementRegistry() throws {
        let registry = try RequirementRegistry(
            schemaVersion: 1,
            requirements: approvedRequirementRows(),
            traceability: [convergenceTraceability()]
        )

        #expect(registry.requirements.count == 26)
        #expect(Set(registry.requirements.map(\.id.rawValue)) == Set(Self.approvedRequirementIDs))
        let convergence = try #require(registry.traceability.first)
        #expect(convergence.accountableOwnerRoleID == "Workflow Maintainer")
        #expect(convergence.allCheckIDs.count == 13)
        #expect(convergence.fixtureMappings.count == 13)
        #expect(convergence.requiredEvidenceKinds == [
            "review_confirmation_receipt/v1",
            "review_convergence_receipt/v1",
        ])

        var duplicated = try approvedRequirementRows()
        duplicated[1] = duplicated[0]
        #expect(throws: ContractError.self) {
            try RequirementRegistry(
                schemaVersion: 1,
                requirements: duplicated,
                traceability: [convergenceTraceability()]
            )
        }
    }

    @Test("convergence traceability requires every check family, both fixture polarities, and both receipts")
    func convergenceTraceabilityCompleteness() throws {
        let valid = try convergenceTraceability()
        #expect(valid.internalCheckIDs == Self.internalConvergenceChecks)
        #expect(valid.publicCheckIDs == Self.publicConvergenceChecks)

        #expect(throws: ContractError.self) {
            try convergenceTraceability(internalCheckIDs: Array(Self.internalConvergenceChecks.dropLast()))
        }
        let firstMapping = try #require(convergenceMappings().first)
        #expect(throws: ContractError.self) {
            try TraceabilityFixtureMapping(
                checkID: firstMapping.checkID,
                positiveFixtureIDs: firstMapping.positiveFixtureIDs,
                negativeFixtureIDs: []
            )
        }
        #expect(throws: ContractError.self) {
            try convergenceTraceability(requiredEvidenceKinds: ["review_confirmation_receipt/v1"])
        }
    }

    @Test("dependency, requirement, traceability, registry, and chapter contracts round-trip canonically")
    func canonContractsRoundTrip() throws {
        let dependency = try chapterDependency()
        let requirement = try RequirementRecord(
            schemaVersion: 1,
            id: RequirementID(validating: "ENT-DATA"),
            accountableOwnerRoleID: "Data Lifecycle Owner",
            status: .completed
        )
        let traceability = try convergenceTraceability()
        let registry = try RequirementRegistry(
            schemaVersion: 1,
            requirements: approvedRequirementRows(statusOverrides: ["ENT-DATA": .completed]),
            traceability: [traceability]
        )
        let chapter = try fullChapterMetadata()

        #expect(try roundTrip(dependency) == dependency)
        #expect(try roundTrip(requirement) == requirement)
        #expect(try roundTrip(traceability) == traceability)
        #expect(try roundTrip(registry) == registry)
        #expect(try roundTrip(chapter) == chapter)
    }

    @Test("contract decoding rejects workflow-shaped keys and schema drift")
    func contractDecodeRejectsUnknownKeysAndSchemaDrift() throws {
        let dependency = try chapterDependency()
        var dependencyObject = try jsonObject(dependency)
        dependencyObject["workflow_state"] = "candidate_pending"
        #expect(throws: ContractError.self) {
            try decode(ChapterDependency.self, object: dependencyObject)
        }

        let requirement = try RequirementRecord(
            schemaVersion: 1,
            id: RequirementID(validating: "ENT-DATA"),
            accountableOwnerRoleID: "Data Lifecycle Owner",
            status: .completed
        )
        var requirementObject = try jsonObject(requirement)
        requirementObject["review_baseline"] = ["state": "approved"]
        #expect(throws: ContractError.self) {
            try decode(RequirementRecord.self, object: requirementObject)
        }
        requirementObject = try jsonObject(requirement)
        requirementObject["schema_version"] = 2
        #expect(throws: ContractError.self) {
            try decode(RequirementRecord.self, object: requirementObject)
        }

        let traceability = try convergenceTraceability()
        var traceabilityObject = try jsonObject(traceability)
        traceabilityObject["workflow_state"] = "reviewing"
        #expect(throws: ContractError.self) {
            try decode(TraceabilityRecord.self, object: traceabilityObject)
        }
        traceabilityObject = try jsonObject(traceability)
        traceabilityObject["schema_version"] = 2
        #expect(throws: ContractError.self) {
            try decode(TraceabilityRecord.self, object: traceabilityObject)
        }

        let chapter = try fullChapterMetadata()
        var chapterObject = try jsonObject(chapter)
        chapterObject["review_round"] = ["id": "round-001"]
        #expect(throws: ContractError.self) {
            try decode(ChapterMetadata.self, object: chapterObject)
        }
        chapterObject = try jsonObject(chapter)
        chapterObject["schema_version"] = 2
        #expect(throws: ContractError.self) {
            try decode(ChapterMetadata.self, object: chapterObject)
        }

        let registry = try RequirementRegistry(
            schemaVersion: 1,
            requirements: approvedRequirementRows(),
            traceability: [traceability]
        )
        var registryObject = try jsonObject(registry)
        registryObject["review_baseline"] = ["digest": "forbidden"]
        #expect(throws: ContractError.self) {
            try decode(RequirementRegistry.self, object: registryObject)
        }
        registryObject = try jsonObject(registry)
        registryObject["schema_version"] = 2
        #expect(throws: ContractError.self) {
            try decode(RequirementRegistry.self, object: registryObject)
        }
    }

    @Test("the structural registry permits lifecycle statuses but preserves exact identities and owners")
    func structuralRegistryAllowsLifecycleStatuses() throws {
        let completedRows = try approvedRequirementRows(statusOverrides: ["ENT-DATA": .completed])
        let completedRegistry = try RequirementRegistry(
            schemaVersion: 1,
            requirements: completedRows,
            traceability: [convergenceTraceability()]
        )
        let completedData = try #require(
            completedRegistry.requirements.first(where: { $0.id.rawValue == "ENT-DATA" })
        )
        #expect(completedData.status == .completed)

        #expect(throws: ContractError.self) {
            try RequirementRegistry(
                schemaVersion: 1,
                requirements: Array(completedRows.dropLast()),
                traceability: [convergenceTraceability()]
            )
        }

        var extraRows = completedRows
        try extraRows.append(RequirementRecord(
            schemaVersion: 1,
            id: RequirementID(validating: "P3-42"),
            accountableOwnerRoleID: "Extra Owner",
            status: .planned
        ))
        #expect(throws: ContractError.self) {
            try RequirementRegistry(
                schemaVersion: 1,
                requirements: extraRows,
                traceability: [convergenceTraceability()]
            )
        }

        var wrongOwnerRows = completedRows
        let first = try #require(wrongOwnerRows.first)
        wrongOwnerRows[0] = try RequirementRecord(
            schemaVersion: 1,
            id: first.id,
            accountableOwnerRoleID: "Wrong Owner",
            status: first.status
        )
        #expect(throws: ContractError.self) {
            try RequirementRegistry(
                schemaVersion: 1,
                requirements: wrongOwnerRows,
                traceability: [convergenceTraceability()]
            )
        }

        #expect(throws: ContractError.self) {
            try RequirementRegistry(
                schemaVersion: 1,
                requirements: completedRows,
                traceability: [
                    convergenceTraceability(),
                    genericTraceability(ownerRoleID: "Wrong Owner"),
                ]
            )
        }
    }

    @Test("registry decoding rejects noncanonical requirement order and convergence cardinality drift")
    func registryDecodeAndConvergenceCardinality() throws {
        let convergence = try convergenceTraceability()
        let registry = try RequirementRegistry(
            schemaVersion: 1,
            requirements: approvedRequirementRows(),
            traceability: [convergence]
        )
        var object = try jsonObject(registry)
        let requirements = try #require(object["requirements"] as? [[String: Any]])
        object["requirements"] = Array(requirements.reversed())
        #expect(throws: ContractError.self) {
            try decode(RequirementRegistry.self, object: object)
        }

        #expect(throws: ContractError.self) {
            try RequirementRegistry(
                schemaVersion: 1,
                requirements: approvedRequirementRows(),
                traceability: []
            )
        }

        let duplicateError = contractError {
            _ = try RequirementRegistry(
                schemaVersion: 1,
                requirements: approvedRequirementRows(),
                traceability: [convergence, convergence]
            )
        }
        #expect(duplicateError == .duplicateIdentifier(
            kind: "requirement traceability",
            id: "REQ-CONVERGENCE"
        ))
    }

    @Test("mapping and traceability ID reuse distinguishes identical and conflicting payloads")
    func duplicateAndReusedPayloadClassification() throws {
        let mappings = try convergenceMappings()
        let first = try #require(mappings.first)
        let identicalMappings = [first, first] + Array(mappings.dropFirst())
        let duplicateMappingError = contractError {
            _ = try convergenceTraceability(fixtureMappings: identicalMappings)
        }
        #expect(duplicateMappingError == .duplicateIdentifier(
            kind: "traceability fixture mapping",
            id: first.checkID
        ))

        let changedFirst = try TraceabilityFixtureMapping(
            checkID: first.checkID,
            positiveFixtureIDs: first.positiveFixtureIDs,
            negativeFixtureIDs: ["FIX-WF-CONV-BASELINE-FAIL-002"]
        )
        let conflictingMappings = [first, changedFirst] + Array(mappings.dropFirst())
        let reusedMappingError = contractError {
            _ = try convergenceTraceability(fixtureMappings: conflictingMappings)
        }
        #expect(reusedMappingError == .reusedIdentifier(
            kind: "traceability fixture mapping",
            id: first.checkID
        ))

        let generic = try genericTraceability()
        let duplicateTraceError = contractError {
            _ = try RequirementRegistry(
                schemaVersion: 1,
                requirements: approvedRequirementRows(),
                traceability: [convergenceTraceability(), generic, generic]
            )
        }
        #expect(duplicateTraceError == .duplicateIdentifier(
            kind: "requirement traceability",
            id: "REQ-CANON"
        ))

        let conflictingGeneric = try genericTraceability(requiredEvidenceKinds: ["contract_test_v2"])
        let reusedTraceError = contractError {
            _ = try RequirementRegistry(
                schemaVersion: 1,
                requirements: approvedRequirementRows(),
                traceability: [convergenceTraceability(), generic, conflictingGeneric]
            )
        }
        #expect(reusedTraceError == .reusedIdentifier(
            kind: "requirement traceability",
            id: "REQ-CANON"
        ))
    }

    @Test("concrete check and fixture identifiers use canonical uppercase ASCII tokens")
    func concreteCheckAndFixtureIdentifiers() throws {
        let validPositive = ["FIX-WF-CONV-BASELINE-001-PASS"]
        let validNegative = ["FIX-WF-CONV-BASELINE-001-FAIL-001"]
        for invalidCheckID in [
            "CHK-", "CHK-lower", "CHK-VALID?", "CHK-VALID[1]",
            "CHK-VALID ID", "CHK-VALID--ID", "CHK-VALID-*",
        ] {
            #expect(throws: ContractError.self) {
                try TraceabilityFixtureMapping(
                    checkID: invalidCheckID,
                    positiveFixtureIDs: validPositive,
                    negativeFixtureIDs: validNegative
                )
            }
        }

        for invalidFixtureID in [
            "FIX-", "FIX-lower", "FIX-VALID?", "FIX-VALID[1]",
            "FIX-VALID ID", "FIX-VALID--ID", "FIX-VALID-*",
        ] {
            #expect(throws: ContractError.self) {
                try TraceabilityFixtureMapping(
                    checkID: "CHK-WF-CONV-BASELINE-001",
                    positiveFixtureIDs: [invalidFixtureID],
                    negativeFixtureIDs: validNegative
                )
            }
        }

        #expect(throws: ContractError.self) {
            try fullChapterMetadata(checkIDs: ["CHK-data-001"])
        }
        #expect(throws: ContractError.self) {
            try fullChapterMetadata(positiveFixtureIDs: ["FIX-DATA LIFE-PASS"])
        }
    }

    @Test("namespace allocations contain one canonical terminal wildcard")
    func canonicalNamespaceAllocations() throws {
        for invalidNamespace in [
            "CHK-CANON", "CHK-canon-*", "CHK-CANON--*",
            "CHK-CANON-?-*", "CHK-CANON-*-BROKEN-*", "CHK-CANON-**",
        ] {
            #expect(throws: ContractError.self) {
                try genericTraceability(internalCheckNamespace: invalidNamespace)
            }
        }
        for invalidNamespace in [
            "FIX-CANON", "FIX-canon-*", "FIX-CANON--*",
            "FIX-CANON-?-*", "FIX-CANON-*-BROKEN-*", "FIX-CANON-**",
        ] {
            #expect(throws: ContractError.self) {
                try genericTraceability(fixtureNamespace: invalidNamespace)
            }
        }
    }

    @Test("convergence preserves semantic order and rejects foreign fixtures")
    func convergenceOrderAndFixtureOwnership() throws {
        #expect(throws: ContractError.self) {
            try convergenceTraceability(publicCheckIDs: Array(Self.publicConvergenceChecks.reversed()))
        }
        #expect(throws: ContractError.self) {
            try convergenceTraceability(fixtureMappings: Array(convergenceMappings().reversed()))
        }
        #expect(throws: ContractError.self) {
            try convergenceTraceability(internalCheckNamespace: "CHK-WF-CONVERGENCE-*")
        }
        #expect(throws: ContractError.self) {
            try convergenceTraceability(fixtureNamespace: "FIX-WF-CONVERGENCE-*")
        }

        var mappings = try convergenceMappings()
        let first = try #require(mappings.first)
        mappings[0] = try TraceabilityFixtureMapping(
            checkID: first.checkID,
            positiveFixtureIDs: ["FIX-FOREIGN-BASELINE-PASS"],
            negativeFixtureIDs: first.negativeFixtureIDs
        )
        #expect(throws: ContractError.self) {
            try convergenceTraceability(fixtureMappings: mappings)
        }
    }

    @Test("canonical strings reject outer whitespace and control characters")
    func canonicalNonBlankStrings() throws {
        #expect(throws: ContractError.self) {
            try ChapterDependency(
                requiredRuleID: RuleID(validating: "DATA-CLASS-001"),
                expectedOwnerRoleID: " Data Governance Owner"
            )
        }
        #expect(throws: ContractError.self) {
            try RequirementRecord(
                schemaVersion: 1,
                id: RequirementID(validating: "ENT-DATA"),
                accountableOwnerRoleID: "Data Lifecycle Owner\n",
                status: .planned
            )
        }
        #expect(throws: ContractError.self) {
            try RequirementRecord(
                schemaVersion: 1,
                id: RequirementID(validating: "ENT-DATA"),
                accountableOwnerRoleID: "Data\u{0007} Lifecycle Owner",
                status: .planned
            )
        }
        #expect(throws: ContractError.self) {
            try fullChapterMetadata(title: "Data lifecycle ")
        }
        #expect(throws: ContractError.self) {
            try convergenceTraceability(
                requiredEvidenceKinds: [
                    "review_confirmation_receipt/v1",
                    "review_convergence_receipt/v1\n",
                ]
            )
        }
    }
}

private extension CanonTraceabilityContractTests {
    static let approvedRequirementIDs = [
        "ENT-ACCESSIBILITY", "ENT-CONCURRENCY", "ENT-DATA", "ENT-OBSERVABILITY",
        "ENT-PERFORMANCE", "ENT-PRIVACY", "ENT-SECURITY", "ENT-SUPPLY",
        "ENT-SWIFTUI", "ENT-TESTING", "P0-1", "P0-2", "P0-3", "P0-4",
        "P0-5", "P0-6", "P0-7", "REQ-AGENTS", "REQ-BOARDY", "REQ-CANON",
        "REQ-CONVERGENCE", "REQ-EFFECTS", "REQ-MIGRATION", "REQ-RC",
        "REQ-RUNTIME", "REQ-VERIFY",
    ]

    static let internalConvergenceChecks = [
        "CHK-WF-CONV-BASELINE-001",
        "CHK-WF-CONV-INVENTORY-001",
        "CHK-WF-CONV-REGISTER-001",
        "CHK-WF-CONV-DISPOSITION-001",
        "CHK-WF-CONV-REMEDIATION-001",
        "CHK-WF-CONV-CONFIRMATION-001",
        "CHK-WF-CONV-EXCEPTION-001",
        "CHK-WF-CONV-INVALIDATION-001",
    ]

    static let publicConvergenceChecks = [
        "CHK-FLOW-CONVERGENCE",
        "CHK-AGENT-CONVERGENCE",
        "CHK-EVIDENCE-CONVERGENCE",
        "CHK-RUN-CONVERGENCE",
        "CHK-RELEASE-CONVERGENCE",
    ]

    func approvedRequirementRows(
        statusOverrides: [String: RequirementStatus] = [:]
    ) throws -> [RequirementRecord] {
        let owners = [
            "ENT-ACCESSIBILITY": "Accessibility Owner",
            "ENT-CONCURRENCY": "Concurrency Chapter Owner",
            "ENT-DATA": "Data Lifecycle Owner",
            "ENT-OBSERVABILITY": "Operability Owner",
            "ENT-PERFORMANCE": "Performance Owner",
            "ENT-PRIVACY": "Privacy Owner",
            "ENT-SECURITY": "Security Owner",
            "ENT-SUPPLY": "Security/Legal Owner",
            "ENT-SWIFTUI": "SwiftUI Profile Owner",
            "ENT-TESTING": "Testing Owner",
            "P0-1": "Workflow Maintainer",
            "P0-2": "Runtime/Agent Owner",
            "P0-3": "Verification Owner",
            "P0-4": "Canon Maintainer",
            "P0-5": "Scaffolding Owner",
            "P0-6": "Workflow Maintainer",
            "P0-7": "Security/Compliance Owner",
            "REQ-AGENTS": "Runtime/Agent Owner",
            "REQ-BOARDY": "iOS Profile Owner",
            "REQ-CANON": "Canon Maintainer",
            "REQ-CONVERGENCE": "Workflow Maintainer",
            "REQ-EFFECTS": "Workflow Maintainer",
            "REQ-MIGRATION": "Release Steward",
            "REQ-RC": "Release Steward",
            "REQ-RUNTIME": "Runtime/Agent Owner",
            "REQ-VERIFY": "Verification Owner",
        ]
        return try Self.approvedRequirementIDs.map { id in
            let owner = try #require(owners[id])
            return try RequirementRecord(
                schemaVersion: 1,
                id: RequirementID(validating: id),
                accountableOwnerRoleID: owner,
                status: statusOverrides[id] ?? .planned
            )
        }
    }

    func convergenceTraceability(
        internalCheckNamespace: String = "CHK-WF-CONV-*",
        internalCheckIDs: [String] = Self.internalConvergenceChecks,
        publicCheckIDs: [String] = Self.publicConvergenceChecks,
        fixtureNamespace: String = "FIX-WF-CONV-*",
        fixtureMappings: [TraceabilityFixtureMapping]? = nil,
        requiredEvidenceKinds: [String] = [
            "review_confirmation_receipt/v1",
            "review_convergence_receipt/v1",
        ]
    ) throws -> TraceabilityRecord {
        try TraceabilityRecord(
            schemaVersion: 1,
            requirementID: RequirementID(validating: "REQ-CONVERGENCE"),
            accountableOwnerRoleID: "Workflow Maintainer",
            ruleBindings: [],
            internalCheckNamespace: internalCheckNamespace,
            internalCheckIDs: internalCheckIDs,
            publicCheckIDs: publicCheckIDs,
            fixtureNamespace: fixtureNamespace,
            fixtureMappings: fixtureMappings ?? convergenceMappings(),
            requiredEvidenceKinds: requiredEvidenceKinds
        )
    }

    func convergenceMappings() throws -> [TraceabilityFixtureMapping] {
        try (Self.internalConvergenceChecks + Self.publicConvergenceChecks).map { checkID in
            let stem = checkID
                .replacingOccurrences(of: "CHK-WF-CONV-", with: "")
                .replacingOccurrences(of: "CHK-", with: "")
            return try TraceabilityFixtureMapping(
                checkID: checkID,
                positiveFixtureIDs: ["FIX-WF-CONV-\(stem)-PASS"],
                negativeFixtureIDs: ["FIX-WF-CONV-\(stem)-FAIL-001"]
            )
        }
    }

    func genericTraceability(
        ownerRoleID: String = "Canon Maintainer",
        internalCheckNamespace: String = "CHK-CANON-*",
        fixtureNamespace: String = "FIX-CANON-*",
        requiredEvidenceKinds: [String] = ["contract_test"]
    ) throws -> TraceabilityRecord {
        let checkID = "CHK-CANON-VALIDATE-001"
        return try TraceabilityRecord(
            schemaVersion: 1,
            requirementID: RequirementID(validating: "REQ-CANON"),
            accountableOwnerRoleID: ownerRoleID,
            ruleBindings: [],
            internalCheckNamespace: internalCheckNamespace,
            internalCheckIDs: [checkID],
            publicCheckIDs: [],
            fixtureNamespace: fixtureNamespace,
            fixtureMappings: [TraceabilityFixtureMapping(
                checkID: checkID,
                positiveFixtureIDs: ["FIX-CANON-VALIDATE-001-PASS"],
                negativeFixtureIDs: ["FIX-CANON-VALIDATE-001-FAIL-001"]
            )],
            requiredEvidenceKinds: requiredEvidenceKinds
        )
    }

    func chapterDependency() throws -> ChapterDependency {
        try ChapterDependency(
            requiredRuleID: RuleID(validating: "DATA-CLASS-001"),
            expectedOwnerRoleID: "Data Governance Owner"
        )
    }

    func fullChapterMetadata(
        id: String = "data-lifecycle",
        title: String = "Data lifecycle",
        checkIDs: [String] = ["CHK-DATA-LIFE-001"],
        positiveFixtureIDs: [String] = ["FIX-DATA-LIFE-001-PASS"],
        negativeFixtureIDs: [String] = ["FIX-DATA-LIFE-001-FAIL-001"]
    ) throws -> ChapterMetadata {
        try ChapterMetadata(
            schemaVersion: 1,
            id: id,
            requirementID: RequirementID(validating: "ENT-DATA"),
            title: title,
            ownerRoleID: "Data Lifecycle Owner",
            rationale: "Data must follow an explicit lifecycle.",
            applicability: ["ios"],
            ruleIDs: [RuleID(validating: "DATA-LIFE-001")],
            rationaleADRIDs: [ADRIdentifier(validating: "ADR-0001")],
            compliantExampleIDs: ["FIX-DATA-LIFE-001-PASS"],
            nonCompliantExampleIDs: ["FIX-DATA-LIFE-001-FAIL-001"],
            checkIDs: checkIDs,
            positiveFixtureIDs: positiveFixtureIDs,
            negativeFixtureIDs: negativeFixtureIDs,
            requiredEvidenceKinds: ["contract_test"],
            reviewChecklistIDs: ["DATA-LIFE-CHECKLIST-001"],
            exceptionPolicy: "time_bound_independent_approval",
            reviewCadence: "quarterly",
            requiredRuleDependencies: [chapterDependency()]
        )
    }

    func roundTrip<Value: Codable & Equatable>(_ value: Value) throws -> Value {
        let encoded = try CanonicalJSON.encode(value)
        let decoded = try CanonicalJSON.decode(Value.self, from: encoded)
        #expect(try CanonicalJSON.encode(decoded) == encoded)
        return decoded
    }

    func jsonObject(_ value: some Encodable) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: CanonicalJSON.encode(value))
        return try #require(object as? [String: Any])
    }

    func decode<Value: Decodable>(
        _ type: Value.Type,
        object: [String: Any]
    ) throws -> Value {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return try CanonicalJSON.decode(type, from: data)
    }

    func contractError(_ operation: () throws -> Void) -> ContractError? {
        do {
            try operation()
            Issue.record("Expected ContractError but the operation succeeded")
            return nil
        } catch let error as ContractError {
            return error
        } catch {
            Issue.record("Expected ContractError but received \(error)")
            return nil
        }
    }
}
