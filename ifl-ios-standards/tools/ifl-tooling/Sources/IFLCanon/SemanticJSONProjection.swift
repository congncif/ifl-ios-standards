import Foundation
import IFLContracts

enum SemanticJSONProjection {
    static func preimage(
        of value: some Encodable,
        excludingKeys: [String],
        additionalFields: [String: Any],
        kind: String
    ) throws -> Data {
        do {
            let encoded = try CanonicalJSON.encode(value)
            let decoded = try JSONSerialization.jsonObject(with: encoded)
            guard var object = decoded as? [String: Any] else {
                throw ContractError.invalidContract(
                    kind: kind,
                    reason: "canonical record must encode as a JSON object"
                )
            }

            for key in excludingKeys {
                object.removeValue(forKey: key)
            }
            for key in additionalFields.keys.sorted() {
                guard object[key] == nil else {
                    throw ContractError.invalidContract(
                        kind: kind,
                        reason: "additional semantic field collides with record property: \(key)"
                    )
                }
                object[key] = additionalFields[key]
            }

            return try JSONSerialization.data(
                withJSONObject: object,
                options: [.sortedKeys, .withoutEscapingSlashes]
            )
        } catch let error as ContractError {
            throw error
        } catch {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "canonical semantic preimage cannot be derived"
            )
        }
    }
}
