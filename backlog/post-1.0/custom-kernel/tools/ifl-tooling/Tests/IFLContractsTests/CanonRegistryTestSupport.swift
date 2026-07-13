import Foundation
@testable import IFLContracts

extension CanonRegistryFileTests {
    static let registryFilenames = [
        "adrs.index.json",
        "chapters.index.json",
        "derived-artifacts.index.json",
        "namespaces.v1.json",
        "profiles.index.json",
        "requirements.v1.json",
        "rules.index.json",
    ]

    var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    var canonRoot: URL {
        pluginRoot.appendingPathComponent("standards/canon")
    }

    var registryRoot: URL {
        canonRoot.appendingPathComponent("registry")
    }

    func registryData(_ filename: String) throws -> Data {
        try Data(contentsOf: registryRoot.appendingPathComponent(filename))
    }

    func canonicalFileData(_ value: some Encodable) throws -> Data {
        var data = try CanonicalJSON.encode(value)
        data.append(0x0A)
        return data
    }

    func recursiveKeys(in value: Any) -> Set<String> {
        if let object = value as? [String: Any] {
            return object.reduce(into: Set(object.keys)) { result, element in
                result.formUnion(recursiveKeys(in: element.value))
            }
        }
        if let array = value as? [Any] {
            return array.reduce(into: []) { result, element in
                result.formUnion(recursiveKeys(in: element))
            }
        }
        return []
    }
}

struct StrictRegistryCodingKey: CodingKey {
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

func rejectAdditionalKeys(
    from decoder: any Decoder,
    allowed: Set<String>
) throws {
    let container = try decoder.container(keyedBy: StrictRegistryCodingKey.self)
    let additional = container.allKeys
        .map(\.stringValue)
        .filter { !allowed.contains($0) }
        .sorted()
    guard additional.isEmpty else {
        throw DecodingError.dataCorrupted(.init(
            codingPath: decoder.codingPath,
            debugDescription: "Unexpected bootstrap registry keys: \(additional)"
        ))
    }
}
