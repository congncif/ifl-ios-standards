import CryptoKit
import Foundation

public enum CanonicalTreeDigest {
    public static func digest(_ inventory: CanonicalTreeInventory) throws -> HashDigest {
        try sha256(CanonicalJSON.encode(inventory))
    }

    public static func sha256(_ data: Data) -> HashDigest {
        let digest = SHA256.hash(data: data)
        return HashDigest(uncheckedLowercaseSHA256: lowercaseHex(digest))
    }

    static func lowercaseHex(_ bytes: some Sequence<UInt8>) -> String {
        let alphabet: [UInt8] = Array("0123456789abcdef".utf8)
        var output: [UInt8] = []
        output.reserveCapacity(64)
        for byte in bytes {
            output.append(alphabet[Int(byte >> 4)])
            output.append(alphabet[Int(byte & 0x0F)])
        }
        return String(decoding: output, as: UTF8.self)
    }
}
