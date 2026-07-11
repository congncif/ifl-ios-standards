import Foundation

public struct FencingToken: Codable, Hashable, Comparable, Sendable {
    public let rawValue: UInt64

    public init(validating rawValue: UInt64) throws {
        guard rawValue > 0 else { throw PersistenceError.invalidLease }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(UInt64.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: FencingToken, rhs: FencingToken) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
