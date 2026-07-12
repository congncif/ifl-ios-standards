import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("LeaseStoreTests")
struct LeaseStoreTests {
    @Test("acquire, renew, and release preserve the exact canonical lease wire")
    func lifecycleAndWireContractAreExact() throws {
        let harness = try GenesisLeaseHarness.make()
        defer { harness.remove() }
        let issuedMicros: Int64 = 1_735_689_600_000_000
        let clock = LeaseTestClock(leaseTestDate(issuedMicros))
        let store = try LeaseStore.testing(
            workItemRoot: harness.workItemRoot,
            runID: harness.runID,
            barrier: TestDurabilityBarrier(trace: harness.barrierTrace),
            clock: { clock.sample() }
        )
        harness.barrierTrace.reset()
        let request = try LeaseRequest(
            runID: harness.runID,
            ownerID: "writer-a",
            ttlMicroseconds: 5_000_000
        )

        let acquired = try store.acquire(request)
        #expect(acquired.fencingToken.rawValue == 1)
        #expect(acquired.issuedAt == leaseTestDate(issuedMicros))
        #expect(acquired.expiresAt == leaseTestDate(issuedMicros + 5_000_000))
        #expect(clock.sampleCount == 1)
        #expect(try Data(contentsOf: leaseRecordURL(harness)) == activeLeaseRecordBytes(
            runID: harness.runID,
            ownerID: "writer-a",
            token: 1,
            issuedMicros: issuedMicros,
            expiresMicros: issuedMicros + 5_000_000
        ))

        let acquiredRetry = try store.acquire(request)
        #expect(acquiredRetry == acquired)
        #expect(clock.sampleCount == 2)

        let renewedMicros = issuedMicros + 1_000_000
        clock.set(leaseTestDate(renewedMicros))
        let renewed = try store.renew(acquired, ttlMicroseconds: 7_000_000)
        #expect(renewed.fencingToken == acquired.fencingToken)
        #expect(renewed.issuedAt == leaseTestDate(renewedMicros))
        #expect(renewed.expiresAt == leaseTestDate(renewedMicros + 7_000_000))
        #expect(try Data(contentsOf: leaseRecordURL(harness)) == activeLeaseRecordBytes(
            runID: harness.runID,
            ownerID: "writer-a",
            token: 1,
            issuedMicros: renewedMicros,
            expiresMicros: renewedMicros + 7_000_000
        ))
        #expect(throws: PersistenceError.staleLease) {
            try store.renew(acquired, ttlMicroseconds: 7_000_000)
        }

        let releasedMicros = renewedMicros + 1_000_000
        clock.set(leaseTestDate(releasedMicros))
        try store.release(renewed)
        let releasedBytes = releasedLeaseRecordBytes(
            runID: harness.runID,
            ownerID: "writer-a",
            token: 1,
            issuedMicros: renewedMicros,
            expiresMicros: renewedMicros + 7_000_000,
            releasedMicros: releasedMicros
        )
        #expect(try Data(contentsOf: leaseRecordURL(harness)) == releasedBytes)
        #expect(leaseRecordKeys(releasedBytes) == [
            "schema_version", "record_kind", "run_id", "last_owner_id", "fencing_token",
            "last_issued_at_unix_microseconds", "last_expires_at_unix_microseconds",
            "released_at_unix_microseconds",
        ])

        clock.set(leaseTestDate(releasedMicros + 1_000_000))
        try store.release(renewed)
        #expect(try Data(contentsOf: leaseRecordURL(harness)) == releasedBytes)
        #expect(throws: PersistenceError.staleLease) {
            try store.release(acquired)
        }
    }

    @Test("exact expiry and released reacquisition advance the high-water token once")
    func expiryAndReacquisitionAreChecked() throws {
        let harness = try GenesisLeaseHarness.make()
        defer { harness.remove() }
        let start: Int64 = 2_000_000_000_000_000
        let clock = LeaseTestClock(leaseTestDate(start))
        let store = try LeaseStore.testing(
            workItemRoot: harness.workItemRoot,
            runID: harness.runID,
            barrier: TestDurabilityBarrier(trace: harness.barrierTrace),
            clock: { clock.sample() }
        )
        let first = try store.acquire(LeaseRequest(
            runID: harness.runID,
            ownerID: "writer-one",
            ttlMicroseconds: 10
        ))

        clock.set(leaseTestDate(start + 9))
        let earlyBytes = try Data(contentsOf: leaseRecordURL(harness))
        #expect(throws: PersistenceError.blockedEnvironment) {
            try store.recover(LeaseRequest(
                runID: harness.runID,
                ownerID: "writer-one",
                ttlMicroseconds: 20
            ))
        }
        #expect(try Data(contentsOf: leaseRecordURL(harness)) == earlyBytes)
        #expect(throws: PersistenceError.blockedEnvironment) {
            try store.recover(LeaseRequest(
                runID: harness.runID,
                ownerID: "writer-two",
                ttlMicroseconds: 20
            ))
        }

        clock.set(leaseTestDate(start + 10))
        let recovered = try store.recover(LeaseRequest(
            runID: harness.runID,
            ownerID: "writer-two",
            ttlMicroseconds: 20
        ))
        #expect(recovered.fencingToken.rawValue == 2)
        #expect(recovered.issuedAt == leaseTestDate(start + 10))
        #expect(recovered.expiresAt == leaseTestDate(start + 30))
        #expect(throws: PersistenceError.staleLease) {
            try store.release(first)
        }

        clock.set(leaseTestDate(start + 11))
        try store.release(recovered)
        let released = try Data(contentsOf: leaseRecordURL(harness))
        clock.set(leaseTestDate(start + 12))
        let reacquired = try store.acquire(LeaseRequest(
            runID: harness.runID,
            ownerID: "writer-three",
            ttlMicroseconds: 30
        ))
        #expect(reacquired.fencingToken.rawValue == 3)
        #expect(try Data(contentsOf: leaseRecordURL(harness)) != released)
    }

    @Test("wrong identities, stale full lease fields, and malformed records do not mutate")
    func invalidInputsFailClosed() throws {
        let harness = try GenesisLeaseHarness.make()
        defer { harness.remove() }
        let nowMicros: Int64 = 1_900_000_000_000_000
        let clock = LeaseTestClock(leaseTestDate(nowMicros))
        let store = try LeaseStore.testing(
            workItemRoot: harness.workItemRoot,
            runID: harness.runID,
            barrier: TestDurabilityBarrier(trace: harness.barrierTrace),
            clock: { clock.sample() }
        )
        let lease = try store.acquire(LeaseRequest(
            runID: harness.runID,
            ownerID: "authoritative-writer",
            ttlMicroseconds: 100
        ))
        let authoritativeBytes = try Data(contentsOf: leaseRecordURL(harness))

        #expect(throws: PersistenceError.invalidLease) {
            _ = try LeaseRequest(
                runID: harness.runID,
                ownerID: "invalid/owner",
                ttlMicroseconds: 1
            )
        }
        #expect(throws: PersistenceError.invalidLease) {
            _ = try LeaseRequest(
                runID: harness.runID,
                ownerID: "writer",
                ttlMicroseconds: 0
            )
        }
        #expect(throws: PersistenceError.invalidLease) {
            try store.acquire(LeaseRequest(
                runID: RunID(rawValue: UUID()),
                ownerID: "writer",
                ttlMicroseconds: 1
            ))
        }

        let wrongOwner = try WriterLease(
            runID: harness.runID,
            ownerID: "different-writer",
            fencingToken: lease.fencingToken,
            issuedAt: lease.issuedAt,
            expiresAt: lease.expiresAt
        )
        #expect(throws: PersistenceError.staleLease) {
            try store.renew(wrongOwner, ttlMicroseconds: 100)
        }
        let wrongToken = try WriterLease(
            runID: harness.runID,
            ownerID: lease.ownerID,
            fencingToken: FencingToken(validating: 2),
            issuedAt: lease.issuedAt,
            expiresAt: lease.expiresAt
        )
        #expect(throws: PersistenceError.staleLease) {
            try store.release(wrongToken)
        }
        let wrongDates = try WriterLease(
            runID: harness.runID,
            ownerID: lease.ownerID,
            fencingToken: lease.fencingToken,
            issuedAt: lease.issuedAt,
            expiresAt: leaseTestDate(nowMicros + 101)
        )
        #expect(throws: PersistenceError.staleLease) {
            try store.renew(wrongDates, ttlMicroseconds: 100)
        }
        #expect(try Data(contentsOf: leaseRecordURL(harness)) == authoritativeBytes)

        let malformed = Data(authoritativeBytes.dropLast()) + Data(",\"unexpected\":true}".utf8)
        try writeLeaseRecord(malformed, for: harness)
        #expect(throws: PersistenceError.integrityViolation) {
            try store.renew(lease, ttlMicroseconds: 100)
        }
        #expect(try Data(contentsOf: leaseRecordURL(harness)) == malformed)
    }

    @Test("timestamp and fencing-token overflow fail before lease mutation")
    func checkedArithmeticRejectsOverflow() throws {
        let timeHarness = try GenesisLeaseHarness.make()
        defer { timeHarness.remove() }
        let extremeClock = LeaseTestClock(
            Date(timeIntervalSince1970: Double(Int64.max) / 1_000_000)
        )
        let timeStore = try LeaseStore.testing(
            workItemRoot: timeHarness.workItemRoot,
            runID: timeHarness.runID,
            barrier: TestDurabilityBarrier(trace: timeHarness.barrierTrace),
            clock: { extremeClock.sample() }
        )
        #expect(throws: PersistenceError.invalidLease) {
            try timeStore.acquire(LeaseRequest(
                runID: timeHarness.runID,
                ownerID: "overflow-writer",
                ttlMicroseconds: 1
            ))
        }
        #expect(!FileManager.default.fileExists(atPath: leaseRecordURL(timeHarness).path))

        let tokenHarness = try GenesisLeaseHarness.make()
        defer { tokenHarness.remove() }
        let nowMicros: Int64 = 1_700_000_000_000_000
        let tokenStore = try LeaseStore.testing(
            workItemRoot: tokenHarness.workItemRoot,
            runID: tokenHarness.runID,
            barrier: TestDurabilityBarrier(trace: tokenHarness.barrierTrace),
            clock: { leaseTestDate(nowMicros) }
        )
        let maximum = releasedLeaseRecordBytes(
            runID: tokenHarness.runID,
            ownerID: "last-writer",
            token: UInt64.max,
            issuedMicros: nowMicros - 20,
            expiresMicros: nowMicros - 10,
            releasedMicros: nowMicros - 11
        )
        try writeLeaseRecord(maximum, for: tokenHarness)
        #expect(throws: PersistenceError.invalidLease) {
            try tokenStore.acquire(LeaseRequest(
                runID: tokenHarness.runID,
                ownerID: "next-writer",
                ttlMicroseconds: 10
            ))
        }
        #expect(try Data(contentsOf: leaseRecordURL(tokenHarness)) == maximum)
    }

    @Test("record path substitution after retained descriptor validation is never authority")
    func retainedDescriptorRejectsPathSwap() throws {
        let harness = try GenesisLeaseHarness.make()
        defer { harness.remove() }
        let now: Int64 = 1_800_000_000_000_000
        let initial = try LeaseStore.testing(
            workItemRoot: harness.workItemRoot,
            runID: harness.runID,
            barrier: TestDurabilityBarrier(trace: harness.barrierTrace),
            clock: { leaseTestDate(now) }
        )
        let lease = try initial.acquire(LeaseRequest(
            runID: harness.runID,
            ownerID: "retained-writer",
            ttlMicroseconds: 1_000_000
        ))
        let authoritative = try Data(contentsOf: leaseRecordURL(harness))
        let replacement = activeLeaseRecordBytes(
            runID: harness.runID,
            ownerID: "replacement-writer",
            token: 2,
            issuedMicros: now,
            expiresMicros: now + 1_000_000
        )
        let substituter = LeaseRecordSubstituter(
            recordURL: leaseRecordURL(harness),
            replacement: replacement
        )
        let hooked = try LeaseStore.testing(
            workItemRoot: harness.workItemRoot,
            runID: harness.runID,
            barrier: TestDurabilityBarrier(trace: harness.barrierTrace),
            clock: { leaseTestDate(now + 1) },
            faultInjector: LeaseStoreFaultInjector { point in
                if point == .recordDescriptorValidated {
                    try substituter.replaceOnce()
                }
            }
        )
        #expect(throws: PersistenceError.integrityViolation) {
            try hooked.renew(lease, ttlMicroseconds: 1_000_000)
        }
        #expect(try Data(contentsOf: leaseRecordURL(harness)) == replacement)
        #expect(try Data(contentsOf: substituter.displacedURL) == authoritative)
    }

    @Test("closed lease wire rejects bounded malformed variants without mutation")
    func malformedWireMatrixIsClosed() throws {
        let issued: Int64 = 1_800_000_000_000_000
        let expires = issued + 1_000_000
        let wrongRunID = RunID(rawValue: UUID()).filesystemComponent
        let cases: [(String, (RunID) -> Data)] = [
            ("missing", { runID in Data(
                ("{\"expires_at_unix_microseconds\":\(expires),"
                    + "\"fencing_token\":1,"
                    + "\"issued_at_unix_microseconds\":\(issued),"
                    + "\"record_kind\":\"active\","
                    + "\"run_id\":\"\(runID.filesystemComponent)\","
                    + "\"schema_version\":1}").utf8
            ) }),
            ("inapplicable", { runID in Data(activeLeaseRecordBytes(
                runID: runID, ownerID: "wire-writer", token: 1,
                issuedMicros: issued, expiresMicros: expires
            ).dropLast()) + Data(",\"last_owner_id\":\"wire-writer\"}".utf8) }),
            ("null", { runID in Data(String(decoding: activeLeaseRecordBytes(
                runID: runID, ownerID: "wire-writer", token: 1,
                issuedMicros: issued, expiresMicros: expires
            ), as: UTF8.self).replacingOccurrences(
                of: "\"owner_id\":\"wire-writer\"", with: "\"owner_id\":null"
            ).utf8) }),
            ("unknown", { runID in Data(activeLeaseRecordBytes(
                runID: runID, ownerID: "wire-writer", token: 1,
                issuedMicros: issued, expiresMicros: expires
            ).dropLast()) + Data(",\"unknown\":1}".utf8) }),
            ("noncanonical", { runID in Data(" ".utf8) + activeLeaseRecordBytes(
                runID: runID, ownerID: "wire-writer", token: 1,
                issuedMicros: issued, expiresMicros: expires
            ) }),
            ("wrong-run", { runID in Data(String(decoding: activeLeaseRecordBytes(
                runID: runID, ownerID: "wire-writer", token: 1,
                issuedMicros: issued, expiresMicros: expires
            ), as: UTF8.self).replacingOccurrences(
                of: runID.filesystemComponent, with: wrongRunID
            ).utf8) }),
            ("wrong-owner", { runID in activeLeaseRecordBytes(
                runID: runID, ownerID: "bad/owner", token: 1,
                issuedMicros: issued, expiresMicros: expires
            ) }),
            ("zero-token", { runID in activeLeaseRecordBytes(
                runID: runID, ownerID: "wire-writer", token: 0,
                issuedMicros: issued, expiresMicros: expires
            ) }),
            ("time-order", { runID in activeLeaseRecordBytes(
                runID: runID, ownerID: "wire-writer", token: 1,
                issuedMicros: expires, expiresMicros: issued
            ) }),
        ]

        for (_, makeBytes) in cases {
            let harness = try GenesisLeaseHarness.make()
            defer { harness.remove() }
            let store = try LeaseStore.testing(
                workItemRoot: harness.workItemRoot,
                runID: harness.runID,
                barrier: TestDurabilityBarrier(trace: harness.barrierTrace),
                clock: { leaseTestDate(expires) }
            )
            let bytes = makeBytes(harness.runID)
            try writeLeaseRecord(bytes, for: harness)
            #expect(throws: PersistenceError.integrityViolation) {
                try store.recover(LeaseRequest(
                    runID: harness.runID,
                    ownerID: "wire-writer",
                    ttlMicroseconds: 100
                ))
            }
            #expect(try Data(contentsOf: leaseRecordURL(harness)) == bytes)
            #expect(!FileManager.default.fileExists(atPath: harness.runRoot.path))
        }
    }

    @Test("fractional and nonfinite clocks are single-sampled and checked")
    func clockConversionMatrixIsExact() throws {
        let fractional = try GenesisLeaseHarness.make()
        defer { fractional.remove() }
        let sampled = Date(timeIntervalSince1970: 1_800_000_000.0000019)
        let clock = LeaseTestClock(sampled)
        let store = try LeaseStore.testing(
            workItemRoot: fractional.workItemRoot,
            runID: fractional.runID,
            barrier: TestDurabilityBarrier(trace: fractional.barrierTrace),
            clock: { clock.sample() }
        )
        let lease = try store.acquire(LeaseRequest(
            runID: fractional.runID,
            ownerID: "fractional-writer",
            ttlMicroseconds: 100
        ))
        let expected = Int64((sampled.timeIntervalSince1970 * 1_000_000).rounded(.towardZero))
        #expect(lease.issuedAt == leaseTestDate(expected))
        #expect(clock.sampleCount == 1)
        #expect(throws: PersistenceError.blockedEnvironment) {
            try store.recover(LeaseRequest(
                runID: fractional.runID,
                ownerID: "fractional-writer",
                ttlMicroseconds: 100
            ))
        }
        #expect(clock.sampleCount == 2)
        clock.set(leaseTestDate(expected + 1))
        let renewed = try store.renew(lease, ttlMicroseconds: 100)
        #expect(clock.sampleCount == 3)
        try store.release(renewed)
        #expect(clock.sampleCount == 4)

        let negative = try GenesisLeaseHarness.make()
        defer { negative.remove() }
        let canonicalNegativeMicros: Int64 = -15_625
        let negativeSample = leaseTestDate(canonicalNegativeMicros)
            .addingTimeInterval(-0.0000009)
        let negativeClock = LeaseTestClock(negativeSample)
        let negativeStore = try LeaseStore.testing(
            workItemRoot: negative.workItemRoot,
            runID: negative.runID,
            barrier: TestDurabilityBarrier(trace: negative.barrierTrace),
            clock: { negativeClock.sample() }
        )
        let negativeLease = try negativeStore.acquire(LeaseRequest(
            runID: negative.runID,
            ownerID: "negative-fractional-writer",
            ttlMicroseconds: 15_625
        ))
        let negativeScaled = negativeSample.timeIntervalSince1970 * 1_000_000
        let towardZero = Int64(negativeScaled.rounded(.towardZero))
        let floor = Int64(negativeScaled.rounded(.down))
        #expect(towardZero != floor)
        #expect(negativeLease.issuedAt == leaseTestDate(towardZero))
        #expect(negativeLease.issuedAt != leaseTestDate(floor))
        #expect(negativeClock.sampleCount == 1)

        let nonfinite = try GenesisLeaseHarness.make()
        defer { nonfinite.remove() }
        let nonfiniteClock = LeaseTestClock(Date(timeIntervalSince1970: .infinity))
        let nonfiniteStore = try LeaseStore.testing(
            workItemRoot: nonfinite.workItemRoot,
            runID: nonfinite.runID,
            barrier: TestDurabilityBarrier(trace: nonfinite.barrierTrace),
            clock: { nonfiniteClock.sample() }
        )
        #expect(throws: PersistenceError.invalidLease) {
            try nonfiniteStore.acquire(LeaseRequest(
                runID: nonfinite.runID,
                ownerID: "nonfinite-writer",
                ttlMicroseconds: 100
            ))
        }
        #expect(nonfiniteClock.sampleCount == 1)
        #expect(!FileManager.default.fileExists(atPath: nonfinite.recordURL.path))
    }

    @Test("facade persistence operations sample the clock exactly once each")
    func facadePersistenceOperationsSampleClockOnce() throws {
        let harness = try FencedPersistenceHarness.make()
        defer { harness.remove() }
        let clock = LeaseTestClock(leaseTestDate(harness.nowMicroseconds))
        let store = try LeaseStore.testing(
            paths: harness.paths,
            barrier: TestDurabilityBarrier(trace: harness.barrierTrace),
            clock: { clock.sample() }
        )
        #expect(clock.sampleCount == 0)

        let beforeCommit = clock.sampleCount
        _ = try store.commit(harness.transaction, lease: harness.initialLease)
        #expect(clock.sampleCount == beforeCommit + 1)

        let beforeLoad = clock.sampleCount
        _ = try store.load(runID: harness.runID, from: harness.paths.runRoot)
        #expect(clock.sampleCount == beforeLoad + 1)

        let beforeRecover = clock.sampleCount
        _ = try store.recover(runID: harness.runID, from: harness.paths.runRoot)
        #expect(clock.sampleCount == beforeRecover + 1)
    }
}

final class LeaseTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var instant: Date
    private var count = 0

    init(_ instant: Date) {
        self.instant = instant
    }

    var sampleCount: Int {
        lock.withLock { count }
    }

    func set(_ instant: Date) {
        lock.withLock { self.instant = instant }
    }

    func sample() -> Date {
        lock.withLock {
            count += 1
            return instant
        }
    }
}

final class LeaseRecordSubstituter: @unchecked Sendable {
    let displacedURL: URL
    private let lock = NSLock()
    private let recordURL: URL
    private let replacement: Data
    private var replaced = false

    init(recordURL: URL, replacement: Data) {
        self.recordURL = recordURL
        self.replacement = replacement
        displacedURL = recordURL.appendingPathExtension("displaced")
    }

    func replaceOnce() throws {
        let shouldReplace = lock.withLock { () -> Bool in
            guard !replaced else { return false }
            replaced = true
            return true
        }
        guard shouldReplace else { return }
        try FileManager.default.moveItem(at: recordURL, to: displacedURL)
        try replacement.write(to: recordURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: recordURL.path
        )
    }
}

func leaseTestDate(_ microseconds: Int64) -> Date {
    Date(timeIntervalSince1970: Double(microseconds) / 1_000_000)
}

protocol LeasePathHarness {
    var workItemRoot: URL { get }
    var runID: RunID { get }
}

extension PersistenceHarness: LeasePathHarness {}
extension GenesisLeaseHarness: LeasePathHarness {}

struct FencedPersistenceHarness: LeasePathHarness, @unchecked Sendable {
    let genesis: GenesisLeaseHarness
    let paths: RunPaths
    let initialLease: WriterLease
    let transaction: StateTransaction
    let nowMicroseconds: Int64

    var workItemRoot: URL { genesis.workItemRoot }
    var runID: RunID { genesis.runID }
    var barrierTrace: TestBarrierTrace { genesis.barrierTrace }

    static func make(
        ownerID: String = "fenced-writer",
        nowMicroseconds: Int64 = 1_800_000_000_000_000,
        ttlMicroseconds: Int64 = 300_000_000
    ) throws -> FencedPersistenceHarness {
        let genesis = try GenesisLeaseHarness.make()
        do {
            let authority = try LeaseStore.testing(
                workItemRoot: genesis.workItemRoot,
                runID: genesis.runID,
                barrier: TestDurabilityBarrier(trace: genesis.barrierTrace),
                clock: { leaseTestDate(nowMicroseconds) }
            )
            let lease = try authority.acquire(LeaseRequest(
                runID: genesis.runID,
                ownerID: ownerID,
                ttlMicroseconds: ttlMicroseconds
            ))
            let paths = try RunPaths.prepareForTesting(
                workItemRoot: genesis.workItemRoot,
                runID: genesis.runID,
                barrier: TestDurabilityBarrier(trace: genesis.barrierTrace)
            )
            return FencedPersistenceHarness(
                genesis: genesis,
                paths: paths,
                initialLease: lease,
                transaction: try makeGenesisTransaction(paths: paths),
                nowMicroseconds: nowMicroseconds
            )
        } catch {
            genesis.remove()
            throw error
        }
    }

    func makeRawStore(
        faultInjector: PersistenceFaultInjector = .none,
        clock: @escaping @Sendable () -> Date? = { nil }
    ) throws -> FileRunStateStore {
        try FileRunStateStore.testing(
            paths: paths,
            barrier: TestDurabilityBarrier(trace: barrierTrace),
            faultInjector: faultInjector,
            clock: { clock() ?? leaseTestDate(nowMicroseconds) }
        )
    }

    func remove() {
        genesis.remove()
    }
}

func leaseRecordURL(_ harness: some LeasePathHarness) -> URL {
    leaseRecordURL(workItemRoot: harness.workItemRoot, runID: harness.runID)
}

func leaseRecordURL(workItemRoot: URL, runID: RunID) -> URL {
    workItemRoot
        .appendingPathComponent("artifacts/workflow/leases", isDirectory: true)
        .appendingPathComponent("\(runID.filesystemComponent).json", isDirectory: false)
}

func leasePendingURL(_ harness: some LeasePathHarness) -> URL {
    leaseRecordURL(harness).appendingPathExtension("pending")
}

func leaseLockURL(_ harness: some LeasePathHarness) -> URL {
    leaseRecordURL(harness)
        .deletingLastPathComponent()
        .appendingPathComponent("\(harness.runID.filesystemComponent).lock")
}

func activeLeaseRecordBytes(
    runID: RunID,
    ownerID: String,
    token: UInt64,
    issuedMicros: Int64,
    expiresMicros: Int64
) -> Data {
    var json = "{\"expires_at_unix_microseconds\":\(expiresMicros),"
    json += "\"fencing_token\":\(token),"
    json += "\"issued_at_unix_microseconds\":\(issuedMicros),"
    json += "\"owner_id\":\"\(ownerID)\","
    json += "\"record_kind\":\"active\","
    json += "\"run_id\":\"\(runID.filesystemComponent)\","
    json += "\"schema_version\":1}"
    return Data(json.utf8)
}

func releasedLeaseRecordBytes(
    runID: RunID,
    ownerID: String,
    token: UInt64,
    issuedMicros: Int64,
    expiresMicros: Int64,
    releasedMicros: Int64
) -> Data {
    var json = "{\"fencing_token\":\(token),"
    json += "\"last_expires_at_unix_microseconds\":\(expiresMicros),"
    json += "\"last_issued_at_unix_microseconds\":\(issuedMicros),"
    json += "\"last_owner_id\":\"\(ownerID)\","
    json += "\"record_kind\":\"released\","
    json += "\"released_at_unix_microseconds\":\(releasedMicros),"
    json += "\"run_id\":\"\(runID.filesystemComponent)\","
    json += "\"schema_version\":1}"
    return Data(json.utf8)
}

func writeLeaseRecord(_ bytes: Data, for harness: some LeasePathHarness) throws {
    let url = leaseRecordURL(harness)
    try bytes.write(to: url)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: url.path
    )
}

func leaseRecordKeys(_ bytes: Data) -> Set<String> {
    guard let object = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any]
    else { return [] }
    return Set(object.keys)
}
