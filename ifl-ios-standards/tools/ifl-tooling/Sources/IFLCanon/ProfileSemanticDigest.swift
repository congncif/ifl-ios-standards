import Foundation
import IFLContracts

public enum ProfileSemanticDigest {
    static let excludedKeysV1: [String] = []

    public static func digest(_ profile: ProfileRecord) throws -> HashDigest {
        CanonicalTreeDigest.sha256(try preimage(profile))
    }

    static func preimage(_ profile: ProfileRecord) throws -> Data {
        try SemanticJSONProjection.preimage(
            of: profile,
            excludingKeys: excludedKeysV1,
            additionalFields: [:],
            kind: "profile_semantic_digest"
        )
    }
}
