import Foundation

public enum CanonicalTreeError: Error, Equatable, Sendable {
    case invalidRelativePath(String)
    case nonCanonicalUnicodePath(String)
    case normalizationCollision(String)
    case invalidExclusion(String)
    case duplicateExclusion(String)
    case overlappingExclusions(String, String)
    case unmatchedExclusions([String])
    case invalidSchemaVersion(Int)
    case invalidMode(UInt32)
    case invalidEntryContent(String)
    case duplicateEntry(String)
    case entriesNotCanonical
    case exclusionsNotCanonical
    case unexpectedKeys([String])
    case explicitNull(String)
    case rootOpenFailed(Int32)
    case syscall(operation: String, path: String, errno: Int32)
    case unsupportedObject(path: String)
    case securityModeBits(path: String)
    case crossDevice(path: String)
    case hardlinkedFile(path: String)
    case objectChanged(path: String)
    case invalidUTF8Name(String)
}

public struct CanonicalRelativePath: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(validating rawValue: String) throws {
        guard !rawValue.isEmpty,
              !rawValue.hasPrefix("/"),
              !rawValue.unicodeScalars.contains(where: { scalar in
                  switch scalar.value {
                  case 0x00 ... 0x1F,
                       0x2A,
                       0x3F,
                       0x5B ... 0x5C,
                       0x7F ... 0x9F,
                       0x2028 ... 0x2029:
                      true
                  default:
                      false
                  }
              })
        else {
            throw CanonicalTreeError.invalidRelativePath(rawValue)
        }

        let components = rawValue.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty else {
            throw CanonicalTreeError.invalidRelativePath(rawValue)
        }
        for componentSlice in components {
            let component = String(componentSlice)
            guard !component.isEmpty, component != ".", component != ".." else {
                throw CanonicalTreeError.invalidRelativePath(rawValue)
            }
            guard canonicalUTF8Equal(component, component.precomposedStringWithCanonicalMapping) else {
                throw CanonicalTreeError.nonCanonicalUnicodePath(rawValue)
            }
        }
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
}

public struct CanonicalTreePolicy: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let excludedRoots: [String]

    public init(excludedRoots: [String]) throws {
        var normalized: [String] = []
        normalized.reserveCapacity(excludedRoots.count)
        for rawValue in excludedRoots {
            guard !rawValue.contains(where: { "*?[".contains($0) }) else {
                throw CanonicalTreeError.invalidExclusion(rawValue)
            }
            try normalized.append(CanonicalRelativePath(validating: rawValue).rawValue)
        }
        normalized.sort(by: canonicalUTF8Less)
        for index in normalized.indices {
            if index > normalized.startIndex {
                let previous = normalized[normalized.index(before: index)]
                let current = normalized[index]
                guard previous != current else {
                    throw CanonicalTreeError.duplicateExclusion(current)
                }
            }
        }
        for parentIndex in normalized.indices {
            for childIndex in normalized.indices where childIndex > parentIndex {
                let parent = normalized[parentIndex]
                let child = normalized[childIndex]
                if child.hasPrefix(parent + "/") {
                    throw CanonicalTreeError.overlappingExclusions(parent, child)
                }
            }
        }
        schemaVersion = Self.currentSchemaVersion
        self.excludedRoots = normalized
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case excludedRoots = "excluded_roots"
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownKeys(
            in: decoder,
            allowed: [CodingKeys.schemaVersion.rawValue, CodingKeys.excludedRoots.rawValue]
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == Self.currentSchemaVersion else {
            throw CanonicalTreeError.invalidSchemaVersion(version)
        }
        let rawRoots = try container.decode([String].self, forKey: .excludedRoots)
        let validated = try Self(excludedRoots: rawRoots)
        guard rawRoots == validated.excludedRoots else {
            throw CanonicalTreeError.exclusionsNotCanonical
        }
        self = validated
    }
}

public struct CanonicalTreeEntry: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        case directory
        case regularFile = "regular_file"
    }

    public let relativePath: String
    public let kind: Kind
    public let contentSHA256: HashDigest?
    public let mode: UInt16

    public init(
        relativePath: String,
        kind: Kind,
        contentSHA256: HashDigest?,
        mode: UInt16
    ) throws {
        let path = try CanonicalRelativePath(validating: relativePath)
        guard mode <= 0o777 else {
            throw CanonicalTreeError.invalidMode(UInt32(mode))
        }
        switch (kind, contentSHA256) {
        case (.directory, nil), (.regularFile, .some):
            break
        case (.directory, .some), (.regularFile, nil):
            throw CanonicalTreeError.invalidEntryContent(relativePath)
        }
        self.relativePath = path.rawValue
        self.kind = kind
        self.contentSHA256 = contentSHA256
        self.mode = mode
    }

    private enum CodingKeys: String, CodingKey {
        case relativePath = "relative_path"
        case kind
        case contentSHA256 = "content_sha256"
        case mode
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownKeys(
            in: decoder,
            allowed: [
                CodingKeys.relativePath.rawValue,
                CodingKeys.kind.rawValue,
                CodingKeys.contentSHA256.rawValue,
                CodingKeys.mode.rawValue,
            ]
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        let contentSHA256: HashDigest?
        switch kind {
        case .directory:
            guard !container.contains(.contentSHA256) else {
                throw CanonicalTreeError.explicitNull(CodingKeys.contentSHA256.rawValue)
            }
            contentSHA256 = nil
        case .regularFile:
            contentSHA256 = try container.decode(HashDigest.self, forKey: .contentSHA256)
        }
        try self.init(
            relativePath: container.decode(String.self, forKey: .relativePath),
            kind: kind,
            contentSHA256: contentSHA256,
            mode: container.decode(UInt16.self, forKey: .mode)
        )
    }
}

public struct CanonicalTreeInventory: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let policy: CanonicalTreePolicy
    public let rootMode: UInt16
    public let entries: [CanonicalTreeEntry]

    public init(
        policy: CanonicalTreePolicy,
        rootMode: UInt16,
        entries: [CanonicalTreeEntry]
    ) throws {
        guard rootMode <= 0o777 else {
            throw CanonicalTreeError.invalidMode(UInt32(rootMode))
        }
        let sortedEntries = entries.sorted { canonicalUTF8Less($0.relativePath, $1.relativePath) }
        for index in sortedEntries.indices where index > sortedEntries.startIndex {
            if sortedEntries[sortedEntries.index(before: index)].relativePath == sortedEntries[index].relativePath {
                throw CanonicalTreeError.duplicateEntry(sortedEntries[index].relativePath)
            }
        }
        schemaVersion = Self.currentSchemaVersion
        self.policy = policy
        self.rootMode = rootMode
        self.entries = sortedEntries
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case policy
        case rootMode = "root_mode"
        case entries
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownKeys(
            in: decoder,
            allowed: [
                CodingKeys.schemaVersion.rawValue,
                CodingKeys.policy.rawValue,
                CodingKeys.rootMode.rawValue,
                CodingKeys.entries.rawValue,
            ]
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == Self.currentSchemaVersion else {
            throw CanonicalTreeError.invalidSchemaVersion(version)
        }
        let rawEntries = try container.decode([CanonicalTreeEntry].self, forKey: .entries)
        let validated = try Self(
            policy: container.decode(CanonicalTreePolicy.self, forKey: .policy),
            rootMode: container.decode(UInt16.self, forKey: .rootMode),
            entries: rawEntries
        )
        guard rawEntries == validated.entries else {
            throw CanonicalTreeError.entriesNotCanonical
        }
        self = validated
    }
}

func canonicalUTF8Less(_ lhs: String, _ rhs: String) -> Bool {
    lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
}

func canonicalUTF8Equal(_ lhs: String, _ rhs: String) -> Bool {
    lhs.utf8.elementsEqual(rhs.utf8)
}

private struct DynamicCodingKey: CodingKey {
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

private func rejectUnknownKeys(in decoder: any Decoder, allowed: Set<String>) throws {
    let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
    let unexpected = dynamicContainer.allKeys
        .map(\.stringValue)
        .filter { !allowed.contains($0) }
        .sorted(by: canonicalUTF8Less)
    guard unexpected.isEmpty else {
        throw CanonicalTreeError.unexpectedKeys(unexpected)
    }
}
