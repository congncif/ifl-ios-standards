import Foundation
import IFLContracts

struct FixtureMutation: Decodable {
    enum Operation: String, CaseIterable, Decodable, Hashable {
        case jsonAdd = "json_add"
        case jsonReplace = "json_replace"
        case jsonRemove = "json_remove"
        case writeUTF8 = "write_utf8"
        case removeFile = "remove_file"

        var requiredKeys: Set<String> {
            switch self {
            case .jsonAdd, .jsonReplace:
                ["operation", "relative_path", "json_pointer", "value"]
            case .jsonRemove:
                ["operation", "relative_path", "json_pointer"]
            case .writeUTF8:
                ["operation", "relative_path", "utf8_content"]
            case .removeFile:
                ["operation", "relative_path"]
            }
        }
    }

    static let maximumUTF8ContentScalars = FixtureManifestContract.maximumUTF8ContentScalars

    let operation: Operation
    let relativePath: CanonicalRelativePath
    let jsonPointer: String?
    let value: FixtureJSONValue?
    let utf8Content: String?

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        operation = try container.decode(Operation.self, forKey: .operation)
        let rawRelativePath = try container.decode(String.self, forKey: .relativePath)
        guard fixturePatternMatches(
            rawRelativePath,
            pattern: FixtureManifestContract.relativePathPattern
        ) else {
            throw fixtureContract("relative_path does not match the fixture schema pattern")
        }
        relativePath = try CanonicalRelativePath(validating: rawRelativePath)

        switch operation {
        case .jsonAdd, .jsonReplace:
            try rejectFixtureUnexpectedKeys(
                from: decoder,
                allowed: operation.requiredKeys,
                kind: "fixture_mutation"
            )
            jsonPointer = try container.decode(String.self, forKey: .jsonPointer)
            _ = try decodeJSONPointer(jsonPointer ?? "")
            guard container.contains(.value) else {
                throw fixtureContract("json_add and json_replace require value")
            }
            value = try container.decode(FixtureJSONValue.self, forKey: .value)
            utf8Content = nil

        case .jsonRemove:
            try rejectFixtureUnexpectedKeys(
                from: decoder,
                allowed: operation.requiredKeys,
                kind: "fixture_mutation"
            )
            jsonPointer = try container.decode(String.self, forKey: .jsonPointer)
            _ = try decodeJSONPointer(jsonPointer ?? "")
            value = nil
            utf8Content = nil

        case .writeUTF8:
            try rejectFixtureUnexpectedKeys(
                from: decoder,
                allowed: operation.requiredKeys,
                kind: "fixture_mutation"
            )
            jsonPointer = nil
            value = nil
            utf8Content = try container.decode(String.self, forKey: .utf8Content)
            guard (utf8Content ?? "").unicodeScalars.count
                <= Self.maximumUTF8ContentScalars
            else {
                throw fixtureContract("utf8_content exceeds schema maxLength")
            }

        case .removeFile:
            try rejectFixtureUnexpectedKeys(
                from: decoder,
                allowed: operation.requiredKeys,
                kind: "fixture_mutation"
            )
            jsonPointer = nil
            value = nil
            utf8Content = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case operation
        case relativePath = "relative_path"
        case jsonPointer = "json_pointer"
        case value
        case utf8Content = "utf8_content"
    }
}

indirect enum FixtureJSONValue: Decodable, Equatable {
    case null
    case bool(Bool)
    case integer(Int64)
    case string(String)
    case array([FixtureJSONValue])
    case object([String: FixtureJSONValue])

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Int64.self) { self = .integer(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([FixtureJSONValue].self) { self = .array(value) }
        else { self = try .object(container.decode([String: FixtureJSONValue].self)) }
    }

    var foundationValue: Any {
        switch self {
        case .null: NSNull()
        case let .bool(value): value
        case let .integer(value): value
        case let .string(value): value
        case let .array(values): values.map(\.foundationValue)
        case let .object(values): values.mapValues(\.foundationValue)
        }
    }
}

func decodeJSONPointer(_ pointer: String) throws -> [String] {
    guard fixturePatternMatches(pointer, pattern: FixtureManifestContract.jsonPointerPattern) else {
        throw fixtureContract("JSON mutation pointer does not match the fixture schema pattern")
    }
    if pointer.isEmpty { return [] }
    guard pointer.first == "/" else {
        throw fixtureContract("JSON mutation pointer must be empty or start with /")
    }
    return try pointer.dropFirst().split(separator: "/", omittingEmptySubsequences: false).map {
        try decodePointerToken(String($0))
    }
}

func fixtureCanonicalJSONFileData(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.fragmentsAllowed, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0A)
    return data
}

private func decodePointerToken(_ token: String) throws -> String {
    var result = ""
    var index = token.startIndex
    while index < token.endIndex {
        if token[index] != "~" {
            result.append(token[index])
            index = token.index(after: index)
            continue
        }
        let escaped = token.index(after: index)
        guard escaped < token.endIndex else {
            throw fixtureContract("JSON mutation pointer has an invalid escape")
        }
        switch token[escaped] {
        case "0": result.append("~")
        case "1": result.append("/")
        default: throw fixtureContract("JSON mutation pointer has an invalid escape")
        }
        index = token.index(after: escaped)
    }
    return result
}
