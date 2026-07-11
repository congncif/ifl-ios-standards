import Darwin
import Foundation
import IFLContracts

public enum DurabilityDescriptorKind: String, Codable, Hashable, Sendable {
    case regularFile = "regular_file"
    case directory
    case symbolicLink = "symbolic_link"
    case other
}

enum DurabilityPurpose: String, Hashable, Sendable {
    case capabilityProbe = "capability_probe"
    case bootstrapComponent = "bootstrap_component"
    case bootstrapIdentity = "bootstrap_identity"
    case receiptParent = "receipt_parent"
    case journalIntent = "journal_intent"
    case payloadPublication = "payload_publication"
    case statePublication = "state_publication"
    case journalCompletion = "journal_completion"
    case epochPublication = "epoch_publication"
    case recoveryRollback = "recovery_rollback"
    case rollbackMarker = "rollback_marker"
    case recoveryCompletion = "recovery_completion"
    case namespaceCleanup = "namespace_cleanup"
}

enum DurabilityLinkRole: Hashable, Sendable {
    case persistent
    case controlledUnlinked
}

public struct DurabilityDescriptorMetadata: Hashable, Sendable {
    public let device: UInt64
    public let inode: UInt64
    public let kind: DurabilityDescriptorKind
    public let permissions: mode_t
    public let linkCount: UInt64

    public init(
        device: UInt64,
        inode: UInt64 = 0,
        kind: DurabilityDescriptorKind,
        permissions: mode_t = 0,
        linkCount: UInt64
    ) {
        self.device = device
        self.inode = inode
        self.kind = kind
        self.permissions = permissions
        self.linkCount = linkCount
    }
}

private enum DurabilityDescriptorOwner: @unchecked Sendable {
    case directory(DescriptorRelativeDirectory)
    case file(DescriptorRelativeFile)
}

private struct DurabilityExpectedIdentity: Hashable, Sendable {
    let device: UInt64
    let inode: UInt64
    let kind: DurabilityDescriptorKind

    init(_ metadata: DescriptorObjectMetadata) {
        device = metadata.device
        inode = metadata.inode
        switch metadata.kind {
        case .regularFile: kind = .regularFile
        case .directory: kind = .directory
        case .symbolicLink: kind = .symbolicLink
        case .other: kind = .other
        }
    }

    func matches(_ metadata: DurabilityDescriptorMetadata) -> Bool {
        device == metadata.device && inode == metadata.inode && kind == metadata.kind
    }
}

public struct DurabilityTarget: Hashable, @unchecked Sendable {
    public let fd: Int32
    public let kind: DurabilityDescriptorKind
    let linkRole: DurabilityLinkRole
    let requiredPermissions: mode_t?
    private let owner: DurabilityDescriptorOwner?
    private let expectedIdentity: DurabilityExpectedIdentity?

    init(
        fd: Int32,
        kind: DurabilityDescriptorKind,
        linkRole: DurabilityLinkRole = .persistent,
        requiredPermissions: mode_t? = nil
    ) {
        self.fd = fd
        self.kind = kind
        self.linkRole = linkRole
        self.requiredPermissions = requiredPermissions
        owner = nil
        expectedIdentity = nil
    }

    init(
        directory: DescriptorRelativeDirectory,
        requiredPermissions: mode_t? = nil
    ) {
        fd = directory.fd
        kind = .directory
        linkRole = .persistent
        self.requiredPermissions = requiredPermissions
        owner = .directory(directory)
        expectedIdentity = DurabilityExpectedIdentity(directory.metadata)
    }

    init(
        file: DescriptorRelativeFile,
        kind: DurabilityDescriptorKind = .regularFile,
        linkRole: DurabilityLinkRole = .persistent,
        requiredPermissions: mode_t? = nil
    ) {
        fd = file.fd
        self.kind = kind
        self.linkRole = linkRole
        self.requiredPermissions = requiredPermissions
        owner = .file(file)
        expectedIdentity = DurabilityExpectedIdentity(file.metadata)
    }

    public static func == (lhs: DurabilityTarget, rhs: DurabilityTarget) -> Bool {
        lhs.fd == rhs.fd
            && lhs.kind == rhs.kind
            && lhs.linkRole == rhs.linkRole
            && lhs.requiredPermissions == rhs.requiredPermissions
            && lhs.expectedIdentity == rhs.expectedIdentity
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(fd)
        hasher.combine(kind)
        hasher.combine(linkRole)
        hasher.combine(requiredPermissions)
        hasher.combine(expectedIdentity)
    }

    fileprivate func validatesExpectedIdentity(_ metadata: DurabilityDescriptorMetadata) -> Bool {
        withExtendedLifetime(owner) {
            expectedIdentity?.matches(metadata) ?? true
        }
    }
}

public struct DurabilityPlan: Hashable, Sendable {
    public let modified: [DurabilityTarget]
    public let requiredDirectoryFDs: Set<Int32>
    public let anchorFD: Int32
    let purpose: DurabilityPurpose

    init(
        modified: [DurabilityTarget],
        requiredDirectoryFDs: Set<Int32>,
        anchorFD: Int32,
        purpose: DurabilityPurpose = .payloadPublication
    ) throws {
        let byFD = Dictionary(grouping: modified, by: \.fd)
        let directoryFDs = Set(modified.filter { $0.kind == .directory }.map(\.fd))
        guard !modified.isEmpty,
              byFD.count == modified.count,
              byFD[anchorFD]?.first?.kind == .regularFile,
              directoryFDs == requiredDirectoryFDs,
              modified.allSatisfy({ $0.kind == .regularFile || $0.kind == .directory }),
              modified.allSatisfy({ target in
                  target.kind == .regularFile || target.linkRole == .persistent
              })
        else { throw DurabilityBarrierError.integrityViolation }
        self.modified = modified
        self.requiredDirectoryFDs = requiredDirectoryFDs
        self.anchorFD = anchorFD
        self.purpose = purpose
    }
}

public enum DurabilityBarrierError: Error, Equatable, Sendable {
    case blockedEnvironment
    case integrityViolation
    case ioFailure(Int32)

    public var exitCode: IFLExitCode {
        switch self {
        case .blockedEnvironment: .blockedEnvironment
        case .integrityViolation: .integrityViolation
        case .ioFailure: .internalError
        }
    }
}

protocol WorkflowDurabilityBarrier: Sendable {
    func validateCapability(in directoryFD: Int32) throws
    func synchronize(_ plan: DurabilityPlan) throws
}

enum DarwinCallError: Error, Equatable, Sendable {
    case interrupted
    case unsupported
    case failure(Int32)
}

struct DurabilitySystemCalls: @unchecked Sendable {
    let metadata: @Sendable (Int32) throws -> DurabilityDescriptorMetadata
    let fsync: @Sendable (Int32) throws -> Void
    let fullFSync: @Sendable (Int32) throws -> Void
    let write: @Sendable (Int32) throws -> Void
    let unlink: @Sendable (Int32, String) throws -> Void
    let close: @Sendable (Int32) throws -> Void

    init(
        metadata: @escaping @Sendable (Int32) throws -> DurabilityDescriptorMetadata,
        fsync: @escaping @Sendable (Int32) throws -> Void,
        fullFSync: @escaping @Sendable (Int32) throws -> Void
    ) {
        self.init(
            metadata: metadata,
            fsync: fsync,
            fullFSync: fullFSync,
            write: DurabilitySystemCalls.liveProbeWrite,
            unlink: DurabilitySystemCalls.liveUnlink,
            close: DurabilitySystemCalls.liveClose
        )
    }

    init(
        metadata: @escaping @Sendable (Int32) throws -> DurabilityDescriptorMetadata,
        fsync: @escaping @Sendable (Int32) throws -> Void,
        fullFSync: @escaping @Sendable (Int32) throws -> Void,
        write: @escaping @Sendable (Int32) throws -> Void,
        unlink: @escaping @Sendable (Int32, String) throws -> Void,
        close: @escaping @Sendable (Int32) throws -> Void
    ) {
        self.metadata = metadata
        self.fsync = fsync
        self.fullFSync = fullFSync
        self.write = write
        self.unlink = unlink
        self.close = close
    }

    static let live = DurabilitySystemCalls(
        metadata: { fd in
            var value = stat()
            guard Darwin.fstat(fd, &value) == 0 else {
                if errno == EINTR { throw DarwinCallError.interrupted }
                throw DarwinCallError.failure(errno)
            }
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
        },
        fsync: { fd in
            guard Darwin.fsync(fd) == 0 else {
                if errno == EINTR { throw DarwinCallError.interrupted }
                throw DarwinCallError.failure(errno)
            }
        },
        fullFSync: { fd in
            guard Darwin.fcntl(fd, F_FULLFSYNC) == 0 else {
                if errno == EINTR { throw DarwinCallError.interrupted }
                if errno == ENOTSUP || errno == EINVAL || errno == ENOSYS {
                    throw DarwinCallError.unsupported
                }
                throw DarwinCallError.failure(errno)
            }
        },
        write: DurabilitySystemCalls.liveProbeWrite,
        unlink: DurabilitySystemCalls.liveUnlink,
        close: DurabilitySystemCalls.liveClose
    )

    private static func liveProbeWrite(_ fd: Int32) throws {
        var byte: UInt8 = 0x0A
        let result = Darwin.write(fd, &byte, 1)
        guard result == 1 else {
            if result < 0, errno == EINTR { throw DarwinCallError.interrupted }
            throw DarwinCallError.failure(result < 0 ? errno : EIO)
        }
    }

    private static func liveUnlink(_ directoryFD: Int32, _ name: String) throws {
        let result = name.withCString { unlinkat(directoryFD, $0, 0) }
        guard result == 0 else {
            if errno == EINTR { throw DarwinCallError.interrupted }
            throw DarwinCallError.failure(errno)
        }
    }

    private static func liveClose(_ fd: Int32) throws {
        guard Darwin.close(fd) == 0 else {
            if errno == EINTR { throw DarwinCallError.interrupted }
            throw DarwinCallError.failure(errno)
        }
    }
}

public struct DarwinDurabilityBarrier: WorkflowDurabilityBarrier, Sendable {
    private let systemCalls: DurabilitySystemCalls

    public init() {
        systemCalls = .live
    }

    init(systemCalls: DurabilitySystemCalls) {
        self.systemCalls = systemCalls
    }

    func validateCapability(in directoryFD: Int32) throws {
        let name = ".durability-probe-\(UUID().uuidString.lowercased())"
        let probeFD = try name.withCString { pointer -> Int32 in
            while true {
                let result = openat(
                    directoryFD,
                    pointer,
                    O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK,
                    0o600
                )
                if result >= 0 { return result }
                if errno == EINTR { continue }
                throw mapCallError(.failure(errno))
            }
        }
        var primaryError: Error?
        var unlinkSucceeded = false
        do {
            try retrying { try systemCalls.unlink(directoryFD, name) }
            unlinkSucceeded = true
            let observed = try retrying { try systemCalls.metadata(probeFD) }
            guard observed.kind == .regularFile,
                  observed.permissions == 0o600,
                  observed.linkCount == 0
            else { throw DurabilityBarrierError.integrityViolation }
            try retrying { try systemCalls.write(probeFD) }
            let plan = try DurabilityPlan(
                modified: [
                    DurabilityTarget(fd: directoryFD, kind: .directory),
                    DurabilityTarget(
                        fd: probeFD,
                        kind: .regularFile,
                        linkRole: .controlledUnlinked,
                        requiredPermissions: 0o600
                    ),
                ],
                requiredDirectoryFDs: [directoryFD],
                anchorFD: probeFD,
                purpose: .capabilityProbe
            )
            try synchronize(plan)
        } catch {
            primaryError = error
            if !unlinkSucceeded {
                do {
                    try retrying { try systemCalls.unlink(directoryFD, name) }
                    unlinkSucceeded = true
                } catch {
                    // Preserve the primary failure while still making cleanup explicit.
                }
            }
        }

        do {
            try systemCalls.close(probeFD)
        } catch {
            if primaryError == nil { primaryError = error }
        }
        if let primaryError { throw normalizedBarrierError(primaryError) }
    }

    func synchronize(_ plan: DurabilityPlan) throws {
        var before: [Int32: DurabilityDescriptorMetadata] = [:]
        for target in plan.modified {
            let value = try retrying { try systemCalls.metadata(target.fd) }
            try validate(value, for: target)
            before[target.fd] = value
        }
        guard let anchor = before[plan.anchorFD],
              anchor.kind == .regularFile,
              before.values.allSatisfy({ $0.device == anchor.device }),
              plan.requiredDirectoryFDs.allSatisfy({ before[$0]?.kind == .directory })
        else { throw DurabilityBarrierError.integrityViolation }

        for target in plan.modified {
            try retrying { try systemCalls.fsync(target.fd) }
        }
        try retrying { try systemCalls.fullFSync(plan.anchorFD) }

        for target in plan.modified {
            let value = try retrying { try systemCalls.metadata(target.fd) }
            try validate(value, for: target)
            guard value == before[target.fd] else {
                throw DurabilityBarrierError.integrityViolation
            }
        }
    }

    private func validate(
        _ value: DurabilityDescriptorMetadata,
        for target: DurabilityTarget
    ) throws {
        guard value.kind == target.kind,
              target.validatesExpectedIdentity(value),
              target.requiredPermissions.map({ value.permissions == $0 }) ?? true
        else { throw DurabilityBarrierError.integrityViolation }
        switch target.linkRole {
        case .persistent:
            guard target.kind == .directory || value.linkCount == 1 else {
                throw DurabilityBarrierError.integrityViolation
            }
        case .controlledUnlinked:
            guard target.kind == .regularFile, value.linkCount == 0 else {
                throw DurabilityBarrierError.integrityViolation
            }
        }
    }

    private func retrying(_ operation: () throws -> Void) throws {
        while true {
            do {
                try operation()
                return
            } catch DarwinCallError.interrupted {
                continue
            } catch let error as DarwinCallError {
                throw mapCallError(error)
            } catch let error as DurabilityBarrierError {
                throw error
            } catch {
                throw DurabilityBarrierError.ioFailure(EIO)
            }
        }
    }

    private func retrying<T>(_ operation: () throws -> T) throws -> T {
        while true {
            do {
                return try operation()
            } catch DarwinCallError.interrupted {
                continue
            } catch let error as DarwinCallError {
                throw mapCallError(error)
            } catch let error as DurabilityBarrierError {
                throw error
            } catch {
                throw DurabilityBarrierError.ioFailure(EIO)
            }
        }
    }
}

private func normalizedBarrierError(_ error: Error) -> DurabilityBarrierError {
    if let error = error as? DurabilityBarrierError { return error }
    if let error = error as? DarwinCallError { return mapCallError(error) }
    return .ioFailure(EIO)
}

private func mapCallError(_ error: DarwinCallError) -> DurabilityBarrierError {
    switch error {
    case .interrupted:
        .ioFailure(EINTR)
    case .unsupported:
        .blockedEnvironment
    case let .failure(code):
        .ioFailure(code)
    }
}
