import Foundation
@testable import IFLContracts
import Testing

@Suite("IdentifierTests")
struct IdentifierTests {
    @Test("stable requirement ID validates without aliasing")
    func stableRequirementID() throws {
        let identifier = try RequirementID(validating: "REQ-CONVERGENCE")
        #expect(identifier.rawValue == "REQ-CONVERGENCE")

        for invalid in ["req-convergence", "REQ_CONVERGENCE", " REQ-CONVERGENCE", "REQ--CONVERGENCE"] {
            #expect(throws: ContractError.self) {
                try RequirementID(validating: invalid)
            }
        }
    }

    @Test("other shared identifier families validate their canonical spelling")
    func otherIdentifiers() throws {
        #expect(try RuleID(validating: "UI-VIEW-001").rawValue == "UI-VIEW-001")
        #expect(try ProfileID(validating: "assurance-high-risk").rawValue == "assurance-high-risk")
        #expect(try ADRIdentifier(validating: "ADR-0007").rawValue == "ADR-0007")
        #expect(throws: ContractError.self) { try RuleID(validating: "UI-VIEW-1") }
        #expect(throws: ContractError.self) { try ProfileID(validating: "Assurance-High-Risk") }
        #expect(throws: ContractError.self) { try ADRIdentifier(validating: "ADR-7") }
    }

    @Test("RunID has one lowercase filesystem and Codable spelling")
    func runIDCanonicalRepresentation() throws {
        let uuid = try #require(UUID(uuidString: "8E0A27C1-C8EF-44CC-BF68-2927277B57F3"))
        let runID = RunID(rawValue: uuid)
        let expected = "8e0a27c1-c8ef-44cc-bf68-2927277b57f3"

        #expect(runID.filesystemComponent == expected)
        #expect(try RunID(validatingFilesystemComponent: expected) == runID)
        #expect(throws: ContractError.self) {
            try RunID(validatingFilesystemComponent: uuid.uuidString)
        }

        let encoded = try CanonicalJSON.encode(runID)
        #expect(String(decoding: encoded, as: UTF8.self) == "\"\(expected)\"")
        #expect(try CanonicalJSON.decode(RunID.self, from: encoded) == runID)
        #expect(throws: Error.self) {
            try CanonicalJSON.decode(RunID.self, from: Data("\"\(uuid.uuidString)\"".utf8))
        }
    }

    @Test("candidate generations are positive and advance without wraparound")
    func candidateGenerationContract() throws {
        #expect(throws: ContractError.self) { try CandidateGenerationID(validating: 0) }
        let first = try CandidateGenerationID(validating: 1)
        #expect(try first.next().rawValue == 2)
        let maximum = try CandidateGenerationID(validating: UInt64.max)
        #expect(throws: ContractError.self) { try maximum.next() }
    }

    @Test("SHA-256 digests require exactly 64 lowercase hexadecimal characters")
    func hashValidation() throws {
        let valid = String(repeating: "a", count: 64)
        #expect(try HashDigest(validating: valid).rawValue == valid)
        for invalid in [String(repeating: "A", count: 64), String(repeating: "a", count: 63), String(repeating: "g", count: 64)] {
            #expect(throws: ContractError.self) { try HashDigest(validating: invalid) }
        }
    }
}
