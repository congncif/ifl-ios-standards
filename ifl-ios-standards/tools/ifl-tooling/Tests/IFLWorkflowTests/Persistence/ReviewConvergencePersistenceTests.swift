import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("ReviewConvergencePersistenceTests")
struct ReviewConvergencePersistenceTests {
    @Test("pending register fixture embeds production canonical wire with independent hashes")
    func pendingRegisterFixtureIsProductionWire() throws {
        let fixture = try pendingRegisterFixture()
        let rawBytes = try persistenceReviewFixtureData("pending-review-register.json")
        try expectCanonicalFixture(
            fixture,
            rawBytes: rawBytes
        )
        #expect(CanonicalTreeDigest.sha256(rawBytes).rawValue
            == "238f98400c7d42d1fb2643ac31724d4bed18118c114c691fd4918dad3680c8f8")
        #expect(CanonicalTreeDigest.sha256(fixture.registerBytes).rawValue
            == fixture.expectedRegisterSHA256)
        #expect(fixture.expectedRegisterSHA256
            == "1bb918ca833c5c4f22563b60bc14722e2a0e36bb7502cf42d4f3d4e886eeb49a")
        let register = try IssueRegister.decodeCanonical(from: fixture.registerBytes)
        #expect(try CanonicalJSON.encode(register) == fixture.registerBytes)
        #expect(register.digest.rawValue
            == "80f817a0ced415d1685d3c4f1457b530fb91dfa92f8d07c7d6962cbc5c5221d6")
        #expect(register.inventoryDigests.map(\.rawValue) == fixture.presentInventoryDigests)
        #expect(fixture.presentInventoryDigests != fixture.requiredInventoryDigests)
        #expect(fixture.schemaVersion == 1)
        #expect(fixture.fixtureKind == "pending_review_register")
        #expect(fixture.transactionID == "txn-02.4b-pending-register")
        #expect(fixture.expectedDecision == "integrity_violation")
        #expect(!(VerifiedReviewPublication.self is any Decodable.Type))
    }

    @Test("tampering canonical convergence bytes is an integrity failure on load")
    func tamperedConvergenceReceiptFailsClosed() throws {
        let fixture = try tamperedConvergenceFixture()
        let rawBytes = try persistenceReviewFixtureData("tampered-convergence-receipt.json")
        try expectCanonicalFixture(
            fixture,
            rawBytes: rawBytes
        )
        #expect(CanonicalTreeDigest.sha256(rawBytes).rawValue
            == "3e0b2b4a8bb64e3b5369073097b23d2dbd638b51430daf934ae9664e365d2bd4")
        #expect(CanonicalTreeDigest.sha256(fixture.untamperedPayloadBytes).rawValue
            == fixture.actualPayloadSHA256)
        #expect(fixture.actualPayloadSHA256
            == "6729785e6562dcf810a8e3f17428eb51cd2a2964a1094836a3168c06a1f865f3")
        #expect(fixture.actualPayloadSHA256 != fixture.claimedPayloadSHA256)
        #expect(fixture.schemaVersion == 2)
        #expect(fixture.fixtureKind == "tampered_convergence_receipt")
        #expect(fixture.expectedDecision == "integrity_violation")
        let receipt = try ConvergenceReceipt.decodeCanonical(from: fixture.untamperedPayloadBytes)
        #expect(try CanonicalJSON.encode(receipt) == fixture.untamperedPayloadBytes)
        #expect(receipt.receiptID == fixture.receiptID)
        #expect(receipt.schemaVersion == 2)
        let expectedAnchor = try HashDigest(validating: String(repeating: "a", count: 64))
        #expect(receipt.publicationAnchorEventHead == expectedAnchor)
        #expect(receipt.receiptID
            == "review-convergence-a1f724dcb328737edc3a2d90f02368490037c62bd01e1ebf08bbb754e8259858")
        let payloadObject = try JSONSerialization.jsonObject(
            with: fixture.untamperedPayloadBytes
        ) as? [String: Any]
        #expect(payloadObject?["publication_anchor_event_head"] != nil)
        #expect(payloadObject?["final_event_head"] == nil)

        let harness = try PersistenceHarness.make()
        defer { harness.remove() }
        #expect(fixture.receiptKind == "review-convergence")
        let kind = try ReceiptKind(validating: fixture.receiptKind)
        let id = try ReceiptID(validating: fixture.receiptID)
        let write = try ReceiptTableWrite(
            kind: kind,
            id: id,
            canonicalPayloadBytes: fixture.untamperedPayloadBytes
        )
        let transaction = try StateTransaction(
            id: TransactionID(rawValue: "txn-02.4b-tamper"),
            runRoot: harness.paths.runRoot,
            expectedStateDigest: nil,
            expectedEventHead: nil,
            state: harness.proposedState,
            event: harness.event,
            receiptWrites: [write]
        )
        let store = try harness.makeStore()
        _ = try store.commit(transaction, lease: harness.lease)

        let receiptURL = try harness.paths.receiptURL(kind: kind, id: id)
        try mutateCanonicalJSONObject(at: receiptURL) { object in
            object["payload_digest"] = fixture.claimedPayloadSHA256
        }
        #expect(throws: PersistenceError.integrityViolation) {
            try store.load(runID: harness.runID, from: harness.paths.runRoot)
        }
    }
}

private struct PendingReviewRegisterFixture: Codable, Equatable {
    let expectedDecision: String
    let expectedRegisterSHA256: String
    let fixtureKind: String
    let presentInventoryDigests: [String]
    let registerBytes: Data
    let requiredInventoryDigests: [String]
    let schemaVersion: Int
    let transactionID: String

    init(from decoder: any Decoder) throws {
        try rejectReviewPersistenceFixtureFields(
            decoder,
            allowed: CodingKeys.allCases.map(\.rawValue)
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        expectedDecision = try values.decode(String.self, forKey: .expectedDecision)
        expectedRegisterSHA256 = try values.decode(String.self, forKey: .expectedRegisterSHA256)
        fixtureKind = try values.decode(String.self, forKey: .fixtureKind)
        presentInventoryDigests = try values.decode([String].self, forKey: .presentInventoryDigests)
        registerBytes = Data(try values.decode(String.self, forKey: .registerBytes).utf8)
        requiredInventoryDigests = try values.decode([String].self, forKey: .requiredInventoryDigests)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        transactionID = try values.decode(String.self, forKey: .transactionID)
    }

    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(expectedDecision, forKey: .expectedDecision)
        try values.encode(expectedRegisterSHA256, forKey: .expectedRegisterSHA256)
        try values.encode(fixtureKind, forKey: .fixtureKind)
        try values.encode(presentInventoryDigests, forKey: .presentInventoryDigests)
        try values.encode(String(decoding: registerBytes, as: UTF8.self), forKey: .registerBytes)
        try values.encode(requiredInventoryDigests, forKey: .requiredInventoryDigests)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(transactionID, forKey: .transactionID)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case expectedDecision = "expected_decision"
        case expectedRegisterSHA256 = "expected_register_sha256"
        case fixtureKind = "fixture_kind"
        case presentInventoryDigests = "present_inventory_digests"
        case registerBytes = "register_bytes"
        case requiredInventoryDigests = "required_inventory_digests"
        case schemaVersion = "schema_version"
        case transactionID = "transaction_id"
    }
}

private struct TamperedConvergenceReceiptFixture: Codable, Equatable {
    let actualPayloadSHA256: String
    let claimedPayloadSHA256: String
    let expectedDecision: String
    let fixtureKind: String
    let untamperedPayloadBytes: Data
    let receiptID: String
    let receiptKind: String
    let schemaVersion: Int

    init(from decoder: any Decoder) throws {
        try rejectReviewPersistenceFixtureFields(
            decoder,
            allowed: CodingKeys.allCases.map(\.rawValue)
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        actualPayloadSHA256 = try values.decode(String.self, forKey: .actualPayloadSHA256)
        claimedPayloadSHA256 = try values.decode(String.self, forKey: .claimedPayloadSHA256)
        expectedDecision = try values.decode(String.self, forKey: .expectedDecision)
        fixtureKind = try values.decode(String.self, forKey: .fixtureKind)
        untamperedPayloadBytes = Data(
            try values.decode(String.self, forKey: .untamperedPayloadBytes).utf8
        )
        receiptID = try values.decode(String.self, forKey: .receiptID)
        receiptKind = try values.decode(String.self, forKey: .receiptKind)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
    }

    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(actualPayloadSHA256, forKey: .actualPayloadSHA256)
        try values.encode(claimedPayloadSHA256, forKey: .claimedPayloadSHA256)
        try values.encode(expectedDecision, forKey: .expectedDecision)
        try values.encode(fixtureKind, forKey: .fixtureKind)
        try values.encode(
            String(decoding: untamperedPayloadBytes, as: UTF8.self),
            forKey: .untamperedPayloadBytes
        )
        try values.encode(receiptID, forKey: .receiptID)
        try values.encode(receiptKind, forKey: .receiptKind)
        try values.encode(schemaVersion, forKey: .schemaVersion)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case actualPayloadSHA256 = "actual_payload_sha256"
        case claimedPayloadSHA256 = "claimed_payload_sha256"
        case expectedDecision = "expected_decision"
        case fixtureKind = "fixture_kind"
        case untamperedPayloadBytes = "untampered_payload_bytes"
        case receiptID = "receipt_id"
        case receiptKind = "receipt_kind"
        case schemaVersion = "schema_version"
    }
}

private func pendingRegisterFixture() throws -> PendingReviewRegisterFixture {
    try CanonicalJSON.decode(
        PendingReviewRegisterFixture.self,
        from: persistenceReviewFixtureData("pending-review-register.json")
    )
}

private func tamperedConvergenceFixture() throws -> TamperedConvergenceReceiptFixture {
    try CanonicalJSON.decode(
        TamperedConvergenceReceiptFixture.self,
        from: persistenceReviewFixtureData("tampered-convergence-receipt.json")
    )
}

private func expectCanonicalFixture<Value: Codable & Equatable>(
    _ fixture: Value,
    rawBytes: Data
) throws {
    var canonical = try CanonicalJSON.encode(fixture)
    canonical.append(0x0A)
    #expect(rawBytes == canonical)
    #expect(rawBytes.last == 0x0A)
    #expect(!rawBytes.dropLast().contains(0x0A))
}

private func persistenceReviewFixtureData(_ filename: String) throws -> Data {
    var root = URL(fileURLWithPath: #filePath)
    while root.lastPathComponent != "ifl-ios-standards", root.path != "/" {
        root.deleteLastPathComponent()
    }
    return try Data(
        contentsOf: root
            .appendingPathComponent("verification/fixtures/workflow/persistence")
            .appendingPathComponent(filename)
    )
}

private struct ReviewPersistenceFixtureCodingKey: CodingKey {
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

private func rejectReviewPersistenceFixtureFields(
    _ decoder: any Decoder,
    allowed: [String]
) throws {
    let values = try decoder.container(keyedBy: ReviewPersistenceFixtureCodingKey.self)
    guard values.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "unexpected review persistence fixture field"
            )
        )
    }
}
