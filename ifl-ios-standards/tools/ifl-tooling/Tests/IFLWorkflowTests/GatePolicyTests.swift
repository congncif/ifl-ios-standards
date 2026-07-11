import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("GatePolicyTests")
struct GatePolicyTests {
    @Test("RC-01 substantive gate aggregation is nonempty and fail-closed")
    func substantiveGateAggregation() throws {
        #expect(throws: WorkflowPolicyError.missingSubstantiveVerdict) {
            try GatePolicy.aggregate([])
        }
        #expect(try GatePolicy.aggregate([.approved]).verdict == .approved)
        #expect(
            try GatePolicy.aggregate([.approved, .changesRequired]).verdict == .changesRequired
        )
        #expect(
            try GatePolicy.aggregate([.approved, .changesRequired, .userInputRequired]).verdict
                == .userInputRequired
        )
        #expect(
            try GatePolicy.aggregate([
                .approved, .changesRequired, .userInputRequired, .blocked,
            ]).verdict == .blocked
        )
    }

    @Test("RC-04 gate verdicts use uppercase canonical wire values only")
    func gateVerdictWireValues() throws {
        let values: [(GateVerdict, String)] = [
            (.approved, "APPROVED"),
            (.changesRequired, "CHANGES_REQUIRED"),
            (.userInputRequired, "USER_INPUT_REQUIRED"),
            (.blocked, "BLOCKED"),
        ]
        for (value, wire) in values {
            let bytes = try CanonicalJSON.encode(value)
            #expect(String(decoding: bytes, as: UTF8.self) == "\"\(wire)\"")
            #expect(try CanonicalJSON.decode(GateVerdict.self, from: bytes) == value)
            #expect(throws: Error.self) {
                try CanonicalJSON.decode(
                    GateVerdict.self,
                    from: Data("\"\(wire.lowercased())\"".utf8)
                )
            }
        }
    }

    @Test("status classification is deterministic and preserves validated root cause")
    func deterministicStatusClassification() throws {
        #expect(try GatePolicy.classify(.userDecisionRequired).resolution == .waitForUser)
        #expect(try GatePolicy.classify(.missingHumanAuthority).resolution == .waitForUser)
        #expect(try GatePolicy.classify(.externalPrerequisite).resolution == .block)
        let fixable = try GatePolicy.classify(.fixableFinding(rootCause: .architecture))
        #expect(fixable.status == .changesRequired)
        #expect(fixable.verdict == .changesRequired)
        #expect(fixable.resolution == .rollback)
        #expect(fixable.correctionTarget == .architecture)
        #expect(try GatePolicy.classify(.unrecoverableIntegrityViolation).resolution == .fail)
    }
}
