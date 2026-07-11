import Foundation
import IFLContracts

public enum ArtifactError: Error, Equatable, Sendable {
    case invalidSchemaVersion(Int)
    case invalidIdentifier
    case invalidScope
    case invalidDigest
    case unexpectedFields
    case invalidDependency
    case missingTraceability
    case duplicateArtifact
    case duplicateDependency
    case unknownArtifact
    case staleEndpointHash
    case cycle
    case invalidChange
    case invalidInvalidationResult
    case invalidApproval
    case invalidApprovalContext
    case invalidObligation
    case invalidIndependentRoot
    case invalidAttestation
}

public struct ArtifactID: RawRepresentable, Codable, Comparable, Hashable, Sendable {
    public let rawValue: String

    public init(validating rawValue: String) throws {
        guard Self.isValid(rawValue) else { throw ArtifactError.invalidIdentifier }
        self.rawValue = rawValue
    }

    public init?(rawValue: String) {
        guard let value = try? Self(validating: rawValue) else { return nil }
        self = value
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: ArtifactID, rhs: ArtifactID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    private static func isValid(_ value: String) -> Bool {
        guard let first = value.utf8.first,
              first >= 97,
              first <= 122,
              value.utf8.last != 45
        else { return false }

        var previousWasHyphen = false
        for byte in value.utf8 {
            let isLowercase = byte >= 97 && byte <= 122
            let isDigit = byte >= 48 && byte <= 57
            let isHyphen = byte == 45
            guard isLowercase || isDigit || isHyphen,
                  !(isHyphen && previousWasHyphen)
            else { return false }
            previousWasHyphen = isHyphen
        }
        return true
    }
}

public enum ArtifactType: String, Codable, CaseIterable, Hashable, Sendable {
    case requirement
    case design
    case architecture
    case plan
    case source
    case commandEvidence = "command_evidence"
    case canon
}

public enum ArtifactScopeKind: String, Codable, CaseIterable, Hashable, Sendable {
    case path
    case semanticSelector = "semantic_selector"
}

public struct ArtifactScope: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let kind: ArtifactScopeKind
    public let value: String

    public init(kind: ArtifactScopeKind, value: String) throws {
        switch kind {
        case .path:
            guard (try? CanonicalRelativePath(validating: value)) != nil else {
                throw ArtifactError.invalidScope
            }
        case .semanticSelector:
            guard Self.isValidSemanticSelector(value) else {
                throw ArtifactError.invalidScope
            }
        }
        schemaVersion = 1
        self.kind = kind
        self.value = value
    }

    public init(from decoder: any Decoder) throws {
        try artifactRejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == 1 else { throw ArtifactError.invalidSchemaVersion(version) }
        try self.init(
            kind: container.decode(ArtifactScopeKind.self, forKey: .kind),
            value: container.decode(String.self, forKey: .value)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case kind
        case value
    }

    public func intersects(_ other: ArtifactScope) -> Bool {
        guard kind == other.kind else { return false }
        let separator: Character = kind == .path ? "/" : "."
        let lhs = value.split(separator: separator, omittingEmptySubsequences: false)
        let rhs = other.value.split(separator: separator, omittingEmptySubsequences: false)
        let sharedCount = min(lhs.count, rhs.count)
        return lhs.prefix(sharedCount).elementsEqual(rhs.prefix(sharedCount))
    }

    private static func isValidSemanticSelector(_ value: String) -> Bool {
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard !components.isEmpty else { return false }
        return components.allSatisfy { component in
            guard let first = component.utf8.first,
                  first >= 97,
                  first <= 122,
                  component.utf8.last != 45
            else { return false }
            var previousWasHyphen = false
            for byte in component.utf8 {
                let isLowercase = byte >= 97 && byte <= 122
                let isDigit = byte >= 48 && byte <= 57
                let isHyphen = byte == 45
                guard isLowercase || isDigit || isHyphen,
                      !(isHyphen && previousWasHyphen)
                else { return false }
                previousWasHyphen = isHyphen
            }
            return true
        }
    }
}

public struct ArtifactReference: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let id: ArtifactID
    public let type: ArtifactType
    public let scope: ArtifactScope
    public let contentHash: HashDigest

    public init(
        id: ArtifactID,
        type: ArtifactType,
        scope: ArtifactScope,
        contentHash: HashDigest
    ) throws {
        self.id = try ArtifactID(validating: id.rawValue)
        self.type = type
        self.scope = try ArtifactScope(kind: scope.kind, value: scope.value)
        do {
            self.contentHash = try HashDigest(validating: contentHash.rawValue)
        } catch {
            throw ArtifactError.invalidDigest
        }
        schemaVersion = 1
    }

    public init(from decoder: any Decoder) throws {
        try artifactRejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == 1 else { throw ArtifactError.invalidSchemaVersion(version) }
        try self.init(
            id: container.decode(ArtifactID.self, forKey: .id),
            type: container.decode(ArtifactType.self, forKey: .type),
            scope: container.decode(ArtifactScope.self, forKey: .scope),
            contentHash: container.decode(HashDigest.self, forKey: .contentHash)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case id = "artifact_id"
        case type = "artifact_type"
        case scope
        case contentHash = "content_hash"
    }
}

struct ArtifactDynamicCodingKey: CodingKey {
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

func artifactRejectUnknownFields(from decoder: any Decoder, allowed: Set<String>) throws {
    let container = try decoder.container(keyedBy: ArtifactDynamicCodingKey.self)
    guard container.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
        throw ArtifactError.unexpectedFields
    }
}

func artifactIsNonBlank(_ value: String) -> Bool {
    !value.isEmpty &&
        value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
        value.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
}

func artifactDecodeCanonical<Value: Codable>(
    _ type: Value.Type,
    from bytes: Data
) throws -> Value {
    let value = try CanonicalJSON.decode(type, from: bytes)
    guard try CanonicalJSON.encode(value) == bytes else {
        throw ArtifactError.unexpectedFields
    }
    return value
}
