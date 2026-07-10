import Foundation

public enum ChapterDependencyResolution: Hashable, Sendable {
    case candidatePending
    case resolved
}

public enum ChapterDependencyContext: Sendable {
    case candidate(
        activeRuleOwners: [RuleID: String],
        declaredRuleOwners: [RuleID: String]
    )
    case production(activeRuleOwners: [RuleID: String])
}

public struct ChapterDependency: Codable, Hashable, Sendable {
    public let requiredRuleID: RuleID
    public let expectedOwnerRoleID: String

    public init(
        requiredRuleID: RuleID,
        expectedOwnerRoleID: String
    ) throws {
        self.requiredRuleID = try RuleID(validating: requiredRuleID.rawValue)
        try ChapterDependencyValidation.requireNonBlank(
            expectedOwnerRoleID,
            field: "expected_owner_role_id"
        )
        self.expectedOwnerRoleID = expectedOwnerRoleID
    }

    public func resolve(in context: ChapterDependencyContext) throws -> ChapterDependencyResolution {
        switch context {
        case let .candidate(activeRuleOwners, declaredRuleOwners):
            if let activeOwnerRoleID = activeRuleOwners[requiredRuleID] {
                try validate(ownerRoleID: activeOwnerRoleID, source: "active rule")
                if let declaredOwnerRoleID = declaredRuleOwners[requiredRuleID] {
                    try validate(ownerRoleID: declaredOwnerRoleID, source: "candidate declaration")
                }
                return .resolved
            }

            guard let declaredOwnerRoleID = declaredRuleOwners[requiredRuleID] else {
                throw ContractError.unresolvedReference(
                    kind: "candidate chapter dependency",
                    id: requiredRuleID.rawValue
                )
            }
            try validate(ownerRoleID: declaredOwnerRoleID, source: "candidate declaration")
            return .candidatePending

        case let .production(activeRuleOwners):
            guard let activeOwnerRoleID = activeRuleOwners[requiredRuleID] else {
                throw ContractError.unresolvedReference(
                    kind: "production chapter dependency",
                    id: requiredRuleID.rawValue
                )
            }
            try validate(ownerRoleID: activeOwnerRoleID, source: "active rule")
            return .resolved
        }
    }

    public init(from decoder: any Decoder) throws {
        try ChapterDependencyValidation.rejectUnexpectedKeys(
            in: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: "chapter_dependency"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            requiredRuleID: container.decode(RuleID.self, forKey: .requiredRuleID),
            expectedOwnerRoleID: container.decode(String.self, forKey: .expectedOwnerRoleID)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(requiredRuleID, forKey: .requiredRuleID)
        try container.encode(expectedOwnerRoleID, forKey: .expectedOwnerRoleID)
    }

    private func validate(ownerRoleID: String, source: String) throws {
        guard ownerRoleID == expectedOwnerRoleID else {
            throw ContractError.invalidContract(
                kind: "chapter_dependency",
                reason: "\(source) owner for \(requiredRuleID.rawValue) is \(ownerRoleID); expected \(expectedOwnerRoleID)"
            )
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case requiredRuleID = "required_rule_id"
        case expectedOwnerRoleID = "expected_owner_role_id"
    }
}

private enum ChapterDependencyValidation {
    static func requireNonBlank(_ value: String, field: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed == value,
              !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else {
            throw ContractError.invalidContract(
                kind: "chapter_dependency",
                reason: "\(field) must be a non-blank canonical string"
            )
        }
    }

    static func rejectUnexpectedKeys(
        in decoder: any Decoder,
        allowed: Set<String>,
        kind: String
    ) throws {
        let container = try decoder.container(keyedBy: ChapterDependencyCodingKey.self)
        let unexpected = container.allKeys
            .map(\.stringValue)
            .filter { !allowed.contains($0) }
            .sorted()
        guard unexpected.isEmpty else {
            throw ContractError.unexpectedKeys(kind: kind, keys: unexpected)
        }
    }
}

private struct ChapterDependencyCodingKey: CodingKey {
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
