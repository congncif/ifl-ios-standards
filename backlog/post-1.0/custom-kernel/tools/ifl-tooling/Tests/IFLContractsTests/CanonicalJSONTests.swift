import Foundation
@testable import IFLContracts
import Testing

@Suite("CanonicalJSONTests")
struct CanonicalJSONTests {
    private struct OrderingPayload: Codable {
        let z: String
        let a: String
    }

    private struct DatePayload: Codable {
        let date: Date
    }

    @Test("canonical bytes sort keys and contain no file newline")
    func sortedHashBytes() throws {
        let data = try CanonicalJSON.encode(OrderingPayload(z: "last", a: "first"))
        #expect(String(decoding: data, as: UTF8.self) == #"{"a":"first","z":"last"}"#)
        #expect(data.last != 0x0A)
    }

    @Test("dates use RFC 3339 UTC with fractional seconds")
    func dateEncoding() throws {
        let data = try CanonicalJSON.encode(DatePayload(date: Date(timeIntervalSince1970: 0.123)))
        #expect(String(decoding: data, as: UTF8.self) == #"{"date":"1970-01-01T00:00:00.123Z"}"#)
        let decoded = try CanonicalJSON.decode(DatePayload.self, from: data).date.timeIntervalSince1970
        #expect(abs(decoded - 0.123) < 0.000_001)
    }

    @Test("file output adds exactly one trailing newline")
    func fileNewline() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let output = directory.appendingPathComponent("payload.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        try CanonicalJSON.write(OrderingPayload(z: "last", a: "first"), to: output)
        let bytes = try Data(contentsOf: output)
        #expect(String(decoding: bytes, as: UTF8.self) == "{\"a\":\"first\",\"z\":\"last\"}\n")
    }
}
