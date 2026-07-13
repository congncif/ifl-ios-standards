import Foundation

public enum NormativeLevel: String, Codable, CaseIterable, Hashable, Sendable {
    case must
    case mustNot = "must_not"
    case should
    case may
}

public enum RiskClass: String, Codable, CaseIterable, Hashable, Sendable {
    case low
    case medium
    case high
    case critical
}

public enum EnforcementMode: String, Codable, CaseIterable, Hashable, Sendable {
    case script
    case independentReview = "independent_review"
    case both
}

public enum RuleLifecycle: String, Codable, CaseIterable, Hashable, Sendable {
    case proposed
    case accepted
    case active
    case deprecated
    case retired
}

public struct RuleRecord: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let id: RuleID
    public let level: NormativeLevel
    public let statement: String
    public let scope: [String]
    public let profileIDs: [ProfileID]
    public let severity: FindingSeverity
    public let riskClass: RiskClass
    public let rationaleADRs: [ADRIdentifier]
    public let evidence: [String]
    public let enforcement: EnforcementMode
    public let exceptionPolicy: String
    public let lifecycle: RuleLifecycle
    public let introducedIn: String
    public let effectiveIn: String
    public let replacementID: RuleID?
    public let examplesRequired: Bool
    public let compliantExampleIDs: [String]
    public let nonCompliantExampleIDs: [String]

    public init(
        schemaVersion: Int,
        id: RuleID,
        level: NormativeLevel,
        statement: String,
        scope: [String],
        profileIDs: [ProfileID],
        severity: FindingSeverity,
        riskClass: RiskClass,
        rationaleADRs: [ADRIdentifier],
        evidence: [String],
        enforcement: EnforcementMode,
        exceptionPolicy: String,
        lifecycle: RuleLifecycle,
        introducedIn: String,
        effectiveIn: String,
        replacementID: RuleID?,
        examplesRequired: Bool,
        compliantExampleIDs: [String],
        nonCompliantExampleIDs: [String]
    ) throws {
        guard schemaVersion == 1 else {
            throw ContractError.unsupportedSchemaVersion(
                kind: "rule_record",
                value: schemaVersion
            )
        }

        let validatedID = try RuleID(validating: id.rawValue)
        let validatedProfileIDs = try profileIDs.map {
            try ProfileID(validating: $0.rawValue)
        }
        let validatedRationaleADRs = try rationaleADRs.map {
            try ADRIdentifier(validating: $0.rawValue)
        }
        let validatedReplacementID = try replacementID.map {
            try RuleID(validating: $0.rawValue)
        }

        try RuleRecordValidation.requireNonBlank(statement, field: "statement")
        try RuleRecordValidation.requireNonBlank(exceptionPolicy, field: "exception_policy")
        let introducedVersion = try RuleRecordValidation.semanticVersion(
            introducedIn,
            field: "introduced_in"
        )
        let effectiveVersion = try RuleRecordValidation.semanticVersion(
            effectiveIn,
            field: "effective_in"
        )
        guard introducedVersion <= effectiveVersion else {
            throw ContractError.invalidContract(
                kind: "rule_record",
                reason: "introduced_in must not follow effective_in by SemVer precedence"
            )
        }
        try RuleRecordValidation.requireComplete(scope, field: "scope")
        try RuleRecordValidation.requireComplete(validatedProfileIDs, field: "profile_ids")
        try RuleRecordValidation.requireComplete(validatedRationaleADRs, field: "rationale_adrs")
        try RuleRecordValidation.requireComplete(evidence, field: "evidence")

        try RuleRecordValidation.validateStrings(scope, field: "scope")
        try RuleRecordValidation.validateUnique(
            validatedProfileIDs,
            kind: "rule profile",
            identifier: \ProfileID.rawValue
        )
        try RuleRecordValidation.validateUnique(
            validatedRationaleADRs,
            kind: "rule rationale ADR",
            identifier: \ADRIdentifier.rawValue
        )
        try RuleRecordValidation.validateStrings(evidence, field: "evidence")
        try RuleRecordValidation.validateStrings(
            compliantExampleIDs,
            field: "compliant_example_ids"
        )
        try RuleRecordValidation.validateStrings(
            nonCompliantExampleIDs,
            field: "non_compliant_example_ids"
        )
        try RuleRecordValidation.requireDisjointExamples(
            compliantExampleIDs,
            nonCompliantExampleIDs
        )

        if examplesRequired {
            try RuleRecordValidation.requireComplete(
                compliantExampleIDs,
                field: "compliant_example_ids"
            )
            try RuleRecordValidation.requireComplete(
                nonCompliantExampleIDs,
                field: "non_compliant_example_ids"
            )
        }

        if validatedReplacementID == validatedID {
            throw ContractError.reusedIdentifier(
                kind: "rule replacement",
                id: validatedID.rawValue
            )
        }

        switch lifecycle {
        case .deprecated:
            guard validatedReplacementID != nil else {
                throw ContractError.invalidContract(
                    kind: "rule_record",
                    reason: "replacement_id is required for deprecated rules"
                )
            }
        case .retired:
            break
        case .proposed, .accepted, .active:
            guard validatedReplacementID == nil else {
                throw ContractError.invalidContract(
                    kind: "rule_record",
                    reason: "replacement_id is forbidden for \(lifecycle.rawValue) rules"
                )
            }
        }

        self.schemaVersion = schemaVersion
        self.id = validatedID
        self.level = level
        self.statement = statement
        self.scope = scope
        self.profileIDs = validatedProfileIDs
        self.severity = severity
        self.riskClass = riskClass
        self.rationaleADRs = validatedRationaleADRs
        self.evidence = evidence
        self.enforcement = enforcement
        self.exceptionPolicy = exceptionPolicy
        self.lifecycle = lifecycle
        self.introducedIn = introducedIn
        self.effectiveIn = effectiveIn
        self.replacementID = validatedReplacementID
        self.examplesRequired = examplesRequired
        self.compliantExampleIDs = compliantExampleIDs
        self.nonCompliantExampleIDs = nonCompliantExampleIDs
    }

    public init(from decoder: any Decoder) throws {
        try RuleRecordValidation.rejectUnexpectedKeys(
            in: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let replacementID: RuleID?
        if container.contains(.replacementID) {
            guard try !container.decodeNil(forKey: .replacementID) else {
                throw ContractError.invalidContract(
                    kind: "rule_record",
                    reason: "replacement_id must be absent rather than null"
                )
            }
            replacementID = try container.decode(RuleID.self, forKey: .replacementID)
        } else {
            replacementID = nil
        }
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            id: container.decode(RuleID.self, forKey: .id),
            level: container.decode(NormativeLevel.self, forKey: .level),
            statement: container.decode(String.self, forKey: .statement),
            scope: container.decode([String].self, forKey: .scope),
            profileIDs: container.decode([ProfileID].self, forKey: .profileIDs),
            severity: container.decode(FindingSeverity.self, forKey: .severity),
            riskClass: container.decode(RiskClass.self, forKey: .riskClass),
            rationaleADRs: container.decode([ADRIdentifier].self, forKey: .rationaleADRs),
            evidence: container.decode([String].self, forKey: .evidence),
            enforcement: container.decode(EnforcementMode.self, forKey: .enforcement),
            exceptionPolicy: container.decode(String.self, forKey: .exceptionPolicy),
            lifecycle: container.decode(RuleLifecycle.self, forKey: .lifecycle),
            introducedIn: container.decode(String.self, forKey: .introducedIn),
            effectiveIn: container.decode(String.self, forKey: .effectiveIn),
            replacementID: replacementID,
            examplesRequired: container.decode(Bool.self, forKey: .examplesRequired),
            compliantExampleIDs: container.decode(
                [String].self,
                forKey: .compliantExampleIDs
            ),
            nonCompliantExampleIDs: container.decode(
                [String].self,
                forKey: .nonCompliantExampleIDs
            )
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case id
        case level
        case statement
        case scope
        case profileIDs = "profile_ids"
        case severity
        case riskClass = "risk_class"
        case rationaleADRs = "rationale_adrs"
        case evidence
        case enforcement
        case exceptionPolicy = "exception_policy"
        case lifecycle
        case introducedIn = "introduced_in"
        case effectiveIn = "effective_in"
        case replacementID = "replacement_id"
        case examplesRequired = "examples_required"
        case compliantExampleIDs = "compliant_example_ids"
        case nonCompliantExampleIDs = "non_compliant_example_ids"
    }
}

private enum RuleRecordValidation {
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
                kind: "rule_record",
                reason: "\(field) must be non-empty, unpadded, and control-free"
            )
        }
    }

    static func semanticVersion(_ value: String, field: String) throws -> RuleSemanticVersion {
        guard let version = RuleSemanticVersion(value) else {
            throw ContractError.invalidContract(
                kind: "rule_record",
                reason: "\(field) must be an exact SemVer 2.0.0 value"
            )
        }
        return version
    }

    static func requireComplete(_ values: [some Any], field: String) throws {
        guard !values.isEmpty else {
            throw ContractError.invalidContract(
                kind: "rule_record",
                reason: "\(field) must not be empty"
            )
        }
    }

    static func validateStrings(_ values: [String], field: String) throws {
        for value in values {
            try requireNonBlank(value, field: field)
        }
        try validateUnique(values, kind: "rule \(field)", identifier: { $0 })
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

    static func requireDisjointExamples(_ compliant: [String], _ nonCompliant: [String]) throws {
        let overlap = Set(compliant).intersection(nonCompliant)
        guard let reused = overlap.sorted().first else { return }
        throw ContractError.reusedIdentifier(kind: "rule example", id: reused)
    }

    static func rejectUnexpectedKeys(in decoder: any Decoder, allowed: Set<String>) throws {
        let container = try decoder.container(keyedBy: RuleRecordCodingKey.self)
        let unexpected = container.allKeys
            .map(\.stringValue)
            .filter { !allowed.contains($0) }
            .sorted()
        guard unexpected.isEmpty else {
            throw ContractError.unexpectedKeys(kind: "rule_record", keys: unexpected)
        }
    }
}

private struct RuleSemanticVersion: Comparable {
    private struct PrereleaseIdentifier: Equatable {
        let value: String
        let isNumeric: Bool
    }

    private let major: String
    private let minor: String
    private let patch: String
    private let prerelease: [PrereleaseIdentifier]?

    init?(_ value: String) {
        let buildParts = value.split(separator: "+", omittingEmptySubsequences: false)
        guard buildParts.count <= 2 else { return nil }
        if buildParts.count == 2,
           !Self.areValidIdentifiers(buildParts[1], numericLeadingZerosAllowed: true)
        {
            return nil
        }

        let versionParts = buildParts[0].split(
            separator: "-",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        guard versionParts.count <= 2 else { return nil }

        let core = versionParts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard core.count == 3,
              core.allSatisfy(Self.isCanonicalNumericIdentifier)
        else {
            return nil
        }

        if versionParts.count == 2 {
            let rawPrerelease = versionParts[1]
            guard Self.areValidIdentifiers(
                rawPrerelease,
                numericLeadingZerosAllowed: false
            ) else {
                return nil
            }
            prerelease = rawPrerelease
                .split(separator: ".", omittingEmptySubsequences: false)
                .map {
                    PrereleaseIdentifier(
                        value: String($0),
                        isNumeric: Self.isNumericIdentifier($0)
                    )
                }
        } else {
            prerelease = nil
        }

        major = String(core[0])
        minor = String(core[1])
        patch = String(core[2])
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        for (left, right) in [
            (lhs.major, rhs.major),
            (lhs.minor, rhs.minor),
            (lhs.patch, rhs.patch),
        ] {
            if left != right {
                return numericLess(left, right)
            }
        }

        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):
            return false
        case (nil, .some):
            return false
        case (.some, nil):
            return true
        case let (.some(left), .some(right)):
            for (leftIdentifier, rightIdentifier) in zip(left, right) {
                if leftIdentifier == rightIdentifier { continue }
                switch (leftIdentifier.isNumeric, rightIdentifier.isNumeric) {
                case (true, true):
                    return numericLess(leftIdentifier.value, rightIdentifier.value)
                case (true, false):
                    return true
                case (false, true):
                    return false
                case (false, false):
                    return leftIdentifier.value < rightIdentifier.value
                }
            }
            return left.count < right.count
        }
    }

    private static func numericLess(_ lhs: String, _ rhs: String) -> Bool {
        if lhs.count != rhs.count { return lhs.count < rhs.count }
        return lhs < rhs
    }

    private static func areValidIdentifiers(
        _ value: Substring,
        numericLeadingZerosAllowed: Bool
    ) -> Bool {
        let identifiers = value.split(separator: ".", omittingEmptySubsequences: false)
        guard !identifiers.isEmpty else { return false }
        return identifiers.allSatisfy { identifier in
            guard !identifier.isEmpty,
                  identifier.utf8.allSatisfy({ byte in
                      (byte >= 48 && byte <= 57)
                          || (byte >= 65 && byte <= 90)
                          || (byte >= 97 && byte <= 122)
                          || byte == 45
                  })
            else {
                return false
            }
            return numericLeadingZerosAllowed
                || !isNumericIdentifier(identifier)
                || isCanonicalNumericIdentifier(identifier)
        }
    }

    private static func isCanonicalNumericIdentifier(_ value: Substring) -> Bool {
        isNumericIdentifier(value) && (value.count == 1 || value.utf8.first != 48)
    }

    private static func isNumericIdentifier(_ value: Substring) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { $0 >= 48 && $0 <= 57 }
    }
}

private struct RuleRecordCodingKey: CodingKey {
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
