import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("ReviewPublicationTransactionTests")
struct ReviewPublicationTransactionTests {
    @Test("every publication kind has a sealed operation and one shared commit boundary")
    func typedOperationsOwnPublicationComposition() throws {
        let publicationSource = try reviewPublicationSource(
            "ReviewPublicationTransaction.swift"
        )
        let productionSource = try #require(
            publicationSource.components(separatedBy: "#if DEBUG").first
        )
        let legacySource = try reviewPublicationSource(
            "ReviewConvergenceValidator.swift"
        )

        for operation in [
            "public func publishInventoryRecorded(",
            "public func publishInventoryClosed(",
            "public func publishRemediationRecorded(",
            "public func publishConfirmationRecorded(",
            "public func publishExceptionOpened(",
            "public func publishDirectConvergence(",
            "public func publishConfirmedConvergence(",
            "public func publishInvalidation(",
        ] {
            #expect(productionSource.contains(operation))
        }
        for sealedInput in [
            "VerifiedReviewerInventoryAuthority",
            "VerifiedIssueRegister",
            "VerifiedRemediationSuccessor",
            "VerifiedCommittedRemediationSuccessor",
            "VerifiedReviewExceptionAdmission",
            "VerifiedConfirmationLineage",
            "VerifiedReviewInvalidationAuthorization",
        ] {
            #expect(productionSource.contains(sealedInput))
        }

        #expect(productionSource.components(
            separatedBy: "return try composeAndPublish("
        ).count - 1 == 8)
        #expect(productionSource.components(
            separatedBy: "let commitReceipt = try store.commit(transaction, lease: lease)"
        ).count - 1 == 1)
        #expect(productionSource.contains("fileprivate struct ReviewPublicationPreimage"))
        #expect(productionSource.contains("fileprivate enum ReviewPublicationBuilder"))
        #expect(!productionSource.contains("public struct ReviewPublicationPreimage"))
        #expect(!productionSource.contains("public func publicationPreimage("))
        #expect(!productionSource.contains("requiredReceiptIDs"))
        #expect(!productionSource.contains("required_receipt_ids"))
        #expect(!legacySource.contains("public enum ReviewConvergenceTransaction"))
        #expect(!(VerifiedReviewPublication.self is any Encodable.Type))
        #expect(!(VerifiedReviewPublication.self is any Decodable.Type))
        #expect(!(VerifiedPublishedReviewReceipt.self is any Encodable.Type))
        #expect(!(VerifiedPublishedReviewReceipt.self is any Decodable.Type))
    }

    @Test("every typed publication operation commits once and returns exact authority")
    func everyTypedOperationPublishesEndToEnd() throws {
        let scenarios = try ReviewCapabilityTestFactory.publicationOperationScenarios()
        #expect(scenarios.count == ReviewPublicationOperationTestKind.allCases.count)
        #expect(Set(scenarios.map(\.kind)) == Set(ReviewPublicationOperationTestKind.allCases))

        for scenario in scenarios {
            let source = scenario.source
            let store = InMemoryReviewPublicationStore(source: source)
            let runRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
                source.state.runID.filesystemComponent,
                isDirectory: true
            )
            let publisher = try reviewPublicationPublisher(kind: scenario.kind)
            let lease = try WriterLease(
                runID: source.state.runID,
                ownerID: "review-publication-writer",
                fencingToken: FencingToken(validating: 10_000),
                issuedAt: Date(timeIntervalSince1970: 1),
                expiresAt: Date(timeIntervalSince1970: 2)
            )

            let committed = try scenario.publish(
                store: store,
                publisher: publisher,
                runRoot: runRoot,
                lease: lease
            )
            let persisted = store.snapshot()
            let transactionAddresses = committed.transaction.receiptWrites.map {
                "\($0.kind.rawValue)/\($0.id.rawValue)"
            }.sorted()
            let authorityAddresses = committed.receipts.map {
                "\($0.kind.rawValue)/\($0.id.rawValue)"
            }.sorted()
            let owningRecord = try #require(persisted.events.last)
            let manifestAddresses = owningRecord.receiptManifest.map {
                "\($0.kind.rawValue)/\($0.id.rawValue)"
            }.sorted()

            #expect(store.commitCount == 1, "\(scenario.kind.rawValue)")
            #expect(store.loadCount == 2, "\(scenario.kind.rawValue)")
            #expect(committed.transaction.expectedStateDigest == source.stateDigest)
            #expect(committed.transaction.expectedEventHead == source.eventHead)
            #expect(committed.transaction.event.kind == scenario.expectedEventKind)
            #expect(committed.transaction.event.id == scenario.expectedEventID)
            #expect(transactionAddresses == scenario.expectedReceiptAddresses)
            #expect(authorityAddresses == scenario.expectedReceiptAddresses)
            #expect(manifestAddresses == scenario.expectedReceiptAddresses)
            #expect(committed.commitReceipt.transactionID == committed.transaction.id)
            #expect(committed.commitReceipt.transactionDigest == committed.transaction.digest)
            #expect(committed.commitReceipt.stateDigest == persisted.stateDigest)
            #expect(committed.commitReceipt.eventHead == persisted.eventHead)
            #expect(owningRecord.previousDigest == source.eventHead)
            #expect(owningRecord.previousStateDigest == source.stateDigest)
            #expect(owningRecord.transactionID == committed.transaction.id)
            #expect(owningRecord.transactionDigest == committed.transaction.digest)
            #expect(persisted.events.count == source.events.count + 1)
            #expect(
                persisted.receipts.count ==
                    source.receipts.count + scenario.expectedReceiptAddresses.count
            )
            #expect(committed.receipts.allSatisfy {
                $0.transactionID == committed.transaction.id &&
                    $0.transactionDigest == committed.transaction.digest &&
                    $0.publicationAnchorEventHead == source.eventHead &&
                    $0.producedEventHead == persisted.eventHead
            })

            if scenario.kind == .remediationRecorded {
                let recovered = try #require(committed.committedRemediationSuccessor)
                #expect(recovered.producedEventHead == persisted.eventHead)
                #expect(recovered.publicationAnchorEventHead == source.eventHead)
                #expect(recovered.receipts.map {
                    "\($0.kind.rawValue)/\($0.id.rawValue)"
                }.sorted() == scenario.expectedReceiptAddresses)
            } else {
                #expect(committed.committedRemediationSuccessor == nil)
            }
        }
    }
}

private final class InMemoryReviewPublicationStore: RunStateStore, @unchecked Sendable {
    private let lock = NSLock()
    private var persisted: PersistedRun
    private var commits = 0
    private var loads = 0

    init(source: PersistedRun) {
        persisted = source
    }

    var commitCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return commits
    }

    var loadCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return loads
    }

    func snapshot() -> PersistedRun {
        lock.lock()
        defer { lock.unlock() }
        return persisted
    }

    func load(runID: RunID, from _: URL) throws -> PersistedRun {
        lock.lock()
        defer { lock.unlock() }
        loads += 1
        guard persisted.state.runID == runID else {
            throw PersistenceError.notFound
        }
        return persisted
    }

    func commit(
        _ transaction: StateTransaction,
        lease: WriterLease
    ) throws -> CommitReceipt {
        lock.lock()
        defer { lock.unlock() }
        commits += 1
        guard transaction.state.runID == persisted.state.runID,
              lease.runID == persisted.state.runID,
              transaction.expectedStateDigest == persisted.stateDigest,
              transaction.expectedEventHead == persisted.eventHead
        else { throw PersistenceError.transactionConflict }

        let manifest = try transaction.receiptWrites.map { write -> ReceiptManifestEntry in
            let envelope = ReceiptEnvelope(write: write, transaction: transaction)
            let envelopeBytes = try CanonicalJSON.encode(envelope)
            return ReceiptManifestEntry(
                kind: write.kind,
                id: write.id,
                envelopeDigest: CanonicalTreeDigest.sha256(envelopeBytes),
                payloadDigest: write.payloadDigest,
                envelopeBytes: envelopeBytes
            )
        }.sorted {
            ($0.kind.rawValue, $0.id.rawValue) < ($1.kind.rawValue, $1.id.rawValue)
        }
        let stateBytes = transaction.stateBytes
        let stateDigest = CanonicalTreeDigest.sha256(stateBytes)
        let record = try EventLogRecord(
            sequence: UInt64(persisted.events.count + 1),
            runID: persisted.state.runID,
            transactionID: transaction.id,
            previousDigest: persisted.eventHead,
            previousStateDigest: persisted.stateDigest,
            stateDigest: stateDigest,
            transactionDigest: transaction.digest,
            fencingToken: lease.fencingToken,
            writerOwnerID: lease.ownerID,
            receiptManifest: manifest,
            event: transaction.event
        )
        let committedReceipts = transaction.receiptWrites.map { write in
            PersistedReceipt(
                kind: write.kind,
                id: write.id,
                transactionID: transaction.id,
                transactionDigest: transaction.digest,
                payloadDigest: write.payloadDigest,
                payloadBytes: write.payloadBytes
            )
        }
        persisted = PersistedRun(
            state: transaction.state,
            stateBytes: stateBytes,
            stateDigest: stateDigest,
            events: persisted.events + [record],
            eventHead: record.recordDigest,
            receipts: (persisted.receipts + committedReceipts).sorted {
                ($0.kind.rawValue, $0.id.rawValue) < ($1.kind.rawValue, $1.id.rawValue)
            }
        )
        return CommitReceipt(
            runID: persisted.state.runID,
            transactionID: transaction.id,
            transactionDigest: transaction.digest,
            stateDigest: stateDigest,
            eventHead: record.recordDigest,
            fencingToken: lease.fencingToken
        )
    }

    func recover(runID: RunID, from _: URL) throws -> RecoveryResult {
        lock.lock()
        defer { lock.unlock() }
        guard persisted.state.runID == runID else {
            return RecoveryResult(disposition: .absent)
        }
        return RecoveryResult(disposition: .unchanged, persistedRun: persisted)
    }
}

private func reviewPublicationDigest(_ label: String) -> HashDigest {
    CanonicalTreeDigest.sha256(Data(label.utf8))
}

private func reviewPublicationPublisher(
    kind: ReviewPublicationOperationTestKind
) throws -> VerifiedAuthorityFact {
    let suffix = kind.rawValue.lowercased()
    return VerifiedAuthorityFact(
        actorID: try ActorID(validating: "review-publication-\(suffix)"),
        principalID: try PrincipalID(
            validating: "review-publication-\(suffix)-principal"
        ),
        roles: [.kernel],
        principalKind: .kernel,
        independentContextDigest: reviewPublicationDigest(
            "kernel-publication-context/\(suffix)"
        ),
        hasAuthorshipEdge: false,
        hasSourceWriteCapability: false
    )
}

private func reviewPublicationSource(_ filename: String) throws -> String {
    var root = URL(fileURLWithPath: #filePath)
    while root.lastPathComponent != "ifl-ios-standards", root.path != "/" {
        root.deleteLastPathComponent()
    }
    return try String(
        contentsOf: root
            .appendingPathComponent("tools/ifl-tooling/Sources/IFLWorkflow/Review")
            .appendingPathComponent(filename),
        encoding: .utf8
    )
}
