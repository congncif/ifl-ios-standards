import Foundation

public enum CanonicalJSON {
    public static func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(rfc3339String(for: date))
        }
        return try encoder.encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            guard let date = rfc3339Formatter().date(from: value) else {
                throw try DecodingError.dataCorruptedError(
                    in: decoder.singleValueContainer(),
                    debugDescription: "Expected RFC 3339 UTC date with fractional seconds"
                )
            }
            return date
        }
        return try decoder.decode(type, from: data)
    }

    public static func write(_ value: some Encodable, to url: URL) throws {
        var data = try encode(value)
        data.append(0x0A)
        try data.write(to: url, options: .atomic)
    }

    private static func rfc3339String(for date: Date) -> String {
        rfc3339Formatter().string(from: date)
    }

    private static func rfc3339Formatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}
