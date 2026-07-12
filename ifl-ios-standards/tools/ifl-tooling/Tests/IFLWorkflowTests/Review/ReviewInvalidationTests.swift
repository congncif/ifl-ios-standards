import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("ReviewInvalidationTests")
struct ReviewInvalidationTests {
    @Test("intersecting mutation derives the complete authoritative lineage publication")
    func intersectingMutationInvalidatesCompleteLineage() throws {
        let scenario = try ReviewCapabilityTestFactory.invalidationScenario()
        #expect(scenario.baselines.count >= 2)
        #expect(scenario.registers.count >= 2)
        #expect(scenario.exceptionRounds.isEmpty)
        #expect(!scenario.downstreamApprovals.isEmpty)

        let decision = try ReviewConvergenceValidator.invalidate(
            lineage: scenario.lineage,
            persistedRun: scenario.persistedRun,
            by: scenario.intersectingInvalidation
        )
        guard case .authorization(let authorization) = decision else {
            Issue.record("intersecting mutation must issue one sealed invalidation authorization")
            return
        }
        let plan = authorization.plan
        let approvalDigests = try scenario.downstreamApprovals.map {
            CanonicalTreeDigest.sha256(try CanonicalJSON.encode($0))
        }.sorted(by: digestOrder)

        #expect(authorization.latestBaseline == scenario.baselines.last)
        #expect(authorization.persistedStateDigest == scenario.persistedRun.stateDigest)
        #expect(authorization.eventHead == scenario.persistedRun.eventHead)
        #expect(plan.invalidatedBaselineDigests
            == scenario.baselines.map(\.digest).sorted(by: digestOrder))
        #expect(plan.invalidatedInventoryDigests
            == scenario.inventories.map(\.digest).sorted(by: digestOrder))
        #expect(plan.invalidatedRegisterDigests
            == scenario.registers.map(\.digest).sorted(by: digestOrder))
        #expect(plan.invalidatedRemediationBatchDigests
            == scenario.remediationBatches.map(\.digest).sorted(by: digestOrder))
        #expect(plan.invalidatedConfirmationReceiptDigests
            == scenario.confirmationReceipts.map(\.digest).sorted(by: digestOrder))
        #expect(plan.invalidatedExceptionProofDigests
            == scenario.exceptionRounds.map(\.proofDigest).sorted(by: digestOrder))
        #expect(plan.invalidatedConvergenceReceiptDigests
            == scenario.convergenceReceipts.map(\.digest).sorted(by: digestOrder))
        #expect(plan.invalidatedApprovalDigests == approvalDigests)
        #expect(plan.requiresFreshInitialCycle)
        #expect(!plan.remainsCurrent)
        #expect(try ReviewInvalidationPlan.decodeCanonical(
            from: CanonicalJSON.encode(plan)
        ) == plan)
    }

    @Test("omitting any persisted review receipt makes invalidation lineage incomplete")
    func incompletePersistedLineageFailsClosed() throws {
        let scenario = try ReviewCapabilityTestFactory.invalidationScenario()
        let reviewReceipts = scenario.persistedRun.receipts.filter {
            $0.kind.rawValue.hasPrefix("review-")
        }
        #expect(reviewReceipts.count >= 8)

        for omitted in reviewReceipts {
            let partial = omittingReceipt(omitted.id, from: scenario.persistedRun)
            #expect(throws: PersistenceError.integrityViolation) {
                try ReviewConvergenceValidator.invalidate(
                    lineage: scenario.lineage,
                    persistedRun: partial,
                    by: scenario.intersectingInvalidation
                )
            }
        }
    }

    @Test("scoped-out mutation remains current and emits no review publication")
    func scopedOutVerifiedMutationDoesNotOverInvalidate() throws {
        let scenario = try ReviewCapabilityTestFactory.invalidationScenario()
        let decision = try ReviewConvergenceValidator.invalidate(
            lineage: scenario.lineage,
            persistedRun: scenario.persistedRun,
            by: scenario.scopedOutInvalidation
        )
        guard case .remainsCurrent = decision else {
            Issue.record("scoped-out verified mutation must not issue invalidation state")
            return
        }
    }

    @Test("invalidation authority is derived from persisted lineage, never digest lists")
    func invalidationSurfaceHasNoCallerDigestLists() throws {
        let source = try reviewValidatorSource()
        #expect(source.contains("lineage: VerifiedConfirmationLineage"))
        #expect(source.contains("persistedRun: PersistedRun"))
        #expect(!source.contains("inventoryDigests: [HashDigest],"))
        #expect(!source.contains("downstreamApprovalDigests: [HashDigest],"))
        #expect(!(VerifiedConfirmationLineage.self is any Decodable.Type))
        #expect(!(VerifiedReviewPublication.self is any Decodable.Type))
    }
}

private func omittingReceipt(
    _ id: ReceiptID,
    from persistedRun: PersistedRun
) -> PersistedRun {
    PersistedRun(
        state: persistedRun.state,
        stateBytes: persistedRun.stateBytes,
        stateDigest: persistedRun.stateDigest,
        events: persistedRun.events,
        eventHead: persistedRun.eventHead,
        receipts: persistedRun.receipts.filter { $0.id != id }
    )
}

private func digestOrder(_ lhs: HashDigest, _ rhs: HashDigest) -> Bool {
    lhs.rawValue < rhs.rawValue
}

private func reviewValidatorSource() throws -> String {
    var root = URL(fileURLWithPath: #filePath)
    while root.lastPathComponent != "ifl-ios-standards", root.path != "/" {
        root.deleteLastPathComponent()
    }
    return try String(
        contentsOf: root
            .appendingPathComponent(
                "tools/ifl-tooling/Sources/IFLWorkflow/Review/ReviewConvergenceValidator.swift"
            ),
        encoding: .utf8
    )
}
