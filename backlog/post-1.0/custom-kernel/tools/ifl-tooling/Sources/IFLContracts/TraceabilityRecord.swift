import Foundation

public enum RequirementStatus: String, CaseIterable, Hashable, Sendable, Codable {
    case planned
    case inProgress = "in_progress"
    case completed
    case deferred
    case blocked

    public init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        guard let status = Self(rawValue: value) else {
            throw ContractError.invalidContract(
                kind: "requirement_status",
                reason: "unsupported value \(value)"
            )
        }
        self = status
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct RequirementRecord: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let id: RequirementID
    public let accountableOwnerRoleID: String
    public let status: RequirementStatus

    public init(
        schemaVersion: Int,
        id: RequirementID,
        accountableOwnerRoleID: String,
        status: RequirementStatus
    ) throws {
        guard schemaVersion == 1 else {
            throw ContractError.unsupportedSchemaVersion(kind: "requirement_record", value: schemaVersion)
        }
        let validatedID = try RequirementID(validating: id.rawValue)
        try TraceabilityValidation.requireNonBlank(
            accountableOwnerRoleID,
            kind: "requirement_record",
            field: "accountable_owner_role_id"
        )

        self.schemaVersion = schemaVersion
        self.id = validatedID
        self.accountableOwnerRoleID = accountableOwnerRoleID
        self.status = status
    }

    public init(from decoder: any Decoder) throws {
        try TraceabilityValidation.rejectUnexpectedKeys(
            in: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: "requirement_record"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            id: container.decode(RequirementID.self, forKey: .id),
            accountableOwnerRoleID: container.decode(String.self, forKey: .accountableOwnerRoleID),
            status: container.decode(RequirementStatus.self, forKey: .status)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(accountableOwnerRoleID, forKey: .accountableOwnerRoleID)
        try container.encode(status, forKey: .status)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case id
        case accountableOwnerRoleID = "accountable_owner_role_id"
        case status
    }
}

public struct RuleOwnerBinding: Codable, Hashable, Sendable {
    public let ruleID: RuleID
    public let ownerRoleID: String

    public init(ruleID: RuleID, ownerRoleID: String) throws {
        self.ruleID = try RuleID(validating: ruleID.rawValue)
        try TraceabilityValidation.requireNonBlank(
            ownerRoleID,
            kind: "rule_owner_binding",
            field: "owner_role_id"
        )
        self.ownerRoleID = ownerRoleID
    }

    public init(from decoder: any Decoder) throws {
        try TraceabilityValidation.rejectUnexpectedKeys(
            in: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: "rule_owner_binding"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            ruleID: container.decode(RuleID.self, forKey: .ruleID),
            ownerRoleID: container.decode(String.self, forKey: .ownerRoleID)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ruleID, forKey: .ruleID)
        try container.encode(ownerRoleID, forKey: .ownerRoleID)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case ruleID = "rule_id"
        case ownerRoleID = "owner_role_id"
    }
}

public struct TraceabilityFixtureMapping: Codable, Hashable, Sendable {
    public let checkID: String
    public let positiveFixtureIDs: [String]
    public let negativeFixtureIDs: [String]

    public init(
        checkID: String,
        positiveFixtureIDs: [String],
        negativeFixtureIDs: [String]
    ) throws {
        try TraceabilityValidation.requireIdentifier(
            checkID,
            prefix: "CHK-",
            kind: "traceability_fixture_mapping",
            field: "check_id"
        )
        try TraceabilityValidation.requireNonEmpty(
            positiveFixtureIDs,
            kind: "traceability_fixture_mapping",
            field: "positive_fixture_ids"
        )
        try TraceabilityValidation.requireNonEmpty(
            negativeFixtureIDs,
            kind: "traceability_fixture_mapping",
            field: "negative_fixture_ids"
        )
        try TraceabilityValidation.validateIdentifierArray(
            positiveFixtureIDs,
            prefix: "FIX-",
            kind: "positive fixture"
        )
        try TraceabilityValidation.validateIdentifierArray(
            negativeFixtureIDs,
            prefix: "FIX-",
            kind: "negative fixture"
        )
        try TraceabilityValidation.requireDisjoint(
            positiveFixtureIDs,
            negativeFixtureIDs,
            kind: "traceability fixture"
        )

        self.checkID = checkID
        self.positiveFixtureIDs = positiveFixtureIDs
        self.negativeFixtureIDs = negativeFixtureIDs
    }

    public init(from decoder: any Decoder) throws {
        try TraceabilityValidation.rejectUnexpectedKeys(
            in: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: "traceability_fixture_mapping"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            checkID: container.decode(String.self, forKey: .checkID),
            positiveFixtureIDs: container.decode([String].self, forKey: .positiveFixtureIDs),
            negativeFixtureIDs: container.decode([String].self, forKey: .negativeFixtureIDs)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(checkID, forKey: .checkID)
        try container.encode(positiveFixtureIDs, forKey: .positiveFixtureIDs)
        try container.encode(negativeFixtureIDs, forKey: .negativeFixtureIDs)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case checkID = "check_id"
        case positiveFixtureIDs = "positive_fixture_ids"
        case negativeFixtureIDs = "negative_fixture_ids"
    }
}

public struct TraceabilityRecord: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let requirementID: RequirementID
    public let accountableOwnerRoleID: String
    public let ruleBindings: [RuleOwnerBinding]
    public let internalCheckNamespace: String
    public let internalCheckIDs: [String]
    public let publicCheckIDs: [String]
    public let fixtureNamespace: String
    public let fixtureMappings: [TraceabilityFixtureMapping]
    public let requiredEvidenceKinds: [String]

    public var allCheckIDs: [String] {
        internalCheckIDs + publicCheckIDs
    }

    public init(
        schemaVersion: Int,
        requirementID: RequirementID,
        accountableOwnerRoleID: String,
        ruleBindings: [RuleOwnerBinding],
        internalCheckNamespace: String,
        internalCheckIDs: [String],
        publicCheckIDs: [String],
        fixtureNamespace: String,
        fixtureMappings: [TraceabilityFixtureMapping],
        requiredEvidenceKinds: [String]
    ) throws {
        guard schemaVersion == 1 else {
            throw ContractError.unsupportedSchemaVersion(kind: "traceability_record", value: schemaVersion)
        }

        let validatedRequirementID = try RequirementID(validating: requirementID.rawValue)
        try TraceabilityValidation.requireNonBlank(
            accountableOwnerRoleID,
            kind: "traceability_record",
            field: "accountable_owner_role_id"
        )
        try TraceabilityValidation.requireNamespace(
            internalCheckNamespace,
            prefix: "CHK-",
            kind: "internal check"
        )
        try TraceabilityValidation.requireNamespace(
            fixtureNamespace,
            prefix: "FIX-",
            kind: "fixture"
        )

        let validatedRuleBindings = try ruleBindings.map {
            try RuleOwnerBinding(ruleID: $0.ruleID, ownerRoleID: $0.ownerRoleID)
        }
        let validatedFixtureMappings = try fixtureMappings.map {
            try TraceabilityFixtureMapping(
                checkID: $0.checkID,
                positiveFixtureIDs: $0.positiveFixtureIDs,
                negativeFixtureIDs: $0.negativeFixtureIDs
            )
        }

        try TraceabilityValidation.validateRuleBindings(validatedRuleBindings)
        try TraceabilityValidation.validateIdentifierArray(
            internalCheckIDs,
            prefix: "CHK-",
            kind: "internal check"
        )
        try TraceabilityValidation.validateIdentifierArray(
            publicCheckIDs,
            prefix: "CHK-",
            kind: "public check"
        )
        try TraceabilityValidation.requireDisjoint(
            internalCheckIDs,
            publicCheckIDs,
            kind: "traceability check"
        )
        try TraceabilityValidation.validateFixtureMappings(validatedFixtureMappings)
        try TraceabilityValidation.validateStringArray(
            requiredEvidenceKinds,
            kind: "required evidence kind"
        )

        let allCheckIDs = internalCheckIDs + publicCheckIDs
        let allCheckIDSet = Set(allCheckIDs)
        for mapping in validatedFixtureMappings where !allCheckIDSet.contains(mapping.checkID) {
            throw ContractError.unresolvedReference(
                kind: "traceability fixture mapping check",
                id: mapping.checkID
            )
        }

        if validatedRequirementID.rawValue == ConvergenceContract.requirementID {
            try Self.validateConvergence(
                accountableOwnerRoleID: accountableOwnerRoleID,
                ruleBindings: validatedRuleBindings,
                internalCheckNamespace: internalCheckNamespace,
                internalCheckIDs: internalCheckIDs,
                publicCheckIDs: publicCheckIDs,
                fixtureNamespace: fixtureNamespace,
                fixtureMappings: validatedFixtureMappings,
                requiredEvidenceKinds: requiredEvidenceKinds
            )
        }

        self.schemaVersion = schemaVersion
        self.requirementID = validatedRequirementID
        self.accountableOwnerRoleID = accountableOwnerRoleID
        self.ruleBindings = validatedRuleBindings
        self.internalCheckNamespace = internalCheckNamespace
        self.internalCheckIDs = internalCheckIDs
        self.publicCheckIDs = publicCheckIDs
        self.fixtureNamespace = fixtureNamespace
        self.fixtureMappings = validatedFixtureMappings
        self.requiredEvidenceKinds = requiredEvidenceKinds
    }

    public init(from decoder: any Decoder) throws {
        try TraceabilityValidation.rejectUnexpectedKeys(
            in: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: "traceability_record"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            requirementID: container.decode(RequirementID.self, forKey: .requirementID),
            accountableOwnerRoleID: container.decode(String.self, forKey: .accountableOwnerRoleID),
            ruleBindings: container.decode([RuleOwnerBinding].self, forKey: .ruleBindings),
            internalCheckNamespace: container.decode(String.self, forKey: .internalCheckNamespace),
            internalCheckIDs: container.decode([String].self, forKey: .internalCheckIDs),
            publicCheckIDs: container.decode([String].self, forKey: .publicCheckIDs),
            fixtureNamespace: container.decode(String.self, forKey: .fixtureNamespace),
            fixtureMappings: container.decode([TraceabilityFixtureMapping].self, forKey: .fixtureMappings),
            requiredEvidenceKinds: container.decode([String].self, forKey: .requiredEvidenceKinds)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(requirementID, forKey: .requirementID)
        try container.encode(accountableOwnerRoleID, forKey: .accountableOwnerRoleID)
        try container.encode(ruleBindings, forKey: .ruleBindings)
        try container.encode(internalCheckNamespace, forKey: .internalCheckNamespace)
        try container.encode(internalCheckIDs, forKey: .internalCheckIDs)
        try container.encode(publicCheckIDs, forKey: .publicCheckIDs)
        try container.encode(fixtureNamespace, forKey: .fixtureNamespace)
        try container.encode(fixtureMappings, forKey: .fixtureMappings)
        try container.encode(requiredEvidenceKinds, forKey: .requiredEvidenceKinds)
    }

    private static func validateConvergence(
        accountableOwnerRoleID: String,
        ruleBindings: [RuleOwnerBinding],
        internalCheckNamespace: String,
        internalCheckIDs: [String],
        publicCheckIDs: [String],
        fixtureNamespace: String,
        fixtureMappings: [TraceabilityFixtureMapping],
        requiredEvidenceKinds: [String]
    ) throws {
        guard accountableOwnerRoleID == ConvergenceContract.accountableOwnerRoleID else {
            throw ContractError.invalidContract(
                kind: "REQ-CONVERGENCE traceability",
                reason: "accountable owner must be \(ConvergenceContract.accountableOwnerRoleID)"
            )
        }
        guard ruleBindings.isEmpty else {
            throw ContractError.invalidContract(
                kind: "REQ-CONVERGENCE traceability",
                reason: "rule_bindings must be empty"
            )
        }
        guard internalCheckNamespace == ConvergenceContract.internalCheckNamespace else {
            throw ContractError.invalidContract(
                kind: "REQ-CONVERGENCE traceability",
                reason: "internal_check_namespace must be \(ConvergenceContract.internalCheckNamespace)"
            )
        }
        guard internalCheckIDs == ConvergenceContract.internalCheckIDs else {
            throw ContractError.invalidContract(
                kind: "REQ-CONVERGENCE traceability",
                reason: "internal_check_ids must contain the exact canonical convergence checks"
            )
        }
        guard publicCheckIDs == ConvergenceContract.publicCheckIDs else {
            throw ContractError.invalidContract(
                kind: "REQ-CONVERGENCE traceability",
                reason: "public_check_ids must contain the exact canonical aggregate checks"
            )
        }
        guard fixtureNamespace == ConvergenceContract.fixtureNamespace else {
            throw ContractError.invalidContract(
                kind: "REQ-CONVERGENCE traceability",
                reason: "fixture_namespace must be \(ConvergenceContract.fixtureNamespace)"
            )
        }
        guard requiredEvidenceKinds == ConvergenceContract.requiredEvidenceKinds else {
            throw ContractError.invalidContract(
                kind: "REQ-CONVERGENCE traceability",
                reason: "required_evidence_kinds must contain both canonical receipt kinds in order"
            )
        }

        let expectedCheckIDs = ConvergenceContract.internalCheckIDs + ConvergenceContract.publicCheckIDs
        guard fixtureMappings.map(\.checkID) == expectedCheckIDs else {
            throw ContractError.invalidContract(
                kind: "REQ-CONVERGENCE traceability",
                reason: "fixture_mappings must contain exactly one canonical mapping per convergence check in order"
            )
        }

        for mapping in fixtureMappings {
            let fixtureIDs = mapping.positiveFixtureIDs + mapping.negativeFixtureIDs
            guard fixtureIDs.allSatisfy({ $0.hasPrefix(ConvergenceContract.fixturePrefix) }) else {
                throw ContractError.invalidContract(
                    kind: "REQ-CONVERGENCE traceability",
                    reason: "fixtures for \(mapping.checkID) must belong to FIX-WF-CONV-*"
                )
            }
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case requirementID = "requirement_id"
        case accountableOwnerRoleID = "accountable_owner_role_id"
        case ruleBindings = "rule_bindings"
        case internalCheckNamespace = "internal_check_namespace"
        case internalCheckIDs = "internal_check_ids"
        case publicCheckIDs = "public_check_ids"
        case fixtureNamespace = "fixture_namespace"
        case fixtureMappings = "fixture_mappings"
        case requiredEvidenceKinds = "required_evidence_kinds"
    }
}

public struct RequirementRegistry: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let requirements: [RequirementRecord]
    public let traceability: [TraceabilityRecord]

    public init(
        schemaVersion: Int,
        requirements: [RequirementRecord],
        traceability: [TraceabilityRecord]
    ) throws {
        guard schemaVersion == 1 else {
            throw ContractError.unsupportedSchemaVersion(kind: "requirement_registry", value: schemaVersion)
        }

        let validatedRequirements = try requirements.map {
            try RequirementRecord(
                schemaVersion: $0.schemaVersion,
                id: $0.id,
                accountableOwnerRoleID: $0.accountableOwnerRoleID,
                status: $0.status
            )
        }
        try Self.validateRequirements(validatedRequirements)

        let validatedTraceability = try traceability.map {
            try TraceabilityRecord(
                schemaVersion: $0.schemaVersion,
                requirementID: $0.requirementID,
                accountableOwnerRoleID: $0.accountableOwnerRoleID,
                ruleBindings: $0.ruleBindings,
                internalCheckNamespace: $0.internalCheckNamespace,
                internalCheckIDs: $0.internalCheckIDs,
                publicCheckIDs: $0.publicCheckIDs,
                fixtureNamespace: $0.fixtureNamespace,
                fixtureMappings: $0.fixtureMappings,
                requiredEvidenceKinds: $0.requiredEvidenceKinds
            )
        }
        try Self.validateTraceability(
            validatedTraceability,
            requirements: validatedRequirements
        )

        self.schemaVersion = schemaVersion
        self.requirements = validatedRequirements.sorted { $0.id.rawValue < $1.id.rawValue }
        self.traceability = validatedTraceability.sorted {
            $0.requirementID.rawValue < $1.requirementID.rawValue
        }
    }

    public init(from decoder: any Decoder) throws {
        try TraceabilityValidation.rejectUnexpectedKeys(
            in: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: "requirement_registry"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        let requirements = try container.decode([RequirementRecord].self, forKey: .requirements)
        let traceability = try container.decode([TraceabilityRecord].self, forKey: .traceability)

        let requirementIDs = requirements.map(\.id.rawValue)
        guard requirementIDs == requirementIDs.sorted() else {
            throw ContractError.invalidContract(
                kind: "requirement_registry",
                reason: "requirements must use canonical identifier order"
            )
        }
        let traceabilityIDs = traceability.map(\.requirementID.rawValue)
        guard traceabilityIDs == traceabilityIDs.sorted() else {
            throw ContractError.invalidContract(
                kind: "requirement_registry",
                reason: "traceability must use canonical requirement identifier order"
            )
        }

        try self.init(
            schemaVersion: schemaVersion,
            requirements: requirements,
            traceability: traceability
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(requirements, forKey: .requirements)
        try container.encode(traceability, forKey: .traceability)
    }

    private static func validateRequirements(_ requirements: [RequirementRecord]) throws {
        var recordsByID: [String: RequirementRecord] = [:]
        for requirement in requirements {
            if let existing = recordsByID[requirement.id.rawValue] {
                if existing == requirement {
                    throw ContractError.duplicateIdentifier(
                        kind: "requirement",
                        id: requirement.id.rawValue
                    )
                }
                throw ContractError.reusedIdentifier(
                    kind: "requirement",
                    id: requirement.id.rawValue
                )
            }
            recordsByID[requirement.id.rawValue] = requirement
        }

        let actualIDs = Set(recordsByID.keys)
        let approvedIDs = Set(RequirementRegistryContract.approvedOwnersByID.keys)
        guard actualIDs == approvedIDs else {
            let missing = approvedIDs.subtracting(actualIDs).sorted()
            let unexpected = actualIDs.subtracting(approvedIDs).sorted()
            throw ContractError.invalidContract(
                kind: "requirement_registry",
                reason: "requirement identity set mismatch; missing=\(missing), unexpected=\(unexpected)"
            )
        }

        for requirement in requirements {
            guard let expectedOwner = RequirementRegistryContract.approvedOwnersByID[requirement.id.rawValue] else {
                throw ContractError.unresolvedReference(
                    kind: "approved requirement",
                    id: requirement.id.rawValue
                )
            }
            guard requirement.accountableOwnerRoleID == expectedOwner else {
                throw ContractError.invalidContract(
                    kind: "requirement_registry",
                    reason: "owner for \(requirement.id.rawValue) must be \(expectedOwner)"
                )
            }
        }
    }

    private static func validateTraceability(
        _ traceability: [TraceabilityRecord],
        requirements: [RequirementRecord]
    ) throws {
        let requirementsByID = Dictionary(
            uniqueKeysWithValues: requirements.map { ($0.id.rawValue, $0) }
        )
        var recordsByID: [String: TraceabilityRecord] = [:]
        var convergenceCount = 0

        for record in traceability {
            let id = record.requirementID.rawValue
            if let existing = recordsByID[id] {
                if existing == record {
                    throw ContractError.duplicateIdentifier(kind: "requirement traceability", id: id)
                }
                throw ContractError.reusedIdentifier(kind: "requirement traceability", id: id)
            }
            recordsByID[id] = record
            guard let requirement = requirementsByID[id] else {
                throw ContractError.unresolvedReference(kind: "traceability requirement", id: id)
            }
            guard record.accountableOwnerRoleID == requirement.accountableOwnerRoleID else {
                throw ContractError.invalidContract(
                    kind: "requirement_registry",
                    reason: "traceability owner for \(id) must match its requirement owner"
                )
            }
            if id == ConvergenceContract.requirementID {
                convergenceCount += 1
            }
        }

        guard convergenceCount == 1 else {
            throw ContractError.invalidContract(
                kind: "requirement_registry",
                reason: "traceability must contain REQ-CONVERGENCE exactly once"
            )
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case requirements
        case traceability
    }
}

private enum ConvergenceContract {
    static let requirementID = "REQ-CONVERGENCE"
    static let accountableOwnerRoleID = "Workflow Maintainer"
    static let internalCheckNamespace = "CHK-WF-CONV-*"
    static let internalCheckIDs = [
        "CHK-WF-CONV-BASELINE-001",
        "CHK-WF-CONV-INVENTORY-001",
        "CHK-WF-CONV-REGISTER-001",
        "CHK-WF-CONV-DISPOSITION-001",
        "CHK-WF-CONV-REMEDIATION-001",
        "CHK-WF-CONV-CONFIRMATION-001",
        "CHK-WF-CONV-EXCEPTION-001",
        "CHK-WF-CONV-INVALIDATION-001",
    ]
    static let publicCheckIDs = [
        "CHK-FLOW-CONVERGENCE",
        "CHK-AGENT-CONVERGENCE",
        "CHK-EVIDENCE-CONVERGENCE",
        "CHK-RUN-CONVERGENCE",
        "CHK-RELEASE-CONVERGENCE",
    ]
    static let fixtureNamespace = "FIX-WF-CONV-*"
    static let fixturePrefix = "FIX-WF-CONV-"
    static let requiredEvidenceKinds = [
        "review_confirmation_receipt/v1",
        "review_convergence_receipt/v1",
    ]
}

private enum RequirementRegistryContract {
    static let approvedOwnersByID = [
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
}

private enum TraceabilityValidation {
    static func requireNonBlank(_ value: String, kind: String, field: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed == value,
              !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "\(field) must be a non-blank canonical string"
            )
        }
    }

    static func requireNonEmpty(_ values: [some Any], kind: String, field: String) throws {
        guard !values.isEmpty else {
            throw ContractError.invalidContract(kind: kind, reason: "\(field) must not be empty")
        }
    }

    static func requireIdentifier(
        _ value: String,
        prefix: String,
        kind: String,
        field: String
    ) throws {
        try CheckFixtureIdentifierValidation.requireConcrete(
            value,
            prefix: prefix,
            kind: kind,
            field: field
        )
    }

    static func requireNamespace(_ value: String, prefix: String, kind: String) throws {
        try CheckFixtureIdentifierValidation.requireAllocation(
            value,
            prefix: prefix,
            kind: "traceability_record",
            field: "\(kind)_namespace"
        )
    }

    static func validateIdentifierArray(
        _ values: [String],
        prefix: String,
        kind: String
    ) throws {
        for value in values {
            try requireIdentifier(value, prefix: prefix, kind: kind, field: "id")
        }
        try validateStringArray(values, kind: kind)
    }

    static func validateStringArray(_ values: [String], kind: String) throws {
        var seen = Set<String>()
        for value in values {
            try requireNonBlank(value, kind: kind, field: "value")
            guard seen.insert(value).inserted else {
                throw ContractError.duplicateIdentifier(kind: kind, id: value)
            }
        }
    }

    static func validateRuleBindings(_ bindings: [RuleOwnerBinding]) throws {
        var ownersByRuleID: [String: String] = [:]
        for binding in bindings {
            let id = binding.ruleID.rawValue
            if let existingOwner = ownersByRuleID[id] {
                if existingOwner == binding.ownerRoleID {
                    throw ContractError.duplicateIdentifier(kind: "rule owner binding", id: id)
                }
                throw ContractError.reusedIdentifier(kind: "rule owner binding", id: id)
            }
            ownersByRuleID[id] = binding.ownerRoleID
        }
    }

    static func validateFixtureMappings(_ mappings: [TraceabilityFixtureMapping]) throws {
        var mappingsByCheckID: [String: TraceabilityFixtureMapping] = [:]
        for mapping in mappings {
            if let existing = mappingsByCheckID[mapping.checkID] {
                if existing == mapping {
                    throw ContractError.duplicateIdentifier(
                        kind: "traceability fixture mapping",
                        id: mapping.checkID
                    )
                }
                throw ContractError.reusedIdentifier(
                    kind: "traceability fixture mapping",
                    id: mapping.checkID
                )
            }
            mappingsByCheckID[mapping.checkID] = mapping
        }
    }

    static func requireDisjoint(_ left: [String], _ right: [String], kind: String) throws {
        let overlap = Set(left).intersection(right)
        guard let reused = overlap.sorted().first else { return }
        throw ContractError.reusedIdentifier(kind: kind, id: reused)
    }

    static func rejectUnexpectedKeys(
        in decoder: any Decoder,
        allowed: Set<String>,
        kind: String
    ) throws {
        let container = try decoder.container(keyedBy: TraceabilityCodingKey.self)
        let unexpected = container.allKeys
            .map(\.stringValue)
            .filter { !allowed.contains($0) }
            .sorted()
        guard unexpected.isEmpty else {
            throw ContractError.unexpectedKeys(kind: kind, keys: unexpected)
        }
    }
}

private struct TraceabilityCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

enum CheckFixtureIdentifierValidation {
    static func requireConcrete(
        _ value: String,
        prefix: String,
        kind: String,
        field: String
    ) throws {
        guard value.hasPrefix(prefix) else {
            throw invalidIdentifier(value, kind: kind, field: field)
        }
        let suffix = String(value.dropFirst(prefix.count))
        guard isCanonicalUppercaseHyphenated(suffix) else {
            throw invalidIdentifier(value, kind: kind, field: field)
        }
    }

    static func requireAllocation(
        _ value: String,
        prefix: String,
        kind: String,
        field: String
    ) throws {
        guard value.hasSuffix("-*"), value.count(where: { $0 == "*" }) == 1 else {
            throw invalidIdentifier(value, kind: kind, field: field)
        }
        let concretePrefix = String(value.dropLast(2))
        do {
            try requireConcrete(
                concretePrefix,
                prefix: prefix,
                kind: kind,
                field: field
            )
        } catch {
            throw invalidIdentifier(value, kind: kind, field: field)
        }
    }

    private static func isCanonicalUppercaseHyphenated(_ value: String) -> Bool {
        let tokens = value.split(separator: "-", omittingEmptySubsequences: false)
        return !tokens.isEmpty && tokens.allSatisfy { token in
            !token.isEmpty && token.utf8.allSatisfy { byte in
                (byte >= 65 && byte <= 90) || (byte >= 48 && byte <= 57)
            }
        }
    }

    private static func invalidIdentifier(
        _ value: String,
        kind: String,
        field: String
    ) -> ContractError {
        .invalidContract(
            kind: kind,
            reason: "\(field) contains invalid canonical identifier \(value)"
        )
    }
}
