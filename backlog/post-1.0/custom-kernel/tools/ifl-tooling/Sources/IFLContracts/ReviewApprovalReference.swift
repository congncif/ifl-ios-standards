import Foundation

struct IFLContractCodingKey: CodingKey, Hashable {
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

enum IFLCanonContractSupport {
    static let schemaVersion = 1

    static func rejectUnknownKeys(
        from decoder: any Decoder,
        allowedKeys: Set<String>,
        kind: String
    ) throws {
        let container = try decoder.container(keyedBy: IFLContractCodingKey.self)
        let unknown = container.allKeys
            .map(\.stringValue)
            .filter { !allowedKeys.contains($0) }
            .sorted(by: canonicalLess)
        guard unknown.isEmpty else {
            throw ContractError.unexpectedKeys(kind: kind, keys: unknown)
        }
    }

    static func validateSchemaVersion(_ value: Int, kind: String) throws {
        guard value == schemaVersion else {
            throw ContractError.unsupportedSchemaVersion(kind: kind, value: value)
        }
    }

    static func nonBlank(_ value: String, kind: String, field: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed == value,
              !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else {
            throw ContractError.invalidContract(kind: kind, reason: "\(field) must be a non-blank canonical string")
        }
        return value
    }

    static func exactRelativePath(_ value: String, kind: String, field: String) throws -> String {
        guard !value.contains(where: { "*?[".contains($0) }) else {
            throw ContractError.invalidContract(kind: kind, reason: "\(field) must be an exact non-wildcard path")
        }
        do {
            return try CanonicalRelativePath(validating: value).rawValue
        } catch {
            throw ContractError.invalidContract(kind: kind, reason: "\(field) must be a confined canonical relative path")
        }
    }

    static func digest(_ value: HashDigest) throws -> HashDigest {
        try HashDigest(validating: value.rawValue)
    }

    static func ruleID(_ value: RuleID) throws -> RuleID {
        try RuleID(validating: value.rawValue)
    }

    static func profileID(_ value: ProfileID) throws -> ProfileID {
        try ProfileID(validating: value.rawValue)
    }

    static func adrID(_ value: ADRIdentifier) throws -> ADRIdentifier {
        try ADRIdentifier(validating: value.rawValue)
    }

    static func requirementID(_ value: RequirementID) throws -> RequirementID {
        try RequirementID(validating: value.rawValue)
    }

    static func finiteDate(_ value: Date, kind: String, field: String) throws -> Date {
        guard value.timeIntervalSinceReferenceDate.isFinite else {
            throw ContractError.invalidContract(kind: kind, reason: "\(field) must be a finite timestamp")
        }
        return value
    }

    static func canonicalDate(_ value: Date, kind: String, field: String) throws -> Date {
        let finite = try finiteDate(value, kind: kind, field: field)
        do {
            let encoded = try CanonicalJSON.encode(finite)
            let decoded = try CanonicalJSON.decode(Date.self, from: encoded)
            guard decoded == finite else {
                throw ContractError.invalidContract(
                    kind: kind,
                    reason: "\(field) must round-trip through the canonical timestamp representation exactly"
                )
            }
        } catch let error as ContractError {
            throw error
        } catch {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "\(field) must use the canonical timestamp representation"
            )
        }
        return finite
    }

    static func decodeCanonicalDate<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        kind: String,
        field: String
    ) throws -> Date {
        let rawValue = try container.decode(String.self, forKey: key)
        do {
            let data = try CanonicalJSON.encode(rawValue)
            let decoded = try CanonicalJSON.decode(Date.self, from: data)
            let canonicalData = try CanonicalJSON.encode(decoded)
            let canonicalValue = try CanonicalJSON.decode(String.self, from: canonicalData)
            guard canonicalValue == rawValue else {
                throw ContractError.invalidContract(
                    kind: kind,
                    reason: "\(field) must use the exact canonical timestamp representation"
                )
            }
            return try canonicalDate(decoded, kind: kind, field: field)
        } catch let error as ContractError {
            throw error
        } catch {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "\(field) must use the exact canonical timestamp representation"
            )
        }
    }

    static func decodeOptionalRejectingNull<Value: Decodable, Key: CodingKey>(
        _ type: Value.Type,
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        kind: String,
        field: String
    ) throws -> Value? {
        guard container.contains(key) else { return nil }
        guard try !container.decodeNil(forKey: key) else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "\(field) must be absent rather than null when there is no before state"
            )
        }
        return try container.decode(type, forKey: key)
    }

    static func semanticVersion(_ value: String, kind: String, field: String) throws -> String {
        let validated = try nonBlank(value, kind: kind, field: field)
        let buildSplit = validated.split(separator: "+", omittingEmptySubsequences: false)
        guard buildSplit.count <= 2 else {
            throw invalidSemanticVersion(kind: kind, field: field)
        }

        let mainAndPrerelease = String(buildSplit[0])
        if buildSplit.count == 2 {
            try validateSemanticIdentifiers(
                String(buildSplit[1]),
                rejectNumericLeadingZero: false,
                kind: kind,
                field: field
            )
        }

        let prereleaseSplit = mainAndPrerelease.split(
            separator: "-",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        guard prereleaseSplit.count <= 2 else {
            throw invalidSemanticVersion(kind: kind, field: field)
        }
        if prereleaseSplit.count == 2 {
            try validateSemanticIdentifiers(
                String(prereleaseSplit[1]),
                rejectNumericLeadingZero: true,
                kind: kind,
                field: field
            )
        }

        let core = prereleaseSplit[0].split(separator: ".", omittingEmptySubsequences: false)
        guard core.count == 3,
              core.allSatisfy({
                  isASCIIDigits(String($0)) && ($0 == "0" || !$0.hasPrefix("0"))
              })
        else {
            throw invalidSemanticVersion(kind: kind, field: field)
        }
        return validated
    }

    static func canonicalSlug(_ value: String, kind: String, field: String) throws -> String {
        let validated = try nonBlank(value, kind: kind, field: field)
        let components = validated.split(separator: "-", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              components.allSatisfy({ component in
                  !component.isEmpty && component.utf8.allSatisfy {
                      ($0 >= 97 && $0 <= 122) || ($0 >= 48 && $0 <= 57)
                  }
              })
        else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "\(field) must be a lowercase ASCII hyphenated identifier"
            )
        }
        return validated
    }

    static func canonicalUppercaseIdentifier(
        _ value: String,
        prefix: String,
        kind: String,
        field: String
    ) throws -> String {
        let validated = try nonBlank(value, kind: kind, field: field)
        guard validated.hasPrefix(prefix) else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "\(field) must use the \(prefix) canonical identifier namespace"
            )
        }
        let suffix = validated.dropFirst(prefix.count)
        let components = suffix.split(separator: "-", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              components.allSatisfy({ component in
                  !component.isEmpty && component.utf8.allSatisfy {
                      ($0 >= 65 && $0 <= 90) || ($0 >= 48 && $0 <= 57)
                  }
              })
        else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "\(field) must be an uppercase ASCII hyphenated identifier"
            )
        }
        return validated
    }

    static func requireNonEmpty(_ values: [some Any], kind: String, field: String) throws {
        guard !values.isEmpty else {
            throw ContractError.invalidContract(kind: kind, reason: "\(field) must not be empty")
        }
    }

    static func requireUnique<T>(
        _ values: [T],
        kind: String,
        id: (T) -> String
    ) throws {
        var seen: Set<String> = []
        for value in values {
            let identifier = id(value)
            guard seen.insert(identifier).inserted else {
                throw ContractError.duplicateIdentifier(kind: kind, id: identifier)
            }
        }
    }

    static func canonicalLess(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }

    private static func validateSemanticIdentifiers(
        _ value: String,
        rejectNumericLeadingZero: Bool,
        kind: String,
        field: String
    ) throws {
        let identifiers = value.split(separator: ".", omittingEmptySubsequences: false)
        guard !identifiers.isEmpty,
              identifiers.allSatisfy({ identifier in
                  guard !identifier.isEmpty,
                        identifier.utf8.allSatisfy({
                            ($0 >= 48 && $0 <= 57)
                                || ($0 >= 65 && $0 <= 90)
                                || ($0 >= 97 && $0 <= 122)
                                || $0 == 45
                        })
                  else { return false }
                  if rejectNumericLeadingZero,
                     isASCIIDigits(String(identifier)),
                     identifier.count > 1,
                     identifier.hasPrefix("0")
                  {
                      return false
                  }
                  return true
              })
        else {
            throw invalidSemanticVersion(kind: kind, field: field)
        }
    }

    private static func isASCIIDigits(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { $0 >= 48 && $0 <= 57 }
    }

    private static func invalidSemanticVersion(kind: String, field: String) -> ContractError {
        ContractError.invalidContract(
            kind: kind,
            reason: "\(field) must use exact SemVer 2.0.0 syntax"
        )
    }
}

public struct ReviewApprovalReference: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let approvalID: String
    public let principalID: String
    public let actorID: String
    public let roleID: String
    public let reviewedComponentID: String
    public let reviewedComponentDigest: HashDigest
    public let attestationID: String
    public let attestationDigest: HashDigest

    public init(
        schemaVersion: Int,
        approvalID: String,
        principalID: String,
        actorID: String,
        roleID: String,
        reviewedComponentID: String,
        reviewedComponentDigest: HashDigest,
        attestationID: String,
        attestationDigest: HashDigest
    ) throws {
        let kind = "review_approval_reference"
        try IFLCanonContractSupport.validateSchemaVersion(schemaVersion, kind: kind)
        self.schemaVersion = schemaVersion
        self.approvalID = try IFLCanonContractSupport.nonBlank(approvalID, kind: kind, field: "approval_id")
        self.principalID = try IFLCanonContractSupport.nonBlank(principalID, kind: kind, field: "principal_id")
        self.actorID = try IFLCanonContractSupport.nonBlank(actorID, kind: kind, field: "actor_id")
        self.roleID = try IFLCanonContractSupport.nonBlank(roleID, kind: kind, field: "role_id")
        self.reviewedComponentID = try IFLCanonContractSupport.nonBlank(
            reviewedComponentID,
            kind: kind,
            field: "reviewed_component_id"
        )
        self.reviewedComponentDigest = try IFLCanonContractSupport.digest(reviewedComponentDigest)
        self.attestationID = try IFLCanonContractSupport.nonBlank(
            attestationID,
            kind: kind,
            field: "attestation_id"
        )
        self.attestationDigest = try IFLCanonContractSupport.digest(attestationDigest)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case approvalID = "approval_id"
        case principalID = "principal_id"
        case actorID = "actor_id"
        case roleID = "role_id"
        case reviewedComponentID = "reviewed_component_id"
        case reviewedComponentDigest = "reviewed_component_digest"
        case attestationID = "attestation_id"
        case attestationDigest = "attestation_digest"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "review_approval_reference"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            approvalID: container.decode(String.self, forKey: .approvalID),
            principalID: container.decode(String.self, forKey: .principalID),
            actorID: container.decode(String.self, forKey: .actorID),
            roleID: container.decode(String.self, forKey: .roleID),
            reviewedComponentID: container.decode(String.self, forKey: .reviewedComponentID),
            reviewedComponentDigest: container.decode(HashDigest.self, forKey: .reviewedComponentDigest),
            attestationID: container.decode(String.self, forKey: .attestationID),
            attestationDigest: container.decode(HashDigest.self, forKey: .attestationDigest)
        )
    }
}

public struct ReviewedComponentApproval: Codable, Hashable, Sendable {
    public let componentID: String
    public let componentKind: String
    public let bundleRelativePath: String
    public let bundleSchemaIdentity: ComponentBundleSchemaIdentity
    public let bundleSchemaDigest: HashDigest
    public let componentDigest: HashDigest
    public let accountableOwnerRoleID: String
    public let accountableOwnerApproval: ReviewApprovalReference
    public let independentReviewerApproval: ReviewApprovalReference

    public init(
        componentID: String,
        componentKind: String,
        bundleRelativePath: String,
        bundleSchemaIdentity: ComponentBundleSchemaIdentity,
        bundleSchemaDigest: HashDigest,
        componentDigest: HashDigest,
        accountableOwnerRoleID: String,
        accountableOwnerApproval: ReviewApprovalReference,
        independentReviewerApproval: ReviewApprovalReference
    ) throws {
        let kind = "reviewed_component_approval"
        let validatedID = try IFLCanonContractSupport.canonicalSlug(
            componentID,
            kind: kind,
            field: "component_id"
        )
        let validatedKind = try IFLCanonContractSupport.canonicalSlug(
            componentKind,
            kind: kind,
            field: "component_kind"
        )
        let validatedBundlePath = try IFLCanonContractSupport.exactRelativePath(
            bundleRelativePath,
            kind: kind,
            field: "bundle_relative_path"
        )
        guard validatedBundlePath == "components/\(validatedID).bundle.json" else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "bundle_relative_path must exactly embed component_id"
            )
        }
        let validatedBundleSchemaDigest = try IFLCanonContractSupport.digest(bundleSchemaDigest)
        guard bundleSchemaIdentity == .v1,
              validatedBundleSchemaDigest == bundleSchemaIdentity.schemaDigest
        else {
            throw ContractError.digestMismatch(
                kind: "reviewed_component_bundle_schema",
                expected: bundleSchemaIdentity.schemaDigest.rawValue,
                actual: validatedBundleSchemaDigest.rawValue
            )
        }
        let validatedDigest = try IFLCanonContractSupport.digest(componentDigest)
        let validatedOwnerRole = try IFLCanonContractSupport.nonBlank(
            accountableOwnerRoleID,
            kind: kind,
            field: "accountable_owner_role_id"
        )

        guard accountableOwnerApproval.reviewedComponentID == validatedID,
              independentReviewerApproval.reviewedComponentID == validatedID
        else {
            throw ContractError.unresolvedReference(kind: kind, id: validatedID)
        }
        guard accountableOwnerApproval.reviewedComponentDigest == validatedDigest else {
            throw ContractError.digestMismatch(
                kind: "accountable_owner_component",
                expected: validatedDigest.rawValue,
                actual: accountableOwnerApproval.reviewedComponentDigest.rawValue
            )
        }
        guard independentReviewerApproval.reviewedComponentDigest == validatedDigest else {
            throw ContractError.digestMismatch(
                kind: "independent_reviewer_component",
                expected: validatedDigest.rawValue,
                actual: independentReviewerApproval.reviewedComponentDigest.rawValue
            )
        }
        guard accountableOwnerApproval.actorID != independentReviewerApproval.actorID,
              accountableOwnerApproval.principalID != independentReviewerApproval.principalID
        else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "accountable owner and independent reviewer must have distinct actors and principals"
            )
        }
        guard accountableOwnerApproval.approvalID != independentReviewerApproval.approvalID else {
            throw ContractError.reusedIdentifier(kind: "approval", id: accountableOwnerApproval.approvalID)
        }
        guard accountableOwnerApproval.attestationID != independentReviewerApproval.attestationID else {
            throw ContractError.reusedIdentifier(kind: "attestation", id: accountableOwnerApproval.attestationID)
        }
        guard accountableOwnerApproval.roleID == validatedOwnerRole else {
            throw ContractError.unresolvedReference(
                kind: "accountable_owner_role",
                id: validatedOwnerRole
            )
        }

        self.componentID = validatedID
        self.componentKind = validatedKind
        self.bundleRelativePath = validatedBundlePath
        self.bundleSchemaIdentity = bundleSchemaIdentity
        self.bundleSchemaDigest = validatedBundleSchemaDigest
        self.componentDigest = validatedDigest
        self.accountableOwnerRoleID = validatedOwnerRole
        self.accountableOwnerApproval = accountableOwnerApproval
        self.independentReviewerApproval = independentReviewerApproval
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case componentID = "component_id"
        case componentKind = "component_kind"
        case bundleRelativePath = "bundle_relative_path"
        case bundleSchemaIdentity = "bundle_schema_identity"
        case bundleSchemaDigest = "bundle_schema_digest"
        case componentDigest = "component_digest"
        case accountableOwnerRoleID = "accountable_owner_role_id"
        case accountableOwnerApproval = "accountable_owner_approval"
        case independentReviewerApproval = "independent_reviewer_approval"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "reviewed_component_approval"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            componentID: container.decode(String.self, forKey: .componentID),
            componentKind: container.decode(String.self, forKey: .componentKind),
            bundleRelativePath: container.decode(String.self, forKey: .bundleRelativePath),
            bundleSchemaIdentity: container.decode(
                ComponentBundleSchemaIdentity.self,
                forKey: .bundleSchemaIdentity
            ),
            bundleSchemaDigest: container.decode(HashDigest.self, forKey: .bundleSchemaDigest),
            componentDigest: container.decode(HashDigest.self, forKey: .componentDigest),
            accountableOwnerRoleID: container.decode(String.self, forKey: .accountableOwnerRoleID),
            accountableOwnerApproval: container.decode(ReviewApprovalReference.self, forKey: .accountableOwnerApproval),
            independentReviewerApproval: container.decode(ReviewApprovalReference.self, forKey: .independentReviewerApproval)
        )
    }
}
