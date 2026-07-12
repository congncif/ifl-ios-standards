import Foundation
import IFLContracts

public final class FileRunStateStore: RunStateStore, @unchecked Sendable {
    private let paths: RunPaths
    private let barrier: any WorkflowDurabilityBarrier
    private let faultInjector: PersistenceFaultInjector
    private let clock: @Sendable () -> Date
    private let trustedFact: TrustedRunFact?
    private let requiresAuthoritativeFact: Bool
    private let allowsUnfencedTestingAccess: Bool

    public convenience init(paths: RunPaths) throws {
        try self.init(
            paths: paths,
            barrier: DarwinDurabilityBarrier(),
            faultInjector: .none,
            clock: Date.init,
            trustedFact: nil,
            requiresAuthoritativeFact: true,
            allowsUnfencedTestingAccess: false
        )
    }

    private init(
        paths: RunPaths,
        barrier: any WorkflowDurabilityBarrier,
        faultInjector: PersistenceFaultInjector,
        clock: @escaping @Sendable () -> Date,
        trustedFact: TrustedRunFact?,
        requiresAuthoritativeFact: Bool,
        allowsUnfencedTestingAccess: Bool
    ) throws {
        self.paths = paths
        self.barrier = barrier
        self.faultInjector = faultInjector
        self.clock = clock
        self.trustedFact = trustedFact
        self.requiresAuthoritativeFact = requiresAuthoritativeFact
        self.allowsUnfencedTestingAccess = allowsUnfencedTestingAccess
        let fileSystem = try validatedFileSystem(rootURL: paths.runRoot)
        if requiresAuthoritativeFact {
            try validateExactAbsence(fileSystem: fileSystem)
        }
    }

    static func testing(
        paths: RunPaths,
        barrier: any WorkflowDurabilityBarrier,
        faultInjector: PersistenceFaultInjector = .none,
        clock: @escaping @Sendable () -> Date = Date.init,
        trustedFact: TrustedRunFact? = nil
    ) throws -> FileRunStateStore {
        try FileRunStateStore(
            paths: paths,
            barrier: barrier,
            faultInjector: faultInjector,
            clock: clock,
            trustedFact: trustedFact,
            requiresAuthoritativeFact: false,
            allowsUnfencedTestingAccess: true
        )
    }

    static func authorized(
        paths: RunPaths,
        barrier: any WorkflowDurabilityBarrier,
        faultInjector: PersistenceFaultInjector = .none,
        clock: @escaping @Sendable () -> Date = Date.init
    ) throws -> FileRunStateStore {
        try FileRunStateStore(
            paths: paths,
            barrier: barrier,
            faultInjector: faultInjector,
            clock: clock,
            trustedFact: nil,
            requiresAuthoritativeFact: false,
            allowsUnfencedTestingAccess: false
        )
    }

    public func load(runID: RunID, from runRoot: URL) throws -> PersistedRun {
        guard allowsUnfencedTestingAccess else { throw PersistenceError.notFound }
        return try loadCore(
            runID: runID,
            from: runRoot,
            authority: nil
        )
    }

    func load(
        runID: RunID,
        from runRoot: URL,
        authority: RawStoreAuthority
    ) throws -> PersistedRun {
        try authority.validate(
            paths: paths,
            runID: runID,
            runRoot: runRoot,
            operation: .load
        )
        return try loadCore(runID: runID, from: runRoot, authority: authority)
    }

    private func loadCore(
        runID: RunID,
        from runRoot: URL,
        authority: RawStoreAuthority?
    ) throws -> PersistedRun {
        try paths.validate(runID: runID, runRoot: runRoot)
        let fileSystem = try validatedFileSystem(rootURL: runRoot)
        return try withFileLock(fileSystem) {
            if let journal = try loadJournal(fileSystem: fileSystem) {
                let recovery = try recoverLocked(
                    runID: runID,
                    fileSystem: fileSystem,
                    journal: journal,
                    authority: authority
                )
                if let authority, authority.isHistoricalCompleted(journal) {
                    return try require(recovery.persistedRun)
                }
            }
            guard let journal = try loadJournal(fileSystem: fileSystem) else {
                try validateExactAbsence(fileSystem: fileSystem)
                throw PersistenceError.notFound
            }
            let persisted = try loadComplete(
                runID: runID,
                journal: journal,
                fileSystem: fileSystem
            )
            try synchronizeCompletionProof(
                journal: journal,
                persisted: persisted,
                fileSystem: fileSystem
            )
            return persisted
        }
    }

    public func commit(
        _ transaction: StateTransaction,
        lease: WriterLease
    ) throws -> CommitReceipt {
        guard allowsUnfencedTestingAccess else {
            throw PersistenceError.fencingViolation
        }
        return try commitCore(
            transaction,
            lease: lease,
            validationInstant: clock(),
            authority: nil
        )
    }

    func commit(
        _ transaction: StateTransaction,
        lease: WriterLease,
        authority: RawStoreAuthority
    ) throws -> CommitReceipt {
        try authority.validate(
            paths: paths,
            runID: transaction.state.runID,
            runRoot: transaction.runRoot,
            operation: .commit,
            suppliedLease: lease
        )
        return try commitCore(
            transaction,
            lease: lease,
            validationInstant: nil,
            authority: authority
        )
    }

    private func commitCore(
        _ transaction: StateTransaction,
        lease: WriterLease,
        validationInstant: Date?,
        authority: RawStoreAuthority?
    ) throws -> CommitReceipt {
        try paths.validate(runID: transaction.state.runID, runRoot: transaction.runRoot)
        let fileSystem = try validatedFileSystem(rootURL: paths.runRoot)
        if requiresAuthoritativeFact {
            try validateExactAbsence(fileSystem: fileSystem)
        }
        if let validationInstant {
            try lease.validate(runID: transaction.state.runID, at: validationInstant)
        }
        return try withFileLock(fileSystem) {
            try faultInjector.hit(.lockAcquired)

            if let journal = try loadJournal(fileSystem: fileSystem) {
                _ = try recoverLocked(
                    runID: transaction.state.runID,
                    fileSystem: fileSystem,
                    journal: journal,
                    authority: authority
                )
            }

            let current: PersistedRun?
            let currentJournal = try loadJournal(fileSystem: fileSystem)
            if let journal = currentJournal {
                current = try loadComplete(
                    runID: transaction.state.runID,
                    journal: journal,
                    fileSystem: fileSystem
                )
            } else {
                try validateExactAbsence(fileSystem: fileSystem)
                current = nil
            }
            try validateFencing(lease, against: current?.events.last)

            if let historical = current?.events.first(where: {
                $0.transactionID == transaction.id
            }) {
                guard historical.transactionDigest == transaction.digest else {
                    throw PersistenceError.transactionConflict
                }
                let epoch = try requireEpoch(for: historical, fileSystem: fileSystem)
                let currentJournal = try require(
                    try loadJournal(fileSystem: fileSystem)
                )
                try synchronizeCompletionProof(
                    journal: currentJournal,
                    persisted: try require(current),
                    fileSystem: fileSystem
                )
                return epoch.receipt
            }

            guard transaction.expectedStateDigest == current?.stateDigest,
                  transaction.expectedEventHead == current?.eventHead,
                  !transaction.receiptWrites.isEmpty,
                  transaction.state.processedEvents.count == (current?.events.count ?? 0) + 1,
                  transaction.state.processedEvents.last?.id == transaction.event.id,
                  transaction.state.processedEvents.last?.kind == transaction.event.kind,
                  transaction.state.processedEvents.last?.candidateGenerationID
                    == transaction.event.candidateGenerationID,
                  transaction.state.processedEvents.last?.eventDigest
                    == CanonicalTreeDigest.sha256(transaction.eventBytes)
            else { throw PersistenceError.transactionConflict }
            for write in transaction.receiptWrites {
                let existing = try readOptionalFile(
                    named: try paths.receiptFilename(id: write.id),
                    in: paths.receiptComponents(kind: write.kind),
                    fileSystem: fileSystem
                )
                guard existing == nil else { throw PersistenceError.transactionConflict }
            }
            let expectedEventDestination = try fileSystem.destinationExpectation(
                named: "events.ndjson",
                in: []
            )
            let expectedStateDestination = try fileSystem.destinationExpectation(
                named: "state.json",
                in: []
            )
            try faultInjector.hit(.currentValidated)

            let receiptIntents = try transaction.receiptWrites.map { write in
                let envelope = ReceiptEnvelope(write: write, transaction: transaction)
                let envelopeBytes = try CanonicalJSON.encode(envelope)
                return JournalReceiptIntent(
                    kind: write.kind,
                    id: write.id,
                    temporaryName: temporaryReceiptName(
                        write: write,
                        transactionDigest: transaction.digest
                    ),
                    envelopeBytes: envelopeBytes,
                    envelopeDigest: CanonicalTreeDigest.sha256(envelopeBytes)
                )
            }.sorted {
                ($0.kind.rawValue, $0.id.rawValue) < ($1.kind.rawValue, $1.id.rawValue)
            }
            let manifest = try receiptIntents.map {
                try $0.manifestEntry(
                    transactionID: transaction.id,
                    transactionDigest: transaction.digest
                )
            }
            let stateDigest = CanonicalTreeDigest.sha256(transaction.stateBytes)
            let priorEventLogBytes = try current.map { try canonicalEventLogBytes($0.events) }
            let eventAppend = try EventLog.append(
                transaction: transaction,
                stateDigest: stateDigest,
                lease: lease,
                receiptManifest: manifest,
                to: priorEventLogBytes
            )
            let prepared = CommitJournalRecord(
                schemaVersion: 1,
                phase: .prepared,
                runID: transaction.state.runID,
                transactionID: transaction.id,
                transactionDigest: transaction.digest,
                expectedStateDigest: transaction.expectedStateDigest,
                expectedEventHead: transaction.expectedEventHead,
                targetStateDigest: stateDigest,
                targetEventHead: eventAppend.record.recordDigest,
                priorStateBytes: current?.stateBytes,
                priorJournalBytes: try currentJournal.map { try CanonicalJSON.encode($0) },
                stateBytes: transaction.stateBytes,
                priorEventLogBytes: priorEventLogBytes,
                targetEventLogBytes: eventAppend.bytes,
                stateTemporaryName: transaction.stateTemporaryFilename,
                eventTemporaryName: transaction.eventTemporaryFilename,
                receipts: receiptIntents,
                lease: lease
            )
            try prepared.validate()
            try persistJournal(
                prepared,
                purpose: .journalIntent,
                beforeFlush: .beforeJournalFlush,
                fileSystem: fileSystem
            )
            try faultInjector.hit(.afterJournalBarrier)

            let receiptDirectories = try prepareReceiptParents(
                kinds: Set(receiptIntents.map(\.kind)),
                fileSystem: fileSystem
            )
            let stateTemporary = try createOrReuseFile(
                data: prepared.stateBytes,
                named: prepared.stateTemporaryName,
                in: [],
                fileSystem: fileSystem
            )
            try faultInjector.hit(.beforeStateFlush)
            let eventTemporary = try createOrReuseFile(
                data: prepared.targetEventLogBytes,
                named: prepared.eventTemporaryName,
                in: [],
                fileSystem: fileSystem
            )
            try faultInjector.hit(.beforeEventFlush)

            var receiptTemporaryFiles: [DescriptorRelativeFile] = []
            for receipt in receiptIntents {
                receiptTemporaryFiles.append(
                    try createOrReuseFile(
                        data: receipt.envelopeBytes,
                        named: receipt.temporaryName,
                        in: paths.receiptComponents(kind: receipt.kind),
                        fileSystem: fileSystem
                    )
                )
                try faultInjector.hit(.beforeReceiptFlush)
            }

            try faultInjector.hit(.beforeEventRename)
            let eventReplacement = try fileSystem.replaceFile(
                temporaryName: prepared.eventTemporaryName,
                destinationName: "events.ndjson",
                in: [],
                expectedDestination: expectedEventDestination
            )
            try faultInjector.hit(.afterEventSwapBeforeCleanup)
            try faultInjector.hit(.afterEventRename)
            try faultInjector.hit(.beforeEventParentFlush)

            for receipt in receiptIntents {
                try faultInjector.hit(.beforeReceiptRename)
                _ = try fileSystem.replaceFile(
                    temporaryName: receipt.temporaryName,
                    destinationName: try paths.receiptFilename(id: receipt.id),
                    in: paths.receiptComponents(kind: receipt.kind),
                    expectedDestination: .absent
                )
                try faultInjector.hit(.afterReceiptRename)
                try faultInjector.hit(.beforeReceiptParentFlush)
            }
            try faultInjector.hit(.beforePayloadDirectoryFlush)
            try synchronize(
                files: [stateTemporary, eventTemporary] + receiptTemporaryFiles
                    + (eventReplacement.map { [$0.file] } ?? []),
                directoryComponents: [[]] + receiptDirectories,
                purpose: .payloadPublication,
                fileSystem: fileSystem
            )
            if let eventReplacement {
                try fileSystem.quarantineNamespaceReplacement(eventReplacement, hook: .none)
                let quarantine = try fileSystem.openFile(
                    named: eventReplacement.quarantineName,
                    in: eventReplacement.components
                )
                try synchronize(
                    files: [eventTemporary, quarantine],
                    directoryComponents: [[]],
                    purpose: .namespaceCleanup,
                    fileSystem: fileSystem
                )
            }
            try faultInjector.hit(.afterPayloadBarrier)

            try faultInjector.hit(.beforeStateRename)
            let stateReplacement = try fileSystem.replaceFile(
                temporaryName: prepared.stateTemporaryName,
                destinationName: "state.json",
                in: [],
                expectedDestination: expectedStateDestination
            )
            try faultInjector.hit(.afterStateSwapBeforeCleanup)
            try faultInjector.hit(.afterStateRename)
            try faultInjector.hit(.beforeStateParentFlush)
            try synchronize(
                files: [stateTemporary] + (stateReplacement.map { [$0.file] } ?? []),
                directoryComponents: [[]],
                purpose: .statePublication,
                fileSystem: fileSystem
            )
            if let stateReplacement {
                try fileSystem.quarantineNamespaceReplacement(stateReplacement, hook: .none)
                let quarantine = try fileSystem.openFile(
                    named: stateReplacement.quarantineName,
                    in: stateReplacement.components
                )
                try synchronize(
                    files: [stateTemporary, quarantine],
                    directoryComponents: [[]],
                    purpose: .namespaceCleanup,
                    fileSystem: fileSystem
                )
            }
            try faultInjector.hit(.afterStateBarrier)

            let receipt = CommitReceipt(
                runID: prepared.runID,
                transactionID: prepared.transactionID,
                transactionDigest: prepared.transactionDigest,
                stateDigest: prepared.targetStateDigest,
                eventHead: prepared.targetEventHead,
                fencingToken: prepared.lease.fencingToken
            )
            let epoch = CompletedEpoch(receipt: receipt, writerOwnerID: lease.ownerID)
            let epochBytes = try CanonicalJSON.encode(epoch)
            let epochFile = try persistEpoch(
                epoch,
                event: eventAppend.record,
                purpose: .epochPublication,
                fileSystem: fileSystem
            )
            do {
                try persistJournal(
                    prepared.completing(),
                    purpose: .journalCompletion,
                    beforeFlush: .beforeJournalCompletionFlush,
                    fileSystem: fileSystem
                )
            } catch {
                try? removeKnownFile(
                    named: paths.epochFilename(for: prepared.transactionDigest),
                    in: ["epochs"],
                    expectedBytes: epochBytes,
                    fileSystem: fileSystem
                )
                _ = epochFile
                throw error
            }
            try faultInjector.hit(.afterJournalCompletionBarrier)
            let complete = try require(try loadJournal(fileSystem: fileSystem))
            let persisted = try loadComplete(
                runID: transaction.state.runID,
                journal: complete,
                fileSystem: fileSystem
            )
            guard persisted.stateDigest == receipt.stateDigest,
                  persisted.eventHead == receipt.eventHead
            else { throw PersistenceError.integrityViolation }
            return receipt
        }
    }

    public func recover(runID: RunID, from runRoot: URL) throws -> RecoveryResult {
        guard allowsUnfencedTestingAccess else { throw PersistenceError.notFound }
        return try recoverCore(
            runID: runID,
            from: runRoot,
            authority: nil
        )
    }

    func recover(
        runID: RunID,
        from runRoot: URL,
        authority: RawStoreAuthority
    ) throws -> RecoveryResult {
        try authority.validate(
            paths: paths,
            runID: runID,
            runRoot: runRoot,
            operation: .recover
        )
        return try recoverCore(runID: runID, from: runRoot, authority: authority)
    }

    func settle(
        runID: RunID,
        from runRoot: URL,
        authority: RawStoreAuthority
    ) throws -> RecoveryResult {
        try authority.validate(
            paths: paths,
            runID: runID,
            runRoot: runRoot,
            operation: .settlement
        )
        return try recoverCore(runID: runID, from: runRoot, authority: authority)
    }

    private func recoverCore(
        runID: RunID,
        from runRoot: URL,
        authority: RawStoreAuthority?
    ) throws -> RecoveryResult {
        try paths.validate(runID: runID, runRoot: runRoot)
        let fileSystem = try validatedFileSystem(rootURL: runRoot)
        return try withFileLock(fileSystem) {
            guard let journal = try loadJournal(fileSystem: fileSystem) else {
                try validateExactAbsence(fileSystem: fileSystem)
                return RecoveryResult(disposition: .absent)
            }
            return try recoverLocked(
                runID: runID,
                fileSystem: fileSystem,
                journal: journal,
                authority: authority
            )
        }
    }

    private func recoverLocked(
        runID: RunID,
        fileSystem: DescriptorRelativeFileSystem,
        journal: CommitJournalRecord,
        authority: RawStoreAuthority? = nil
    ) throws -> RecoveryResult {
        try journal.validate()
        guard journal.runID == runID else { throw PersistenceError.integrityViolation }
        if let authority, try authority.validateJournal(journal) {
            let historical = try loadComplete(
                runID: runID,
                journal: journal,
                fileSystem: fileSystem
            )
            return RecoveryResult(disposition: .unchanged, persistedRun: historical)
        }
        let completionWasUnproven = try reconcileJournalPublication(
            journal,
            fileSystem: fileSystem
        )

        if journal.phase == .complete {
            let visible = try loadVisibleRun(
                runID: runID,
                journal: journal,
                fileSystem: fileSystem
            )
            try synchronizeCompletionProof(
                journal: journal,
                persisted: visible,
                fileSystem: fileSystem
            )
            if try epochIfPresent(for: visible.events.last!, fileSystem: fileSystem) != nil {
                try validateEpochTable(events: visible.events, allowMissingLatest: false, fileSystem: fileSystem)
                try validateTrustedFact(visible)
                return RecoveryResult(
                    disposition: completionWasUnproven ? .completed : .unchanged,
                    persistedRun: visible
                )
            }
            try validateEpochTable(events: visible.events, allowMissingLatest: true, fileSystem: fileSystem)
            try faultInjector.hit(.beforeRecoveryCompletionBarrier)
            try synchronizeVisibleRun(
                journal: journal,
                purpose: .recoveryCompletion,
                fileSystem: fileSystem
            )
            try faultInjector.hit(.afterRecoveryCompletionBarrier)
            _ = try persistLatestEpoch(
                journal: journal,
                visible: visible,
                purpose: .epochPublication,
                fileSystem: fileSystem
            )
            let completed = try loadComplete(
                runID: runID,
                journal: journal,
                fileSystem: fileSystem
            )
            return RecoveryResult(disposition: .completed, persistedRun: completed)
        }

        if journal.phase == .rolledBack {
            try cleanupRolledBackJournal(journal, fileSystem: fileSystem)
            return RecoveryResult(disposition: .rolledBack)
        }

        let stateBytes = try readOptionalFile(named: "state.json", in: [], fileSystem: fileSystem)
        if stateBytes.map(CanonicalTreeDigest.sha256) == journal.targetStateDigest {
            try reconcileStateSwapIntermediate(journal, fileSystem: fileSystem)
            let visible = try loadVisibleRun(
                runID: runID,
                journal: journal,
                fileSystem: fileSystem
            )
            try validateEpochTable(events: visible.events, allowMissingLatest: true, fileSystem: fileSystem)
            try faultInjector.hit(.beforeRecoveryCompletionBarrier)
            try synchronizeVisibleRun(
                journal: journal,
                purpose: .recoveryCompletion,
                fileSystem: fileSystem
            )
            try faultInjector.hit(.afterRecoveryCompletionBarrier)
            _ = try persistLatestEpoch(
                journal: journal,
                visible: visible,
                purpose: .epochPublication,
                fileSystem: fileSystem
            )
            let complete = journal.completing()
            try persistJournal(
                complete,
                purpose: .journalCompletion,
                beforeFlush: .beforeJournalCompletionFlush,
                fileSystem: fileSystem
            )
            let persisted = try loadComplete(
                runID: runID,
                journal: complete,
                fileSystem: fileSystem
            )
            return RecoveryResult(disposition: .completed, persistedRun: persisted)
        }

        let stateIsPrior: Bool
        if let expected = journal.expectedStateDigest {
            stateIsPrior = stateBytes.map(CanonicalTreeDigest.sha256) == expected
        } else {
            stateIsPrior = stateBytes == nil
        }
        guard stateIsPrior else { throw PersistenceError.integrityViolation }
        return try rollback(journal: journal, runID: runID, fileSystem: fileSystem)
    }

    private func rollback(
        journal: CommitJournalRecord,
        runID: RunID,
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> RecoveryResult {
        let rolling = journal.phase == .rollingBack
            ? journal
            : journal.startingRollback()
        if journal.phase != .rollingBack {
            try persistJournal(
                rolling,
                purpose: .rollbackMarker,
                beforeFlush: nil,
                fileSystem: fileSystem
            )
        }
        try proveExistingReceiptInfrastructure(
            kinds: Set(rolling.receipts.map(\.kind)),
            fileSystem: fileSystem
        )
        try validateRollbackSurface(journal: rolling, fileSystem: fileSystem)
        let restoredEventQuarantine = try restorePriorEventLog(
            journal: rolling,
            fileSystem: fileSystem
        )
        for receipt in rolling.receipts {
            let components = paths.receiptComponents(kind: receipt.kind)
            try removeKnownFileIfPresent(
                named: try paths.receiptFilename(id: receipt.id),
                in: components,
                expectedBytes: receipt.envelopeBytes,
                fileSystem: fileSystem
            )
            try removeKnownFileIfPresent(
                named: receipt.temporaryName,
                in: components,
                expectedBytes: receipt.envelopeBytes,
                fileSystem: fileSystem
            )
        }
        try removeKnownFileIfPresent(
            named: rolling.stateTemporaryName,
            in: [],
            expectedBytes: rolling.stateBytes,
            fileSystem: fileSystem
        )
        try removeKnownFileIfPresent(
            named: rolling.eventTemporaryName,
            in: [],
            expectedBytes: rolling.targetEventLogBytes,
            fileSystem: fileSystem
        )

        try faultInjector.hit(.beforeRollbackPayloadBarrier)
        var rollbackFiles: [DescriptorRelativeFile] = []
        if let restoredEventQuarantine { rollbackFiles.append(restoredEventQuarantine) }
        if try readOptionalFile(named: "events.ndjson", in: [], fileSystem: fileSystem) != nil {
            rollbackFiles.append(try fileSystem.openFile(named: "events.ndjson", in: []))
        }
        let directoryCandidates = [[], ["receipts"]]
            + rolling.receipts.map { paths.receiptComponents(kind: $0.kind) }
        try synchronize(
            files: rollbackFiles,
            directoryComponents: try existingDirectoryComponents(
                directoryCandidates,
                fileSystem: fileSystem
            ),
            purpose: .recoveryRollback,
            fileSystem: fileSystem
        )
        try faultInjector.hit(.afterRollbackPayloadBarrier)

        try faultInjector.hit(.beforeRollbackMarkerBarrier)
        if let priorJournalBytes = rolling.priorJournalBytes {
            let restoreName = ".restore-journal-\(rolling.transactionDigest.rawValue).tmp"
            let restored = try createOrReuseFile(
                data: priorJournalBytes,
                named: restoreName,
                in: [],
                fileSystem: fileSystem
            )
            let expectation = try fileSystem.destinationExpectation(
                named: "commit-journal.json",
                in: []
            )
            let replacement = try fileSystem.replaceFile(
                temporaryName: restoreName,
                destinationName: "commit-journal.json",
                in: [],
                expectedDestination: expectation
            )
            try synchronize(
                files: [restored] + (replacement.map { [$0.file] } ?? []),
                directoryComponents: [[]],
                purpose: .rollbackMarker,
                fileSystem: fileSystem
            )
            if let replacement {
                try fileSystem.quarantineNamespaceReplacement(replacement, hook: .none)
                let quarantine = try fileSystem.openFile(
                    named: replacement.quarantineName,
                    in: []
                )
                try synchronize(
                    files: [restored, quarantine],
                    directoryComponents: [[]],
                    purpose: .rollbackMarker,
                    fileSystem: fileSystem
                )
            }
            try faultInjector.hit(.afterRollbackMarkerBarrier)
            let priorJournal = try require(try loadJournal(fileSystem: fileSystem))
            let prior = try loadComplete(
                runID: runID,
                journal: priorJournal,
                fileSystem: fileSystem
            )
            return RecoveryResult(disposition: .rolledBack, persistedRun: prior)
        }
        let rolledBack = rolling.markingRolledBack()
        try persistJournal(
            rolledBack,
            purpose: .rollbackMarker,
            beforeFlush: nil,
            fileSystem: fileSystem
        )
        try faultInjector.hit(.afterRollbackMarkerBarrier)
        try cleanupRolledBackJournal(rolledBack, fileSystem: fileSystem)
        try validateExactAbsence(fileSystem: fileSystem)
        return RecoveryResult(disposition: .rolledBack)
    }

    private func cleanupRolledBackJournal(
        _ journal: CommitJournalRecord,
        fileSystem: DescriptorRelativeFileSystem
    ) throws {
        try removeKnownFileIfPresent(
            named: "commit-journal.json",
            in: [],
            expectedBytes: try CanonicalJSON.encode(journal),
            fileSystem: fileSystem
        )
        try synchronize(
            files: [],
            directoryComponents: [[]],
            purpose: .namespaceCleanup,
            fileSystem: fileSystem
        )
    }

    private func loadComplete(
        runID: RunID,
        journal: CommitJournalRecord,
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> PersistedRun {
        guard journal.phase == .complete else { throw PersistenceError.integrityViolation }
        let visible = try loadVisibleRun(runID: runID, journal: journal, fileSystem: fileSystem)
        try validateEpochTable(events: visible.events, allowMissingLatest: false, fileSystem: fileSystem)
        try validateTrustedFact(visible)
        return visible
    }

    private func loadVisibleRun(
        runID: RunID,
        journal: CommitJournalRecord,
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> PersistedRun {
        do {
            let stateBytes = try readPersistentFile(
                named: "state.json",
                in: [],
                fileSystem: fileSystem
            )
            let state = try CanonicalJSON.decode(RunState.self, from: stateBytes)
            guard try CanonicalJSON.encode(state) == stateBytes,
                  stateBytes == journal.stateBytes,
                  state.runID == runID
            else { throw PersistenceError.integrityViolation }
            let stateDigest = CanonicalTreeDigest.sha256(stateBytes)
            guard stateDigest == journal.targetStateDigest else {
                throw PersistenceError.integrityViolation
            }

            let eventBytes = try readPersistentFile(
                named: "events.ndjson",
                in: [],
                fileSystem: fileSystem
            )
            guard eventBytes == journal.targetEventLogBytes else {
                throw PersistenceError.integrityViolation
            }
            let events = try EventLog.decode(eventBytes)
            guard let eventHead = events.last?.recordDigest,
                  eventHead == journal.targetEventHead,
                  events.last?.runID == runID,
                  events.last?.stateDigest == stateDigest,
                  events.last?.transactionID == journal.transactionID,
                  events.last?.transactionDigest == journal.transactionDigest,
                  events.last?.fencingToken == journal.lease.fencingToken,
                  events.last?.writerOwnerID == journal.lease.ownerID,
                  state.processedEvents.count == events.count
            else { throw PersistenceError.integrityViolation }
            for (processed, record) in zip(state.processedEvents, events) {
                guard processed.id == record.event.id,
                      processed.kind == record.event.kind,
                      processed.candidateGenerationID == record.event.candidateGenerationID,
                      processed.eventDigest == CanonicalTreeDigest.sha256(record.eventBytes)
                else { throw PersistenceError.integrityViolation }
            }
            let receipts = try loadExactReceiptTable(events: events, fileSystem: fileSystem)
            return PersistedRun(
                state: state,
                stateBytes: stateBytes,
                stateDigest: stateDigest,
                events: events,
                eventHead: eventHead,
                receipts: receipts
            )
        } catch {
            throw PersistenceError.integrityViolation
        }
    }

    private func loadExactReceiptTable(
        events: [EventLogRecord],
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> [PersistedReceipt] {
        let expectedEntries = events.flatMap(\.receiptManifest)
        let expected = Dictionary(uniqueKeysWithValues: expectedEntries.map {
            (receiptKey(kind: $0.kind, id: $0.id), $0)
        })
        let kindNames: [String]
        do {
            _ = try fileSystem.openDirectory(["receipts"], requiredMode: 0o700)
            _ = try validatedReceiptParentProvenance(kind: nil, fileSystem: fileSystem)
            kindNames = try validatedNamespaceEntries(
                in: ["receipts"],
                fileSystem: fileSystem
            ).filter {
                $0 != ".parent-provenance.json"
            }
        } catch let error as PersistenceError where error == .ioFailure(ENOENT) {
            guard expected.isEmpty else { throw PersistenceError.integrityViolation }
            return []
        }
        var physicalKeys: Set<String> = []
        var result: [PersistedReceipt] = []
        for kindName in kindNames {
            let kind = try ReceiptKind(validating: kindName)
            _ = try fileSystem.openDirectory(["receipts", kindName], requiredMode: 0o700)
            _ = try validatedReceiptParentProvenance(kind: kind, fileSystem: fileSystem)
            for filename in try validatedNamespaceEntries(
                in: ["receipts", kindName],
                fileSystem: fileSystem
            ).filter({
                $0 != ".parent-provenance.json"
            }) {
                guard filename.hasSuffix(".json") else {
                    throw PersistenceError.integrityViolation
                }
                let id = try ReceiptID(validating: String(filename.dropLast(5)))
                let expectedFilename = try paths.receiptFilename(id: id)
                guard filename == expectedFilename else {
                    throw PersistenceError.integrityViolation
                }
                let key = receiptKey(kind: kind, id: id)
                guard physicalKeys.insert(key).inserted, let manifest = expected[key] else {
                    throw PersistenceError.integrityViolation
                }
                let bytes = try readPersistentFile(
                    named: filename,
                    in: ["receipts", kindName],
                    fileSystem: fileSystem
                )
                guard bytes == manifest.envelopeBytes,
                      CanonicalTreeDigest.sha256(bytes) == manifest.envelopeDigest
                else { throw PersistenceError.integrityViolation }
                let envelope = try manifest.validatedEnvelope()
                result.append(
                    PersistedReceipt(
                        kind: envelope.kind,
                        id: envelope.id,
                        transactionID: envelope.transactionID,
                        transactionDigest: envelope.transactionDigest,
                        payloadDigest: envelope.payloadDigest,
                        payloadBytes: envelope.payloadBytes
                    )
                )
            }
        }
        guard physicalKeys == Set(expected.keys) else {
            throw PersistenceError.integrityViolation
        }
        return result.sorted {
            ($0.kind.rawValue, $0.id.rawValue) < ($1.kind.rawValue, $1.id.rawValue)
        }
    }

    private func loadJournal(
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> CommitJournalRecord? {
        guard let bytes = try readOptionalPersistentFile(
            named: "commit-journal.json",
            in: [],
            fileSystem: fileSystem
        ) else { return nil }
        do {
            let journal = try CanonicalJSON.decode(CommitJournalRecord.self, from: bytes)
            guard try CanonicalJSON.encode(journal) == bytes else {
                throw PersistenceError.integrityViolation
            }
            try journal.validate()
            return journal
        } catch {
            throw PersistenceError.integrityViolation
        }
    }

    private func reconcileJournalPublication(
        _ journal: CommitJournalRecord,
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> Bool {
        let temporaryName = temporaryJournalName(journal.transactionID)
        guard let temporaryBytes = try readOptionalFile(
            named: temporaryName,
            in: [],
            fileSystem: fileSystem
        ) else { return false }
        let expectedBytes: Data?
        switch journal.phase {
        case .prepared:
            expectedBytes = journal.priorJournalBytes
        case .rollingBack:
            expectedBytes = try CanonicalJSON.encode(journal.preparing())
        case .rolledBack:
            expectedBytes = try CanonicalJSON.encode(journal.startingRollback())
        case .complete:
            expectedBytes = try CanonicalJSON.encode(journal.preparing())
        }
        guard let expectedBytes, temporaryBytes == expectedBytes else {
            throw PersistenceError.integrityViolation
        }
        let identity = try fileSystem.entryIdentity(named: temporaryName, in: [])
        let replacement = try fileSystem.namespaceReplacement(
            temporaryName: temporaryName,
            in: [],
            expectedIdentity: identity
        )
        let journalFile = try fileSystem.openFile(named: "commit-journal.json", in: [])
        try synchronize(
            files: [journalFile, replacement.file],
            directoryComponents: [[]],
            purpose: .recoveryCompletion,
            fileSystem: fileSystem
        )
        try fileSystem.quarantineNamespaceReplacement(replacement, hook: .none)
        let quarantine = try fileSystem.openFile(named: replacement.quarantineName, in: [])
        try synchronize(
            files: [journalFile, quarantine],
            directoryComponents: [[]],
            purpose: .recoveryCompletion,
            fileSystem: fileSystem
        )
        return true
    }

    private func reconcileStateSwapIntermediate(
        _ journal: CommitJournalRecord,
        fileSystem: DescriptorRelativeFileSystem
    ) throws {
        guard let bytes = try readOptionalFile(
            named: journal.stateTemporaryName,
            in: [],
            fileSystem: fileSystem
        ) else { return }
        guard let priorStateBytes = journal.priorStateBytes, bytes == priorStateBytes else {
            throw PersistenceError.integrityViolation
        }
        let identity = try fileSystem.entryIdentity(named: journal.stateTemporaryName, in: [])
        let replacement = try fileSystem.namespaceReplacement(
            temporaryName: journal.stateTemporaryName,
            in: [],
            expectedIdentity: identity
        )
        let state = try fileSystem.openFile(named: "state.json", in: [])
        try synchronize(
            files: [state, replacement.file],
            directoryComponents: [[]],
            purpose: .recoveryCompletion,
            fileSystem: fileSystem
        )
        try fileSystem.quarantineNamespaceReplacement(replacement, hook: .none)
        let quarantine = try fileSystem.openFile(named: replacement.quarantineName, in: [])
        try synchronize(
            files: [state, quarantine],
            directoryComponents: [[]],
            purpose: .recoveryCompletion,
            fileSystem: fileSystem
        )
    }

    private func persistJournal(
        _ journal: CommitJournalRecord,
        purpose: DurabilityPurpose,
        beforeFlush: PersistenceMutationPoint?,
        fileSystem: DescriptorRelativeFileSystem
    ) throws {
        try journal.validate()
        let bytes = try CanonicalJSON.encode(journal)
        let temporaryName = temporaryJournalName(journal.transactionID)
        let expectedDestination = try fileSystem.destinationExpectation(
            named: "commit-journal.json",
            in: []
        )
        let file = try createOrReuseFile(
            data: bytes,
            named: temporaryName,
            in: [],
            fileSystem: fileSystem
        )
        let replacement = try fileSystem.replaceFile(
            temporaryName: temporaryName,
            destinationName: "commit-journal.json",
            in: [],
            expectedDestination: expectedDestination
        )
        if purpose == .journalCompletion {
            try faultInjector.hit(.afterJournalCompletionRenameBeforeBarrier)
        }
        if let beforeFlush { try faultInjector.hit(beforeFlush) }
        try synchronize(
            files: [file] + (replacement.map { [$0.file] } ?? []),
            directoryComponents: [[]],
            purpose: purpose,
            fileSystem: fileSystem
        )
        if let replacement {
            try fileSystem.quarantineNamespaceReplacement(replacement, hook: .none)
            let quarantine = try fileSystem.openFile(
                named: replacement.quarantineName,
                in: replacement.components
            )
            try synchronize(
                files: [file, quarantine],
                directoryComponents: [[]],
                purpose: purpose,
                fileSystem: fileSystem
            )
        }
    }

    private func prepareReceiptParents(
        kinds: Set<ReceiptKind>,
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> [[String]] {
        let receiptRoot = try fileSystem.ensureDirectory("receipts", in: [], mode: 0o700)
        let receiptRootProvenance = try prepareReceiptParentProvenance(
            creation: receiptRoot,
            kind: nil,
            components: ["receipts"],
            fileSystem: fileSystem
        )
        try faultInjector.hit(.beforeReceiptRootBarrier)
        try synchronizeDirectoryCreation(
            receiptRoot,
            provenance: receiptRootProvenance,
            purpose: .receiptParent,
            fileSystem: fileSystem
        )
        try faultInjector.hit(.afterReceiptRootBarrier)
        var result = [["receipts"]]
        for kind in kinds.sorted() {
            let creation = try fileSystem.ensureDirectory(
                kind.rawValue,
                in: ["receipts"],
                mode: 0o700
            )
            let provenance = try prepareReceiptParentProvenance(
                creation: creation,
                kind: kind,
                components: ["receipts", kind.rawValue],
                fileSystem: fileSystem
            )
            try faultInjector.hit(.beforeReceiptKindBarrier)
            try synchronizeDirectoryCreation(
                creation,
                provenance: provenance,
                purpose: .receiptParent,
                fileSystem: fileSystem
            )
            try faultInjector.hit(.afterReceiptKindBarrier)
            result.append(["receipts", kind.rawValue])
        }
        return result
    }

    private func synchronizeDirectoryCreation(
        _ creation: DescriptorDirectoryCreation,
        provenance: DescriptorRelativeFile,
        purpose: DurabilityPurpose,
        fileSystem: DescriptorRelativeFileSystem
    ) throws {
        let anchor = try fileSystem.openFile(named: ".durability-anchor", in: [])
        let plan = try DurabilityPlan(
            modified: [
                .init(directory: creation.parent),
                .init(directory: creation.child, requiredPermissions: 0o700),
                .init(
                    file: provenance,
                    kind: .regularFile,
                    requiredPermissions: 0o600
                ),
                .init(
                    file: anchor,
                    kind: .regularFile,
                    requiredPermissions: 0o600
                ),
            ],
            requiredDirectoryFDs: [creation.parent.fd, creation.child.fd],
            anchorFD: anchor.fd,
            purpose: purpose
        )
        try barrier.synchronize(plan)
    }

    private func prepareReceiptParentProvenance(
        creation: DescriptorDirectoryCreation,
        kind: ReceiptKind?,
        components: [String],
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> DescriptorRelativeFile {
        let record = ReceiptParentProvenance(
            runID: paths.runID,
            kind: kind,
            directory: creation.child.metadata,
            parent: creation.parent.metadata,
            runIdentityDigest: paths.runIdentityDigest
        )
        let bytes = try CanonicalJSON.encode(record)
        let name = ".parent-provenance.json"
        if creation.created {
            return try fileSystem.createFile(
                data: bytes,
                named: name,
                in: components,
                mode: 0o600
            )
        }
        guard let existing = try readOptionalPersistentFile(
            named: name,
            in: components,
            fileSystem: fileSystem
        ), existing == bytes
        else { throw PersistenceError.integrityViolation }
        let decoded = try decodeReceiptParentProvenance(existing)
        try decoded.validate(
            runID: paths.runID,
            kind: kind,
            directory: creation.child.metadata,
            parent: creation.parent.metadata,
            runIdentityDigest: paths.runIdentityDigest
        )
        return try fileSystem.openFile(named: name, in: components)
    }

    private func validatedReceiptParentProvenance(
        kind: ReceiptKind?,
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> DescriptorRelativeFile {
        let parentComponents = kind == nil ? [] : ["receipts"]
        let components = kind.map { ["receipts", $0.rawValue] } ?? ["receipts"]
        let parent = try fileSystem.openDirectory(parentComponents, requiredMode: 0o700)
        let directory = try fileSystem.openDirectory(components, requiredMode: 0o700)
        let bytes = try readPersistentFile(
            named: ".parent-provenance.json",
            in: components,
            fileSystem: fileSystem
        )
        let record = try decodeReceiptParentProvenance(bytes)
        try record.validate(
            runID: paths.runID,
            kind: kind,
            directory: directory.metadata,
            parent: parent.metadata,
            runIdentityDigest: paths.runIdentityDigest
        )
        return try fileSystem.openFile(named: ".parent-provenance.json", in: components)
    }

    private func proveExistingReceiptInfrastructure(
        kinds: Set<ReceiptKind>,
        fileSystem: DescriptorRelativeFileSystem
    ) throws {
        let candidates: [(ReceiptKind?, [String], [String])] =
            [(nil, [], ["receipts"])]
            + kinds.sorted().map { ($0, ["receipts"], ["receipts", $0.rawValue]) }
        for (kind, parentComponents, components) in candidates {
            let directory: DescriptorRelativeDirectory
            do {
                directory = try fileSystem.openDirectory(components, requiredMode: 0o700)
            } catch let error as PersistenceError where error == .ioFailure(ENOENT) {
                continue
            }
            let parent = try fileSystem.openDirectory(parentComponents, requiredMode: 0o700)
            let provenance = try validatedReceiptParentProvenance(
                kind: kind,
                fileSystem: fileSystem
            )
            try synchronizeDirectoryCreation(
                DescriptorDirectoryCreation(parent: parent, child: directory, created: false),
                provenance: provenance,
                purpose: .receiptParent,
                fileSystem: fileSystem
            )
        }
    }

    private func synchronize(
        files: [DescriptorRelativeFile],
        directoryComponents: [[String]],
        purpose: DurabilityPurpose,
        fileSystem: DescriptorRelativeFileSystem
    ) throws {
        var seenDirectories: Set<String> = []
        var directories: [DescriptorRelativeDirectory] = []
        for components in directoryComponents {
            let key = components.joined(separator: "/")
            guard seenDirectories.insert(key).inserted else { continue }
            directories.append(try fileSystem.openDirectory(components, requiredMode: 0o700))
        }
        let anchor = try fileSystem.openFile(named: ".durability-anchor", in: [])
        var seenFDs: Set<Int32> = []
        var targets: [DurabilityTarget] = []
        for file in files where seenFDs.insert(file.fd).inserted {
            targets.append(
                .init(file: file, kind: .regularFile, requiredPermissions: 0o600)
            )
        }
        for directory in directories where seenFDs.insert(directory.fd).inserted {
            targets.append(
                .init(directory: directory, requiredPermissions: 0o700)
            )
        }
        if seenFDs.insert(anchor.fd).inserted {
            targets.append(
                .init(file: anchor, kind: .regularFile, requiredPermissions: 0o600)
            )
        }
        let plan = try DurabilityPlan(
            modified: targets,
            requiredDirectoryFDs: Set(directories.map(\.fd)),
            anchorFD: anchor.fd,
            purpose: purpose
        )
        try barrier.synchronize(plan)
    }

    private func synchronizeVisibleRun(
        journal: CommitJournalRecord,
        purpose: DurabilityPurpose,
        fileSystem: DescriptorRelativeFileSystem
    ) throws {
        var files = [
            try fileSystem.openFile(named: "state.json", in: []),
            try fileSystem.openFile(named: "events.ndjson", in: []),
        ]
        for receipt in journal.receipts {
            files.append(
                try fileSystem.openFile(
                    named: try paths.receiptFilename(id: receipt.id),
                    in: paths.receiptComponents(kind: receipt.kind)
                )
            )
        }
        let directories = [[], ["receipts"]]
            + journal.receipts.map { paths.receiptComponents(kind: $0.kind) }
        try synchronize(
            files: files,
            directoryComponents: directories,
            purpose: purpose,
            fileSystem: fileSystem
        )
    }

    private func synchronizeCompletionProof(
        journal: CommitJournalRecord,
        persisted: PersistedRun,
        fileSystem: DescriptorRelativeFileSystem
    ) throws {
        var files = [
            try fileSystem.openFile(named: "commit-journal.json", in: []),
            try fileSystem.openFile(named: "state.json", in: []),
            try fileSystem.openFile(named: "events.ndjson", in: []),
        ]
        var directories: [[String]] = [[], ["epochs"]]
        var receiptDirectories: Set<String> = []
        for receipt in persisted.receipts {
            let components = paths.receiptComponents(kind: receipt.kind)
            files.append(
                try fileSystem.openFile(
                    named: try paths.receiptFilename(id: receipt.id),
                    in: components
                )
            )
            if receiptDirectories.insert(receipt.kind.rawValue).inserted {
                directories.append(components)
            }
        }
        if !persisted.receipts.isEmpty {
            directories.append(["receipts"])
            files.append(
                try validatedReceiptParentProvenance(kind: nil, fileSystem: fileSystem)
            )
            for kindName in receiptDirectories.sorted() {
                files.append(
                    try validatedReceiptParentProvenance(
                        kind: ReceiptKind(validating: kindName),
                        fileSystem: fileSystem
                    )
                )
            }
        }
        for event in persisted.events {
            let name = paths.epochFilename(for: event.transactionDigest)
            if try readOptionalPersistentFile(
                named: name,
                in: ["epochs"],
                fileSystem: fileSystem
            ) != nil {
                files.append(try fileSystem.openFile(named: name, in: ["epochs"]))
            }
        }
        for name in try fileSystem.listEntries(in: []) where name.hasPrefix(".quarantine-") {
            _ = try fileSystem.validateNamespaceQuarantine(named: name, in: [])
            files.append(try fileSystem.openFile(named: name, in: []))
        }
        try synchronize(
            files: files,
            directoryComponents: directories,
            purpose: .recoveryCompletion,
            fileSystem: fileSystem
        )
    }

    private func persistLatestEpoch(
        journal: CommitJournalRecord,
        visible: PersistedRun,
        purpose: DurabilityPurpose,
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> DescriptorRelativeFile {
        let receipt = CommitReceipt(
            runID: journal.runID,
            transactionID: journal.transactionID,
            transactionDigest: journal.transactionDigest,
            stateDigest: journal.targetStateDigest,
            eventHead: journal.targetEventHead,
            fencingToken: journal.lease.fencingToken
        )
        let epoch = CompletedEpoch(receipt: receipt, writerOwnerID: journal.lease.ownerID)
        return try persistEpoch(
            epoch,
            event: try require(visible.events.last),
            purpose: purpose,
            fileSystem: fileSystem
        )
    }

    private func persistEpoch(
        _ epoch: CompletedEpoch,
        event: EventLogRecord,
        purpose: DurabilityPurpose,
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> DescriptorRelativeFile {
        try epoch.validate(event: event)
        let bytes = try CanonicalJSON.encode(epoch)
        let file = try createOrReuseFile(
            data: bytes,
            named: paths.epochFilename(for: epoch.receipt.transactionDigest),
            in: ["epochs"],
            fileSystem: fileSystem
        )
        try synchronize(
            files: [file],
            directoryComponents: [["epochs"]],
            purpose: purpose,
            fileSystem: fileSystem
        )
        return file
    }

    private func validateEpochTable(
        events: [EventLogRecord],
        allowMissingLatest: Bool,
        fileSystem: DescriptorRelativeFileSystem
    ) throws {
        _ = try fileSystem.openDirectory(["epochs"], requiredMode: 0o700)
        let filenames = try validatedNamespaceEntries(
            in: ["epochs"],
            fileSystem: fileSystem
        )
        let expected = Set(events.map { paths.epochFilename(for: $0.transactionDigest) })
        let actual = Set(filenames)
        if allowMissingLatest, let latest = events.last {
            let latestName = paths.epochFilename(for: latest.transactionDigest)
            guard actual == expected || actual == expected.subtracting([latestName]) else {
                throw PersistenceError.integrityViolation
            }
        } else {
            guard actual == expected else { throw PersistenceError.integrityViolation }
        }
        let byDigest = Dictionary(uniqueKeysWithValues: events.map { ($0.transactionDigest, $0) })
        for filename in filenames {
            guard filename.hasSuffix(".json") else { throw PersistenceError.integrityViolation }
            let digest = try HashDigest(validating: String(filename.dropLast(5)))
            guard filename == paths.epochFilename(for: digest), let event = byDigest[digest] else {
                throw PersistenceError.integrityViolation
            }
            _ = try requireEpoch(for: event, fileSystem: fileSystem)
        }
    }

    private func requireEpoch(
        for event: EventLogRecord,
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> CompletedEpoch {
        guard let epoch = try epochIfPresent(for: event, fileSystem: fileSystem) else {
            throw PersistenceError.integrityViolation
        }
        return epoch
    }

    private func epochIfPresent(
        for event: EventLogRecord,
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> CompletedEpoch? {
        guard let bytes = try readOptionalPersistentFile(
            named: paths.epochFilename(for: event.transactionDigest),
            in: ["epochs"],
            fileSystem: fileSystem
        ) else { return nil }
        do {
            let epoch = try CanonicalJSON.decode(CompletedEpoch.self, from: bytes)
            guard try CanonicalJSON.encode(epoch) == bytes else {
                throw PersistenceError.integrityViolation
            }
            try epoch.validate(event: event)
            return epoch
        } catch {
            throw PersistenceError.integrityViolation
        }
    }

    private func validateFencing(
        _ lease: WriterLease,
        against latest: EventLogRecord?
    ) throws {
        guard let latest else { return }
        guard lease.fencingToken >= latest.fencingToken,
              lease.fencingToken != latest.fencingToken
                || lease.ownerID == latest.writerOwnerID
        else { throw PersistenceError.fencingViolation }
    }

    private func validateTrustedFact(_ persisted: PersistedRun) throws {
        guard let trustedFact else {
            if requiresAuthoritativeFact, !persisted.events.isEmpty {
                throw PersistenceError.integrityViolation
            }
            return
        }
        guard trustedFact.runID == persisted.state.runID,
              trustedFact.stateDigest == persisted.stateDigest,
              trustedFact.eventHead == persisted.eventHead,
              let token = persisted.events.last?.fencingToken,
              token >= trustedFact.minimumFencingToken
        else { throw PersistenceError.integrityViolation }
    }

    private func validateExactAbsence(
        fileSystem: DescriptorRelativeFileSystem
    ) throws {
        let baseline: Set<String> = [
            ".durability-anchor", ".run-identity.json", "writer.lock", "epochs", "receipts",
        ]
        let entries = try validatedNamespaceEntries(in: [], fileSystem: fileSystem)
        guard Set(entries).isSubset(of: baseline),
              try validatedNamespaceEntries(
                  in: ["epochs"],
                  fileSystem: fileSystem
              ).isEmpty
        else { throw PersistenceError.integrityViolation }
        do {
            _ = try fileSystem.openDirectory(["receipts"], requiredMode: 0o700)
        } catch let error as PersistenceError where error == .ioFailure(ENOENT) {
            return
        }
        do {
            _ = try validatedReceiptParentProvenance(kind: nil, fileSystem: fileSystem)
            for kindName in try validatedNamespaceEntries(
                in: ["receipts"],
                fileSystem: fileSystem
            ).filter({
                $0 != ".parent-provenance.json"
            }) {
                _ = try ReceiptKind(validating: kindName)
                _ = try fileSystem.openDirectory(
                    ["receipts", kindName],
                    requiredMode: 0o700
                )
                let kind = try ReceiptKind(validating: kindName)
                _ = try validatedReceiptParentProvenance(kind: kind, fileSystem: fileSystem)
                let entries = try validatedNamespaceEntries(
                    in: ["receipts", kindName],
                    fileSystem: fileSystem
                ).filter {
                    $0 != ".parent-provenance.json"
                }
                guard entries.isEmpty else {
                    throw PersistenceError.integrityViolation
                }
            }
        } catch let error as PersistenceError {
            if error == .invalidPathComponent || error == .ioFailure(ENOENT) {
                throw PersistenceError.integrityViolation
            }
            throw error
        }
    }

    private func validatedFileSystem(rootURL: URL) throws -> DescriptorRelativeFileSystem {
        do {
            let fileSystem = try DescriptorRelativeFileSystem(rootURL: rootURL)
            let root = try fileSystem.openDirectory([], requiredMode: 0o700)
            let anchor = try fileSystem.openFile(named: ".durability-anchor", in: [])
            let lock = try fileSystem.openFile(named: "writer.lock", in: [])
            let identityBytes = try readPersistentFile(
                named: ".run-identity.json",
                in: [],
                fileSystem: fileSystem
            )
            guard root.metadata.hasSameIdentity(as: paths.runRootIdentity),
                  root.metadata.permissions == 0o700,
                  anchor.metadata == paths.durabilityAnchorIdentity,
                  anchor.metadata.permissions == 0o600,
                  anchor.metadata.linkCount == 1,
                  try fileSystem.readFile(named: ".durability-anchor", in: [])
                    == Data("ifl-workflow-durability-anchor-v1\n".utf8),
                  lock.metadata == paths.lockIdentity.metadata,
                  lock.metadata.permissions == 0o600,
                  lock.metadata.linkCount == 1,
                  try fileSystem.readFile(named: "writer.lock", in: []).isEmpty,
                  CanonicalTreeDigest.sha256(identityBytes) == paths.runIdentityDigest
            else { throw PersistenceError.integrityViolation }
            _ = try fileSystem.openDirectory(["epochs"], requiredMode: 0o700)
            return fileSystem
        } catch {
            throw PersistenceError.integrityViolation
        }
    }

    private func withFileLock<T>(
        _ fileSystem: DescriptorRelativeFileSystem,
        _ body: () throws -> T
    ) throws -> T {
        let lock = try FileLock.acquire(
            in: fileSystem,
            expectedIdentity: paths.lockIdentity
        )
        return try withExtendedLifetime(lock) { try body() }
    }

    private func createOrReuseFile(
        data: Data,
        named name: String,
        in components: [String],
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> DescriptorRelativeFile {
        if let existing = try readOptionalFile(named: name, in: components, fileSystem: fileSystem) {
            guard existing == data else { throw PersistenceError.integrityViolation }
            let file = try fileSystem.openFile(named: name, in: components)
            guard file.metadata.permissions == 0o600, file.metadata.linkCount == 1 else {
                throw PersistenceError.integrityViolation
            }
            return file
        }
        return try fileSystem.createFile(
            data: data,
            named: name,
            in: components,
            mode: 0o600
        )
    }

    private func readPersistentFile(
        named name: String,
        in components: [String],
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> Data {
        let file = try fileSystem.openFile(named: name, in: components)
        guard file.metadata.permissions == 0o600, file.metadata.linkCount == 1 else {
            throw PersistenceError.integrityViolation
        }
        return try fileSystem.readFile(named: name, in: components)
    }

    private func readOptionalPersistentFile(
        named name: String,
        in components: [String],
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> Data? {
        do {
            return try readPersistentFile(named: name, in: components, fileSystem: fileSystem)
        } catch let error as PersistenceError where error == .ioFailure(ENOENT) {
            return nil
        }
    }

    private func readOptionalFile(
        named name: String,
        in components: [String],
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> Data? {
        do {
            return try fileSystem.readFileIfPresent(named: name, in: components)
        } catch let error as PersistenceError where error == .ioFailure(ENOENT) {
            return nil
        }
    }

    private func removeKnownFileIfPresent(
        named name: String,
        in components: [String],
        expectedBytes: Data,
        fileSystem: DescriptorRelativeFileSystem
    ) throws {
        guard try readOptionalFile(named: name, in: components, fileSystem: fileSystem) != nil else {
            return
        }
        try removeKnownFile(
            named: name,
            in: components,
            expectedBytes: expectedBytes,
            fileSystem: fileSystem
        )
    }

    private func removeKnownFile(
        named name: String,
        in components: [String],
        expectedBytes: Data,
        fileSystem: DescriptorRelativeFileSystem
    ) throws {
        guard try fileSystem.readFile(named: name, in: components) == expectedBytes else {
            throw PersistenceError.integrityViolation
        }
        let identity = try fileSystem.entryIdentity(named: name, in: components)
        try fileSystem.removeExpectedFile(
            named: name,
            in: components,
            expectedIdentity: identity
        )
    }

    private func validateRollbackSurface(
        journal: CommitJournalRecord,
        fileSystem: DescriptorRelativeFileSystem
    ) throws {
        let event = try readOptionalFile(named: "events.ndjson", in: [], fileSystem: fileSystem)
        guard event == nil || event == journal.priorEventLogBytes || event == journal.targetEventLogBytes
        else { throw PersistenceError.integrityViolation }
        if let temporary = try readOptionalFile(
            named: journal.eventTemporaryName,
            in: [],
            fileSystem: fileSystem
        ) {
            guard temporary == journal.targetEventLogBytes
                    || temporary == journal.priorEventLogBytes
            else {
                throw PersistenceError.integrityViolation
            }
        }
        if let temporary = try readOptionalFile(
            named: journal.stateTemporaryName,
            in: [],
            fileSystem: fileSystem
        ) {
            guard temporary == journal.stateBytes else {
                throw PersistenceError.integrityViolation
            }
        }
        for receipt in journal.receipts {
            let components = paths.receiptComponents(kind: receipt.kind)
            for name in [try paths.receiptFilename(id: receipt.id), receipt.temporaryName] {
                if let bytes = try readOptionalFile(
                    named: name,
                    in: components,
                    fileSystem: fileSystem
                ) {
                    guard bytes == receipt.envelopeBytes else {
                        throw PersistenceError.integrityViolation
                    }
                }
            }
        }
    }

    private func restorePriorEventLog(
        journal: CommitJournalRecord,
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> DescriptorRelativeFile? {
        let current = try readOptionalFile(named: "events.ndjson", in: [], fileSystem: fileSystem)
        guard current != journal.priorEventLogBytes else { return nil }
        guard current == journal.targetEventLogBytes else {
            throw PersistenceError.integrityViolation
        }
        if let prior = journal.priorEventLogBytes {
            let stagedPrior: String
            if try readOptionalFile(
                named: journal.eventTemporaryName,
                in: [],
                fileSystem: fileSystem
            ) == prior {
                stagedPrior = journal.eventTemporaryName
            } else {
                stagedPrior = ".recovery-events-\(journal.transactionDigest.rawValue).tmp"
                _ = try createOrReuseFile(
                    data: prior,
                    named: stagedPrior,
                    in: [],
                    fileSystem: fileSystem
                )
            }
            let expectation = try fileSystem.destinationExpectation(
                named: "events.ndjson",
                in: []
            )
            let replacement = try require(try fileSystem.replaceFile(
                temporaryName: stagedPrior,
                destinationName: "events.ndjson",
                in: [],
                expectedDestination: expectation
            ))
            try fileSystem.quarantineNamespaceReplacement(replacement, hook: .none)
            return try fileSystem.openFile(named: replacement.quarantineName, in: [])
        } else {
            try removeKnownFileIfPresent(
                named: "events.ndjson",
                in: [],
                expectedBytes: journal.targetEventLogBytes,
                fileSystem: fileSystem
            )
            return nil
        }
    }

    private func existingDirectoryComponents(
        _ candidates: [[String]],
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> [[String]] {
        var result: [[String]] = []
        var seen: Set<String> = []
        for components in candidates {
            let key = components.joined(separator: "/")
            guard seen.insert(key).inserted else { continue }
            do {
                _ = try fileSystem.openDirectory(components, requiredMode: 0o700)
                result.append(components)
            } catch let error as PersistenceError where error == .ioFailure(ENOENT) {
                continue
            }
        }
        return result
    }

    private func validatedNamespaceEntries(
        in components: [String],
        fileSystem: DescriptorRelativeFileSystem
    ) throws -> [String] {
        let entries = try fileSystem.listEntries(in: components)
        for name in entries where name.hasPrefix(".quarantine-") {
            _ = try fileSystem.validateNamespaceQuarantine(named: name, in: components)
        }
        return entries.filter { !$0.hasPrefix(".quarantine-") }
    }
}

private struct CompletedEpoch: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let receipt: CommitReceipt
    let writerOwnerID: String

    init(receipt: CommitReceipt, writerOwnerID: String) {
        schemaVersion = 1
        self.receipt = receipt
        self.writerOwnerID = writerOwnerID
    }

    init(from decoder: any Decoder) throws {
        do {
            try rejectUnknownFields(
                from: decoder,
                allowed: Set(CodingKeys.allCases.map(\.stringValue))
            )
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
            receipt = try container.decode(CommitReceipt.self, forKey: .receipt)
            writerOwnerID = try container.decode(String.self, forKey: .writerOwnerID)
            guard schemaVersion == 1, isValidatedPersistenceIdentifier(writerOwnerID) else {
                throw PersistenceError.integrityViolation
            }
        } catch {
            throw PersistenceError.integrityViolation
        }
    }

    func validate(event: EventLogRecord) throws {
        guard schemaVersion == 1,
              receipt.schemaVersion == 1,
              receipt.isDurable,
              receipt.runID == event.runID,
              receipt.transactionID == event.transactionID,
              receipt.transactionDigest == event.transactionDigest,
              receipt.stateDigest == event.stateDigest,
              receipt.eventHead == event.recordDigest,
              receipt.fencingToken == event.fencingToken,
              writerOwnerID == event.writerOwnerID
        else { throw PersistenceError.integrityViolation }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case receipt
        case writerOwnerID = "writer_owner_id"
    }
}

private struct ReceiptParentProvenance: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let runID: RunID
    let kind: ReceiptKind?
    let directoryDevice: UInt64
    let directoryInode: UInt64
    let parentDevice: UInt64
    let parentInode: UInt64
    let runIdentityDigest: HashDigest

    init(
        runID: RunID,
        kind: ReceiptKind?,
        directory: DescriptorObjectMetadata,
        parent: DescriptorObjectMetadata,
        runIdentityDigest: HashDigest
    ) {
        schemaVersion = 1
        self.runID = runID
        self.kind = kind
        directoryDevice = directory.device
        directoryInode = directory.inode
        parentDevice = parent.device
        parentInode = parent.inode
        self.runIdentityDigest = runIdentityDigest
    }

    init(from decoder: any Decoder) throws {
        do {
            try rejectUnknownFields(
                from: decoder,
                allowed: Set(CodingKeys.allCases.map(\.stringValue))
            )
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
            runID = try container.decode(RunID.self, forKey: .runID)
            kind = try container.decodeIfPresent(ReceiptKind.self, forKey: .kind)
            directoryDevice = try container.decode(UInt64.self, forKey: .directoryDevice)
            directoryInode = try container.decode(UInt64.self, forKey: .directoryInode)
            parentDevice = try container.decode(UInt64.self, forKey: .parentDevice)
            parentInode = try container.decode(UInt64.self, forKey: .parentInode)
            runIdentityDigest = try container.decode(HashDigest.self, forKey: .runIdentityDigest)
            guard schemaVersion == 1 else { throw PersistenceError.integrityViolation }
        } catch {
            throw PersistenceError.integrityViolation
        }
    }

    func validate(
        runID: RunID,
        kind: ReceiptKind?,
        directory: DescriptorObjectMetadata,
        parent: DescriptorObjectMetadata,
        runIdentityDigest: HashDigest
    ) throws {
        guard schemaVersion == 1,
              self.runID == runID,
              self.kind == kind,
              directoryDevice == directory.device,
              directoryInode == directory.inode,
              parentDevice == parent.device,
              parentInode == parent.inode,
              self.runIdentityDigest == runIdentityDigest,
              directory.kind == .directory,
              directory.permissions == 0o700
        else { throw PersistenceError.integrityViolation }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case runID = "run_id"
        case kind
        case directoryDevice = "directory_device"
        case directoryInode = "directory_inode"
        case parentDevice = "parent_device"
        case parentInode = "parent_inode"
        case runIdentityDigest = "run_identity_digest"
    }
}

private func decodeReceiptParentProvenance(
    _ bytes: Data
) throws -> ReceiptParentProvenance {
    do {
        let record = try CanonicalJSON.decode(ReceiptParentProvenance.self, from: bytes)
        guard try CanonicalJSON.encode(record) == bytes else {
            throw PersistenceError.integrityViolation
        }
        return record
    } catch {
        throw PersistenceError.integrityViolation
    }
}

private func canonicalEventLogBytes(_ records: [EventLogRecord]) throws -> Data {
    try records.reduce(into: Data()) { bytes, record in
        bytes.append(try CanonicalJSON.encode(record))
        bytes.append(0x0A)
    }
}

private func temporaryReceiptName(
    write: ReceiptTableWrite,
    transactionDigest: HashDigest
) -> String {
    let identity = Data(
        "\(write.kind.rawValue)\u{0}\(write.id.rawValue)\u{0}\(transactionDigest.rawValue)".utf8
    )
    return ".receipt-\(CanonicalTreeDigest.sha256(identity).rawValue).tmp"
}

private func temporaryJournalName(_ transactionID: TransactionID) -> String {
    let digest = CanonicalTreeDigest.sha256(Data(transactionID.rawValue.utf8))
    return ".journal-\(digest.rawValue).tmp"
}

private func receiptKey(kind: ReceiptKind, id: ReceiptID) -> String {
    "\(kind.rawValue)/\(id.rawValue)"
}

private func require<T>(_ value: T?) throws -> T {
    guard let value else { throw PersistenceError.integrityViolation }
    return value
}
