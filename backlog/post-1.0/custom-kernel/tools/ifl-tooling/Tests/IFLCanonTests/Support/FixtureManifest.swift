import Foundation
import IFLContracts

struct FixtureManifest: Decodable {
    let schemaVersion: Int
    let fixtureID: String
    let baseFixture: String
    let mutations: [FixtureMutation]
    let expected: FixtureExpected

    init(from decoder: any Decoder) throws {
        try rejectFixtureUnexpectedKeys(
            from: decoder,
            allowed: FixtureManifestContract.manifestKeys,
            kind: "fixture_manifest"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == FixtureManifestContract.schemaVersion else {
            throw ContractError.unsupportedSchemaVersion(
                kind: "fixture_manifest",
                value: schemaVersion
            )
        }

        fixtureID = try container.decode(String.self, forKey: .fixtureID)
        try requireFixtureIdentifier(
            fixtureID,
            pattern: FixtureManifestContract.fixtureIDPattern,
            field: "fixture_id"
        )

        baseFixture = try container.decode(String.self, forKey: .baseFixture)
        guard baseFixture == FixtureManifestContract.baseFixture else {
            throw fixtureContract("base_fixture must be positive/minimal")
        }

        mutations = try container.decode([FixtureMutation].self, forKey: .mutations)
        guard !mutations.isEmpty else {
            throw fixtureContract("mutations must contain at least one entry")
        }
        expected = try container.decode(FixtureExpected.self, forKey: .expected)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case fixtureID = "fixture_id"
        case baseFixture = "base_fixture"
        case mutations
        case expected
    }
}

enum FixtureExpected: Decodable, Equatable {
    case contractError(code: String)
    case findings(checkIDs: [String])

    init(from decoder: any Decoder) throws {
        let probe = try decoder.container(keyedBy: FixtureCodingKey.self)
        guard let kindKey = FixtureCodingKey(stringValue: "kind"),
              probe.contains(kindKey)
        else {
            throw fixtureContract("expected.kind is required")
        }
        let kind = try probe.decode(String.self, forKey: kindKey)

        switch kind {
        case "contract_error":
            try rejectFixtureUnexpectedKeys(
                from: decoder,
                allowed: FixtureManifestContract.contractExpectedKeys,
                kind: "fixture_expected"
            )
            let container = try decoder.container(keyedBy: ContractCodingKeys.self)
            let code = try container.decode(String.self, forKey: .contractErrorCode)
            guard FixtureManifestContract.contractErrorCodes.contains(code) else {
                throw fixtureContract("unsupported contract_error_code")
            }
            self = .contractError(code: code)

        case "findings":
            try rejectFixtureUnexpectedKeys(
                from: decoder,
                allowed: FixtureManifestContract.findingsExpectedKeys,
                kind: "fixture_expected"
            )
            let container = try decoder.container(keyedBy: FindingCodingKeys.self)
            let checkIDs = try container.decode([String].self, forKey: .checkIDs)
            guard !checkIDs.isEmpty else {
                throw fixtureContract("expected findings require at least one check_id")
            }
            for checkID in checkIDs {
                try requireFixtureIdentifier(
                    checkID,
                    pattern: FixtureManifestContract.checkIDPattern,
                    field: "check_ids"
                )
            }
            guard Set(checkIDs).count == checkIDs.count else {
                throw ContractError.duplicateIdentifier(
                    kind: "fixture expected check",
                    id: checkIDs.first { value in
                        checkIDs.count(where: { $0 == value }) > 1
                    } ?? ""
                )
            }
            self = .findings(checkIDs: checkIDs)

        default:
            throw fixtureContract("expected.kind must be contract_error or findings")
        }
    }

    private enum ContractCodingKeys: String, CodingKey {
        case kind
        case contractErrorCode = "contract_error_code"
    }

    private enum FindingCodingKeys: String, CodingKey {
        case kind
        case checkIDs = "check_ids"
    }
}
