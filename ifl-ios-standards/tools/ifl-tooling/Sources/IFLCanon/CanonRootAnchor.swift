import Darwin
import Foundation

package enum CanonDescriptorFailure: Error, Equatable {
    case integrityViolation(String)
}

extension CanonDescriptorFailure: CustomStringConvertible {
    package var description: String {
        switch self {
        case let .integrityViolation(reason):
            "Canon descriptor integrity violation: \(reason)"
        }
    }
}

package final class CanonRootAnchor: @unchecked Sendable {
    private let descriptor: CanonOwnedFileDescriptor
    private let snapshot: CanonFileSnapshot
    let retainedPluginIdentity: RetainedPluginRootIdentity?
    package let path: String

    var objectIdentity: CanonObjectIdentity {
        snapshot.objectIdentity
    }

    package init(
        duplicatingRootDirectoryDescriptor sourceDescriptor: Int32,
        path: String,
        retainedPluginIdentity: RetainedPluginRootIdentity? = nil
    ) throws {
        let duplicated = try canonDuplicateDescriptor(sourceDescriptor, path: path)
        let ownedDescriptor = CanonOwnedFileDescriptor(duplicated)
        let snapshot = try canonDescriptorSnapshot(duplicated, path: path)
        try canonValidateRootSnapshot(snapshot, path: path)

        descriptor = ownedDescriptor
        self.snapshot = snapshot
        self.retainedPluginIdentity = retainedPluginIdentity
        self.path = path
    }

    func duplicateRootDescriptor() throws -> CanonRootDescriptor {
        let duplicated = try canonDuplicateDescriptor(descriptor.rawValue, path: path)
        let ownedDescriptor = CanonOwnedFileDescriptor(duplicated)
        let current = try canonDescriptorSnapshot(duplicated, path: path)
        guard current.hasSameRootIdentity(as: snapshot) else {
            throw CanonDescriptorFailure.integrityViolation(
                "\(path) changed or crossed a descriptor-confined file boundary"
            )
        }
        try canonValidateRootSnapshot(current, path: path)
        return CanonRootDescriptor(
            descriptor: ownedDescriptor,
            path: path,
            snapshot: current,
            requiresPathBinding: false,
            retainedPluginIdentity: retainedPluginIdentity
        )
    }
}

struct CanonObjectIdentity: Hashable {
    let device: UInt64
    let inode: UInt64
}

final class CanonRootDescriptor {
    let descriptor: CanonOwnedFileDescriptor
    let path: String
    let snapshot: CanonFileSnapshot
    let retainedPluginIdentity: RetainedPluginRootIdentity?
    private let requiresPathBinding: Bool

    init(opening root: URL) throws {
        path = root.path
        let linkSnapshot = try canonRootLinkSnapshot(path: path)
        try canonValidateRootSnapshot(linkSnapshot, path: path)

        let rawDescriptor = try canonOpenRoot(path: path)
        let ownedDescriptor = CanonOwnedFileDescriptor(rawDescriptor)
        let openedSnapshot = try canonDescriptorSnapshot(rawDescriptor, path: path)
        guard openedSnapshot == linkSnapshot else {
            throw CanonDescriptorFailure.integrityViolation(
                "\(path) changed or crossed a descriptor-confined file boundary"
            )
        }
        try canonValidateRootSnapshot(openedSnapshot, path: path)

        descriptor = ownedDescriptor
        snapshot = openedSnapshot
        retainedPluginIdentity = nil
        requiresPathBinding = true
    }

    init(
        descriptor: CanonOwnedFileDescriptor,
        path: String,
        snapshot: CanonFileSnapshot,
        requiresPathBinding: Bool,
        retainedPluginIdentity: RetainedPluginRootIdentity?
    ) {
        self.descriptor = descriptor
        self.path = path
        self.snapshot = snapshot
        self.requiresPathBinding = requiresPathBinding
        self.retainedPluginIdentity = retainedPluginIdentity
    }

    func validateBinding() throws {
        let current = try canonDescriptorSnapshot(descriptor.rawValue, path: path)
        let descriptorMatches = requiresPathBinding
            ? current == snapshot
            : current.hasSameRootIdentity(as: snapshot)
        guard descriptorMatches else {
            throw CanonDescriptorFailure.integrityViolation(
                "\(path) changed or crossed a descriptor-confined file boundary"
            )
        }
        try canonValidateRootSnapshot(current, path: path)

        if requiresPathBinding {
            let link = try canonRootLinkSnapshot(path: path)
            guard link == snapshot else {
                throw CanonDescriptorFailure.integrityViolation(
                    "\(path) changed or crossed a descriptor-confined file boundary"
                )
            }
        }
    }
}

final class CanonOwnedFileDescriptor {
    let rawValue: Int32

    init(_ rawValue: Int32) {
        self.rawValue = rawValue
    }

    deinit {
        Darwin.close(rawValue)
    }
}

struct CanonFileSnapshot: Equatable {
    let device: UInt64
    let inode: UInt64
    let kind: mode_t
    let rawMode: mode_t
    let linkCount: UInt64
    let size: Int64
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64
    let changeSeconds: Int64
    let changeNanoseconds: Int64

    init(_ value: stat) {
        device = UInt64(value.st_dev)
        inode = UInt64(value.st_ino)
        kind = value.st_mode & mode_t(S_IFMT)
        rawMode = value.st_mode
        linkCount = UInt64(value.st_nlink)
        size = value.st_size
        modificationSeconds = Int64(value.st_mtimespec.tv_sec)
        modificationNanoseconds = Int64(value.st_mtimespec.tv_nsec)
        changeSeconds = Int64(value.st_ctimespec.tv_sec)
        changeNanoseconds = Int64(value.st_ctimespec.tv_nsec)
    }

    func hasSameRootIdentity(as other: CanonFileSnapshot) -> Bool {
        device == other.device
            && inode == other.inode
            && kind == other.kind
            && rawMode == other.rawMode
            && linkCount == other.linkCount
    }

    var objectIdentity: CanonObjectIdentity {
        CanonObjectIdentity(device: device, inode: inode)
    }

    var isRegularFile: Bool {
        kind == mode_t(S_IFREG)
    }
}

private func canonDuplicateDescriptor(_ descriptor: Int32, path: String) throws -> Int32 {
    while true {
        let duplicated = Darwin.fcntl(descriptor, F_DUPFD_CLOEXEC, 0)
        if duplicated >= 0 {
            return duplicated
        }
        if errno == EINTR {
            continue
        }
        throw CanonDescriptorFailure.integrityViolation(
            "\(path) cannot duplicate its retained Canon root descriptor"
        )
    }
}

private func canonOpenRoot(path: String) throws -> Int32 {
    while true {
        let descriptor = path.withCString {
            Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        if descriptor >= 0 {
            return descriptor
        }
        if errno == EINTR {
            continue
        }
        throw CanonDescriptorFailure.integrityViolation(
            "\(path) changed or crossed a descriptor-confined file boundary"
        )
    }
}

private func canonRootLinkSnapshot(path: String) throws -> CanonFileSnapshot {
    var value = stat()
    let result = path.withCString { Darwin.lstat($0, &value) }
    guard result == 0 else {
        throw CanonDescriptorFailure.integrityViolation(
            "\(path) changed or crossed a descriptor-confined file boundary"
        )
    }
    return CanonFileSnapshot(value)
}

func canonDescriptorSnapshot(_ descriptor: Int32, path: String) throws -> CanonFileSnapshot {
    var value = stat()
    guard Darwin.fstat(descriptor, &value) == 0 else {
        throw CanonDescriptorFailure.integrityViolation(
            "\(path) changed or crossed a descriptor-confined file boundary"
        )
    }
    return CanonFileSnapshot(value)
}

private func canonValidateRootSnapshot(_ snapshot: CanonFileSnapshot, path: String) throws {
    guard snapshot.kind == mode_t(S_IFDIR),
          snapshot.linkCount > 0,
          snapshot.rawMode & mode_t(S_ISUID | S_ISGID | S_ISVTX) == 0
    else {
        throw CanonDescriptorFailure.integrityViolation(
            "\(path) changed or crossed a descriptor-confined file boundary"
        )
    }
}
