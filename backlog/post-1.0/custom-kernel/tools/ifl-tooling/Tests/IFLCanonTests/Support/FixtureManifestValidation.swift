import Foundation
import IFLContracts

enum FixtureManifestContract {
    static let schemaVersion = 1
    static let baseFixture = "positive/minimal"
    static let maximumUTF8ContentScalars = 1_048_576

    static let manifestKeys: Set<String> = [
        "schema_version",
        "fixture_id",
        "base_fixture",
        "mutations",
        "expected",
    ]
    static let contractExpectedKeys: Set<String> = ["kind", "contract_error_code"]
    static let findingsExpectedKeys: Set<String> = ["kind", "check_ids"]
    static let contractErrorCodes: Set<String> = [
        "candidate_generation_overflow",
        "digest_mismatch",
        "duplicate_identifier",
        "invalid_candidate_generation",
        "invalid_canon_version",
        "invalid_contract",
        "invalid_identifier",
        "invalid_run_id_filesystem_component",
        "invalid_sha256",
        "reused_identifier",
        "unexpected_keys",
        "unresolved_reference",
        "unsupported_schema_version",
    ]
    static let jsonValueTypes: Set<String> = [
        "array",
        "boolean",
        "integer",
        "null",
        "object",
        "string",
    ]

    static let fixtureIDPattern = #"^FIX-[A-Z0-9]+(?:-[A-Z0-9]+)*(?![\s\S])"#
    static let checkIDPattern = #"^CHK-[A-Z0-9]+(?:-[A-Z0-9]+)*(?![\s\S])"#
    static let jsonPointerPattern = #"^(?:/(?:[^~/]|~0|~1)*)*(?![\s\S])"#
    static let relativePathPattern = #"^(?!/)(?!\.{1,2}(?:/|$))[^/\\*?\[\u0000-\u001F\u007F-\u009F\u2028\u2029]+(?:/(?!\.{1,2}(?:/|$))[^/\\*?\[\u0000-\u001F\u007F-\u009F\u2028\u2029]+)*(?![\s\S])"#
}

func requireFixtureIdentifier(
    _ value: String,
    pattern: String,
    field: String
) throws {
    guard fixturePatternMatches(value, pattern: pattern) else {
        throw fixtureContract("\(field) must use uppercase ASCII hyphenated tokens")
    }
}

func fixturePatternMatches(_ value: String, pattern: String) -> Bool {
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
    let range = NSRange(value.startIndex ..< value.endIndex, in: value)
    return expression.firstMatch(in: value, range: range)?.range == range
}

func rejectFixtureUnexpectedKeys(
    from decoder: any Decoder,
    allowed: Set<String>,
    kind: String
) throws {
    let container = try decoder.container(keyedBy: FixtureCodingKey.self)
    let unexpected = container.allKeys.map(\.stringValue).filter { !allowed.contains($0) }
    guard unexpected.isEmpty else {
        throw ContractError.unexpectedKeys(kind: kind, keys: unexpected.sorted())
    }
}

func fixtureContract(_ reason: String) -> ContractError {
    .invalidContract(kind: "fixture_manifest", reason: reason)
}

struct FixtureCodingKey: CodingKey {
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
