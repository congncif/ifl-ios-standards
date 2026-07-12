import Darwin
import Foundation
import IFLContracts

public struct LeaseRequest: Hashable, Sendable {
    public let runID: RunID
    public let ownerID: String
    public let ttlMicroseconds: Int64

    public init(
        runID: RunID,
        ownerID: String,
        ttlMicroseconds: Int64
    ) throws {
        guard isValidatedPersistenceIdentifier(ownerID), ttlMicroseconds > 0 else {
            throw PersistenceError.invalidLease
        }
        self.runID = runID
        self.ownerID = ownerID
        self.ttlMicroseconds = ttlMicroseconds
    }
}

enum LeaseStoreMutationPoint: Hashable, Sendable {
    case lockAcquired
    case recordDescriptorValidated
    case afterPendingBarrier
    case afterRecordRenameBeforeBarrier
}

enum LeaseStoreInterruption: Error, Equatable, Sendable {
    case injected(LeaseStoreMutationPoint)
}

struct LeaseStoreFaultInjector: @unchecked Sendable {
    private let handler: @Sendable (LeaseStoreMutationPoint) throws -> Void

    init(_ handler: @escaping @Sendable (LeaseStoreMutationPoint) throws -> Void) {
        self.handler = handler
    }

    static var none: LeaseStoreFaultInjector {
        LeaseStoreFaultInjector { _ in }
    }

    func hit(_ point: LeaseStoreMutationPoint) throws {
        try handler(point)
    }
}

enum RawStoreAuthorityOperation: Hashable, Sendable {
    case load
    case commit
    case recover
    case settlement
}

final class RawStoreAuthority: @unchecked Sendable {
    let workItemRoot: URL
    let runRoot: URL
    let runID: RunID
    let lease: WriterLease
    let operation: RawStoreAuthorityOperation
    private let witness: LeaseLockWitness

    fileprivate init(
        paths: RunPaths,
        lease: WriterLease,
        operation: RawStoreAuthorityOperation,
        witness: LeaseLockWitness
    ) {
        workItemRoot = paths.workItemRoot.standardizedFileURL
        runRoot = paths.runRoot.standardizedFileURL
        runID = paths.runID
        self.lease = lease
        self.operation = operation
        self.witness = witness
    }

    func validate(
        paths: RunPaths,
        runID: RunID,
        runRoot: URL,
        operation: RawStoreAuthorityOperation,
        suppliedLease: WriterLease? = nil
    ) throws {
        try witness.validate()
        guard self.operation == operation,
              self.runID == runID,
              paths.runID == runID,
              workItemRoot == paths.workItemRoot.standardizedFileURL,
              self.runRoot == runRoot.standardizedFileURL,
              paths.runRoot.standardizedFileURL == runRoot.standardizedFileURL
        else { throw PersistenceError.fencingViolation }
        if operation == .commit {
            guard suppliedLease == lease else { throw PersistenceError.staleLease }
        } else {
            guard suppliedLease == nil else { throw PersistenceError.fencingViolation }
        }
    }

    func validateJournal(_ journal: CommitJournalRecord) throws -> Bool {
        try witness.validate()
        guard journal.runID == runID else { throw PersistenceError.integrityViolation }
        if journal.phase == .complete, journal.lease.fencingToken < lease.fencingToken {
            return true
        }
        guard journal.lease.fencingToken == lease.fencingToken,
              journal.lease.ownerID == lease.ownerID
        else { throw PersistenceError.integrityViolation }
        return false
    }

    func isHistoricalCompleted(_ journal: CommitJournalRecord) -> Bool {
        journal.phase == .complete && journal.lease.fencingToken < lease.fencingToken
    }
}

public final class LeaseStore: RunStateStore, @unchecked Sendable {
    fileprivate static let leaseComponents = ["artifacts", "workflow", "leases"]

    private let workItemRoot: URL
    private let runID: RunID
    private let paths: RunPaths?
    private let rawStore: FileRunStateStore?
    private let barrier: any WorkflowDurabilityBarrier
    private let clock: @Sendable () -> Date
    private let faultInjector: LeaseStoreFaultInjector
    private let fileSystem: DescriptorRelativeFileSystem
    private let lockIdentity: DescriptorEntryIdentity

    public convenience init(workItemRoot: URL, runID: RunID) throws {
        let barrier = DarwinDurabilityBarrier()
        try self.init(
            workItemRoot: workItemRoot,
            runID: runID,
            paths: nil,
            barrier: barrier,
            clock: Date.init,
            faultInjector: .none,
            rawFaultInjector: .none
        )
    }

    public convenience init(paths: RunPaths) throws {
        let barrier = DarwinDurabilityBarrier()
        try self.init(
            workItemRoot: paths.workItemRoot,
            runID: paths.runID,
            paths: paths,
            barrier: barrier,
            clock: Date.init,
            faultInjector: .none,
            rawFaultInjector: .none
        )
    }

    private init(
        workItemRoot: URL,
        runID: RunID,
        paths: RunPaths?,
        barrier: any WorkflowDurabilityBarrier,
        clock: @escaping @Sendable () -> Date,
        faultInjector: LeaseStoreFaultInjector,
        rawFaultInjector: PersistenceFaultInjector
    ) throws {
        let standardizedRoot = workItemRoot.standardizedFileURL
        if let paths {
            guard paths.workItemRoot.standardizedFileURL == standardizedRoot,
                  paths.runID == runID
            else { throw PersistenceError.integrityViolation }
        }
        let fileSystem = try DescriptorRelativeFileSystem(rootURL: standardizedRoot)
        let lockIdentity = try prepareLeaseNamespace(
            fileSystem: fileSystem,
            runID: runID,
            barrier: barrier
        )
        let rawStore = try paths.map {
            try FileRunStateStore.authorized(
                paths: $0,
                barrier: barrier,
                faultInjector: rawFaultInjector,
                clock: clock
            )
        }
        self.workItemRoot = standardizedRoot
        self.runID = runID
        self.paths = paths
        self.rawStore = rawStore
        self.barrier = barrier
        self.clock = clock
        self.faultInjector = faultInjector
        self.fileSystem = fileSystem
        self.lockIdentity = lockIdentity
        try validateConstructionBinding()
    }

    static func testing(
        workItemRoot: URL,
        runID: RunID,
        barrier: any WorkflowDurabilityBarrier,
        clock: @escaping @Sendable () -> Date,
        faultInjector: LeaseStoreFaultInjector = .none
    ) throws -> LeaseStore {
        try LeaseStore(
            workItemRoot: workItemRoot,
            runID: runID,
            paths: nil,
            barrier: barrier,
            clock: clock,
            faultInjector: faultInjector,
            rawFaultInjector: .none
        )
    }

    static func testing(
        paths: RunPaths,
        barrier: any WorkflowDurabilityBarrier,
        clock: @escaping @Sendable () -> Date,
        faultInjector: LeaseStoreFaultInjector = .none,
        rawFaultInjector: PersistenceFaultInjector = .none
    ) throws -> LeaseStore {
        try LeaseStore(
            workItemRoot: paths.workItemRoot,
            runID: paths.runID,
            paths: paths,
            barrier: barrier,
            clock: clock,
            faultInjector: faultInjector,
            rawFaultInjector: rawFaultInjector
        )
    }

    public func acquire(_ request: LeaseRequest) throws -> WriterLease {
        try validate(request)
        return try withLeaseLock { witness in
            let now = try sampleInstant()
            switch try loadRecordLocked() {
            case .none:
                try validateGenesisHasNoRunRoot()
                let active = try makeActiveRecord(
                    ownerID: request.ownerID,
                    token: FencingToken(validating: 1),
                    now: now,
                    ttlMicroseconds: request.ttlMicroseconds
                )
                let publication = try preparePublication(.active(active))
                try publishLocked(publication)
                return try active.writerLease()

            case let .some(.active(active)):
                guard now.microseconds >= active.issuedAtMicroseconds else {
                    throw PersistenceError.staleLease
                }
                if now.microseconds < active.expiresAtMicroseconds {
                    guard active.ownerID == request.ownerID else {
                        throw PersistenceError.blockedEnvironment
                    }
                    return try active.writerLease()
                }
                throw PersistenceError.staleLease

            case let .some(.released(released)):
                let active = try makeActiveRecord(
                    ownerID: request.ownerID,
                    token: try increment(released.fencingToken),
                    now: now,
                    ttlMicroseconds: request.ttlMicroseconds
                )
                let publication = try preparePublication(.active(active))
                try settleOldEpoch(record: .released(released), witness: witness)
                try publishLocked(publication)
                return try active.writerLease()
            }
        }
    }

    public func renew(
        _ lease: WriterLease,
        ttlMicroseconds: Int64
    ) throws -> WriterLease {
        try validate(lease: lease)
        guard ttlMicroseconds > 0 else { throw PersistenceError.invalidLease }
        return try withLeaseLock { witness in
            let now = try sampleInstant()
            guard case let .active(active)? = try loadRecordLocked(),
                  try active.writerLease() == lease
            else { throw PersistenceError.staleLease }
            try validateCurrent(active, at: now)
            let renewed = try makeActiveRecord(
                ownerID: active.ownerID,
                token: active.fencingToken,
                now: now,
                ttlMicroseconds: ttlMicroseconds
            )
            let publication = try preparePublication(.active(renewed))
            try settleOldEpoch(record: .active(active), witness: witness)
            if renewed != active {
                try publishLocked(publication)
            }
            return try renewed.writerLease()
        }
    }

    public func recover(_ request: LeaseRequest) throws -> WriterLease {
        try validate(request)
        return try withLeaseLock { witness in
            let now = try sampleInstant()
            switch try loadRecordLocked() {
            case .none:
                throw PersistenceError.notFound

            case let .some(.active(active)):
                guard now.microseconds >= active.issuedAtMicroseconds else {
                    throw PersistenceError.staleLease
                }
                if now.microseconds < active.expiresAtMicroseconds {
                    throw PersistenceError.blockedEnvironment
                }
                let successor = try makeActiveRecord(
                    ownerID: request.ownerID,
                    token: try increment(active.fencingToken),
                    now: now,
                    ttlMicroseconds: request.ttlMicroseconds
                )
                let publication = try preparePublication(.active(successor))
                try settleOldEpoch(record: .active(active), witness: witness)
                try publishLocked(publication)
                return try successor.writerLease()

            case let .some(.released(released)):
                let successor = try makeActiveRecord(
                    ownerID: request.ownerID,
                    token: try increment(released.fencingToken),
                    now: now,
                    ttlMicroseconds: request.ttlMicroseconds
                )
                let publication = try preparePublication(.active(successor))
                try settleOldEpoch(record: .released(released), witness: witness)
                try publishLocked(publication)
                return try successor.writerLease()
            }
        }
    }

    public func release(_ lease: WriterLease) throws {
        try validate(lease: lease)
        try withLeaseLock { witness in
            let now = try sampleInstant()
            switch try loadRecordLocked() {
            case let .some(.active(active)):
                guard try active.writerLease() == lease else {
                    throw PersistenceError.staleLease
                }
                try validateCurrent(active, at: now)
                let publication = try preparePublication(
                    .released(
                        ReleasedLeaseRecord(
                            runID: active.runID,
                            lastOwnerID: active.ownerID,
                            fencingToken: active.fencingToken,
                            lastIssuedAtMicroseconds: active.issuedAtMicroseconds,
                            lastExpiresAtMicroseconds: active.expiresAtMicroseconds,
                            releasedAtMicroseconds: now.microseconds
                        )
                    )
                )
                try settleOldEpoch(record: .active(active), witness: witness)
                try publishLocked(publication)

            case let .some(.released(released)):
                guard try released.writerLease() == lease else {
                    throw PersistenceError.staleLease
                }
                return

            case .none:
                throw PersistenceError.staleLease
            }
        }
    }

    public func load(runID: RunID, from runRoot: URL) throws -> PersistedRun {
        let (paths, rawStore) = try boundStore(runID: runID, runRoot: runRoot)
        return try withLeaseLock { witness in
            let now = try sampleInstant()
            let active = try currentActiveRecord(at: now)
            let authority = RawStoreAuthority(
                paths: paths,
                lease: try active.writerLease(),
                operation: .load,
                witness: witness
            )
            return try rawStore.load(
                runID: runID,
                from: runRoot,
                authority: authority
            )
        }
    }

    public func commit(
        _ transaction: StateTransaction,
        lease: WriterLease
    ) throws -> CommitReceipt {
        let (paths, rawStore) = try boundStore(
            runID: transaction.state.runID,
            runRoot: transaction.runRoot
        )
        try validate(lease: lease)
        return try withLeaseLock { witness in
            let now = try sampleInstant()
            let active = try currentActiveRecord(at: now)
            guard try active.writerLease() == lease else {
                throw PersistenceError.staleLease
            }
            let authority = RawStoreAuthority(
                paths: paths,
                lease: lease,
                operation: .commit,
                witness: witness
            )
            return try rawStore.commit(
                transaction,
                lease: lease,
                authority: authority
            )
        }
    }

    public func recover(runID: RunID, from runRoot: URL) throws -> RecoveryResult {
        let (paths, rawStore) = try boundStore(runID: runID, runRoot: runRoot)
        return try withLeaseLock { witness in
            let now = try sampleInstant()
            let active = try currentActiveRecord(at: now)
            let authority = RawStoreAuthority(
                paths: paths,
                lease: try active.writerLease(),
                operation: .recover,
                witness: witness
            )
            return try rawStore.recover(
                runID: runID,
                from: runRoot,
                authority: authority
            )
        }
    }

    private func boundStore(
        runID: RunID,
        runRoot: URL
    ) throws -> (RunPaths, FileRunStateStore) {
        guard let paths, let rawStore else { throw PersistenceError.fencingViolation }
        try paths.validate(runID: runID, runRoot: runRoot)
        return (paths, rawStore)
    }

    private func validate(_ request: LeaseRequest) throws {
        guard request.runID == runID,
              isValidatedPersistenceIdentifier(request.ownerID),
              request.ttlMicroseconds > 0
        else { throw PersistenceError.invalidLease }
    }

    private func validate(lease: WriterLease) throws {
        guard lease.runID == runID,
              isValidatedPersistenceIdentifier(lease.ownerID)
        else { throw PersistenceError.invalidLease }
    }

    private func withLeaseLock<T>(
        hitFaultInjector: Bool = true,
        _ body: (LeaseLockWitness) throws -> T
    ) throws -> T {
        let held = try StableLeaseLock(
            fileSystem: fileSystem,
            components: Self.leaseComponents,
            name: lockName,
            expectedIdentity: lockIdentity
        )
        let witness = LeaseLockWitness(lock: held)
        defer { witness.invalidate() }
        if hitFaultInjector {
            try faultInjector.hit(.lockAcquired)
        }
        return try withExtendedLifetime(held) {
            try body(witness)
        }
    }

    private func sampleInstant() throws -> LeaseInstant {
        let sampled = clock()
        let scaled = sampled.timeIntervalSince1970 * 1_000_000
        guard scaled.isFinite,
              scaled >= Double(Int64.min),
              scaled < Double(Int64.max)
        else { throw PersistenceError.invalidLease }
        let integral = scaled.rounded(.towardZero)
        guard integral >= Double(Int64.min), integral < Double(Int64.max) else {
            throw PersistenceError.invalidLease
        }
        let microseconds = Int64(integral)
        let exact = date(fromUnixMicroseconds: microseconds)
        guard exact.timeIntervalSince1970.isFinite else {
            throw PersistenceError.invalidLease
        }
        return LeaseInstant(microseconds: microseconds, date: exact)
    }

    private func currentActiveRecord(at now: LeaseInstant) throws -> ActiveLeaseRecord {
        guard case let .active(active)? = try loadRecordLocked() else {
            throw PersistenceError.staleLease
        }
        try validateCurrent(active, at: now)
        return active
    }

    private func validateCurrent(
        _ active: ActiveLeaseRecord,
        at now: LeaseInstant
    ) throws {
        guard now.microseconds >= active.issuedAtMicroseconds,
              now.microseconds < active.expiresAtMicroseconds
        else { throw PersistenceError.staleLease }
    }

    private func makeActiveRecord(
        ownerID: String,
        token: FencingToken,
        now: LeaseInstant,
        ttlMicroseconds: Int64
    ) throws -> ActiveLeaseRecord {
        guard ttlMicroseconds > 0 else { throw PersistenceError.invalidLease }
        let (expires, overflow) = now.microseconds.addingReportingOverflow(ttlMicroseconds)
        guard !overflow, expires > now.microseconds else {
            throw PersistenceError.invalidLease
        }
        let active = ActiveLeaseRecord(
            runID: runID,
            ownerID: ownerID,
            fencingToken: token,
            issuedAtMicroseconds: now.microseconds,
            expiresAtMicroseconds: expires
        )
        try active.validate(expectedRunID: runID)
        return active
    }

    private func increment(_ token: FencingToken) throws -> FencingToken {
        let (next, overflow) = token.rawValue.addingReportingOverflow(1)
        guard !overflow else { throw PersistenceError.invalidLease }
        return try FencingToken(validating: next)
    }

    private func settleOldEpoch(
        record: LeaseRecord,
        witness: LeaseLockWitness
    ) throws {
        guard let paths, let rawStore else {
            try validateGenesisHasNoRunRoot()
            return
        }
        let authority = RawStoreAuthority(
            paths: paths,
            lease: try record.writerLease(),
            operation: .settlement,
            witness: witness
        )
        _ = try rawStore.settle(
            runID: runID,
            from: paths.runRoot,
            authority: authority
        )
    }

    private func validateGenesisHasNoRunRoot() throws {
        guard try runRootExists() == false else {
            throw PersistenceError.integrityViolation
        }
    }

    private func validateConstructionBinding() throws {
        try withLeaseLock(hitFaultInjector: false) { _ in
            if try runRootExists(), try loadRecordLocked() == nil {
                throw PersistenceError.integrityViolation
            }
        }
    }

    private func runRootExists() throws -> Bool {
        do {
            _ = try fileSystem.openDirectory(
                ["artifacts", "workflow", "runs", runID.filesystemComponent],
                requiredMode: 0o700
            )
            return true
        } catch let error as PersistenceError where error == .ioFailure(ENOENT) {
            return false
        }
    }

    private func loadRecordLocked() throws -> LeaseRecord? {
        try cleanupPendingLocked()
        do {
            let file = try fileSystem.openFile(
                named: recordName,
                in: Self.leaseComponents
            )
            let identity = try fileSystem.entryIdentity(
                named: recordName,
                in: Self.leaseComponents
            )
            guard file.metadata.permissions == 0o600,
                  file.metadata.linkCount == 1,
                  identity.metadata == file.metadata,
                  try descriptorMatches(file.fd, metadata: file.metadata)
            else { throw PersistenceError.integrityViolation }
            try faultInjector.hit(.recordDescriptorValidated)
            guard try fileSystem.entryIdentity(
                named: recordName,
                in: Self.leaseComponents
            ) == identity,
            try descriptorMatches(file.fd, metadata: file.metadata)
            else { throw PersistenceError.integrityViolation }
            let bytes = try readDescriptorBytes(file.fd)
            guard try fileSystem.entryIdentity(
                named: recordName,
                in: Self.leaseComponents
            ) == identity,
            try descriptorMatches(file.fd, metadata: file.metadata)
            else { throw PersistenceError.integrityViolation }
            let record = try decodeLeaseRecord(bytes)
            try record.validate(expectedRunID: runID)
            return record
        } catch let error as PersistenceError where error == .ioFailure(ENOENT) {
            return nil
        }
    }

    private func cleanupPendingLocked() throws {
        let pending: DescriptorRelativeFile
        do {
            pending = try fileSystem.openFile(
                named: pendingName,
                in: Self.leaseComponents
            )
        } catch let error as PersistenceError where error == .ioFailure(ENOENT) {
            return
        }
        guard pending.metadata.permissions == 0o600,
              pending.metadata.linkCount == 1
        else { throw PersistenceError.integrityViolation }
        let directory = try fileSystem.openDirectory(
            Self.leaseComponents,
            requiredMode: 0o700
        )
        try unlinkExpected(
            pending,
            named: pendingName,
            directory: directory
        )
        let plan = try DurabilityPlan(
            modified: [
                .init(directory: directory, requiredPermissions: 0o700),
                .init(
                    fd: pending.fd,
                    kind: .regularFile,
                    linkRole: .controlledUnlinked,
                    requiredPermissions: 0o600
                ),
            ],
            requiredDirectoryFDs: [directory.fd],
            anchorFD: pending.fd,
            purpose: .namespaceCleanup
        )
        try barrier.synchronize(plan)
    }

    private func preparePublication(
        _ record: LeaseRecord
    ) throws -> PreparedLeasePublication {
        try record.validate(expectedRunID: runID)
        let bytes = try CanonicalJSON.encode(record)
        guard try CanonicalJSON.decode(LeaseRecord.self, from: bytes) == record else {
            throw PersistenceError.integrityViolation
        }
        return PreparedLeasePublication(record: record, bytes: bytes)
    }

    private func publishLocked(_ publication: PreparedLeasePublication) throws {
        let bytes = publication.bytes
        guard try fileSystem.readFileIfPresent(
            named: pendingName,
            in: Self.leaseComponents
        ) == nil
        else { throw PersistenceError.integrityViolation }
        let expectedDestination = try fileSystem.destinationExpectation(
            named: recordName,
            in: Self.leaseComponents
        )
        let pending = try fileSystem.createFile(
            data: bytes,
            named: pendingName,
            in: Self.leaseComponents,
            mode: 0o600
        )
        let directory = try fileSystem.openDirectory(
            Self.leaseComponents,
            requiredMode: 0o700
        )
        try barrier.synchronize(
            DurabilityPlan(
                modified: [
                    .init(directory: directory, requiredPermissions: 0o700),
                    .init(file: pending, requiredPermissions: 0o600),
                ],
                requiredDirectoryFDs: [directory.fd],
                anchorFD: pending.fd,
                purpose: .payloadPublication
            )
        )
        try faultInjector.hit(.afterPendingBarrier)

        let replacement = try fileSystem.replaceFile(
            temporaryName: pendingName,
            destinationName: recordName,
            in: Self.leaseComponents,
            expectedDestination: expectedDestination
        )
        try faultInjector.hit(.afterRecordRenameBeforeBarrier)
        let published = try fileSystem.openFile(
            named: recordName,
            in: Self.leaseComponents
        )
        guard published.metadata == pending.metadata,
              published.metadata.permissions == 0o600,
              published.metadata.linkCount == 1,
              try readDescriptorBytes(published.fd) == bytes
        else { throw PersistenceError.integrityViolation }

        let priorBytes = try replacement.map { try readDescriptorBytes($0.file.fd) }
        var modified: [DurabilityTarget] = [
            .init(directory: directory, requiredPermissions: 0o700),
            .init(file: published, requiredPermissions: 0o600),
        ]
        if let replacement {
            modified.append(.init(file: replacement.file, requiredPermissions: 0o600))
        }
        do {
            try barrier.synchronize(
                DurabilityPlan(
                    modified: modified,
                    requiredDirectoryFDs: [directory.fd],
                    anchorFD: published.fd,
                    purpose: .payloadPublication
                )
            )
        } catch {
            try rollbackPublication(
                replacement: replacement,
                pending: pending,
                published: published,
                directory: directory
            )
            throw error
        }

        if let replacement, let priorBytes {
            do {
                try unlinkExpected(
                    replacement.file,
                    named: pendingName,
                    directory: directory
                )
            } catch {
                if try fileSystem.readFileIfPresent(
                    named: pendingName,
                    in: Self.leaseComponents
                ) != nil {
                    try rollbackPublication(
                        replacement: replacement,
                        pending: pending,
                        published: published,
                        directory: directory
                    )
                } else {
                    try restorePriorBytesAfterCleanupFailure(
                        priorBytes,
                        published: published,
                        directory: directory
                    )
                }
                throw error
            }
            do {
                try barrier.synchronize(
                    DurabilityPlan(
                        modified: [
                            .init(directory: directory, requiredPermissions: 0o700),
                            .init(file: published, requiredPermissions: 0o600),
                            .init(
                                fd: replacement.file.fd,
                                kind: .regularFile,
                                linkRole: .controlledUnlinked,
                                requiredPermissions: 0o600
                            ),
                        ],
                        requiredDirectoryFDs: [directory.fd],
                        anchorFD: published.fd,
                        purpose: .namespaceCleanup
                    )
                )
            } catch {
                try restorePriorBytesAfterCleanupFailure(
                    priorBytes,
                    published: published,
                    directory: directory
                )
                throw error
            }
        }
    }

    private func rollbackPublication(
        replacement: DescriptorNamespaceReplacement?,
        pending: DescriptorRelativeFile,
        published: DescriptorRelativeFile,
        directory: DescriptorRelativeDirectory
    ) throws {
        if replacement != nil {
            _ = try fileSystem.replaceFile(
                temporaryName: pendingName,
                destinationName: recordName,
                in: Self.leaseComponents,
                expectedDestination: .exact(
                    DescriptorEntryIdentity(metadata: published.metadata)
                )
            )
            let restored = try fileSystem.openFile(
                named: recordName,
                in: Self.leaseComponents
            )
            try synchronizeRollback(
                authoritative: restored,
                pending: pending,
                directory: directory
            )
        } else {
            _ = try fileSystem.replaceFile(
                temporaryName: recordName,
                destinationName: pendingName,
                in: Self.leaseComponents,
                expectedDestination: .absent
            )
            try barrier.synchronize(
                DurabilityPlan(
                    modified: [
                        .init(directory: directory, requiredPermissions: 0o700),
                        .init(file: pending, requiredPermissions: 0o600),
                    ],
                    requiredDirectoryFDs: [directory.fd],
                    anchorFD: pending.fd,
                    purpose: .rollbackMarker
                )
            )
        }
        try cleanupPendingLocked()
    }

    private func restorePriorBytesAfterCleanupFailure(
        _ priorBytes: Data,
        published: DescriptorRelativeFile,
        directory: DescriptorRelativeDirectory
    ) throws {
        let stagedPrior = try fileSystem.createFile(
            data: priorBytes,
            named: pendingName,
            in: Self.leaseComponents,
            mode: 0o600
        )
        _ = try fileSystem.replaceFile(
            temporaryName: pendingName,
            destinationName: recordName,
            in: Self.leaseComponents,
            expectedDestination: .exact(
                DescriptorEntryIdentity(metadata: published.metadata)
            )
        )
        let restored = try fileSystem.openFile(named: recordName, in: Self.leaseComponents)
        try synchronizeRollback(
            authoritative: restored,
            pending: published,
            directory: directory
        )
        _ = stagedPrior
        try cleanupPendingLocked()
    }

    private func synchronizeRollback(
        authoritative: DescriptorRelativeFile,
        pending: DescriptorRelativeFile,
        directory: DescriptorRelativeDirectory
    ) throws {
        try barrier.synchronize(
            DurabilityPlan(
                modified: [
                    .init(directory: directory, requiredPermissions: 0o700),
                    .init(file: authoritative, requiredPermissions: 0o600),
                    .init(file: pending, requiredPermissions: 0o600),
                ],
                requiredDirectoryFDs: [directory.fd],
                anchorFD: authoritative.fd,
                purpose: .rollbackMarker
            )
        )
    }

    private func unlinkExpected(
        _ file: DescriptorRelativeFile,
        named name: String,
        directory: DescriptorRelativeDirectory
    ) throws {
        guard file.metadata.permissions == 0o600,
              file.metadata.linkCount == 1,
              try fileSystem.entryIdentity(
                  named: name,
                  in: Self.leaseComponents
              ).metadata == file.metadata,
              try descriptorMatches(file.fd, metadata: file.metadata)
        else { throw PersistenceError.integrityViolation }
        while true {
            let result = name.withCString { unlinkat(directory.fd, $0, 0) }
            if result == 0 { break }
            if errno == EINTR { continue }
            throw persistencePOSIXError(errno)
        }
        guard try fileSystem.readFileIfPresent(
            named: name,
            in: Self.leaseComponents
        ) == nil,
        try descriptorLinkCount(file.fd) == 0
        else { throw PersistenceError.integrityViolation }
    }

    private var recordName: String {
        "\(runID.filesystemComponent).json"
    }

    private var pendingName: String {
        "\(recordName).pending"
    }

    private var lockName: String {
        "\(runID.filesystemComponent).lock"
    }
}

private struct LeaseInstant: Hashable, Sendable {
    let microseconds: Int64
    let date: Date
}

private struct PreparedLeasePublication: Hashable, Sendable {
    let record: LeaseRecord
    let bytes: Data
}

private struct ActiveLeaseRecord: Hashable, Sendable {
    let runID: RunID
    let ownerID: String
    let fencingToken: FencingToken
    let issuedAtMicroseconds: Int64
    let expiresAtMicroseconds: Int64

    func validate(expectedRunID: RunID) throws {
        guard runID == expectedRunID,
              isValidatedPersistenceIdentifier(ownerID),
              issuedAtMicroseconds < expiresAtMicroseconds
        else { throw PersistenceError.integrityViolation }
        _ = try writerLease()
    }

    func writerLease() throws -> WriterLease {
        try WriterLease(
            runID: runID,
            ownerID: ownerID,
            fencingToken: fencingToken,
            issuedAt: date(fromUnixMicroseconds: issuedAtMicroseconds),
            expiresAt: date(fromUnixMicroseconds: expiresAtMicroseconds)
        )
    }
}

private struct ReleasedLeaseRecord: Hashable, Sendable {
    let runID: RunID
    let lastOwnerID: String
    let fencingToken: FencingToken
    let lastIssuedAtMicroseconds: Int64
    let lastExpiresAtMicroseconds: Int64
    let releasedAtMicroseconds: Int64

    func validate(expectedRunID: RunID) throws {
        guard runID == expectedRunID,
              isValidatedPersistenceIdentifier(lastOwnerID),
              lastIssuedAtMicroseconds < lastExpiresAtMicroseconds,
              releasedAtMicroseconds >= lastIssuedAtMicroseconds,
              releasedAtMicroseconds < lastExpiresAtMicroseconds
        else { throw PersistenceError.integrityViolation }
        _ = try writerLease()
    }

    func writerLease() throws -> WriterLease {
        try WriterLease(
            runID: runID,
            ownerID: lastOwnerID,
            fencingToken: fencingToken,
            issuedAt: date(fromUnixMicroseconds: lastIssuedAtMicroseconds),
            expiresAt: date(fromUnixMicroseconds: lastExpiresAtMicroseconds)
        )
    }
}

private enum LeaseRecord: Codable, Hashable, Sendable {
    case active(ActiveLeaseRecord)
    case released(ReleasedLeaseRecord)

    init(from decoder: any Decoder) throws {
        do {
            try rejectUnknownFields(
                from: decoder,
                allowed: Set(CodingKeys.allCases.map(\.stringValue))
            )
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let keys = Set(container.allKeys)
            let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
            let kind = try container.decode(String.self, forKey: .recordKind)
            guard schemaVersion == 1 else { throw PersistenceError.integrityViolation }
            switch kind {
            case "active":
                guard keys == CodingKeys.activeKeys else {
                    throw PersistenceError.integrityViolation
                }
                self = .active(
                    ActiveLeaseRecord(
                        runID: try container.decode(RunID.self, forKey: .runID),
                        ownerID: try container.decode(String.self, forKey: .ownerID),
                        fencingToken: try container.decode(
                            FencingToken.self,
                            forKey: .fencingToken
                        ),
                        issuedAtMicroseconds: try container.decode(
                            Int64.self,
                            forKey: .issuedAtMicroseconds
                        ),
                        expiresAtMicroseconds: try container.decode(
                            Int64.self,
                            forKey: .expiresAtMicroseconds
                        )
                    )
                )
            case "released":
                guard keys == CodingKeys.releasedKeys else {
                    throw PersistenceError.integrityViolation
                }
                self = .released(
                    ReleasedLeaseRecord(
                        runID: try container.decode(RunID.self, forKey: .runID),
                        lastOwnerID: try container.decode(String.self, forKey: .lastOwnerID),
                        fencingToken: try container.decode(
                            FencingToken.self,
                            forKey: .fencingToken
                        ),
                        lastIssuedAtMicroseconds: try container.decode(
                            Int64.self,
                            forKey: .lastIssuedAtMicroseconds
                        ),
                        lastExpiresAtMicroseconds: try container.decode(
                            Int64.self,
                            forKey: .lastExpiresAtMicroseconds
                        ),
                        releasedAtMicroseconds: try container.decode(
                            Int64.self,
                            forKey: .releasedAtMicroseconds
                        )
                    )
                )
            default:
                throw PersistenceError.integrityViolation
            }
        } catch {
            throw PersistenceError.integrityViolation
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(1, forKey: .schemaVersion)
        switch self {
        case let .active(active):
            try container.encode("active", forKey: .recordKind)
            try container.encode(active.runID, forKey: .runID)
            try container.encode(active.ownerID, forKey: .ownerID)
            try container.encode(active.fencingToken, forKey: .fencingToken)
            try container.encode(active.issuedAtMicroseconds, forKey: .issuedAtMicroseconds)
            try container.encode(active.expiresAtMicroseconds, forKey: .expiresAtMicroseconds)
        case let .released(released):
            try container.encode("released", forKey: .recordKind)
            try container.encode(released.runID, forKey: .runID)
            try container.encode(released.lastOwnerID, forKey: .lastOwnerID)
            try container.encode(released.fencingToken, forKey: .fencingToken)
            try container.encode(
                released.lastIssuedAtMicroseconds,
                forKey: .lastIssuedAtMicroseconds
            )
            try container.encode(
                released.lastExpiresAtMicroseconds,
                forKey: .lastExpiresAtMicroseconds
            )
            try container.encode(
                released.releasedAtMicroseconds,
                forKey: .releasedAtMicroseconds
            )
        }
    }

    func validate(expectedRunID: RunID) throws {
        switch self {
        case let .active(active):
            try active.validate(expectedRunID: expectedRunID)
        case let .released(released):
            try released.validate(expectedRunID: expectedRunID)
        }
    }

    func writerLease() throws -> WriterLease {
        switch self {
        case let .active(active): return try active.writerLease()
        case let .released(released): return try released.writerLease()
        }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case recordKind = "record_kind"
        case runID = "run_id"
        case ownerID = "owner_id"
        case fencingToken = "fencing_token"
        case issuedAtMicroseconds = "issued_at_unix_microseconds"
        case expiresAtMicroseconds = "expires_at_unix_microseconds"
        case lastOwnerID = "last_owner_id"
        case lastIssuedAtMicroseconds = "last_issued_at_unix_microseconds"
        case lastExpiresAtMicroseconds = "last_expires_at_unix_microseconds"
        case releasedAtMicroseconds = "released_at_unix_microseconds"

        static let activeKeys: Set<CodingKeys> = [
            .schemaVersion, .recordKind, .runID, .ownerID, .fencingToken,
            .issuedAtMicroseconds, .expiresAtMicroseconds,
        ]
        static let releasedKeys: Set<CodingKeys> = [
            .schemaVersion, .recordKind, .runID, .lastOwnerID, .fencingToken,
            .lastIssuedAtMicroseconds, .lastExpiresAtMicroseconds, .releasedAtMicroseconds,
        ]
    }
}

fileprivate final class StableLeaseLock: @unchecked Sendable {
    private let fileSystem: DescriptorRelativeFileSystem
    private let components: [String]
    private let name: String
    private let expectedIdentity: DescriptorEntryIdentity
    private let file: DescriptorRelativeFile
    private var locked = false

    init(
        fileSystem: DescriptorRelativeFileSystem,
        components: [String],
        name: String,
        expectedIdentity: DescriptorEntryIdentity
    ) throws {
        self.fileSystem = fileSystem
        self.components = components
        self.name = name
        self.expectedIdentity = expectedIdentity
        file = try fileSystem.openFile(named: name, in: components)
        guard file.metadata == expectedIdentity.metadata,
              file.metadata.permissions == 0o600,
              file.metadata.linkCount == 1,
              try fileSystem.entryIdentity(named: name, in: components) == expectedIdentity
        else { throw PersistenceError.integrityViolation }
        while true {
            if flock(file.fd, LOCK_EX) == 0 {
                locked = true
                break
            }
            if errno == EINTR { continue }
            throw persistencePOSIXError(errno)
        }
        try validate()
    }

    deinit {
        if locked { _ = flock(file.fd, LOCK_UN) }
    }

    func validate() throws {
        guard locked,
              try descriptorMatches(file.fd, metadata: expectedIdentity.metadata),
              try fileSystem.entryIdentity(named: name, in: components) == expectedIdentity
        else { throw PersistenceError.integrityViolation }
    }
}

fileprivate final class LeaseLockWitness: @unchecked Sendable {
    private let stateLock = NSLock()
    private let lock: StableLeaseLock
    private var active = true

    fileprivate init(lock: StableLeaseLock) {
        self.lock = lock
    }

    fileprivate func invalidate() {
        stateLock.withLock { active = false }
    }

    func validate() throws {
        guard stateLock.withLock({ active }) else {
            throw PersistenceError.fencingViolation
        }
        try lock.validate()
    }
}

private func prepareLeaseNamespace(
    fileSystem: DescriptorRelativeFileSystem,
    runID: RunID,
    barrier: any WorkflowDurabilityBarrier
) throws -> DescriptorEntryIdentity {
    let root = try fileSystem.rootDirectory()
    guard root.metadata.permissions == 0o700 else {
        throw PersistenceError.integrityViolation
    }
    try barrier.validateCapability(in: root.fd)
    var retained = [root]
    var parentComponents: [String] = []
    for component in LeaseStore.leaseComponents {
        let creation = try fileSystem.ensureDirectory(
            component,
            in: parentComponents,
            mode: 0o700
        )
        retained.append(creation.child)
        parentComponents.append(component)
    }
    let name = "\(runID.filesystemComponent).lock"
    let lock: DescriptorRelativeFile
    do {
        if let bytes = try fileSystem.readFileIfPresent(
            named: name,
            in: LeaseStore.leaseComponents
        ) {
            guard bytes.isEmpty else { throw PersistenceError.integrityViolation }
            lock = try fileSystem.openFile(named: name, in: LeaseStore.leaseComponents)
        } else {
            do {
                lock = try fileSystem.createFile(
                    data: Data(),
                    named: name,
                    in: LeaseStore.leaseComponents,
                    mode: 0o600
                )
            } catch let error as PersistenceError where error == .ioFailure(EEXIST) {
                lock = try fileSystem.openFile(named: name, in: LeaseStore.leaseComponents)
            }
        }
    }
    guard lock.metadata.permissions == 0o600,
          lock.metadata.linkCount == 1,
          try fileSystem.readFile(named: name, in: LeaseStore.leaseComponents).isEmpty
    else { throw PersistenceError.integrityViolation }
    var modified = retained.map {
        DurabilityTarget(directory: $0, requiredPermissions: 0o700)
    }
    modified.append(.init(file: lock, requiredPermissions: 0o600))
    try barrier.synchronize(
        DurabilityPlan(
            modified: modified,
            requiredDirectoryFDs: Set(retained.map(\.fd)),
            anchorFD: lock.fd,
            purpose: .bootstrapIdentity
        )
    )
    let identity = try fileSystem.entryIdentity(
        named: name,
        in: LeaseStore.leaseComponents
    )
    guard identity.metadata == lock.metadata else {
        throw PersistenceError.integrityViolation
    }
    return identity
}

private func decodeLeaseRecord(_ bytes: Data) throws -> LeaseRecord {
    do {
        let record = try CanonicalJSON.decode(LeaseRecord.self, from: bytes)
        guard try CanonicalJSON.encode(record) == bytes else {
            throw PersistenceError.integrityViolation
        }
        return record
    } catch {
        throw PersistenceError.integrityViolation
    }
}

private func date(fromUnixMicroseconds microseconds: Int64) -> Date {
    Date(timeIntervalSince1970: Double(microseconds) / 1_000_000)
}

private func descriptorMatches(
    _ fd: Int32,
    metadata: DescriptorObjectMetadata
) throws -> Bool {
    var value = stat()
    while true {
        if fstat(fd, &value) == 0 { break }
        if errno == EINTR { continue }
        throw persistencePOSIXError(errno)
    }
    return UInt64(value.st_dev) == metadata.device
        && UInt64(value.st_ino) == metadata.inode
        && (value.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG)
        && (value.st_mode & 0o777) == metadata.permissions
        && UInt64(value.st_nlink) == metadata.linkCount
}

private func descriptorLinkCount(_ fd: Int32) throws -> UInt64 {
    var value = stat()
    while true {
        if fstat(fd, &value) == 0 { return UInt64(value.st_nlink) }
        if errno == EINTR { continue }
        throw persistencePOSIXError(errno)
    }
}

private func readDescriptorBytes(_ fd: Int32) throws -> Data {
    guard lseek(fd, 0, SEEK_SET) >= 0 else { throw persistencePOSIXError(errno) }
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 16 * 1024)
    while true {
        let count = Darwin.read(fd, &buffer, buffer.count)
        if count > 0 {
            result.append(contentsOf: buffer.prefix(count))
        } else if count == 0 {
            return result
        } else if errno == EINTR {
            continue
        } else {
            throw persistencePOSIXError(errno)
        }
    }
}
