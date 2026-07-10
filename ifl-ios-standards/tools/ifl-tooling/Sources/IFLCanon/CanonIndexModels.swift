import Foundation
import IFLContracts

struct CanonRecordIndex: Codable, Hashable {
    let schemaVersion: Int
    let id: String
    let entries: [CanonRecordIndexEntry]

    init(from decoder: any Decoder) throws {
        try CanonIndexValidation.rejectUnexpectedKeys(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: "canon_record_index"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else {
            throw ContractError.unsupportedSchemaVersion(
                kind: "canon_record_index",
                value: schemaVersion
            )
        }

        let id = try container.decode(String.self, forKey: .id)
        try CanonIndexValidation.requireNonBlank(id, kind: "canon_record_index", field: "id")
        let entries = try container.decode([CanonRecordIndexEntry].self, forKey: .entries)

        var identifiers = Set<String>()
        var paths = Set<CanonicalRelativePath>()
        for entry in entries {
            guard identifiers.insert(entry.id).inserted else {
                throw ContractError.duplicateIdentifier(kind: "canon index", id: entry.id)
            }
            guard paths.insert(entry.relativePath).inserted else {
                throw ContractError.duplicateIdentifier(
                    kind: "canon index path",
                    id: entry.relativePath.rawValue
                )
            }
        }
        let sortedIDs = entries.map(\.id).sorted(by: CanonIndexValidation.canonicalLess)
        guard entries.map(\.id) == sortedIDs else {
            throw ContractError.invalidContract(
                kind: "canon_record_index",
                reason: "entries must use canonical ID order"
            )
        }

        self.schemaVersion = schemaVersion
        self.id = id
        self.entries = entries
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case id
        case entries
    }
}

struct CanonRecordIndexEntry: Codable, Hashable {
    let id: String
    let relativePath: CanonicalRelativePath
    let recordDigest: HashDigest

    init(from decoder: any Decoder) throws {
        try CanonIndexValidation.rejectUnexpectedKeys(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: "canon_record_index_entry"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        try CanonIndexValidation.requireNonBlank(
            id,
            kind: "canon_record_index_entry",
            field: "id"
        )
        self.id = id
        relativePath = try container.decode(CanonicalRelativePath.self, forKey: .relativePath)
        recordDigest = try container.decode(HashDigest.self, forKey: .recordDigest)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case relativePath = "relative_path"
        case recordDigest = "record_digest"
    }
}

struct CanonDerivedArtifactIndex: Codable, Hashable {
    let schemaVersion: Int
    let id: String
    let entries: [DerivedRegistrationEntry]

    init(from decoder: any Decoder) throws {
        try CanonIndexValidation.rejectUnexpectedKeys(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: "canon_derived_artifact_index"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else {
            throw ContractError.unsupportedSchemaVersion(
                kind: "canon_derived_artifact_index",
                value: schemaVersion
            )
        }
        let id = try container.decode(String.self, forKey: .id)
        try CanonIndexValidation.requireNonBlank(
            id,
            kind: "canon_derived_artifact_index",
            field: "id"
        )
        let entries = try container.decode([DerivedRegistrationEntry].self, forKey: .entries)

        var indexKeys = Set<String>()
        var targetPaths = Set<String>()
        for entry in entries {
            guard indexKeys.insert(entry.indexKey).inserted else {
                throw ContractError.duplicateIdentifier(
                    kind: "derived artifact index key",
                    id: entry.indexKey
                )
            }
            guard targetPaths.insert(entry.targetPath).inserted else {
                throw ContractError.duplicateIdentifier(
                    kind: "derived artifact target path",
                    id: entry.targetPath
                )
            }
        }
        let sortedTargets = entries.map(\.targetPath).sorted(by: CanonIndexValidation.canonicalLess)
        guard entries.map(\.targetPath) == sortedTargets else {
            throw ContractError.invalidContract(
                kind: "canon_derived_artifact_index",
                reason: "entries must use canonical target_path order"
            )
        }

        self.schemaVersion = schemaVersion
        self.id = id
        self.entries = entries
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case id
        case entries
    }
}

private enum CanonIndexValidation {
    static func rejectUnexpectedKeys(
        from decoder: any Decoder,
        allowed: Set<String>,
        kind: String
    ) throws {
        let container = try decoder.container(keyedBy: CanonIndexCodingKey.self)
        let unexpected = container.allKeys
            .map(\.stringValue)
            .filter { !allowed.contains($0) }
            .sorted(by: canonicalLess)
        guard unexpected.isEmpty else {
            throw ContractError.unexpectedKeys(kind: kind, keys: unexpected)
        }
    }

    static func requireNonBlank(_ value: String, kind: String, field: String) throws {
        guard !value.isEmpty,
              value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "\(field) must be a non-blank canonical string"
            )
        }
    }

    static func canonicalLess(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }
}

private struct CanonIndexCodingKey: CodingKey {
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
