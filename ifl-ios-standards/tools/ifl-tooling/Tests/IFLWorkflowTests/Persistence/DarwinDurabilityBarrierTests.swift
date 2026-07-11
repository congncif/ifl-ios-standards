import Darwin
import Foundation
import IFLContracts
@testable import IFLWorkflow
import Testing

@Suite("DarwinDurabilityBarrierTests")
struct DarwinDurabilityBarrierTests {
    @Test("EINTR is retried and every file/directory fsync precedes one full anchor barrier")
    func retriesAndOrdersBarrier() throws {
        let trace = DurabilityCallTrace()
        let calls = DurabilitySystemCalls(
            metadata: { fd in
                DurabilityDescriptorMetadata(
                    device: 7,
                    kind: fd == 11 ? .directory : .regularFile,
                    linkCount: 1
                )
            },
            fsync: { fd in
                let attempt = trace.record("fsync:\(fd)")
                if fd == 10, attempt == 1 { throw DarwinCallError.interrupted }
            },
            fullFSync: { fd in _ = trace.record("full:\(fd)") }
        )
        let plan = try DurabilityPlan(
            modified: [
                .init(fd: 10, kind: .regularFile),
                .init(fd: 11, kind: .directory),
                .init(fd: 12, kind: .regularFile),
            ],
            requiredDirectoryFDs: [11],
            anchorFD: 12,
            purpose: .payloadPublication
        )
        try DarwinDurabilityBarrier(systemCalls: calls).synchronize(plan)
        #expect(plan.purpose == .payloadPublication)
        #expect(trace.values == ["fsync:10", "fsync:10", "fsync:11", "fsync:12", "full:12"])
    }

    @Test("missing directory coverage, cross-volume, symlink, and hardlink anchors fail closed")
    func rejectsInvalidPlansAndAnchors() throws {
        let base = try DurabilityPlan(
            modified: [.init(fd: 20, kind: .directory), .init(fd: 21, kind: .regularFile)],
            requiredDirectoryFDs: [20],
            anchorFD: 21
        )
        let noOp: @Sendable (Int32) throws -> Void = { _ in }

        #expect(throws: DurabilityBarrierError.integrityViolation) {
            try DurabilityPlan(
                modified: [.init(fd: 21, kind: .regularFile)],
                requiredDirectoryFDs: [20],
                anchorFD: 21
            )
        }
        #expect(throws: DurabilityBarrierError.integrityViolation) {
            try DurabilityPlan(
                modified: [
                    .init(fd: 20, kind: .directory),
                    .init(fd: 22, kind: .directory),
                    .init(fd: 21, kind: .regularFile),
                ],
                requiredDirectoryFDs: [20],
                anchorFD: 21,
                purpose: .payloadPublication
            )
        }
        #expect(throws: DurabilityBarrierError.integrityViolation) {
            try DurabilityPlan(
                modified: [.init(fd: 23, kind: .other)],
                requiredDirectoryFDs: [],
                anchorFD: 23,
                purpose: .payloadPublication
            )
        }
        for anchorMetadata in [
            DurabilityDescriptorMetadata(device: 8, kind: .regularFile, linkCount: 1),
            DurabilityDescriptorMetadata(device: 7, kind: .symbolicLink, linkCount: 1),
            DurabilityDescriptorMetadata(device: 7, kind: .regularFile, linkCount: 2),
        ] {
            let calls = DurabilitySystemCalls(
                metadata: { fd in
                    if fd == 21 { return anchorMetadata }
                    return DurabilityDescriptorMetadata(device: 7, kind: .directory, linkCount: 1)
                },
                fsync: noOp,
                fullFSync: noOp
            )
            #expect(throws: DurabilityBarrierError.integrityViolation) {
                try DarwinDurabilityBarrier(systemCalls: calls).synchronize(base)
            }
        }
    }

    @Test("plain fsync success cannot mask unsupported full durability capability")
    func unsupportedFullBarrierIsBlockedEnvironment() throws {
        let calls = DurabilitySystemCalls(
            metadata: { fd in
                DurabilityDescriptorMetadata(
                    device: 1,
                    kind: fd == 30 ? .directory : .regularFile,
                    linkCount: 1
                )
            },
            fsync: { _ in },
            fullFSync: { _ in throw DarwinCallError.unsupported }
        )
        let plan = try DurabilityPlan(
            modified: [.init(fd: 30, kind: .directory), .init(fd: 31, kind: .regularFile)],
            requiredDirectoryFDs: [30],
            anchorFD: 31
        )
        #expect(throws: DurabilityBarrierError.blockedEnvironment) {
            try DarwinDurabilityBarrier(systemCalls: calls).synchronize(plan)
        }
        #expect(DurabilityBarrierError.blockedEnvironment.exitCode == .blockedEnvironment)
    }

    @Test("a hardlinked non-anchor data target cannot receive a durable receipt")
    func rejectsHardlinkedDataTarget() throws {
        let calls = DurabilitySystemCalls(
            metadata: { fd in
                switch fd {
                case 40:
                    DurabilityDescriptorMetadata(device: 1, kind: .regularFile, linkCount: 2)
                case 41:
                    DurabilityDescriptorMetadata(device: 1, kind: .directory, linkCount: 1)
                default:
                    DurabilityDescriptorMetadata(device: 1, kind: .regularFile, linkCount: 1)
                }
            },
            fsync: { _ in },
            fullFSync: { _ in }
        )
        let plan = try DurabilityPlan(
            modified: [
                .init(fd: 40, kind: .regularFile),
                .init(fd: 41, kind: .directory),
                .init(fd: 42, kind: .regularFile),
            ],
            requiredDirectoryFDs: [41],
            anchorFD: 42
        )
        #expect(throws: DurabilityBarrierError.integrityViolation) {
            try DarwinDurabilityBarrier(systemCalls: calls).synchronize(plan)
        }
    }

    @Test("persistent and controlled-unlinked link roles are distinct and mode-bound")
    func validatesRolesAndModes() throws {
        let calls = DurabilitySystemCalls(
            metadata: { fd in
                switch fd {
                case 50:
                    DurabilityDescriptorMetadata(
                        device: 1,
                        inode: 50,
                        kind: .directory,
                        permissions: 0o755,
                        linkCount: 2
                    )
                case 51:
                    DurabilityDescriptorMetadata(
                        device: 1,
                        inode: 51,
                        kind: .regularFile,
                        permissions: 0o600,
                        linkCount: 0
                    )
                default:
                    DurabilityDescriptorMetadata(
                        device: 1,
                        inode: 52,
                        kind: .regularFile,
                        permissions: 0o600,
                        linkCount: 1
                    )
                }
            },
            fsync: { _ in },
            fullFSync: { _ in }
        )
        #expect(throws: DurabilityBarrierError.integrityViolation) {
            try DarwinDurabilityBarrier(systemCalls: calls).synchronize(
                DurabilityPlan(
                    modified: [
                        .init(fd: 50, kind: .directory, requiredPermissions: 0o700),
                        .init(fd: 51, kind: .regularFile, linkRole: .persistent),
                    ],
                    requiredDirectoryFDs: [50],
                    anchorFD: 51,
                    purpose: .bootstrapComponent
                )
            )
        }

        let validCalls = DurabilitySystemCalls(
            metadata: { fd in
                DurabilityDescriptorMetadata(
                    device: 1,
                    inode: UInt64(fd),
                    kind: fd == 50 ? .directory : .regularFile,
                    permissions: fd == 50 ? 0o700 : 0o600,
                    linkCount: fd == 51 ? 0 : 2
                )
            },
            fsync: { _ in },
            fullFSync: { _ in }
        )
        let plan = try DurabilityPlan(
            modified: [
                .init(fd: 50, kind: .directory, requiredPermissions: 0o700),
                .init(fd: 51, kind: .regularFile, linkRole: .controlledUnlinked),
            ],
            requiredDirectoryFDs: [50],
            anchorFD: 51,
            purpose: .bootstrapComponent
        )
        try DarwinDurabilityBarrier(systemCalls: validCalls).synchronize(plan)
    }

    @Test("descriptor identity is verified both before and after synchronization")
    func rejectsIdentityChangeDuringBarrier() throws {
        let trace = DurabilityMetadataTrace()
        let calls = DurabilitySystemCalls(
            metadata: { fd in
                let attempt = trace.next(fd)
                return DurabilityDescriptorMetadata(
                    device: 1,
                    inode: UInt64(fd + (attempt > 1 ? 100 : 0)),
                    kind: fd == 60 ? .directory : .regularFile,
                    permissions: fd == 60 ? 0o700 : 0o600,
                    linkCount: fd == 60 ? 2 : 1
                )
            },
            fsync: { _ in },
            fullFSync: { _ in }
        )
        let plan = try DurabilityPlan(
            modified: [
                .init(fd: 60, kind: .directory, requiredPermissions: 0o700),
                .init(fd: 61, kind: .regularFile),
            ],
            requiredDirectoryFDs: [60],
            anchorFD: 61,
            purpose: .statePublication
        )
        #expect(throws: DurabilityBarrierError.integrityViolation) {
            try DarwinDurabilityBarrier(systemCalls: calls).synchronize(plan)
        }
    }

    @Test("durability targets retain descriptor owners and their expected identities through the barrier")
    func planRetainsDescriptorOwners() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ifl-barrier-owner-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let fileSystem = try DescriptorRelativeFileSystem(rootURL: root)
        var directory: DescriptorRelativeDirectory? = try fileSystem.rootDirectory()
        var anchor: DescriptorRelativeFile? = try fileSystem.createFile(
            data: Data("anchor".utf8),
            named: "anchor",
            in: [],
            mode: 0o600
        )
        let directoryFD = try #require(directory).fd
        let anchorFD = try #require(anchor).fd
        var plan: DurabilityPlan? = try DurabilityPlan(
            modified: [
                DurabilityTarget(
                    directory: try #require(directory),
                    requiredPermissions: 0o700
                ),
                DurabilityTarget(
                    file: try #require(anchor),
                    kind: .regularFile,
                    linkRole: .persistent,
                    requiredPermissions: 0o600
                ),
            ],
            requiredDirectoryFDs: [directoryFD],
            anchorFD: anchorFD,
            purpose: .payloadPublication
        )
        directory = nil
        anchor = nil

        #expect(fcntl(directoryFD, F_GETFD) >= 0)
        #expect(fcntl(anchorFD, F_GETFD) >= 0)
        let calls = DurabilitySystemCalls(
            metadata: residualDescriptorMetadata,
            fsync: { _ in },
            fullFSync: { _ in }
        )
        try DarwinDurabilityBarrier(systemCalls: calls).synchronize(try #require(plan))

        plan = nil
        errno = 0
        #expect(fcntl(anchorFD, F_GETFD) == -1)
        #expect(errno == EBADF)
    }

    @Test("a fresh capability probe is open-unlinked and every operation failure fails closed")
    func capabilityProbeUsesOpenUnlinkedAnchor() throws {
        try exerciseCapabilityProbe(failure: nil)
        for failure in CapabilityProbeFailure.allCases {
            try exerciseCapabilityProbe(failure: failure)
        }
    }
}

final class DurabilityCallTrace: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var values: [String] { lock.withLock { storage } }

    @discardableResult
    func record(_ value: String) -> Int {
        lock.withLock {
            storage.append(value)
            return storage.filter { $0 == value }.count
        }
    }
}

final class DurabilityMetadataTrace: @unchecked Sendable {
    private let lock = NSLock()
    private var attempts: [Int32: Int] = [:]

    func next(_ fd: Int32) -> Int {
        lock.withLock {
            attempts[fd, default: 0] += 1
            return attempts[fd, default: 0]
        }
    }
}

private func residualDescriptorMetadata(_ fd: Int32) throws -> DurabilityDescriptorMetadata {
    var value = stat()
    guard fstat(fd, &value) == 0 else { throw DarwinCallError.failure(errno) }
    let kind: DurabilityDescriptorKind
    switch value.st_mode & mode_t(S_IFMT) {
    case mode_t(S_IFREG): kind = .regularFile
    case mode_t(S_IFDIR): kind = .directory
    case mode_t(S_IFLNK): kind = .symbolicLink
    default: kind = .other
    }
    return DurabilityDescriptorMetadata(
        device: UInt64(value.st_dev),
        inode: UInt64(value.st_ino),
        kind: kind,
        permissions: value.st_mode & 0o777,
        linkCount: UInt64(value.st_nlink)
    )
}

private func residualProbeWrite(_ fd: Int32) throws {
    var byte: UInt8 = 0x0A
    while true {
        let result = Darwin.write(fd, &byte, 1)
        if result == 1 { return }
        if result < 0, errno == EINTR { continue }
        throw DarwinCallError.failure(errno)
    }
}

private func residualProbeUnlink(_ directoryFD: Int32, _ name: String) throws {
    try name.withCString { pointer in
        while true {
            if unlinkat(directoryFD, pointer, 0) == 0 { return }
            if errno == EINTR { continue }
            throw DarwinCallError.failure(errno)
        }
    }
}

private enum CapabilityProbeFailure: CaseIterable, Sendable {
    case write
    case unlink
    case barrier
    case close

    var code: Int32 {
        switch self {
        case .write: EIO
        case .unlink: EPERM
        case .barrier: ENOSPC
        case .close: EBADF
        }
    }
}

private func exerciseCapabilityProbe(failure: CapabilityProbeFailure?) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
        "ifl-open-unlinked-probe-\(UUID().uuidString)",
        isDirectory: true
    )
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    let directoryFD = Darwin.open(
        root.path,
        O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
    )
    #expect(directoryFD >= 0)
    defer { if directoryFD >= 0 { _ = Darwin.close(directoryFD) } }

    let trace = DurabilityCallTrace()
    let calls = capabilityProbeCalls(
        directoryFD: directoryFD,
        trace: trace,
        failure: failure
    )
    let barrier = DarwinDurabilityBarrier(systemCalls: calls)
    if let failure {
        #expect(throws: DurabilityBarrierError.ioFailure(failure.code)) {
            try barrier.validateCapability(in: directoryFD)
        }
    } else {
        try barrier.validateCapability(in: directoryFD)
    }

    #expect(trace.values == expectedCapabilityProbeTrace(failure: failure))
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
}

private func capabilityProbeCalls(
    directoryFD: Int32,
    trace: DurabilityCallTrace,
    failure: CapabilityProbeFailure?
) -> DurabilitySystemCalls {
    DurabilitySystemCalls(
        metadata: { fd in
            let metadata = try residualDescriptorMetadata(fd)
            if fd == directoryFD {
                _ = trace.record("metadata:directory")
            } else {
                _ = trace.record("metadata:probe:\(metadata.linkCount)")
            }
            return metadata
        },
        fsync: { fd in
            _ = trace.record(fd == directoryFD ? "fsync:directory" : "fsync:probe")
        },
        fullFSync: { _ in
            _ = trace.record("full:probe")
            if failure == .barrier {
                throw DarwinCallError.failure(CapabilityProbeFailure.barrier.code)
            }
        },
        write: { fd in
            _ = trace.record("write:probe")
            if failure == .write {
                throw DarwinCallError.failure(CapabilityProbeFailure.write.code)
            }
            try residualProbeWrite(fd)
        },
        unlink: { parentFD, name in
            let attempt = trace.record("unlink")
            if failure == .unlink, attempt == 1 {
                throw DarwinCallError.failure(CapabilityProbeFailure.unlink.code)
            }
            try residualProbeUnlink(parentFD, name)
        },
        close: { fd in
            _ = trace.record("close:probe")
            let result = Darwin.close(fd)
            if failure == .close {
                throw DarwinCallError.failure(CapabilityProbeFailure.close.code)
            }
            guard result == 0 else { throw DarwinCallError.failure(errno) }
        }
    )
}

private func expectedCapabilityProbeTrace(
    failure: CapabilityProbeFailure?
) -> [String] {
    let complete = [
        "unlink",
        "metadata:probe:0",
        "write:probe",
        "metadata:directory",
        "metadata:probe:0",
        "fsync:directory",
        "fsync:probe",
        "full:probe",
        "metadata:directory",
        "metadata:probe:0",
        "close:probe",
    ]
    switch failure {
    case .none, .close:
        return complete
    case .write:
        return Array(complete.prefix(3)) + ["close:probe"]
    case .unlink:
        return ["unlink", "unlink", "close:probe"]
    case .barrier:
        return Array(complete.prefix(8)) + ["close:probe"]
    }
}
