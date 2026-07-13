import Foundation

public struct ProfileRecord: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let id: ProfileID
    public let displayName: String
    public let description: String
    public let ownerRoleID: String
    public let applicability: [String]
    public let inheritsProfileIDs: [ProfileID]
    public let ruleIDs: [RuleID]

    public init(
        schemaVersion: Int,
        id: ProfileID,
        displayName: String,
        description: String,
        ownerRoleID: String,
        applicability: [String],
        inheritsProfileIDs: [ProfileID],
        ruleIDs: [RuleID]
    ) throws {
        guard schemaVersion == 1 else {
            throw ContractError.unsupportedSchemaVersion(
                kind: "profile_record",
                value: schemaVersion
            )
        }

        let validatedID = try ProfileID(validating: id.rawValue)
        let validatedInheritedIDs = try inheritsProfileIDs.map {
            try ProfileID(validating: $0.rawValue)
        }
        let validatedRuleIDs = try Self.validating(ruleIDs: ruleIDs)

        try ProfileRecordValidation.requireNonBlank(displayName, field: "display_name")
        try ProfileRecordValidation.requireNonBlank(description, field: "description")
        try ProfileRecordValidation.requireNonBlank(ownerRoleID, field: "owner_role_id")
        try ProfileRecordValidation.requireComplete(applicability, field: "applicability")
        try ProfileRecordValidation.validateStrings(applicability, field: "applicability")
        try ProfileRecordValidation.validateUnique(
            validatedInheritedIDs,
            kind: "profile inheritance",
            identifier: \ProfileID.rawValue
        )

        if validatedInheritedIDs.contains(validatedID) {
            throw ContractError.reusedIdentifier(
                kind: "profile inheritance",
                id: validatedID.rawValue
            )
        }

        self.schemaVersion = schemaVersion
        self.id = validatedID
        self.displayName = displayName
        self.description = description
        self.ownerRoleID = ownerRoleID
        self.applicability = applicability
        self.inheritsProfileIDs = validatedInheritedIDs
        self.ruleIDs = validatedRuleIDs
    }

    public static func validating(ruleIDs: [RuleID]) throws -> [RuleID] {
        try ProfileRecordValidation.requireComplete(ruleIDs, field: "rule_ids")
        let validated = try ruleIDs.map { try RuleID(validating: $0.rawValue) }
        try ProfileRecordValidation.validateUnique(
            validated,
            kind: "profile rule",
            identifier: \RuleID.rawValue
        )
        return validated
    }

    public init(from decoder: any Decoder) throws {
        try ProfileRecordValidation.rejectUnexpectedKeys(
            in: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            id: container.decode(ProfileID.self, forKey: .id),
            displayName: container.decode(String.self, forKey: .displayName),
            description: container.decode(String.self, forKey: .description),
            ownerRoleID: container.decode(String.self, forKey: .ownerRoleID),
            applicability: container.decode([String].self, forKey: .applicability),
            inheritsProfileIDs: container.decode([ProfileID].self, forKey: .inheritsProfileIDs),
            ruleIDs: container.decode([RuleID].self, forKey: .ruleIDs)
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case id
        case displayName = "display_name"
        case description
        case ownerRoleID = "owner_role_id"
        case applicability
        case inheritsProfileIDs = "inherits_profile_ids"
        case ruleIDs = "rule_ids"
    }
}

private enum ProfileRecordValidation {
    static func requireNonBlank(_ value: String, field: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasControlCharacter = value.unicodeScalars.contains {
            CharacterSet.controlCharacters.contains($0)
        }
        guard !value.isEmpty,
              value == trimmed,
              !hasControlCharacter
        else {
            throw ContractError.invalidContract(
                kind: "profile_record",
                reason: "\(field) must be non-empty, unpadded, and control-free"
            )
        }
    }

    static func requireComplete(_ values: [some Any], field: String) throws {
        guard !values.isEmpty else {
            throw ContractError.invalidContract(
                kind: "profile_record",
                reason: "\(field) must not be empty"
            )
        }
    }

    static func validateStrings(_ values: [String], field: String) throws {
        for value in values {
            try requireNonBlank(value, field: field)
        }
        try validateUnique(values, kind: "profile \(field)", identifier: { $0 })
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

    static func rejectUnexpectedKeys(in decoder: any Decoder, allowed: Set<String>) throws {
        let container = try decoder.container(keyedBy: ProfileRecordCodingKey.self)
        let unexpected = container.allKeys
            .map(\.stringValue)
            .filter { !allowed.contains($0) }
            .sorted()
        guard unexpected.isEmpty else {
            throw ContractError.unexpectedKeys(kind: "profile_record", keys: unexpected)
        }
    }
}

private struct ProfileRecordCodingKey: CodingKey {
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
