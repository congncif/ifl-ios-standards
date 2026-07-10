import Foundation
@testable import IFLContracts

struct FixtureRecordIndex: Decodable {
    let schemaVersion: Int
    let id: String
    let entries: [FixtureRecordIndexEntry]

    init(from decoder: any Decoder) throws {
        try fixtureRejectAdditionalKeys(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else {
            throw ContractError.unsupportedSchemaVersion(kind: "record_index", value: schemaVersion)
        }
        id = try container.decode(String.self, forKey: .id)
        entries = try container.decode([FixtureRecordIndexEntry].self, forKey: .entries)

        var seen = Set<String>()
        for entry in entries where !seen.insert(entry.id).inserted {
            throw ContractError.duplicateIdentifier(kind: "record index", id: entry.id)
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case id
        case entries
    }
}

struct FixtureRecordIndexEntry: Decodable {
    let id: String
    let relativePath: CanonicalRelativePath
    let recordDigest: HashDigest

    init(from decoder: any Decoder) throws {
        try fixtureRejectAdditionalKeys(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
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

func fixturePluginRoot(filePath: String = #filePath) -> URL {
    URL(fileURLWithPath: filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

func fixtureCanonicalFileData(_ value: some Encodable) throws -> Data {
    var data = try CanonicalJSON.encode(value)
    data.append(0x0A)
    return data
}

func fixtureCanonicalJSONObjectData(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0A)
    return data
}

func fixtureContractError(_ body: () throws -> Void) -> ContractError? {
    do {
        try body()
        return nil
    } catch let error as ContractError {
        return error
    } catch {
        return nil
    }
}

func fixtureCanonicalTreeInventory(at root: URL) throws -> CanonicalTreeInventory {
    try CanonicalTreeScanner().scan(
        root: root,
        policy: CanonicalTreePolicy(excludedRoots: [])
    )
}

func fixtureIdentifier(_ identifier: String, belongsToRuleID ruleID: String) -> Bool {
    let prefix = "FIX-\(ruleID)-"
    guard !ruleID.isEmpty, identifier.hasPrefix(prefix) else { return false }

    let disposition = identifier.dropFirst(prefix.count)
    if disposition == "PASS" {
        return true
    }
    guard disposition.hasPrefix("FAIL-") else { return false }

    let ordinal = disposition.dropFirst("FAIL-".count)
    return ordinal.utf8.count == 3 && ordinal.utf8.allSatisfy { byte in
        byte >= 0x30 && byte <= 0x39
    }
}

private func fixtureRejectAdditionalKeys(
    from decoder: any Decoder,
    allowed: Set<String>
) throws {
    let container = try decoder.container(keyedBy: FixtureCodingKey.self)
    let unexpected = container.allKeys.map(\.stringValue).filter { !allowed.contains($0) }
    guard unexpected.isEmpty else {
        throw ContractError.unexpectedKeys(kind: "record_index", keys: unexpected.sorted())
    }
}

private struct FixtureCodingKey: CodingKey {
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
