import Foundation

public struct ChapterMetadata: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let id: String
    public let requirementID: RequirementID
    public let title: String
    public let ownerRoleID: String
    public let rationale: String
    public let applicability: [String]
    public let ruleIDs: [RuleID]
    public let rationaleADRIDs: [ADRIdentifier]
    public let compliantExampleIDs: [String]
    public let nonCompliantExampleIDs: [String]
    public let checkIDs: [String]
    public let positiveFixtureIDs: [String]
    public let negativeFixtureIDs: [String]
    public let requiredEvidenceKinds: [String]
    public let reviewChecklistIDs: [String]
    public let exceptionPolicy: String
    public let reviewCadence: String
    public let requiredRuleDependencies: [ChapterDependency]

    public init(
        schemaVersion: Int,
        id: String,
        requirementID: RequirementID,
        title: String,
        ownerRoleID: String,
        rationale: String,
        applicability: [String],
        ruleIDs: [RuleID],
        rationaleADRIDs: [ADRIdentifier],
        compliantExampleIDs: [String],
        nonCompliantExampleIDs: [String],
        checkIDs: [String],
        positiveFixtureIDs: [String],
        negativeFixtureIDs: [String],
        requiredEvidenceKinds: [String],
        reviewChecklistIDs: [String],
        exceptionPolicy: String,
        reviewCadence: String,
        requiredRuleDependencies: [ChapterDependency]
    ) throws {
        guard schemaVersion == 1 else {
            throw ContractError.unsupportedSchemaVersion(kind: "chapter_metadata", value: schemaVersion)
        }

        try ChapterMetadataValidation.requireNonBlank(id, field: "id")
        try ChapterMetadataValidation.requireNonBlank(title, field: "title")
        try ChapterMetadataValidation.requireNonBlank(ownerRoleID, field: "owner_role_id")
        try ChapterMetadataValidation.requireNonBlank(rationale, field: "rationale")
        try ChapterMetadataValidation.requireNonBlank(exceptionPolicy, field: "exception_policy")
        try ChapterMetadataValidation.requireNonBlank(reviewCadence, field: "review_cadence")

        let validatedRequirementID = try RequirementID(validating: requirementID.rawValue)
        let validatedRuleIDs = try ruleIDs.map { try RuleID(validating: $0.rawValue) }
        let validatedADRIDs = try rationaleADRIDs.map { try ADRIdentifier(validating: $0.rawValue) }
        let validatedDependencies = try requiredRuleDependencies.map {
            try ChapterDependency(
                requiredRuleID: $0.requiredRuleID,
                expectedOwnerRoleID: $0.expectedOwnerRoleID
            )
        }

        try ChapterMetadataValidation.requireComplete(applicability, field: "applicability")
        try ChapterMetadataValidation.requireComplete(validatedRuleIDs, field: "rule_ids")
        try ChapterMetadataValidation.requireComplete(validatedADRIDs, field: "rationale_adr_ids")
        try ChapterMetadataValidation.requireComplete(compliantExampleIDs, field: "compliant_example_ids")
        try ChapterMetadataValidation.requireComplete(nonCompliantExampleIDs, field: "non_compliant_example_ids")
        try ChapterMetadataValidation.requireComplete(checkIDs, field: "check_ids")
        try ChapterMetadataValidation.requireComplete(positiveFixtureIDs, field: "positive_fixture_ids")
        try ChapterMetadataValidation.requireComplete(negativeFixtureIDs, field: "negative_fixture_ids")
        try ChapterMetadataValidation.requireComplete(requiredEvidenceKinds, field: "required_evidence_kinds")
        try ChapterMetadataValidation.requireComplete(reviewChecklistIDs, field: "review_checklist_ids")

        try ChapterMetadataValidation.validateStrings(applicability, field: "applicability")
        try ChapterMetadataValidation.validateUnique(
            validatedRuleIDs,
            kind: "chapter rule",
            identifier: \RuleID.rawValue
        )
        try ChapterMetadataValidation.validateUnique(
            validatedADRIDs,
            kind: "chapter rationale ADR",
            identifier: \ADRIdentifier.rawValue
        )
        try ChapterMetadataValidation.validateStrings(compliantExampleIDs, field: "compliant_example_ids")
        try ChapterMetadataValidation.validateStrings(nonCompliantExampleIDs, field: "non_compliant_example_ids")
        try ChapterMetadataValidation.validateStrings(checkIDs, field: "check_ids")
        try ChapterMetadataValidation.validateStrings(positiveFixtureIDs, field: "positive_fixture_ids")
        try ChapterMetadataValidation.validateStrings(negativeFixtureIDs, field: "negative_fixture_ids")
        try ChapterMetadataValidation.validateStrings(requiredEvidenceKinds, field: "required_evidence_kinds")
        try ChapterMetadataValidation.validateStrings(reviewChecklistIDs, field: "review_checklist_ids")
        try ChapterMetadataValidation.validateDependencies(validatedDependencies)

        try ChapterMetadataValidation.requireConcreteIdentifiers(
            compliantExampleIDs,
            prefix: "FIX-",
            field: "compliant_example_ids"
        )
        try ChapterMetadataValidation.requireConcreteIdentifiers(
            nonCompliantExampleIDs,
            prefix: "FIX-",
            field: "non_compliant_example_ids"
        )
        try ChapterMetadataValidation.requireConcreteIdentifiers(checkIDs, prefix: "CHK-", field: "check_ids")
        try ChapterMetadataValidation.requireConcreteIdentifiers(
            positiveFixtureIDs,
            prefix: "FIX-",
            field: "positive_fixture_ids"
        )
        try ChapterMetadataValidation.requireConcreteIdentifiers(
            negativeFixtureIDs,
            prefix: "FIX-",
            field: "negative_fixture_ids"
        )
        try ChapterMetadataValidation.requireDisjoint(
            compliantExampleIDs,
            nonCompliantExampleIDs,
            kind: "chapter example"
        )
        try ChapterMetadataValidation.requireDisjoint(
            positiveFixtureIDs,
            negativeFixtureIDs,
            kind: "chapter fixture"
        )

        self.schemaVersion = schemaVersion
        self.id = id
        self.requirementID = validatedRequirementID
        self.title = title
        self.ownerRoleID = ownerRoleID
        self.rationale = rationale
        self.applicability = applicability
        self.ruleIDs = validatedRuleIDs
        self.rationaleADRIDs = validatedADRIDs
        self.compliantExampleIDs = compliantExampleIDs
        self.nonCompliantExampleIDs = nonCompliantExampleIDs
        self.checkIDs = checkIDs
        self.positiveFixtureIDs = positiveFixtureIDs
        self.negativeFixtureIDs = negativeFixtureIDs
        self.requiredEvidenceKinds = requiredEvidenceKinds
        self.reviewChecklistIDs = reviewChecklistIDs
        self.exceptionPolicy = exceptionPolicy
        self.reviewCadence = reviewCadence
        self.requiredRuleDependencies = validatedDependencies
    }

    public init(from decoder: any Decoder) throws {
        try ChapterMetadataValidation.rejectUnexpectedKeys(
            in: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: "chapter_metadata"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            id: container.decode(String.self, forKey: .id),
            requirementID: container.decode(RequirementID.self, forKey: .requirementID),
            title: container.decode(String.self, forKey: .title),
            ownerRoleID: container.decode(String.self, forKey: .ownerRoleID),
            rationale: container.decode(String.self, forKey: .rationale),
            applicability: container.decode([String].self, forKey: .applicability),
            ruleIDs: container.decode([RuleID].self, forKey: .ruleIDs),
            rationaleADRIDs: container.decode([ADRIdentifier].self, forKey: .rationaleADRIDs),
            compliantExampleIDs: container.decode([String].self, forKey: .compliantExampleIDs),
            nonCompliantExampleIDs: container.decode([String].self, forKey: .nonCompliantExampleIDs),
            checkIDs: container.decode([String].self, forKey: .checkIDs),
            positiveFixtureIDs: container.decode([String].self, forKey: .positiveFixtureIDs),
            negativeFixtureIDs: container.decode([String].self, forKey: .negativeFixtureIDs),
            requiredEvidenceKinds: container.decode([String].self, forKey: .requiredEvidenceKinds),
            reviewChecklistIDs: container.decode([String].self, forKey: .reviewChecklistIDs),
            exceptionPolicy: container.decode(String.self, forKey: .exceptionPolicy),
            reviewCadence: container.decode(String.self, forKey: .reviewCadence),
            requiredRuleDependencies: container.decode(
                [ChapterDependency].self,
                forKey: .requiredRuleDependencies
            )
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(requirementID, forKey: .requirementID)
        try container.encode(title, forKey: .title)
        try container.encode(ownerRoleID, forKey: .ownerRoleID)
        try container.encode(rationale, forKey: .rationale)
        try container.encode(applicability, forKey: .applicability)
        try container.encode(ruleIDs, forKey: .ruleIDs)
        try container.encode(rationaleADRIDs, forKey: .rationaleADRIDs)
        try container.encode(compliantExampleIDs, forKey: .compliantExampleIDs)
        try container.encode(nonCompliantExampleIDs, forKey: .nonCompliantExampleIDs)
        try container.encode(checkIDs, forKey: .checkIDs)
        try container.encode(positiveFixtureIDs, forKey: .positiveFixtureIDs)
        try container.encode(negativeFixtureIDs, forKey: .negativeFixtureIDs)
        try container.encode(requiredEvidenceKinds, forKey: .requiredEvidenceKinds)
        try container.encode(reviewChecklistIDs, forKey: .reviewChecklistIDs)
        try container.encode(exceptionPolicy, forKey: .exceptionPolicy)
        try container.encode(reviewCadence, forKey: .reviewCadence)
        try container.encode(requiredRuleDependencies, forKey: .requiredRuleDependencies)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case id
        case requirementID = "requirement_id"
        case title
        case ownerRoleID = "owner_role_id"
        case rationale
        case applicability
        case ruleIDs = "rule_ids"
        case rationaleADRIDs = "rationale_adr_ids"
        case compliantExampleIDs = "compliant_example_ids"
        case nonCompliantExampleIDs = "non_compliant_example_ids"
        case checkIDs = "check_ids"
        case positiveFixtureIDs = "positive_fixture_ids"
        case negativeFixtureIDs = "negative_fixture_ids"
        case requiredEvidenceKinds = "required_evidence_kinds"
        case reviewChecklistIDs = "review_checklist_ids"
        case exceptionPolicy = "exception_policy"
        case reviewCadence = "review_cadence"
        case requiredRuleDependencies = "required_rule_dependencies"
    }
}

private enum ChapterMetadataValidation {
    static func requireNonBlank(_ value: String, field: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed == value,
              !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else {
            throw ContractError.invalidContract(
                kind: "chapter_metadata",
                reason: "\(field) must be a non-blank canonical string"
            )
        }
    }

    static func requireComplete(_ values: [some Any], field: String) throws {
        guard !values.isEmpty else {
            throw ContractError.invalidContract(
                kind: "chapter_metadata",
                reason: "\(field) must not be empty"
            )
        }
    }

    static func validateStrings(_ values: [String], field: String) throws {
        for value in values {
            try requireNonBlank(value, field: field)
        }
        try validateUnique(values, kind: "chapter \(field)", identifier: { $0 })
    }

    static func validateUnique<Element: Hashable>(
        _ values: [Element],
        kind: String,
        identifier: (Element) -> String
    ) throws {
        var seen = Set<Element>()
        for value in values where !seen.insert(value).inserted {
            throw ContractError.duplicateIdentifier(kind: kind, id: identifier(value))
        }
    }

    static func validateDependencies(_ dependencies: [ChapterDependency]) throws {
        var ownersByRuleID: [String: String] = [:]
        for dependency in dependencies {
            let ruleID = dependency.requiredRuleID.rawValue
            if let existingOwner = ownersByRuleID[ruleID] {
                if existingOwner == dependency.expectedOwnerRoleID {
                    throw ContractError.duplicateIdentifier(kind: "chapter dependency", id: ruleID)
                }
                throw ContractError.reusedIdentifier(kind: "chapter dependency", id: ruleID)
            }
            ownersByRuleID[ruleID] = dependency.expectedOwnerRoleID
        }
    }

    static func requireConcreteIdentifiers(
        _ values: [String],
        prefix: String,
        field: String
    ) throws {
        for value in values {
            try CheckFixtureIdentifierValidation.requireConcrete(
                value,
                prefix: prefix,
                kind: "chapter_metadata",
                field: field
            )
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
        let container = try decoder.container(keyedBy: ChapterMetadataCodingKey.self)
        let unexpected = container.allKeys
            .map(\.stringValue)
            .filter { !allowed.contains($0) }
            .sorted()
        guard unexpected.isEmpty else {
            throw ContractError.unexpectedKeys(kind: kind, keys: unexpected)
        }
    }
}

private struct ChapterMetadataCodingKey: CodingKey {
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
