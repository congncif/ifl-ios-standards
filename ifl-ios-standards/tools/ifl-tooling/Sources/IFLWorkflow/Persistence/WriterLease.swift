import Foundation
import IFLContracts

public struct WriterLease: Codable, Hashable, Sendable {
    public let runID: RunID
    public let ownerID: String
    public let fencingToken: FencingToken
    public let issuedAt: Date
    public let expiresAt: Date

    public init(
        runID: RunID,
        ownerID: String,
        fencingToken: FencingToken,
        issuedAt: Date,
        expiresAt: Date
    ) throws {
        guard isValidatedPersistenceIdentifier(ownerID), issuedAt < expiresAt else {
            throw PersistenceError.invalidLease
        }
        _ = try Self.unixMicroseconds(for: issuedAt)
        _ = try Self.unixMicroseconds(for: expiresAt)
        self.runID = runID
        self.ownerID = ownerID
        self.fencingToken = fencingToken
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
    }

    public func validate(runID: RunID, at instant: Date) throws {
        guard self.runID == runID else { throw PersistenceError.invalidLease }
        guard instant >= issuedAt, instant < expiresAt else { throw PersistenceError.staleLease }
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.stringValue)))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let issuedAtUnixMicroseconds = try container.decode(
            Int64.self,
            forKey: .issuedAtUnixMicroseconds
        )
        let expiresAtUnixMicroseconds = try container.decode(
            Int64.self,
            forKey: .expiresAtUnixMicroseconds
        )
        let issuedAt = Date(
            timeIntervalSince1970: Double(issuedAtUnixMicroseconds) / 1_000_000
        )
        let expiresAt = Date(
            timeIntervalSince1970: Double(expiresAtUnixMicroseconds) / 1_000_000
        )
        try self.init(
            runID: container.decode(RunID.self, forKey: .runID),
            ownerID: container.decode(String.self, forKey: .ownerID),
            fencingToken: container.decode(FencingToken.self, forKey: .fencingToken),
            issuedAt: issuedAt,
            expiresAt: expiresAt
        )
        guard try Self.unixMicroseconds(for: issuedAt) == issuedAtUnixMicroseconds,
              try Self.unixMicroseconds(for: expiresAt) == expiresAtUnixMicroseconds
        else { throw PersistenceError.invalidLease }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(runID, forKey: .runID)
        try container.encode(ownerID, forKey: .ownerID)
        try container.encode(fencingToken, forKey: .fencingToken)
        try container.encode(Self.unixMicroseconds(for: issuedAt), forKey: .issuedAtUnixMicroseconds)
        try container.encode(
            Self.unixMicroseconds(for: expiresAt),
            forKey: .expiresAtUnixMicroseconds
        )
    }

    private static func unixMicroseconds(for date: Date) throws -> Int64 {
        let scaled = date.timeIntervalSince1970 * 1_000_000
        guard scaled.isFinite,
              scaled >= Double(Int64.min),
              scaled < Double(Int64.max),
              scaled.rounded(.towardZero) == scaled
        else { throw PersistenceError.invalidLease }
        let value = Int64(scaled)
        let roundTrip = Date(timeIntervalSince1970: Double(value) / 1_000_000)
        guard roundTrip == date else { throw PersistenceError.invalidLease }
        return value
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case runID = "run_id"
        case ownerID = "owner_id"
        case fencingToken = "fencing_token"
        case issuedAtUnixMicroseconds = "issued_at_unix_microseconds"
        case expiresAtUnixMicroseconds = "expires_at_unix_microseconds"
    }
}
