import Foundation

public enum ADRStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case draft
    case inReview = "in_review"
    case accepted
    case superseded
    case rejected
}

public struct ADRMetadata: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let id: ADRIdentifier
    public let title: String
    public let status: ADRStatus
    public let ownerRoleID: String
    public let decisionDate: String
    public let markdownDigest: HashDigest
    public let context: String
    public let decision: String
    public let alternatives: [String]
    public let consequences: [String]
    public let migration: [String]
    public let affectedRuleIDs: [RuleID]
    public let affectedProfileIDs: [ProfileID]
    public let verificationImpact: [String]
    public let checkIDs: [String]
    public let fixtureIDs: [String]
    public let referenceArtifactIDs: [String]
    public let migrationIDs: [String]
    public let supersedesADRIDs: [ADRIdentifier]
    public let supersededBy: ADRIdentifier?
    public let acceptedAt: Date?

    public init(
        schemaVersion: Int,
        id: ADRIdentifier,
        title: String,
        status: ADRStatus,
        ownerRoleID: String,
        decisionDate: String,
        markdownDigest: HashDigest,
        context: String,
        decision: String,
        alternatives: [String],
        consequences: [String],
        migration: [String],
        affectedRuleIDs: [RuleID],
        affectedProfileIDs: [ProfileID],
        verificationImpact: [String],
        checkIDs: [String],
        fixtureIDs: [String],
        referenceArtifactIDs: [String],
        migrationIDs: [String],
        supersedesADRIDs: [ADRIdentifier],
        supersededBy: ADRIdentifier?,
        acceptedAt: Date?
    ) throws {
        guard schemaVersion == 1 else {
            throw ContractError.unsupportedSchemaVersion(
                kind: "adr_metadata",
                value: schemaVersion
            )
        }

        let validatedID = try ADRIdentifier(validating: id.rawValue)
        let validatedMarkdownDigest = try HashDigest(validating: markdownDigest.rawValue)
        let validatedRuleIDs = try affectedRuleIDs.map {
            try RuleID(validating: $0.rawValue)
        }
        let validatedProfileIDs = try affectedProfileIDs.map {
            try ProfileID(validating: $0.rawValue)
        }
        let validatedSupersedesIDs = try supersedesADRIDs.map {
            try ADRIdentifier(validating: $0.rawValue)
        }
        let validatedSupersededBy = try supersededBy.map {
            try ADRIdentifier(validating: $0.rawValue)
        }
        let validatedAcceptedAt = try acceptedAt.map {
            try ADRMetadataValidation.validateAcceptedAt($0)
        }

        try ADRMetadataValidation.requireNonBlank(title, field: "title")
        try ADRMetadataValidation.requireNonBlank(ownerRoleID, field: "owner_role_id")
        try ADRMetadataValidation.validateDecisionDate(decisionDate)
        try ADRMetadataValidation.requireNonBlank(context, field: "context")
        try ADRMetadataValidation.requireNonBlank(decision, field: "decision")

        try ADRMetadataValidation.validateStrings(alternatives, field: "alternatives")
        try ADRMetadataValidation.validateStrings(consequences, field: "consequences")
        try ADRMetadataValidation.validateStrings(migration, field: "migration")
        try ADRMetadataValidation.validateUnique(
            validatedRuleIDs,
            kind: "ADR affected rule",
            identifier: \RuleID.rawValue
        )
        try ADRMetadataValidation.validateUnique(
            validatedProfileIDs,
            kind: "ADR affected profile",
            identifier: \ProfileID.rawValue
        )
        try ADRMetadataValidation.validateStrings(
            verificationImpact,
            field: "verification_impact"
        )
        try ADRMetadataValidation.validateStrings(checkIDs, field: "check_ids")
        try ADRMetadataValidation.validateStrings(fixtureIDs, field: "fixture_ids")
        try ADRMetadataValidation.validateStrings(
            referenceArtifactIDs,
            field: "reference_artifact_ids"
        )
        try ADRMetadataValidation.validateStrings(migrationIDs, field: "migration_ids")
        try ADRMetadataValidation.validateConcreteIdentifiers(
            checkIDs,
            prefix: "CHK-",
            field: "check_ids"
        )
        try ADRMetadataValidation.validateConcreteIdentifiers(
            fixtureIDs,
            prefix: "FIX-",
            field: "fixture_ids"
        )
        try ADRMetadataValidation.validateConcreteIdentifiers(
            migrationIDs,
            prefix: "MIG-",
            field: "migration_ids"
        )
        try ADRMetadataValidation.validateCanonicalRelativePaths(referenceArtifactIDs)
        try ADRMetadataValidation.validateUnique(
            validatedSupersedesIDs,
            kind: "ADR supersedes",
            identifier: \ADRIdentifier.rawValue
        )

        if validatedSupersedesIDs.contains(validatedID) {
            throw ContractError.reusedIdentifier(kind: "ADR supersedes", id: validatedID.rawValue)
        }
        if validatedSupersededBy == validatedID {
            throw ContractError.reusedIdentifier(kind: "ADR superseded_by", id: validatedID.rawValue)
        }
        if let validatedSupersededBy,
           validatedSupersedesIDs.contains(validatedSupersededBy)
        {
            throw ContractError.reusedIdentifier(
                kind: "ADR lifecycle",
                id: validatedSupersededBy.rawValue
            )
        }

        switch status {
        case .accepted:
            guard validatedAcceptedAt != nil else {
                throw ContractError.invalidContract(
                    kind: "adr_metadata",
                    reason: "accepted_at is required for accepted ADRs"
                )
            }
            guard validatedSupersededBy == nil else {
                throw ContractError.invalidContract(
                    kind: "adr_metadata",
                    reason: "superseded_by is forbidden for accepted ADRs"
                )
            }
            try ADRMetadataValidation.requireAtomicMapping(
                alternatives: alternatives,
                consequences: consequences,
                migration: migration,
                affectedRuleIDs: validatedRuleIDs,
                affectedProfileIDs: validatedProfileIDs,
                verificationImpact: verificationImpact,
                checkIDs: checkIDs,
                fixtureIDs: fixtureIDs,
                referenceArtifactIDs: referenceArtifactIDs,
                migrationIDs: migrationIDs
            )

        case .superseded:
            guard validatedAcceptedAt != nil else {
                throw ContractError.invalidContract(
                    kind: "adr_metadata",
                    reason: "accepted_at is required for superseded ADRs"
                )
            }
            guard validatedSupersededBy != nil else {
                throw ContractError.invalidContract(
                    kind: "adr_metadata",
                    reason: "superseded_by is required for superseded ADRs"
                )
            }
            try ADRMetadataValidation.requireAtomicMapping(
                alternatives: alternatives,
                consequences: consequences,
                migration: migration,
                affectedRuleIDs: validatedRuleIDs,
                affectedProfileIDs: validatedProfileIDs,
                verificationImpact: verificationImpact,
                checkIDs: checkIDs,
                fixtureIDs: fixtureIDs,
                referenceArtifactIDs: referenceArtifactIDs,
                migrationIDs: migrationIDs
            )

        case .draft, .inReview, .rejected:
            guard validatedAcceptedAt == nil else {
                throw ContractError.invalidContract(
                    kind: "adr_metadata",
                    reason: "accepted_at is forbidden for \(status.rawValue) ADRs"
                )
            }
            guard validatedSupersededBy == nil else {
                throw ContractError.invalidContract(
                    kind: "adr_metadata",
                    reason: "superseded_by is forbidden for \(status.rawValue) ADRs"
                )
            }
        }

        self.schemaVersion = schemaVersion
        self.id = validatedID
        self.title = title
        self.status = status
        self.ownerRoleID = ownerRoleID
        self.decisionDate = decisionDate
        self.markdownDigest = validatedMarkdownDigest
        self.context = context
        self.decision = decision
        self.alternatives = alternatives
        self.consequences = consequences
        self.migration = migration
        self.affectedRuleIDs = validatedRuleIDs
        self.affectedProfileIDs = validatedProfileIDs
        self.verificationImpact = verificationImpact
        self.checkIDs = checkIDs
        self.fixtureIDs = fixtureIDs
        self.referenceArtifactIDs = referenceArtifactIDs
        self.migrationIDs = migrationIDs
        self.supersedesADRIDs = validatedSupersedesIDs
        self.supersededBy = validatedSupersededBy
        self.acceptedAt = validatedAcceptedAt
    }

    public init(from decoder: any Decoder) throws {
        try ADRMetadataValidation.rejectUnexpectedKeys(
            in: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let supersededBy: ADRIdentifier?
        if container.contains(.supersededBy) {
            guard try !container.decodeNil(forKey: .supersededBy) else {
                throw ContractError.invalidContract(
                    kind: "adr_metadata",
                    reason: "superseded_by must be absent rather than null"
                )
            }
            supersededBy = try container.decode(ADRIdentifier.self, forKey: .supersededBy)
        } else {
            supersededBy = nil
        }

        let acceptedAt: Date?
        if container.contains(.acceptedAt) {
            guard try !container.decodeNil(forKey: .acceptedAt) else {
                throw ContractError.invalidContract(
                    kind: "adr_metadata",
                    reason: "accepted_at must be absent rather than null"
                )
            }
            acceptedAt = try ADRMetadataValidation.decodeAcceptedAt(
                container.decode(String.self, forKey: .acceptedAt)
            )
        } else {
            acceptedAt = nil
        }
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            id: container.decode(ADRIdentifier.self, forKey: .id),
            title: container.decode(String.self, forKey: .title),
            status: container.decode(ADRStatus.self, forKey: .status),
            ownerRoleID: container.decode(String.self, forKey: .ownerRoleID),
            decisionDate: container.decode(String.self, forKey: .decisionDate),
            markdownDigest: container.decode(HashDigest.self, forKey: .markdownDigest),
            context: container.decode(String.self, forKey: .context),
            decision: container.decode(String.self, forKey: .decision),
            alternatives: container.decode([String].self, forKey: .alternatives),
            consequences: container.decode([String].self, forKey: .consequences),
            migration: container.decode([String].self, forKey: .migration),
            affectedRuleIDs: container.decode([RuleID].self, forKey: .affectedRuleIDs),
            affectedProfileIDs: container.decode([ProfileID].self, forKey: .affectedProfileIDs),
            verificationImpact: container.decode([String].self, forKey: .verificationImpact),
            checkIDs: container.decode([String].self, forKey: .checkIDs),
            fixtureIDs: container.decode([String].self, forKey: .fixtureIDs),
            referenceArtifactIDs: container.decode(
                [String].self,
                forKey: .referenceArtifactIDs
            ),
            migrationIDs: container.decode([String].self, forKey: .migrationIDs),
            supersedesADRIDs: container.decode([ADRIdentifier].self, forKey: .supersedesADRIDs),
            supersededBy: supersededBy,
            acceptedAt: acceptedAt
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case id
        case title
        case status
        case ownerRoleID = "owner_role_id"
        case decisionDate = "decision_date"
        case markdownDigest = "markdown_digest"
        case context
        case decision
        case alternatives
        case consequences
        case migration
        case affectedRuleIDs = "affected_rule_ids"
        case affectedProfileIDs = "affected_profile_ids"
        case verificationImpact = "verification_impact"
        case checkIDs = "check_ids"
        case fixtureIDs = "fixture_ids"
        case referenceArtifactIDs = "reference_artifact_ids"
        case migrationIDs = "migration_ids"
        case supersedesADRIDs = "supersedes_adr_ids"
        case supersededBy = "superseded_by"
        case acceptedAt = "accepted_at"
    }
}

private enum ADRMetadataValidation {
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
                kind: "adr_metadata",
                reason: "\(field) must be non-empty, unpadded, and control-free"
            )
        }
    }

    static func requireComplete(_ values: [some Any], field: String) throws {
        guard !values.isEmpty else {
            throw ContractError.invalidContract(
                kind: "adr_metadata",
                reason: "\(field) must not be empty"
            )
        }
    }

    static func validateStrings(_ values: [String], field: String) throws {
        for value in values {
            try requireNonBlank(value, field: field)
        }
        try validateUnique(values, kind: "ADR \(field)", identifier: { $0 })
    }

    static func validateAcceptedAt(_ value: Date) throws -> Date {
        guard value.timeIntervalSinceReferenceDate.isFinite else {
            throw invalidAcceptedAt()
        }

        let data: Data
        let decoded: ADRMetadataCanonicalDate
        do {
            data = try CanonicalJSON.encode(ADRMetadataCanonicalDate(value: value))
            decoded = try CanonicalJSON.decode(ADRMetadataCanonicalDate.self, from: data)
        } catch {
            throw invalidAcceptedAt()
        }
        guard decoded.value == value else {
            throw invalidAcceptedAt()
        }
        return value
    }

    static func decodeAcceptedAt(_ rawValue: String) throws -> Date {
        do {
            let sourceBytes = try CanonicalJSON.encode(rawValue)
            let decoded = try CanonicalJSON.decode(Date.self, from: sourceBytes)
            let canonicalBytes = try CanonicalJSON.encode(decoded)
            guard sourceBytes == canonicalBytes else {
                throw invalidAcceptedAt()
            }
            return try validateAcceptedAt(decoded)
        } catch {
            throw invalidAcceptedAt()
        }
    }

    static func validateConcreteIdentifiers(
        _ values: [String],
        prefix: String,
        field: String
    ) throws {
        for value in values {
            let suffix = String(value.dropFirst(prefix.count))
            let tokens = suffix.split(separator: "-", omittingEmptySubsequences: false)
            guard value.hasPrefix(prefix),
                  !tokens.isEmpty,
                  tokens.allSatisfy({ token in
                      !token.isEmpty && token.utf8.allSatisfy { byte in
                          (byte >= 65 && byte <= 90) || (byte >= 48 && byte <= 57)
                      }
                  })
            else {
                throw ContractError.invalidContract(
                    kind: "adr_metadata",
                    reason: "\(field) contains invalid concrete identifier \(value)"
                )
            }
        }
    }

    static func validateCanonicalRelativePaths(_ values: [String]) throws {
        for value in values {
            guard !value.unicodeScalars.contains(where: { scalar in
                switch scalar.value {
                case 0x2A, 0x3F, 0x5B, 0x5D, 0x7B, 0x7D:
                    true
                default:
                    false
                }
            }) else {
                throw ContractError.invalidContract(
                    kind: "adr_metadata",
                    reason: "reference_artifact_ids contains glob path \(value)"
                )
            }
            do {
                _ = try CanonicalRelativePath(validating: value)
            } catch {
                throw ContractError.invalidContract(
                    kind: "adr_metadata",
                    reason: "reference_artifact_ids contains noncanonical path \(value)"
                )
            }
        }
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

    static func validateDecisionDate(_ value: String) throws {
        let bytes = Array(value.utf8)
        guard bytes.count == 10,
              bytes[4] == 45,
              bytes[7] == 45,
              bytes.enumerated().allSatisfy({ index, byte in
                  index == 4 || index == 7 || (byte >= 48 && byte <= 57)
              })
        else {
            throw invalidDecisionDate(value)
        }

        let year = decimalValue(bytes[0 ... 3])
        let month = decimalValue(bytes[5 ... 6])
        let day = decimalValue(bytes[8 ... 9])
        guard year > 0 else { throw invalidDecisionDate(value) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day

        guard let date = calendar.date(from: components) else {
            throw invalidDecisionDate(value)
        }
        let roundTrip = calendar.dateComponents([.year, .month, .day], from: date)
        guard roundTrip.year == year,
              roundTrip.month == month,
              roundTrip.day == day
        else {
            throw invalidDecisionDate(value)
        }
    }

    static func requireAtomicMapping(
        alternatives: [String],
        consequences: [String],
        migration: [String],
        affectedRuleIDs: [RuleID],
        affectedProfileIDs: [ProfileID],
        verificationImpact: [String],
        checkIDs: [String],
        fixtureIDs: [String],
        referenceArtifactIDs: [String],
        migrationIDs: [String]
    ) throws {
        try requireComplete(alternatives, field: "alternatives")
        try requireComplete(consequences, field: "consequences")
        try requireComplete(migration, field: "migration")
        try requireComplete(affectedRuleIDs, field: "affected_rule_ids")
        try requireComplete(affectedProfileIDs, field: "affected_profile_ids")
        try requireComplete(verificationImpact, field: "verification_impact")
        try requireComplete(checkIDs, field: "check_ids")
        try requireComplete(fixtureIDs, field: "fixture_ids")
        try requireComplete(referenceArtifactIDs, field: "reference_artifact_ids")
        try requireComplete(migrationIDs, field: "migration_ids")
    }

    static func rejectUnexpectedKeys(in decoder: any Decoder, allowed: Set<String>) throws {
        let container = try decoder.container(keyedBy: ADRMetadataCodingKey.self)
        let unexpected = container.allKeys
            .map(\.stringValue)
            .filter { !allowed.contains($0) }
            .sorted()
        guard unexpected.isEmpty else {
            throw ContractError.unexpectedKeys(kind: "adr_metadata", keys: unexpected)
        }
    }

    private static func decimalValue(_ bytes: ArraySlice<UInt8>) -> Int {
        bytes.reduce(0) { partialResult, byte in
            (partialResult * 10) + Int(byte - 48)
        }
    }

    private static func invalidDecisionDate(_ value: String) -> ContractError {
        .invalidContract(
            kind: "adr_metadata",
            reason: "decision_date must be a real calendar date in YYYY-MM-DD form: \(value)"
        )
    }

    private static func invalidAcceptedAt() -> ContractError {
        .invalidContract(
            kind: "adr_metadata",
            reason: "accepted_at must be finite and exactly representable by canonical RFC 3339"
        )
    }
}

private struct ADRMetadataCanonicalDate: Codable {
    let value: Date
}

private struct ADRMetadataCodingKey: CodingKey {
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
