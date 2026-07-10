import Foundation

public enum ContractError: Error, Equatable, Sendable {
    case invalidIdentifier(kind: String, value: String)
    case invalidRunIDFilesystemComponent(String)
    case invalidCandidateGeneration(UInt64)
    case candidateGenerationOverflow
    case invalidSHA256(String)
}

extension ContractError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .invalidIdentifier(kind, value):
            "Invalid \(kind) identifier: \(value)"
        case let .invalidRunIDFilesystemComponent(value):
            "Invalid RunID filesystem component: \(value)"
        case let .invalidCandidateGeneration(value):
            "Candidate generation must be positive: \(value)"
        case .candidateGenerationOverflow:
            "Candidate generation cannot advance beyond UInt64.max"
        case let .invalidSHA256(value):
            "Invalid lowercase SHA-256 digest: \(value)"
        }
    }
}

public struct RequirementID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(validating rawValue: String) throws {
        guard Self.isValid(rawValue) else {
            throw ContractError.invalidIdentifier(kind: "requirement", value: rawValue)
        }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static func isValid(_ value: String) -> Bool {
        guard value.hasPrefix("REQ-") else { return false }
        return ASCIIIdentifier.isUppercaseHyphenated(String(value.dropFirst(4)))
    }
}

public struct RuleID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(validating rawValue: String) throws {
        let components = rawValue.split(separator: "-", omittingEmptySubsequences: false)
        guard components.count >= 3,
              components.dropLast().allSatisfy({ ASCIIIdentifier.isUppercaseToken(String($0)) }),
              components.last?.count == 3,
              components.last?.allSatisfy({ $0.isASCII && $0.isNumber }) == true
        else {
            throw ContractError.invalidIdentifier(kind: "rule", value: rawValue)
        }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct ProfileID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(validating rawValue: String) throws {
        guard ASCIIIdentifier.isLowercaseHyphenated(rawValue) else {
            throw ContractError.invalidIdentifier(kind: "profile", value: rawValue)
        }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct ADRIdentifier: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(validating rawValue: String) throws {
        let suffix = rawValue.dropFirst(4)
        guard rawValue.hasPrefix("ADR-"),
              suffix.count == 4,
              suffix.allSatisfy({ $0.isASCII && $0.isNumber })
        else {
            throw ContractError.invalidIdentifier(kind: "ADR", value: rawValue)
        }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct RunID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    public init(validatingFilesystemComponent value: String) throws {
        guard value.count == 36,
              value == value.lowercased(),
              let uuid = UUID(uuidString: value),
              uuid.uuidString.lowercased() == value
        else {
            throw ContractError.invalidRunIDFilesystemComponent(value)
        }
        rawValue = uuid
    }

    public var filesystemComponent: String {
        rawValue.uuidString.lowercased()
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validatingFilesystemComponent: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(filesystemComponent)
    }
}

public struct CandidateGenerationID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: UInt64

    public init(validating rawValue: UInt64) throws {
        guard rawValue > 0 else {
            throw ContractError.invalidCandidateGeneration(rawValue)
        }
        self.rawValue = rawValue
    }

    public init?(rawValue: UInt64) {
        guard rawValue > 0 else { return nil }
        self.rawValue = rawValue
    }

    public func next() throws -> CandidateGenerationID {
        guard rawValue < UInt64.max else {
            throw ContractError.candidateGenerationOverflow
        }
        return try CandidateGenerationID(validating: rawValue + 1)
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(UInt64.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct HashDigest: Codable, Hashable, Sendable {
    public let rawValue: String

    public init(validating rawValue: String) throws {
        let allowed = CharacterSet(charactersIn: "0123456789abcdef")
        guard rawValue.count == 64,
              rawValue.unicodeScalars.allSatisfy(allowed.contains)
        else { throw ContractError.invalidSHA256(rawValue) }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    init(uncheckedLowercaseSHA256 rawValue: String) {
        self.rawValue = rawValue
    }
}

private enum ASCIIIdentifier {
    static func isUppercaseHyphenated(_ value: String) -> Bool {
        let tokens = value.split(separator: "-", omittingEmptySubsequences: false)
        return !tokens.isEmpty && tokens.allSatisfy { isUppercaseToken(String($0)) }
    }

    static func isUppercaseToken(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { byte in
            (byte >= 65 && byte <= 90) || (byte >= 48 && byte <= 57)
        }
    }

    static func isLowercaseHyphenated(_ value: String) -> Bool {
        let tokens = value.split(separator: "-", omittingEmptySubsequences: false)
        return !tokens.isEmpty && tokens.allSatisfy { token in
            guard let first = token.utf8.first, first >= 97, first <= 122 else { return false }
            return token.utf8.allSatisfy { byte in
                (byte >= 97 && byte <= 122) || (byte >= 48 && byte <= 57)
            }
        }
    }
}
