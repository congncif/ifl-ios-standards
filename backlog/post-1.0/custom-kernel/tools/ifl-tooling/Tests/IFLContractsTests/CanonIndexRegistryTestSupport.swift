import Foundation
@testable import IFLContracts

extension CanonRegistryFileTests {
    static let digestA = String(repeating: "a", count: 64)
    static let digestB = String(repeating: "b", count: 64)
    static let digestC = String(repeating: "c", count: 64)

    static let syntheticRecordIndexData = Data(
        """
        {"entries":[{"id":"CAN-AUTH-001","record_digest":"\(digestA)","relative_path":"rules/core/canon.rules.json"}],"id":"rules","schema_version":1}
        """.utf8
    )

    static let syntheticDerivedArtifactIndexData = Data(
        """
        {"entries":[{"artifact_kind":"skill","cited_adr_ids":["ADR-0001"],"cited_rule_ids":["CAN-DERIVED-001"],"file_digest":"\(digestA)","index_key":"standards.brain","source_semantic_bindings":[{"digest":"\(digestB)","source_id":"ADR-0001","source_kind":"adr"},{"digest":"\(digestC)","source_id":"CAN-DERIVED-001","source_kind":"rule"}],"target_path":"skills/brain-flow/SKILL.md"}],"id":"derived-artifacts","schema_version":1}
        """.utf8
    )

    static let indexDescriptors = [
        IndexDescriptor(filename: "adrs.index.json", id: "adrs", entryKind: .record),
        IndexDescriptor(filename: "chapters.index.json", id: "chapters", entryKind: .record),
        IndexDescriptor(filename: "derived-artifacts.index.json", id: "derived-artifacts", entryKind: .derivedArtifact),
        IndexDescriptor(filename: "profiles.index.json", id: "profiles", entryKind: .record),
        IndexDescriptor(filename: "rules.index.json", id: "rules", entryKind: .record),
    ]
}

struct IndexDescriptor {
    let filename: String
    let id: String
    let entryKind: IndexEntryKind
}

enum IndexEntryKind {
    case record
    case derivedArtifact
}

struct StrictRecordIndex: Codable, Equatable {
    let schemaVersion: Int
    let id: String
    let entries: [StrictRecordIndexEntry]

    init(from decoder: any Decoder) throws {
        try rejectAdditionalKeys(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        id = try container.decode(String.self, forKey: .id)
        entries = try container.decode([StrictRecordIndexEntry].self, forKey: .entries)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case id
        case entries
    }
}

struct StrictRecordIndexEntry: Codable, Equatable {
    let id: String
    let relativePath: CanonicalRelativePath
    let recordDigest: HashDigest

    init(from decoder: any Decoder) throws {
        try rejectAdditionalKeys(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        relativePath = try container.decode(CanonicalRelativePath.self, forKey: .relativePath)
        recordDigest = try container.decode(HashDigest.self, forKey: .recordDigest)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case relativePath = "relative_path"
        case recordDigest = "record_digest"
    }
}

struct StrictDerivedArtifactIndex: Codable, Equatable {
    let schemaVersion: Int
    let id: String
    let entries: [DerivedRegistrationEntry]

    init(from decoder: any Decoder) throws {
        try rejectAdditionalKeys(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        id = try container.decode(String.self, forKey: .id)
        entries = try container.decode([DerivedRegistrationEntry].self, forKey: .entries)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case id
        case entries
    }
}
