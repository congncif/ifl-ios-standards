import Foundation
import IFLContracts

public enum RuleSemanticDigest {
    static let excludedKeysV1 = ["effective_in", "lifecycle"]

    public static func digest(_ rule: RuleRecord) throws -> HashDigest {
        CanonicalTreeDigest.sha256(try preimage(rule))
    }

    static func preimage(_ rule: RuleRecord) throws -> Data {
        try SemanticJSONProjection.preimage(
            of: rule,
            excludingKeys: excludedKeysV1,
            additionalFields: [:],
            kind: "rule_semantic_digest"
        )
    }
}
